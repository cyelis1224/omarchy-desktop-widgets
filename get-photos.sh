#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import urllib.parse

IMAGE_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif')
STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
LEGACY_CONFIG = os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/settings.json')

DEFAULT_DIRS = [
    os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/photos'),
    os.path.expanduser('~/Wallpapers'),
    os.path.expanduser('~/.config/omarchy/backgrounds'),
    os.path.expanduser('~/Pictures')
]

def load_settings():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    elif os.path.exists(LEGACY_CONFIG):
        try:
            with open(LEGACY_CONFIG, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    return {"gallery_folder": "ALL"}

def save_settings(settings):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(STATE_FILE, 'w') as f:
            json.dump(settings, f, indent=2)
    except Exception:
        pass

def pick_folder_dialog():
    try:
        p = subprocess.run(
            ['zenity', '--file-selection', '--directory', '--title=Select Photo Gallery Folder'],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.strip()
    except Exception:
        pass
    return None

def find_images(target_dir):
    images = []
    seen = set()

    if target_dir == "ALL" or not target_dir:
        search_dirs = DEFAULT_DIRS
    else:
        search_dirs = [os.path.expanduser(target_dir)]

    for d in search_dirs:
        if not os.path.exists(d):
            continue
        try:
            for root, _, files in os.walk(d):
                for f in sorted(files):
                    ext = os.path.splitext(f)[1].lower()
                    if ext in IMAGE_EXTENSIONS:
                        full_path = os.path.join(root, f)
                        try:
                            if not os.path.isfile(full_path):
                                continue
                            size = os.path.getsize(full_path)
                            if size < 5000:
                                continue
                        except Exception:
                            continue

                        if full_path not in seen:
                            seen.add(full_path)
                            base_name = os.path.splitext(f)[0].replace('_', ' ').replace('-', ' ')
                            title = ' '.join(word.capitalize() for word in base_name.split()[:4])
                            images.append({
                                "path": "file://" + urllib.parse.quote(full_path),
                                "raw_path": full_path,
                                "title": title,
                                "filename": f
                            })
        except Exception:
            pass

    return images

def main():
    settings = load_settings()
    current_folder = settings.get("gallery_folder", "ALL")

    if len(sys.argv) > 1:
        arg = sys.argv[1].strip()
        if arg == "pick_dialog":
            chosen = pick_folder_dialog()
            if chosen:
                current_folder = chosen
                settings["gallery_folder"] = current_folder
                save_settings(settings)
        elif arg:
            current_folder = arg
            settings["gallery_folder"] = current_folder
            save_settings(settings)

    imgs = find_images(current_folder)
    print(json.dumps({"type": "init", "folder": current_folder, "total": len(imgs)}), flush=True)
    for img in imgs:
        payload = {"type": "photo"}
        payload.update(img)
        print(json.dumps(payload), flush=True)
    print(json.dumps({"type": "done"}), flush=True)

if __name__ == '__main__':
    main()
