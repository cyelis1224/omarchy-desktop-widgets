#!/usr/bin/env bash
# check-update.sh - Check and apply updates for omarchy-desktop-widgets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIVE_DIR="$HOME/.config/omarchy/plugins/dagyr.desktop-widgets"
DEV_DIR="$HOME/Projects/desktop-widgets"
REMOTE_REPO_URL="https://github.com/cyelis1224/omarchy-desktop-widgets.git"
RAW_MANIFEST_URL="https://raw.githubusercontent.com/cyelis1224/omarchy-desktop-widgets/master/manifest.json"
MOCK_FLAG_FILE="/tmp/omarchy-desktop-widgets-mock-update"

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}"

find_repo_dir() {
  if [[ -d "$PLUGIN_DIR/.git" ]]; then
    echo "$PLUGIN_DIR"
  elif [[ -d "$LIVE_DIR/.git" ]]; then
    echo "$LIVE_DIR"
  elif [[ -d "$DEV_DIR/.git" ]]; then
    echo "$DEV_DIR"
  else
    echo ""
  fi
}

cmd_mock_on() {
  cat <<'EOF' > "$MOCK_FLAG_FILE"
{
  "new_version": "1.1.0",
  "new_commit": "4c8f2a1",
  "commits_behind": 3,
  "commit_message": "Feature: interactive widget resizing & update indicator"
}
EOF
  echo "Mock update mode ENABLED."
}

cmd_mock_off() {
  rm -f "$MOCK_FLAG_FILE"
  echo "Mock update mode DISABLED."
}

cmd_check() {
  local local_version="1.0.0"
  if [[ -f "$PLUGIN_DIR/manifest.json" ]]; then
    local_version=$(jq -r '.version // "1.0.0"' "$PLUGIN_DIR/manifest.json" 2>/dev/null || echo "1.0.0")
  fi

  local repo_dir
  repo_dir=$(find_repo_dir)

  local local_commit=""
  local local_short=""
  if [[ -n "$repo_dir" ]]; then
    local_commit=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)
    local_short=$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)
  fi

  # Check if simulated mock update is active
  if [[ -f "$MOCK_FLAG_FILE" ]]; then
    local mock_data
    mock_data=$(cat "$MOCK_FLAG_FILE" 2>/dev/null || echo "{}")
    local mock_ver
    mock_ver=$(echo "$mock_data" | jq -r '.new_version // "1.1.0"')
    local mock_cmt
    mock_cmt=$(echo "$mock_data" | jq -r '.new_commit // "f4a8b29"')
    local mock_behind
    mock_behind=$(echo "$mock_data" | jq -r '.commits_behind // 2')
    local mock_msg
    mock_msg=$(echo "$mock_data" | jq -r '.commit_message // "Photo gallery resize & update indicator"')

    jq -c -n \
      --arg ua "true" \
      --arg cv "$local_version" \
      --arg cc "${local_short:-dev}" \
      --arg nv "$mock_ver" \
      --arg nc "$mock_cmt" \
      --argjson cb "$mock_behind" \
      --arg msg "$mock_msg" \
      --arg repo "${repo_dir:-$PLUGIN_DIR}" \
      --argjson mock "true" \
      '{
        update_available: true,
        current_version: $cv,
        current_commit: $cc,
        new_version: $nv,
        new_commit: $nc,
        commits_behind: $cb,
        commit_message: $msg,
        repo_dir: $repo,
        is_mock: $mock
      }'
    return 0
  fi

  local remote_commit=""
  local remote_short=""
  local remote_version="$local_version"
  local commits_behind=0
  local commit_msg=""
  local update_available="false"

  # Fast git check if repo exists
  if [[ -n "$repo_dir" ]]; then
    timeout 8 git -C "$repo_dir" fetch --quiet origin master 2>/dev/null || timeout 8 git -C "$repo_dir" fetch --quiet 2>/dev/null || true
    remote_commit=$(git -C "$repo_dir" rev-parse FETCH_HEAD 2>/dev/null || git -C "$repo_dir" rev-parse origin/master 2>/dev/null || true)
    if [[ -n "$remote_commit" ]]; then
      remote_short=$(git -C "$repo_dir" rev-parse --short "$remote_commit" 2>/dev/null || true)
      commits_behind=$(git -C "$repo_dir" rev-list --count HEAD.."$remote_commit" 2>/dev/null || echo 0)
      commit_msg=$(git -C "$repo_dir" log -1 --format="%s" "$remote_commit" 2>/dev/null || echo "")
    fi
  fi

  # Network fallback if git fetch was empty
  if [[ -z "$remote_commit" ]]; then
    local ls_out
    ls_out=$(timeout 8 git ls-remote "$REMOTE_REPO_URL" refs/heads/master 2>/dev/null || true)
    if [[ -n "$ls_out" ]]; then
      remote_commit=$(echo "$ls_out" | awk '{print $1}')
      remote_short="${remote_commit:0:7}"
    fi
  fi

  # Attempt to extract remote manifest version directly from git commit
  if [[ -n "$repo_dir" && -n "$remote_commit" ]]; then
    local git_ver
    git_ver=$(git -C "$repo_dir" show "$remote_commit:manifest.json" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)
    if [[ -n "$git_ver" ]]; then
      remote_version="$git_ver"
    fi
  fi

  # Network fallback if git manifest was not extracted
  if [[ "$remote_version" == "$local_version" ]]; then
    local remote_manifest
    remote_manifest=$(curl -s --max-time 4 "${RAW_MANIFEST_URL}?v=$(date +%s)" 2>/dev/null || true)
    if [[ -n "$remote_manifest" ]]; then
      local parsed_ver
      parsed_ver=$(echo "$remote_manifest" | jq -r '.version // empty' 2>/dev/null || true)
      if [[ -n "$parsed_ver" ]]; then
        remote_version="$parsed_ver"
      fi
    fi
  fi

  # Compare versions / commits
  if (( commits_behind > 0 )); then
    update_available="true"
  elif [[ -n "$remote_version" && "$remote_version" != "$local_version" ]]; then
    if [[ "$(printf '%s\n%s' "$local_version" "$remote_version" | sort -V | tail -n1)" == "$remote_version" ]]; then
      update_available="true"
    fi
  elif [[ -z "$repo_dir" && -n "$remote_commit" && "$remote_commit" != "$local_commit" ]]; then
    update_available="true"
  fi

  if [[ -z "$commit_msg" && "$update_available" == "true" ]]; then
    commit_msg="Update available: $local_version → $remote_version"
  fi

  jq -c -n \
    --argjson ua "$update_available" \
    --arg cv "$local_version" \
    --arg cc "${local_short:-HEAD}" \
    --arg nv "$remote_version" \
    --arg nc "${remote_short:-HEAD}" \
    --argjson cb "$commits_behind" \
    --arg msg "$commit_msg" \
    --arg repo "${repo_dir:-$PLUGIN_DIR}" \
    --argjson mock "false" \
    '{
      update_available: $ua,
      current_version: $cv,
      current_commit: $cc,
      new_version: $nv,
      new_commit: $nc,
      commits_behind: $cb,
      commit_message: $msg,
      repo_dir: $repo,
      is_mock: $mock
    }'
}

cmd_apply() {
  echo "Applying desktop widgets update..."

  # If in mock mode, disable it and restart
  if [[ -f "$MOCK_FLAG_FILE" ]]; then
    rm -f "$MOCK_FLAG_FILE"
    echo "Cleared mock update state."
  fi

  local repo_dir
  repo_dir=$(find_repo_dir)

  if [[ -n "$repo_dir" && -d "$repo_dir/.git" ]]; then
    echo "Updating git repository at $repo_dir..."
    git -C "$repo_dir" pull --ff-only origin master 2>&1 || git -C "$repo_dir" pull origin master 2>&1 || true
  fi

  # Sync DEV_DIR to LIVE_DIR if needed
  if [[ -d "$DEV_DIR" && -d "$LIVE_DIR" && "$DEV_DIR" != "$LIVE_DIR" ]]; then
    echo "Syncing $DEV_DIR to $LIVE_DIR..."
    rsync -a --exclude='.git' "$DEV_DIR/" "$LIVE_DIR/" 2>/dev/null || cp -r "$DEV_DIR/"* "$LIVE_DIR/" 2>/dev/null || true
  fi

  # Validate
  if command -v omarchy-plugin-validate >/dev/null 2>&1; then
    omarchy-plugin-validate "$LIVE_DIR" || true
  fi

  # Rescan and restart shell
  echo "Reloading Omarchy shell..."
  if command -v omarchy-restart-shell >/dev/null 2>&1; then
    omarchy-restart-shell
  elif command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi

  echo '{"success": true, "message": "Updated and reloaded successfully"}'
}

case "${1:-check}" in
  check)
    cmd_check
    ;;
  apply)
    cmd_apply
    ;;
  mock-on)
    cmd_mock_on
    ;;
  mock-off)
    cmd_mock_off
    ;;
  status)
    cmd_check
    ;;
  *)
    echo "Usage: $0 [check|apply|mock-on|mock-off|status]"
    exit 1
    ;;
esac
