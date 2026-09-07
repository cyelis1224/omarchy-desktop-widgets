#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import mimetypes
import shutil

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

    name = entry.get('Name', os.path.basename(filepath))
    icon = entry.get('Icon', 'application-x-executable')
    raw_exec = entry.get('Exec', '')
    clean_exec = raw_exec
    for param in ('%u', '%U', '%f', '%F', '%i', '%c', '%k'):
        clean_exec = clean_exec.replace(param, '')
    clean_exec = clean_exec.strip()

    terminal = entry.get('Terminal', '').lower() == 'true'

    return {
        "name": name,
        "icon": icon,
        "exec": clean_exec,
        "raw_exec": raw_exec,
        "terminal": terminal
    }

def format_size(size_bytes):
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"

def get_file_icon(filename, is_dir):
    if is_dir:
        return "folder"
    ext = os.path.splitext(filename)[1].lower()
    if ext in ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp'):
        return "image-x-generic"
    elif ext in ('.mp4', '.mkv', '.webm', '.avi', '.mov'):
        return "video-x-generic"
    elif ext in ('.mp3', '.flac', '.wav', '.ogg', '.m4a'):
        return "audio-x-generic"
    elif ext in ('.zip', '.tar', '.gz', '.xz', '.7z', '.bz2', '.zst'):
        return "package-x-generic"
    elif ext in ('.py', '.sh', '.bash', '.js', '.ts', '.qml', '.json', '.c', '.cpp', '.rs', '.go', '.html', '.css'):
        return "text-x-script"
    elif ext in ('.pdf', '.doc', '.docx', '.odt', '.md', '.txt'):
        return "x-office-document"
    else:
        return "text-x-generic"

def list_folder(folder_path):
    expanded = os.path.expanduser(folder_path)
    if not os.path.exists(expanded):
        try:
            os.makedirs(expanded, exist_ok=True)
        except Exception:
            expanded = os.path.expanduser("~")

    real_path = os.path.realpath(expanded)
    folder_name = os.path.basename(real_path) or "/"
    parent_path = os.path.dirname(real_path)

    items = []
    try:
        with os.scandir(real_path) as entries:
            for entry in entries:
                # Skip hidden files starting with .
                if entry.name.startswith('.'):
                    continue

                full_path = entry.path
                is_dir = entry.is_dir(follow_symlinks=True)
                is_desktop = entry.name.endswith('.desktop') and not is_dir

                try:
                    stat = entry.stat(follow_symlinks=True)
                    size_str = format_size(stat.st_size) if not is_dir else ""
                    mtime = int(stat.st_mtime)
                except Exception:
                    size_str = ""
                    mtime = 0

                display_name = entry.name
                app_icon = get_file_icon(entry.name, is_dir)
                app_exec = ""
                terminal = False

                if is_desktop:
                    desktop_info = parse_desktop_file(full_path)
                    if desktop_info:
                        display_name = desktop_info["name"]
                        app_icon = desktop_info["icon"]
                        app_exec = desktop_info["exec"]
                        terminal = desktop_info["terminal"]

                items.append({
                    "name": entry.name,
                    "display_name": display_name,
                    "path": full_path,
                    "is_dir": is_dir,
                    "is_desktop": is_desktop,
                    "icon": app_icon,
                    "exec": app_exec,
                    "terminal": terminal,
                    "size": size_str,
                    "mtime": mtime
                })
    except Exception as e:
        pass

    # Sort: folders first, then desktop apps / files alphabetically
    items.sort(key=lambda x: (not x['is_dir'], x['display_name'].lower()))

    print(json.dumps({
        "status": "ok",
        "folder": real_path,
        "folder_name": folder_name,
        "parent": parent_path,
        "items": items
    }))

def open_item(target_path):
    if not target_path or not os.path.exists(target_path):
        print(json.dumps({"status": "error", "error": "file does not exist"}))
        return

    if target_path.endswith('.desktop'):
        desktop_info = parse_desktop_file(target_path)
        if desktop_info and desktop_info.get("exec"):
            cmd = desktop_info["exec"]
            if desktop_info.get("terminal"):
                # Run in terminal
                subprocess.Popen(f"xdg-terminal-exec {cmd} || alacritty -e {cmd} || foot {cmd} || kitty {cmd}", shell=True)
            else:
                subprocess.Popen(cmd, shell=True)
            print(json.dumps({"status": "launched", "path": target_path}))
            return

    # Default xdg-open
    try:
        subprocess.Popen(["xdg-open", target_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"status": "opened", "path": target_path}))
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}))

def pick_folder_dialog():
    omarchy_select = shutil.which('omarchy-file-select')
    if omarchy_select:
        try:
            p = subprocess.run(
                [omarchy_select, '--title', 'Select Desktop Folder', '--directory'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip().splitlines()[0]
            elif p.returncode != 0:
                return None
        except Exception:
            pass

    zenity = shutil.which('zenity')
    if zenity:
        try:
            p = subprocess.run(
                [zenity, '--file-selection', '--directory', '--title=Select Desktop Folder'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    kdialog = shutil.which('kdialog')
    if kdialog:
        try:
            p = subprocess.run(
                [kdialog, '--title', 'Select Desktop Folder', '--getexistingdirectory'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    return None

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "pick":
        picked = pick_folder_dialog()
        if picked and os.path.isdir(picked):
            list_folder(picked)
        else:
            print(json.dumps({"status": "cancelled"}))
    elif len(sys.argv) > 2 and sys.argv[1] == "open":
        open_item(sys.argv[2])
    else:
        target = sys.argv[1] if len(sys.argv) > 1 else "~/Desktop"
        list_folder(target)
