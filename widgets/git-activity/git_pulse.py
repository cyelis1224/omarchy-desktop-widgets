#!/usr/bin/env python3
import subprocess
import os
import sys
import datetime
import json
import re
import shutil

STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
CACHE_DIR = os.path.expanduser('~/.cache/omarchy/git-remotes')

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

def is_remote_url(path):
    if not path or not isinstance(path, str):
        return False
    p = path.strip()
    return p.startswith('http://') or p.startswith('https://') or p.startswith('git@') or p.startswith('ssh://')

def get_remote_slug(url):
    clean = re.sub(r'^(https?://|git@|ssh://)', '', url.strip())
    clean = clean.replace(':', '/').rstrip('/')
    if clean.endswith('.git'):
        clean = clean[:-4]
    return re.sub(r'[^a-zA-Z0-9_\-\.]', '_', clean)

def get_remote_name(url):
    clean = re.sub(r'^(https?://|git@|ssh://)', '', url.strip())
    clean = clean.replace(':', '/').rstrip('/')
    if clean.endswith('.git'):
        clean = clean[:-4]
    parts = [p for p in clean.split('/') if p]
    if len(parts) >= 2:
        return f"{parts[-2]}/{parts[-1]}"
    return parts[-1] if parts else url

def sync_remote_repo(url):
    os.makedirs(CACHE_DIR, exist_ok=True)
    slug = get_remote_slug(url)
    repo_cache_dir = os.path.join(CACHE_DIR, slug)

    if not os.path.exists(repo_cache_dir):
        # Initial bare shallow clone
        cmd = ['git', 'clone', '--bare', '--depth=200', '--single-branch', url, repo_cache_dir]
        p = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=25)
        if p.returncode != 0:
            if os.path.exists(repo_cache_dir):
                shutil.rmtree(repo_cache_dir, ignore_errors=True)
            return None
    else:
        # Fast background fetch
        try:
            cmd = ['git', '-C', repo_cache_dir, 'fetch', '--depth=200']
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        except Exception:
            pass

    return repo_cache_dir

def pick_repo_dialog():
    try:
        p = subprocess.run(
            ['zenity', '--file-selection', '--directory', '--title=Select Local Git Repository'],
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

def pick_remote_url_dialog():
    try:
        p = subprocess.run(
            ['zenity', '--entry', '--title=Track Remote Git Repository',
             '--text=Enter Git repository URL (e.g. https://github.com/owner/repo):'],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
        if p.returncode == 0 and p.stdout.strip():
            chosen = p.stdout.strip()
            if is_remote_url(chosen):
                return chosen
    except Exception:
        pass
    return None

def find_repos(custom_repos=None):
    repos = []
    seen = set()

    # ONLY show repositories the user has added themselves (local paths or remote URLs)
    if custom_repos:
        for cr in custom_repos:
            if not cr or cr in seen:
                continue

            if is_remote_url(cr):
                seen.add(cr)
                cached = os.path.join(CACHE_DIR, get_remote_slug(cr))
                repos.append({
                    "name": get_remote_name(cr),
                    "path": cr,
                    "is_remote": True,
                    "cache_path": cached if os.path.exists(cached) else None,
                    "category": "Remote URL"
                })
            elif os.path.exists(cr) and os.path.exists(os.path.join(cr, '.git')):
                seen.add(cr)
                repos.append({
                    "name": os.path.basename(cr),
                    "path": cr,
                    "is_remote": False,
                    "cache_path": cr,
                    "category": "Local Repo"
                })

    return sorted(repos, key=lambda r: r["name"].lower())

def get_git_data(repo_path, all_repos=None, num_weeks=12):
    today = datetime.date.today()
    days_to_sat = (5 - today.weekday()) % 7
    end_date = today + datetime.timedelta(days=days_to_sat)
    total_days = num_weeks * 7
    start_date = end_date - datetime.timedelta(days=total_days - 1)

    is_all_mode = (repo_path == "ALL")
    target_items = (all_repos or []) if is_all_mode else ([r for r in (all_repos or []) if r["path"] == repo_path])

    # Default empty heatmap matrix template
    matrix = []
    curr = start_date
    while curr <= end_date:
        d_str = curr.isoformat()
        matrix.append({
            "date": d_str,
            "day": curr.strftime('%a'),
            "count": 0,
            "level": 0,
            "is_today": (d_str == today.isoformat())
        })
        curr += datetime.timedelta(days=1)

    if not target_items:
        return {
            "repo_name": "No Tracked Repositories",
            "repo_path": "",
            "is_remote": False,
            "is_all_mode": False,
            "has_repos": False,
            "branch": "none",
            "uncommitted_count": 0,
            "status_label": "clean",
            "total_commits": 0,
            "streak_days": 0,
            "heatmap": matrix,
            "recent_commits": []
        }

    # Resolve paths (local or remote cache)
    valid_targets = []
    for item in target_items:
        p = item["path"]
        if item.get("is_remote"):
            cache = sync_remote_repo(p)
            if cache and os.path.exists(cache):
                valid_targets.append((item, cache))
        else:
            if os.path.exists(p) and os.path.exists(os.path.join(p, '.git')):
                valid_targets.append((item, p))

    if not valid_targets:
        return {
            "repo_name": target_items[0]["name"] if target_items else "Unknown Repo",
            "repo_path": target_items[0]["path"] if target_items else "",
            "is_remote": bool(target_items[0].get("is_remote")) if target_items else False,
            "is_all_mode": is_all_mode,
            "has_repos": True,
            "branch": "connecting...",
            "uncommitted_count": 0,
            "status_label": "offline",
            "total_commits": 0,
            "streak_days": 0,
            "heatmap": matrix,
            "recent_commits": []
        }

    # Aggregate commit counts by date
    commit_counts = {}
    for item, query_path in valid_targets:
        try:
            cmd = ['git', '-C', query_path, 'log', f'--since={start_date.isoformat()}', '--date=short', '--pretty=format:%ad']
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            for line in proc.stdout.splitlines():
                d = line.strip()
                if d:
                    commit_counts[d] = commit_counts.get(d, 0) + 1
        except Exception:
            pass

    # Update counts and levels in heatmap matrix
    for cell in matrix:
        count = commit_counts.get(cell["date"], 0)
        cell["count"] = count
        if count >= 6:
            cell["level"] = 4
        elif count >= 4:
            cell["level"] = 3
        elif count >= 2:
            cell["level"] = 2
        elif count >= 1:
            cell["level"] = 1

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

    primary_item, primary_path = valid_targets[0]
    is_remote = primary_item.get("is_remote", False)
    branch = "all repos" if is_all_mode else "master"
    uncommitted = 0
    status_label = "remote" if is_remote else "clean"
    recent_commits = []

    if not is_all_mode:
        if is_remote:
            # For bare remote cache, query symbolic-ref HEAD or rev-parse
            try:
                proc = subprocess.run(['git', '-C', primary_path, 'symbolic-ref', '--short', 'HEAD'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                b = proc.stdout.strip()
                if b:
                    branch = b
            except Exception:
                pass
        else:
            # For local repos, query active branch & uncommitted porcelain status
            try:
                proc = subprocess.run(['git', '-C', primary_path, 'branch', '--show-current'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                b = proc.stdout.strip()
                if b:
                    branch = b
            except Exception:
                pass

            try:
                proc = subprocess.run(['git', '-C', primary_path, 'status', '--porcelain'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                lines = [l for l in proc.stdout.splitlines() if l.strip()]
                uncommitted = len(lines)
                status_label = f"{uncommitted} diffs" if uncommitted > 0 else "clean"
            except Exception:
                pass

        try:
            proc = subprocess.run(['git', '-C', primary_path, 'log', '-n', '3', '--pretty=format:%h|%cr|%s'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
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
        for item, query_path in valid_targets:
            try:
                proc = subprocess.run(['git', '-C', query_path, 'log', '-n', '2', '--pretty=format:%h|%cr|%s'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                for l in proc.stdout.splitlines():
                    parts = l.split('|', 2)
                    if len(parts) == 3:
                        recent_commits.append({
                            "hash": parts[0],
                            "time": parts[1],
                            "msg": f"[{item['name']}] {parts[2]}"
                        })
            except Exception:
                pass
        recent_commits = recent_commits[:4]

    return {
        "repo_name": "All Repositories (Combined)" if is_all_mode else primary_item["name"],
        "repo_path": "ALL" if is_all_mode else primary_item["path"],
        "is_remote": is_remote,
        "is_all_mode": is_all_mode,
        "has_repos": True,
        "branch": branch,
        "uncommitted_count": uncommitted,
        "status_label": status_label,
        "total_commits": sum(commit_counts.values()),
        "streak_days": streak,
        "heatmap": matrix,
        "recent_commits": recent_commits
    }

def main():
    settings = load_settings()
    custom_repos = settings.get("git_custom_repos", [])

    # Handle argument to switch active repository, remove, or open picker dialog
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
        elif req == "pick_remote_dialog":
            chosen = pick_remote_url_dialog()
            if chosen:
                sync_remote_repo(chosen)
                if chosen not in custom_repos:
                    custom_repos.append(chosen)
                    settings["git_custom_repos"] = custom_repos
                settings["git_active_repo"] = chosen
                save_settings(settings)
        elif req.startswith("remove:"):
            target_to_remove = req[7:].strip()
            if target_to_remove in custom_repos:
                custom_repos = [r for r in custom_repos if r != target_to_remove]
                settings["git_custom_repos"] = custom_repos
                # If remote URL, clean up cached bare clone
                if is_remote_url(target_to_remove):
                    c_path = os.path.join(CACHE_DIR, get_remote_slug(target_to_remove))
                    if os.path.exists(c_path):
                        shutil.rmtree(c_path, ignore_errors=True)
            if settings.get("git_active_repo") == target_to_remove:
                settings["git_active_repo"] = custom_repos[0] if custom_repos else ""
            save_settings(settings)
        elif req == "ALL":
            settings["git_active_repo"] = "ALL"
            save_settings(settings)
        elif is_remote_url(req):
            sync_remote_repo(req)
            if req not in custom_repos:
                custom_repos.append(req)
                settings["git_custom_repos"] = custom_repos
            settings["git_active_repo"] = req
            save_settings(settings)
        elif os.path.exists(req) and os.path.exists(os.path.join(req, '.git')):
            if req not in custom_repos:
                custom_repos.append(req)
                settings["git_custom_repos"] = custom_repos
            settings["git_active_repo"] = req
            save_settings(settings)

    detected_repos = find_repos(custom_repos)

    active_repo = settings.get("git_active_repo", "")
    if active_repo == "ALL":
        if not detected_repos:
            active_repo = ""
    elif not active_repo or not any(r["path"] == active_repo for r in detected_repos):
        active_repo = detected_repos[0]["path"] if detected_repos else ""
        settings["git_active_repo"] = active_repo
        save_settings(settings)

    data = get_git_data(active_repo, detected_repos)
    data["detected_repos"] = detected_repos
    print(json.dumps(data))

if __name__ == "__main__":
    main()
