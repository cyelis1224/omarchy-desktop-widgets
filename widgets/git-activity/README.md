# 🌿 Git Contribution Radar & Repo Pulse (`GitActivityWidget`)

A developer desktop widget for Omarchy and Hyprland displaying GitHub-style commit activity, repository branch status, streak metrics, and recent commit history across local projects.

## Features
- **12-Week Contribution Matrix**: 84-day grid showing commit density (Levels 0–4) with glowing emerald/mint cells and interactive hover tooltips (date + commit count).
- **Active Repository Status**:
  - Live branch detection.
  - Uncommitted changes pill counter (`+N diffs` / `clean`).
  - Daily commit streak calculation.
  - Total commits metric.
- **Recent Commit Timeline**:
  - Displays the last 3 commits with short hashes, relative timestamps, and commit messages.
- **Robust Right-Click Context Menu**:
  - **Active Repository Switcher**: Live list of all detected local git repositories in `~/Projects` and `~/.config/omarchy/plugins`. Selecting one immediately updates the radar.
  - **Display Preferences**: Toggle recent commits timeline.
  - **Actions**:
    - *Open Repo in Terminal*: Launches `xdg-terminal-exec` inside the active repository.
    - *Refresh Git Pulse*: Manually re-scan git logs.
  - **Layout Management**: Standard Lock/Unlock layout, Widget Selector, and Reset Layout controls.

## Architecture
- `GitActivityWidget.qml`: Interactive user interface inheriting `WidgetCard`.
- `git_pulse.py`: High-performance Python backend analyzing git status and logs.
