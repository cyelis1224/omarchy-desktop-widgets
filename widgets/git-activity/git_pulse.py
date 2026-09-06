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

def pick_repo_dialog():
    try:
        p = subprocess.run(
            ['zenity', '--file-selection', '--directory', '--title=Select Git Repository to Track'],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
        if p.returncode == 0 and p.stdout.strip():
            chosen = p.stdout.strip()
            if os.path.exists(os.path.join(chosen, '.git')):
                return chosen
    except Exception:
        pass
    return None

def find_repos(custom_repos=None):
    search_dirs = [
        os.path.expanduser('~/Projects'),
        os.path.expanduser('~/.config/omarchy/plugins')
    ]
    repos = []
    seen = set()

    # 1. Custom user-added repositories
    if custom_repos:
        for cr in custom_repos:
            if os.path.exists(cr) and os.path.exists(os.path.join(cr, '.git')) and cr not in seen:
                seen.add(cr)
                repos.append({
                    "name": os.path.basename(cr),
                    "path": cr,
                    "category": "Custom"
                })

    # 2. Automatically discovered repositories
    for sdir in search_dirs:
        if os.path.exists(sdir):
            for root, dirs, files in os.walk(sdir):
                if '.git' in dirs:
                    dirs.remove('.git')
                    if root not in seen:
                        seen.add(root)
                        repos.append({
                            "name": os.path.basename(root),
                            "path": root,
                            "category": "Projects" if "Projects" in root else "Plugins"
                        })

    return sorted(repos, key=lambda r: (0 if r["category"] == "Custom" else 1, r["name"].lower()))

def get_git_data(repo_path, all_repos=None, num_weeks=12):
    today = datetime.date.today()
    days_to_sat = (5 - today.weekday()) % 7
    end_date = today + datetime.timedelta(days=days_to_sat)
    total_days = num_weeks * 7
    start_date = end_date - datetime.timedelta(days=total_days - 1)

    is_all_mode = (repo_path == "ALL")
    target_repos = [r["path"] for r in (all_repos or [])] if is_all_mode else [repo_path]
    if not target_repos and not is_all_mode:
        target_repos = [os.path.expanduser('~/Projects/desktop-widgets')]

    # Aggregate commit counts by date
    commit_counts = {}
    for rp in target_repos:
        if not os.path.exists(rp) or not os.path.exists(os.path.join(rp, '.git')):
            continue
        try:
            cmd = ['git', '-C', rp, 'log', f'--since={start_date.isoformat()}', '--date=short', '--pretty=format:%ad']
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
            if chk == today:
                chk -= datetime.timedelta(days=1)
                continue
            break

    # Branch and uncommitted status for primary repo
    primary_repo = target_repos[0] if target_repos else os.path.expanduser('~/Projects/desktop-widgets')
    branch = "all repos" if is_all_mode else "unknown"
    uncommitted = 0
    recent_commits = []

    if not is_all_mode and os.path.exists(primary_repo):
        try:
            proc = subprocess.run(['git', '-C', primary_repo, 'branch', '--show-current'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            b = proc.stdout.strip()
            if b:
                branch = b
        except Exception:
            pass

        try:
            proc = subprocess.run(['git', '-C', primary_repo, 'status', '--porcelain'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            lines = [l for l in proc.stdout.splitlines() if l.strip()]
            uncommitted = len(lines)
        except Exception:
            pass

        try:
            proc = subprocess.run(['git', '-C', primary_repo, 'log', '-n', '3', '--pretty=format:%h|%cr|%s'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
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
    elif is_all_mode:
        # Collect recent commits across all repos
        for rp in target_repos:
            try:
                proc = subprocess.run(['git', '-C', rp, 'log', '-n', '2', '--pretty=format:%h|%cr|%s'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                for l in proc.stdout.splitlines():
                    parts = l.split('|', 2)
                    if len(parts) == 3:
                        recent_commits.append({
                            "hash": parts[0],
                            "time": parts[1],
                            "msg": f"[{os.path.basename(rp)}] {parts[2]}"
                        })
            except Exception:
                pass
        recent_commits = recent_commits[:4]

    return {
        "repo_name": "All Projects (Aggregate)" if is_all_mode else os.path.basename(primary_repo),
        "repo_path": "ALL" if is_all_mode else primary_repo,
        "is_all_mode": is_all_mode,
        "branch": branch,
        "uncommitted_count": uncommitted,
        "total_commits": sum(commit_counts.values()),
        "streak_days": streak,
        "heatmap": matrix,
        "recent_commits": recent_commits
    }

def main():
    settings = load_settings()
    custom_repos = settings.get("git_custom_repos", [])

    # Handle argument to switch active repository or open picker dialog
    if len(sys.argv) > 1 and sys.argv[1].strip():
        req = sys.argv[1].strip()
        if req == "pick_dialog":
            chosen = pick_repo_dialog()
            if chosen:
                if chosen not in custom_repos:
                    custom_repos.append(chosen)
                    settings["git_custom_repos"] = custom_repos
                settings["git_active_repo"] = chosen
                save_settings(settings)
        elif req == "ALL" or os.path.exists(req):
            settings["git_active_repo"] = req
            save_settings(settings)

    detected_repos = find_repos(custom_repos)

    active_repo = settings.get("git_active_repo", "")
    if not active_repo or (active_repo != "ALL" and not os.path.exists(active_repo)):
        default_repo = os.path.expanduser('~/Projects/desktop-widgets')
        if os.path.exists(default_repo):
            active_repo = default_repo
        elif detected_repos:
            active_repo = detected_repos[0]["path"]
        else:
            active_repo = "ALL"

    data = get_git_data(active_repo, detected_repos)
    data["detected_repos"] = detected_repos
    print(json.dumps(data))

if __name__ == "__main__":
    main()
