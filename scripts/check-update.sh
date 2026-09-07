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

version_gt() {
  # returns 0 (true) if $1 is strictly newer than $2
  [[ -n "$1" && -n "$2" && "$1" != "$2" && "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

find_repo_dir() {
  if [[ -d "$LIVE_DIR/.git" ]]; then
    echo "$LIVE_DIR"
  elif [[ -d "$PLUGIN_DIR/.git" ]]; then
    echo "$PLUGIN_DIR"
  elif [[ -d "$DEV_DIR/.git" ]]; then
    echo "$DEV_DIR"
  else
    echo ""
  fi
}

cmd_mock_on() {
  cat <<'EOF' > "$MOCK_FLAG_FILE"
{
  "new_version": "1.2.0",
  "new_commit": "4c8f2a1",
  "commits_behind": 3,
  "commit_message": "Feature: interactive widget resizing & changelog viewer",
  "release_title": "v1.2.0 - Complete Widget Suite & Changelog Viewer",
  "release_notes": "### 🚀 Major Highlights\n- **In-App Changelog Viewer**: Read full release notes before updating.\n- **Layout Management**: Save and revert widget configurations at any time.\n- **Interactive Resizing**: Live dimension pills and 20px grid snapping.\n\n### 🛠️ Improvements & Fixes\n- Smoother animations and refined hover states.\n- Fixed file selector dialog and network interface discovery.",
  "release_url": "https://github.com/cyelis1224/omarchy-desktop-widgets/releases/tag/v1.2.0",
  "published_at": "2026-09-07T18:00:00Z"
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
  if [[ -d "$DEV_DIR" && -f "$DEV_DIR/manifest.json" ]]; then
    local dev_ver
    dev_ver=$(jq -r '.version // empty' "$DEV_DIR/manifest.json" 2>/dev/null || true)
    if [[ -n "$dev_ver" && "$dev_ver" != "$local_version" ]]; then
      if version_gt "$local_version" "$dev_ver"; then
        local_version="$dev_ver"
      fi
    fi
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
    mock_ver=$(echo "$mock_data" | jq -r '.new_version // "1.2.0"')
    local mock_cmt
    mock_cmt=$(echo "$mock_data" | jq -r '.new_commit // "f4a8b29"')
    local mock_behind
    mock_behind=$(echo "$mock_data" | jq -r '.commits_behind // 2')
    local mock_msg
    mock_msg=$(echo "$mock_data" | jq -r '.commit_message // "Photo gallery resize & update indicator"')
    local mock_title
    mock_title=$(echo "$mock_data" | jq -r '.release_title // "v1.2.0 - New Features"')
    local mock_notes
    mock_notes=$(echo "$mock_data" | jq -r '.release_notes // "Release notes mock"')
    local mock_url
    mock_url=$(echo "$mock_data" | jq -r '.release_url // "https://github.com/cyelis1224/omarchy-desktop-widgets/releases"')
    local mock_pub
    mock_pub=$(echo "$mock_data" | jq -r '.published_at // "2026-09-07T18:00:00Z"')

    jq -c -n \
      --arg ua "true" \
      --arg cv "$local_version" \
      --arg cc "${local_short:-dev}" \
      --arg nv "$mock_ver" \
      --arg nc "$mock_cmt" \
      --argjson cb "$mock_behind" \
      --arg msg "$mock_msg" \
      --arg rt "$mock_title" \
      --arg rn "$mock_notes" \
      --arg ru "$mock_url" \
      --arg rp "$mock_pub" \
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
        release_title: $rt,
        release_notes: $rn,
        release_url: $ru,
        published_at: $rp,
        repo_dir: $repo,
        is_mock: $mock
      }'
    return 0
  fi

  local remote_commit=""
  local remote_short=""
  local remote_version=""
  local commits_behind=0
  local commit_msg=""
  local update_available="false"
  local release_title=""
  local release_notes=""
  local release_url=""
  local release_published=""

  # 1. Query GitHub Releases API for official release info & changelog
  local gh_release_json=""
  if command -v gh >/dev/null 2>&1; then
    gh_release_json=$(gh api repos/cyelis1224/omarchy-desktop-widgets/releases/latest 2>/dev/null || true)
  fi
  if [[ -z "$gh_release_json" ]]; then
    gh_release_json=$(curl -s --max-time 8 -H "User-Agent: Omarchy-Desktop-Widgets" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/cyelis1224/omarchy-desktop-widgets/releases/latest" 2>/dev/null || true)
  fi

  if [[ -n "$gh_release_json" && "$gh_release_json" != *"Not Found"* && "$gh_release_json" != *"API rate limit"* ]]; then
    local release_tag
    release_tag=$(echo "$gh_release_json" | jq -r '.tag_name // empty' 2>/dev/null || true)
    if [[ -n "$release_tag" ]]; then
      remote_version="${release_tag#v}"
      release_title=$(echo "$gh_release_json" | jq -r '.name // empty' 2>/dev/null || true)
      release_notes=$(echo "$gh_release_json" | jq -r '.body // empty' 2>/dev/null || true)
      release_url=$(echo "$gh_release_json" | jq -r '.html_url // empty' 2>/dev/null || true)
      release_published=$(echo "$gh_release_json" | jq -r '.published_at // empty' 2>/dev/null || true)
      commit_msg="${release_title:-Update to $release_tag}"
    fi
  fi

  # 2. Fast git check to fetch commits & count commits_behind
  if [[ -n "$repo_dir" ]]; then
    timeout 8 git -C "$repo_dir" fetch --quiet origin master 2>/dev/null || timeout 8 git -C "$repo_dir" fetch --quiet 2>/dev/null || true
    remote_commit=$(git -C "$repo_dir" rev-parse FETCH_HEAD 2>/dev/null || git -C "$repo_dir" rev-parse origin/master 2>/dev/null || true)
    if [[ -n "$remote_commit" ]]; then
      remote_short=$(git -C "$repo_dir" rev-parse --short "$remote_commit" 2>/dev/null || true)
      commits_behind=$(git -C "$repo_dir" rev-list --count HEAD.."$remote_commit" 2>/dev/null || echo 0)
      if [[ -z "$commit_msg" ]]; then
        commit_msg=$(git -C "$repo_dir" log -1 --format="%s" "$remote_commit" 2>/dev/null || echo "")
      fi

      # Fallback version extraction from git if GitHub Release was not available
      if [[ -z "$remote_version" ]]; then
        local git_ver
        git_ver=$(git -C "$repo_dir" show "$remote_commit:manifest.json" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)
        if [[ -n "$git_ver" ]]; then
          remote_version="$git_ver"
        fi
      fi

      # Fallback changelog from git commit messages if no release notes
      if [[ -z "$release_notes" && "$commits_behind" -gt 0 ]]; then
        release_notes=$(git -C "$repo_dir" log -n 5 --pretty=format:"- %s" HEAD.."$remote_commit" 2>/dev/null || true)
      fi
    fi
  fi

  # Fallback ONLY if git and GitHub API both could not resolve remote version
  if [[ -z "$remote_version" ]]; then
    if [[ -z "$remote_commit" ]]; then
      local ls_out
      ls_out=$(timeout 8 git ls-remote "$REMOTE_REPO_URL" refs/heads/master 2>/dev/null || true)
      if [[ -n "$ls_out" ]]; then
        remote_commit=$(echo "$ls_out" | awk '{print $1}')
        remote_short="${remote_commit:0:7}"
      fi
    fi

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

  # If remote_version could still not be determined, default to local_version
  if [[ -z "$remote_version" ]]; then
    remote_version="$local_version"
  fi

  if [[ -z "$release_title" ]]; then
    release_title="Release v$remote_version"
  fi
  if [[ -z "$release_url" ]]; then
    release_url="https://github.com/cyelis1224/omarchy-desktop-widgets/releases"
  fi

  # STRICT UPDATE CHECK:
  # 1. An update is available ONLY if remote_version is strictly newer than local_version.
  # 2. If the local commit is already identical to the remote commit (commits_behind == 0),
  #    we are already on the target commit.
  if version_gt "$remote_version" "$local_version"; then
    update_available="true"
  elif [[ -n "$repo_dir" && -n "$local_commit" && -n "$remote_commit" && "$local_commit" == "$remote_commit" && "$commits_behind" -eq 0 ]]; then
    update_available="false"
  else
    update_available="false"
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
    --arg rt "$release_title" \
    --arg rn "$release_notes" \
    --arg ru "$release_url" \
    --arg rp "$release_published" \
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
      release_title: $rt,
      release_notes: $rn,
      release_url: $ru,
      published_at: $rp,
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

  # If LIVE_DIR is a git repository, fetch and reset to ensure a clean sync
  if [[ -d "$LIVE_DIR/.git" ]]; then
    echo "Updating live plugin git repository at $LIVE_DIR..."
    git -C "$LIVE_DIR" fetch --quiet origin master 2>&1 || true
    git -C "$LIVE_DIR" reset --hard origin/master 2>&1 || true
    git -C "$LIVE_DIR" clean -fd 2>&1 || true
  fi

  # If DEV_DIR is separate and git-managed, pull it
  if [[ -d "$DEV_DIR/.git" && "$DEV_DIR" != "$LIVE_DIR" ]]; then
    echo "Updating dev repository at $DEV_DIR..."
    git -C "$DEV_DIR" pull --ff-only origin master 2>&1 || git -C "$DEV_DIR" pull origin master 2>&1 || true
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
