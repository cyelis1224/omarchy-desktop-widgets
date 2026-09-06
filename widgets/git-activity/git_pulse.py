#!/usr/bin/env python3
import subprocess
import os
import sys
import datetime
import json

STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')

def load_settings():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_settings(settings):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(STATE_FILE, 'w') as f:
            json.dump(settings, f, indent=2)
    except Exception:
        pass

def find_repos():
    search_dirs = [
        os.path.expanduser('~/Projects'),
        os.path.expanduser('~/.config/omarchy/plugins')
    ]
    repos = []
    for sdir in search_dirs:
        if os.path.exists(sdir):
            for root, dirs, files in os.walk(sdir):
                if '.git' in dirs:
                    dirs.remove('.git')
                    name = os.path.basename(root)
                    repos.append({
                        "name": name,
                        "path": root,
                        "category": "Projects" if "Projects" in root else "Plugins"
                    })
    return sorted(repos, key=lambda r: r["name"].lower())

def get_git_data(repo_path, num_weeks=12):
    if not os.path.exists(repo_path) or not os.path.exists(os.path.join(repo_path, '.git')):
        repo_path = os.path.expanduser('~/Projects/desktop-widgets')

    today = datetime.date.today()
    days_to_sat = (5 - today.weekday()) % 7
    end_date = today + datetime.timedelta(days=days_to_sat)
    total_days = num_weeks * 7
    start_date = end_date - datetime.timedelta(days=total_days - 1)

    # Commits by date
    commit_counts = {}
    try:
        cmd = ['git', '-C', repo_path, 'log', f'--since={start_date.isoformat()}', '--date=short', '--pretty=format:%ad']
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for line in proc.stdout.splitlines():
            d = line.strip()
            if d:
                commit_counts[d] = commit_counts.get(d, 0) + 1
    except Exception:
        pass

    # Heatmap matrix
    matrix = []
    curr = start_date
    current_streak = 0
    counting_streak = True
    temp_date = today

    while curr <= end_date:
        d_str = curr.isoformat()
        count = commit_counts.get(d_str, 0)
        level = 0
        if count >= 6:
            level = 4
        elif count >= 4:
            level = 3
        elif count >= 2:
            level = 2
        elif count >= 1:
            level = 1

        matrix.append({
            "date": d_str,
            "day": curr.strftime('%a'),
            "count": count,
            "level": level,
            "is_today": (d_str == today.isoformat())
        })
        curr += datetime.timedelta(days=1)

    # Calculate streak backwards from today
    streak = 0
    chk = today
    while True:
        d_str = chk.isoformat()
        if commit_counts.get(d_str, 0) > 0:
            streak += 1
            chk -= datetime.timedelta(days=1)
        else:
            # If today has 0 commits, check if yesterday had commits (streak still alive)
            if chk == today:
                chk -= datetime.timedelta(days=1)
                continue
            break

    # Branch
    branch = "unknown"
    try:
        proc = subprocess.run(['git', '-C', repo_path, 'branch', '--show-current'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        b = proc.stdout.strip()
        if b:
            branch = b
    except Exception:
        pass

    # Uncommitted status
    uncommitted = 0
    try:
        proc = subprocess.run(['git', '-C', repo_path, 'status', '--porcelain'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        lines = [l for l in proc.stdout.splitlines() if l.strip()]
        uncommitted = len(lines)
    except Exception:
        pass

    # Recent Commits
    recent_commits = []
    try:
        proc = subprocess.run(['git', '-C', repo_path, 'log', '-n', '3', '--pretty=format:%h|%cr|%s'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for l in proc.stdout.splitlines():
            parts = l.split('|', 2)
            if len(parts) == 3:
                recent_commits.append({
                    "hash": parts[0],
                    "time": parts[1],
                    "msg": parts[2]
                })
    except Exception:
        pass

    return {
        "repo_name": os.path.basename(repo_path),
        "repo_path": repo_path,
        "branch": branch,
        "uncommitted_count": uncommitted,
        "total_commits": sum(commit_counts.values()),
        "streak_days": streak,
        "heatmap": matrix,
        "recent_commits": recent_commits
    }

def main():
    settings = load_settings()
    detected_repos = find_repos()

    # Handle argument to switch active repository
    if len(sys.argv) > 1 and sys.argv[1].strip():
        req = sys.argv[1].strip()
        if os.path.exists(req):
            settings["git_active_repo"] = req
            save_settings(settings)

    active_repo = settings.get("git_active_repo", "")
    if not active_repo or not os.path.exists(active_repo):
        default_repo = os.path.expanduser('~/Projects/desktop-widgets')
        if os.path.exists(default_repo):
            active_repo = default_repo
        elif detected_repos:
            active_repo = detected_repos[0]["path"]

    data = get_git_data(active_repo)
    data["detected_repos"] = detected_repos
    print(json.dumps(data))

if __name__ == "__main__":
    main()
