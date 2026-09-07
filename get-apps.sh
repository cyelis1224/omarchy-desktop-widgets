#!/usr/bin/env python3
import os
import sys
import glob
import json
import subprocess

APP_DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/local/share/applications",
    "/usr/share/applications",
    "/var/lib/flatpak/exports/share/applications"
]

def parse_desktop_file(filepath):
    entry = {}
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            in_entry = False
            for line in f:
                line = line.strip()
                if line == '[Desktop Entry]':
                    in_entry = True
                    continue
                elif line.startswith('[') and line.endswith(']'):
                    in_entry = False
                if in_entry and '=' in line:
                    k, v = line.split('=', 1)
                    k = k.strip()
                    if k not in entry:
                        entry[k] = v.strip()
    except Exception:
        return None

    # Filter invalid or hidden applications
    if entry.get('Type') and entry.get('Type') != 'Application':
        return None
    if entry.get('NoDisplay', '').lower() == 'true':
        return None
    if not entry.get('Name') or not entry.get('Exec'):
        return None

    name = entry.get('Name', '')
    comment = entry.get('Comment', entry.get('GenericName', ''))
    icon = entry.get('Icon', 'application-x-executable')
    raw_exec = entry.get('Exec', '')
    # Strip %u, %U, %f, %F parameters
    clean_exec = raw_exec
    for param in ('%u', '%U', '%f', '%F', '%i', '%c', '%k'):
        clean_exec = clean_exec.replace(param, '')
    clean_exec = clean_exec.strip()

    terminal = entry.get('Terminal', '').lower() == 'true'
    categories_str = entry.get('Categories', '')
    category = "Other"
    cats = categories_str.split(';')
    if any(c in ('Network', 'WebBrowser', 'Email', 'Chat', 'IRCClient') for c in cats):
        category = "Internet"
    elif any(c in ('Development', 'IDE', 'Debugger', 'TextEditor', 'GUIDesigner') for c in cats):
        category = "Dev"
    elif any(c in ('AudioVideo', 'Audio', 'Video', 'Player', 'Recorder', 'Music') for c in cats):
        category = "Media"
    elif any(c in ('System', 'Settings', 'PackageManager', 'Monitor', 'HardwareSettings') for c in cats):
        category = "System"
    elif any(c in ('Office', 'Spreadsheet', 'WordProcessor', 'Presentation', 'Publishing') for c in cats):
        category = "Productivity"
    elif any(c in ('Game', 'ActionGame', 'AdventureGame', 'ArcadeGame', 'Emulator') for c in cats):
        category = "Games"
    elif any(c in ('Utility', 'Archiving', 'Calculator', 'Compression', 'FileTools', 'TerminalEmulator') for c in cats):
        category = "Utilities"

    filename = os.path.basename(filepath)
    app_id = filename[:-8] if filename.endswith('.desktop') else filename

    return {
        "id": app_id,
        "name": name,
        "comment": comment,
        "icon": icon,
        "exec": clean_exec,
        "raw_exec": raw_exec,
        "category": category,
        "terminal": terminal,
        "path": filepath
    }

def list_apps():
    seen_ids = set()
    apps = []

    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(glob.glob(os.path.join(d, "*.desktop"))):
            base = os.path.basename(f)
            app_id = base[:-8] if base.endswith('.desktop') else base
            if app_id in seen_ids:
                continue
            item = parse_desktop_file(f)
            if item:
                seen_ids.add(app_id)
                apps.append(item)

    apps.sort(key=lambda x: x['name'].lower())
    print(json.dumps(apps))

def launch_app(app_id_or_exec):
    # Try gtk-launch first if it's an app id
    if not app_id_or_exec:
        return
    if " " not in app_id_or_exec and not os.path.exists(app_id_or_exec):
        try:
            subprocess.Popen(["gtk-launch", app_id_or_exec], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(json.dumps({"status": "launched", "target": app_id_or_exec}))
            return
        except Exception:
            pass

    # Fallback to direct shell execution detached
    try:
        subprocess.Popen(app_id_or_exec, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"status": "launched", "target": app_id_or_exec}))
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}))

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "launch":
        launch_app(sys.argv[2])
    else:
        list_apps()
