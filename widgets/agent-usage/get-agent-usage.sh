#!/usr/bin/env bash
# Agent usage feed for the Agent Usage desktop widget.
#
#   get-agent-usage.sh            print every usage record as one JSON array
#   get-agent-usage.sh refresh    re-run the collectors, then print
#   get-agent-usage.sh force      same, but skip the collectors' caches
#   get-agent-usage.sh profiles   list the extra accounts that were found
#
# Records come from Omarchy's own collectors (omarchy-agent-usage-update writes
# ~/.local/state/omarchy/agents/usage/<agent>.json for the default ~/.claude
# and ~/.codex). Every extra account — a second Claude Code or Codex login in
# its own config directory — is collected with CLAUDE_CONFIG_DIR / CODEX_HOME
# pointed at it and written next to the stock records, so the stock Agents bar
# panel shows those accounts too.
#
# Extra accounts are discovered automatically from ~/.claude-* and ~/.codex-*
# directories, plus any CLAUDE_CONFIG_DIR= / CODEX_HOME= paths in your shell rc
# files. To pin the list instead, create ~/.config/omarchy/agents/profiles.conf
# with one "kind|id|Display name|config dir" line per account, e.g.
#   claude|claude-work|Claude Work|~/.claude-work
#   codex|codex-personal|Codex Personal|~/.codex-personal

set -uo pipefail

USAGE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage"
PROFILES_FILE="${AGENT_USAGE_PROFILES:-$HOME/.config/omarchy/agents/profiles.conf}"
mode="${1:-read}"

title_case() {
  local out="" word
  for word in ${1//[-_.]/ }; do out+="${word^} "; done
  printf '%s' "${out% }"
}

# kind|id|name|dir for one extra config directory; nothing for the defaults.
profile_line() {
  local kind="$1" dir="${2%/}" base slug label
  dir="${dir/#\~/$HOME}"
  dir="${dir//\$HOME/$HOME}"
  dir="${dir//\$\{HOME\}/$HOME}"
  [[ -d $dir ]] || return 0
  case $kind in
    claude) [[ $dir == "$HOME/.claude" ]] && return 0
            [[ -f $dir/.credentials.json || -d $dir/projects ]] || return 0
            label="Claude" ;;
    codex)  [[ $dir == "$HOME/.codex" ]] && return 0
            [[ -f $dir/auth.json || -d $dir/sessions ]] || return 0
            label="Codex" ;;
  esac
  base="${dir##*/}"
  slug="${base#.}"
  slug="${slug#"$kind"}"
  slug="${slug#[-_.]}"
  [[ -n $slug ]] || slug="$(basename "$(dirname "$dir")")"
  slug="$(tr '[:upper:]' '[:lower:]' <<<"$slug" | tr -c 'a-z0-9\n' '-')"
  printf '%s|%s-%s|%s %s|%s\n' "$kind" "$kind" "$slug" "$label" "$(title_case "$slug")" "$dir"
}

discover_profiles() {
  local dir path
  shopt -s nullglob
  for dir in "$HOME"/.claude-*/; do profile_line claude "$dir"; done
  for dir in "$HOME"/.codex-*/; do profile_line codex "$dir"; done
  shopt -u nullglob
  # Accounts kept elsewhere usually show up as an alias or export in a shell rc.
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    [[ -f $rc ]] || continue
    grep -oE 'CLAUDE_CONFIG_DIR[= ]+"?[^" ;]+' "$rc" | sed -E 's/^CLAUDE_CONFIG_DIR[= ]+"?//' |
      while read -r path; do profile_line claude "$path"; done
    grep -oE 'CODEX_HOME[= ]+"?[^" ;]+' "$rc" | sed -E 's/^CODEX_HOME[= ]+"?//' |
      while read -r path; do profile_line codex "$path"; done
  done
}

profiles() {
  if [[ -f $PROFILES_FILE ]]; then
    grep -v '^[[:space:]]*\(#\|$\)' "$PROFILES_FILE"
  else
    discover_profiles | awk -F'|' '!seen[$4]++'
  fi
}

collect_profile() {
  local kind="$1" id="$2" name="$3" dir="$4" record tmp collector var
  local flags=()
  [[ $mode == force ]] && flags+=(--force)
  dir="${dir/#\~/$HOME}"
  [[ -d $dir ]] || return 0
  case $kind in
    claude) collector=omarchy-agent-usage-claude; var=CLAUDE_CONFIG_DIR ;;
    codex)  collector=omarchy-agent-usage-codex;  var=CODEX_HOME ;;
    *) return 0 ;;
  esac

  # A private cache root keeps this account's cached rate limits from
  # overwriting the default account's (the collectors key some caches by name).
  record=$(env -u CLAUDE_CONFIG_DIR -u CODEX_HOME \
    XDG_CACHE_HOME="$HOME/.cache/omarchy/agent-profiles/$id" "$var=$dir" \
    "$collector" "${flags[@]}" 2>/dev/null) || return 0
  jq -e . >/dev/null 2>&1 <<<"$record" || return 0

  tmp=$(mktemp "$USAGE_DIR/.$id.XXXXXX")
  jq --arg id "$id" --arg name "$name" --arg kind "$kind" --arg dir "$dir" \
    '.id = $id | .name = $name | .kind = $kind | .configDir = $dir' <<<"$record" >"$tmp" &&
    mv "$tmp" "$USAGE_DIR/$id.json"
}

if [[ $mode == profiles ]]; then
  profiles
  exit 0
fi

if [[ $mode == refresh || $mode == force ]]; then
  mkdir -p "$USAGE_DIR"
  update_flags=()
  [[ $mode == force ]] && update_flags+=(--force)
  # The stock collectors cover the default accounts; never let an inherited
  # CLAUDE_CONFIG_DIR / CODEX_HOME point them at an extra one.
  env -u CLAUDE_CONFIG_DIR -u CODEX_HOME omarchy-agent-usage-update "${update_flags[@]}" >/dev/null 2>&1 &
  while IFS='|' read -r kind id name dir; do
    [[ -n $kind && -n $id && -n $dir ]] && collect_profile "$kind" "$id" "${name:-$id}" "$dir" &
  done < <(profiles)
  wait
fi

# Print every record, tagged with its tool (kind) and signed-in account email
# so the widget can tell two logins of the same tool apart.
python3 - "$USAGE_DIR" <<'PY'
import base64, glob, json, os, sys

home = os.path.expanduser("~")

def load(path):
  try:
    with open(path, encoding="utf-8") as f:
      return json.load(f)
  except Exception:
    return None

def claude_account(config_dir):
  # Claude Code keeps the login in <dir>/.claude.json, or ~/.claude.json for
  # the default profile.
  for path in ([os.path.join(config_dir, ".claude.json")] if config_dir else []) + [os.path.join(home, ".claude.json")]:
    data = load(path) or {}
    email = (data.get("oauthAccount") or {}).get("emailAddress")
    if email:
      return email
    if config_dir:
      break
  return ""

def codex_account(config_dir):
  data = load(os.path.join(config_dir or os.path.join(home, ".codex"), "auth.json")) or {}
  token = (data.get("tokens") or {}).get("id_token") or ""
  try:
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload)).get("email", "")
  except Exception:
    return ""

records = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
  rec = load(path)
  if not isinstance(rec, dict) or not rec.get("id"):
    continue
  rid = rec["id"]
  kind = rec.get("kind") or next((k for k in ("claude", "codex") if rid == k or rid.startswith(k + "-")), rid)
  rec["kind"] = kind
  config_dir = rec.get("configDir") or ""
  if kind == "claude":
    rec["account"] = claude_account(config_dir)
  elif kind == "codex":
    rec["account"] = codex_account(config_dir)
  else:
    rec.setdefault("account", "")
  records.append(rec)

print(json.dumps(records, separators=(",", ":")))
PY
