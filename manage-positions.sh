#!/usr/bin/env python3
import sys
import os
import json
import shutil
import subprocess
import copy

STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
LEGACY_CONFIG = os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/settings.json')

DEFAULT_ENABLED = ["clock", "gallery", "network", "media", "system"]

BUILTIN_MIGRATION = {
    "GitActivityWidget.qml": "git_activity",
    "HardwareTelemetryWidget.qml": "hardware_telemetry",
    "PomodoroWidget.qml": "pomodoro",
    "QuickNotesWidget.qml": "quick_notes",
    "WeatherWidget.qml": "weather",
    "AppLauncherWidget.qml": "app_launcher",
    "FolderViewWidget.qml": "folder_view"
}

BUILTIN_PROFILES = {
    "Default": {
        "name": "Default",
        "description": "Standard balanced desktop setup with clock, photo deck, network sparklines, media, and system specs.",
        "enabled_widgets": ["clock", "gallery", "network", "media", "system"],
        "positions": {
            "clock": {"x": 700, "y": 20},
            "gallery": {"x": 20, "y": 40, "w": 360, "h": 220},
            "network": {"x": 1520, "y": 40, "w": 360, "h": 180},
            "media": {"x": 1520, "y": 240, "w": 360, "h": 120},
            "system": {"x": 1520, "y": 860, "w": 360, "h": 200}
        }
    },
    "Minimal": {
        "name": "Minimal",
        "description": "Clean, distraction-free glance layout featuring only the centerpiece clock and weather forecast.",
        "enabled_widgets": ["clock", "weather"],
        "positions": {
            "clock": {"x": 700, "y": 40},
            "weather": {"x": 790, "y": 240, "w": 340, "h": 250}
        }
    },
    "Productivity": {
        "name": "Productivity",
        "description": "Focus workspace equipped with Pomodoro timer, Kanban todos, Git radar, and folder view.",
        "enabled_widgets": ["clock", "quick_notes", "pomodoro", "git_activity", "folder_view"],
        "positions": {
            "clock": {"x": 700, "y": 20},
            "quick_notes": {"x": 40, "y": 280, "w": 320, "h": 340},
            "pomodoro": {"x": 40, "y": 640, "w": 320, "h": 420},
            "git_activity": {"x": 380, "y": 560, "w": 360, "h": 500},
            "folder_view": {"x": 760, "y": 680, "w": 340, "h": 380}
        }
    },
    "Full Dashboard": {
        "name": "Full Dashboard",
        "description": "Comprehensive command center featuring all desktop widgets arranged across the screen.",
        "enabled_widgets": ["clock", "gallery", "weather", "quick_notes", "pomodoro", "git_activity", "folder_view", "app_launcher", "network", "media", "hardware_telemetry", "system"],
        "positions": {
            "clock": {"x": 700, "y": 20},
            "gallery": {"x": 20, "y": 40, "w": 360, "h": 220},
            "quick_notes": {"x": 40, "y": 280, "w": 320, "h": 340},
            "pomodoro": {"x": 40, "y": 640, "w": 320, "h": 420},
            "weather": {"x": 400, "y": 140, "w": 340, "h": 250},
            "git_activity": {"x": 380, "y": 560, "w": 360, "h": 500},
            "folder_view": {"x": 760, "y": 680, "w": 340, "h": 380},
            "app_launcher": {"x": 1140, "y": 640, "w": 360, "h": 420},
            "network": {"x": 1520, "y": 40, "w": 360, "h": 180},
            "media": {"x": 1520, "y": 240, "w": 360, "h": 120},
            "hardware_telemetry": {"x": 1520, "y": 380, "w": 360, "h": 460},
            "system": {"x": 1520, "y": 860, "w": 360, "h": 200}
        }
    },
    "Gaming": {
        "name": "Gaming",
        "description": "Performance telemetry layout tracking CPU/GPU stats, RAM, multi-drive storage, and network bandwidth.",
        "enabled_widgets": ["hardware_telemetry", "system", "network", "media"],
        "positions": {
            "network": {"x": 1520, "y": 40, "w": 360, "h": 180},
            "media": {"x": 1520, "y": 240, "w": 360, "h": 120},
            "hardware_telemetry": {"x": 1520, "y": 380, "w": 360, "h": 460},
            "system": {"x": 1520, "y": 860, "w": 360, "h": 200}
        }
    }
}

DEFAULT_APPEARANCE = {
    "bg_opacity": 0.85,
    "corner_radius": 18,
    "grid_snap": 20,
    "auto_hide_mode": "tiled",
    "shadows_enabled": True,
    "animations_enabled": True
}

def pick_file_dialog(title="Select File", extensions="json", directory=False, save=False):
    # 1. omarchy-file-select (Standard Omarchy XDG Desktop Portal FileChooser)
    omarchy_select = shutil.which('omarchy-file-select')
    if omarchy_select:
        cmd = [omarchy_select, '--title', title]
        if directory:
            cmd.append('--directory')
        elif save:
            cmd.append('--save')
            if extensions:
                cmd.extend(['--filename', f'profile.{extensions.split()[0]}'])
        elif extensions:
            cmd.extend(['--extensions', extensions])
        try:
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip().splitlines()[0]
            elif p.returncode != 0:
                return None
        except Exception:
            pass

    # 2. zenity fallback
    zenity = shutil.which('zenity')
    if zenity:
        cmd = [zenity, '--file-selection', f'--title={title}']
        if directory:
            cmd.append('--directory')
        elif save:
            cmd.append('--save')
            cmd.append('--confirm-overwrite')
        elif extensions:
            ext_filter = ' '.join(f'*.{ext}' for ext in extensions.split())
            cmd.append(f'--file-filter=Files ({ext_filter}) | {ext_filter}')
        try:
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    # 3. kdialog fallback
    kdialog = shutil.which('kdialog')
    if kdialog:
        cmd = [kdialog, '--title', title]
        if directory:
            cmd.append('--getexistingdirectory')
        elif save:
            ext_filter = ' '.join(f'*.{ext}' for ext in extensions.split())
            cmd.extend(['--getsavefilename', '.', ext_filter])
        elif extensions:
            ext_filter = ' '.join(f'*.{ext}' for ext in extensions.split())
            cmd.extend(['--getopenfilename', '.', ext_filter])
        else:
            cmd.extend(['--getopenfilename', '.'])
        try:
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass

    return None

def prompt_text_dialog(title="Save Preset", text="Enter name for this layout preset:", default=""):
    zenity = shutil.which('zenity')
    if zenity:
        cmd = [zenity, '--entry', f'--title={title}', f'--text={text}']
        if default:
            cmd.append(f'--entry-text={default}')
        try:
            p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            if p.returncode == 0 and p.stdout.strip():
                return p.stdout.strip()
        except Exception:
            pass
    return None

def migrate_custom_builtins(data):
    changed = False
    customs = data.get('custom_widgets', [])
    new_customs = []
    positions = data.get('positions', {})
    enabled = data.get('enabled_widgets', [])

    for c in customs:
        path = c.get('path', '')
        custom_id = c.get('id', '')
        matched_builtin = None
        for filename, b_id in BUILTIN_MIGRATION.items():
            if path.endswith(filename):
                matched_builtin = b_id
                break
        
        if matched_builtin:
            changed = True
            if custom_id in positions:
                if matched_builtin not in positions:
                    positions[matched_builtin] = positions[custom_id]
                del positions[custom_id]
            if custom_id in enabled:
                enabled = [matched_builtin if x == custom_id else x for x in enabled]
        else:
            new_customs.append(c)

    if changed:
        dedup_enabled = []
        for e in enabled:
            if e not in dedup_enabled:
                dedup_enabled.append(e)
        data['enabled_widgets'] = dedup_enabled
        data['custom_widgets'] = new_customs
        data['positions'] = positions
        save_settings(data)
    return data

def load_settings():
    data = None
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                data = json.load(f)
        except Exception:
            pass
    elif os.path.exists(LEGACY_CONFIG):
        try:
            with open(LEGACY_CONFIG, 'r') as f:
                data = json.load(f)
        except Exception:
            pass

    if not isinstance(data, dict):
        data = {
            "gallery_folder": "ALL",
            "positions": {},
            "enabled_widgets": DEFAULT_ENABLED,
            "custom_widgets": [],
            "widget_settings": {}
        }

    if 'positions' not in data:
        data['positions'] = {}
    if 'enabled_widgets' not in data:
        data['enabled_widgets'] = DEFAULT_ENABLED
    if 'custom_widgets' not in data:
        data['custom_widgets'] = []
    if 'widget_settings' not in data:
        data['widget_settings'] = {}

    # Initialize layout profiles
    if 'layout_profiles' not in data or not isinstance(data['layout_profiles'], dict):
        data['layout_profiles'] = {}
    for prof_name, prof_data in BUILTIN_PROFILES.items():
        if prof_name not in data['layout_profiles']:
            data['layout_profiles'][prof_name] = copy.deepcopy(prof_data)

    if 'active_profile' not in data or not data['active_profile']:
        data['active_profile'] = "Default"

    # Initialize appearance settings
    if 'appearance' not in data or not isinstance(data['appearance'], dict):
        data['appearance'] = copy.deepcopy(DEFAULT_APPEARANCE)
    else:
        for k, v in DEFAULT_APPEARANCE.items():
            if k not in data['appearance']:
                data['appearance'][k] = v

    # Initialize multi-monitor positions
    if 'monitor_positions' not in data or not isinstance(data['monitor_positions'], dict):
        data['monitor_positions'] = {}

    return migrate_custom_builtins(data)

def save_settings(data):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(STATE_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

def main():
    settings = load_settings()
    action = sys.argv[1] if len(sys.argv) > 1 else 'load'

    if action == 'save_pos' and len(sys.argv) >= 5:
        widget_id = sys.argv[2]
        x = int(sys.argv[3])
        y = int(sys.argv[4])
        pos_entry = {'x': x, 'y': y}
        monitor = None
        if len(sys.argv) >= 7 and sys.argv[5].lstrip('-').isdigit() and sys.argv[6].lstrip('-').isdigit():
            pos_entry['w'] = int(sys.argv[5])
            pos_entry['h'] = int(sys.argv[6])
            if len(sys.argv) >= 8:
                monitor = sys.argv[7]
        else:
            if len(sys.argv) >= 6 and not sys.argv[5].lstrip('-').isdigit():
                monitor = sys.argv[5]
            if widget_id in settings.get('positions', {}):
                old = settings['positions'][widget_id]
                if 'w' in old and 'h' in old:
                    pos_entry['w'] = old['w']
                    pos_entry['h'] = old['h']
        settings['positions'][widget_id] = pos_entry
        if monitor:
            if monitor not in settings['monitor_positions']:
                settings['monitor_positions'][monitor] = {}
            settings['monitor_positions'][monitor][widget_id] = copy.deepcopy(pos_entry)
        save_settings(settings)
        print(json.dumps({"status": "saved", "positions": settings['positions']}))
    elif action == 'save_geometry' and len(sys.argv) >= 7:
        widget_id = sys.argv[2]
        x = int(sys.argv[3])
        y = int(sys.argv[4])
        w = int(sys.argv[5])
        h = int(sys.argv[6])
        monitor = sys.argv[7] if len(sys.argv) >= 8 else None
        geom = {'x': x, 'y': y, 'w': w, 'h': h}
        settings['positions'][widget_id] = geom
        if monitor:
            if monitor not in settings['monitor_positions']:
                settings['monitor_positions'][monitor] = {}
            settings['monitor_positions'][monitor][widget_id] = copy.deepcopy(geom)
        save_settings(settings)
        print(json.dumps({"status": "geometry_saved", "widget_id": widget_id, "geometry": settings['positions'][widget_id]}))
    elif action == 'toggle_widget' and len(sys.argv) >= 4:
        widget_id = sys.argv[2]
        enable = sys.argv[3].lower() in ('true', '1', 'yes')
        enabled = set(settings.get('enabled_widgets', []))
        if enable:
            enabled.add(widget_id)
        else:
            enabled.discard(widget_id)
        settings['enabled_widgets'] = list(enabled)
        save_settings(settings)
        print(json.dumps({"status": "toggled", "enabled_widgets": settings['enabled_widgets']}))
    elif action == 'save_setting' and len(sys.argv) >= 5:
        widget_id = sys.argv[2]
        key = sys.argv[3]
        raw_val = sys.argv[4]
        try:
            val = json.loads(raw_val)
        except Exception:
            val = raw_val
        ws = settings.get('widget_settings', {})
        if widget_id not in ws:
            ws[widget_id] = {}
        ws[widget_id][key] = val
        settings['widget_settings'] = ws
        save_settings(settings)
        print(json.dumps({"status": "setting_saved", "widget_id": widget_id, "key": key, "val": val}))
    elif action == 'save_widget_settings' and len(sys.argv) >= 4:
        widget_id = sys.argv[2]
        raw_map = sys.argv[3]
        try:
            val_map = json.loads(raw_map)
        except Exception:
            val_map = {}
        ws = settings.get('widget_settings', {})
        if widget_id not in ws:
            ws[widget_id] = {}
        ws[widget_id].update(val_map)
        settings['widget_settings'] = ws
        save_settings(settings)
        print(json.dumps({"status": "settings_saved", "widget_id": widget_id, "settings": ws[widget_id]}))
    elif action == 'save_appearance' and len(sys.argv) >= 3:
        raw_map = sys.argv[2]
        try:
            val_map = json.loads(raw_map)
        except Exception:
            val_map = {}
        app = settings.get('appearance', copy.deepcopy(DEFAULT_APPEARANCE))
        app.update(val_map)
        settings['appearance'] = app
        save_settings(settings)
        print(json.dumps({"status": "appearance_saved", "appearance": app}))
    elif action == 'list_profiles':
        profiles = []
        active = settings.get('active_profile', 'Default')
        profs = settings.get('layout_profiles', {})
        for name, pdata in profs.items():
            profiles.append({
                "name": name,
                "description": pdata.get("description", ""),
                "widget_count": len(pdata.get("enabled_widgets", [])),
                "is_active": (name == active),
                "is_builtin": (name in BUILTIN_PROFILES)
            })
        print(json.dumps({
            "status": "ok",
            "active_profile": active,
            "profiles": profiles
        }))
    elif action == 'switch_profile' and len(sys.argv) >= 3:
        target_name = sys.argv[2]
        profs = settings.get('layout_profiles', {})
        if target_name in profs:
            prof = profs[target_name]
            settings['active_profile'] = target_name
            settings['positions'] = copy.deepcopy(prof.get('positions', {}))
            settings['enabled_widgets'] = list(prof.get('enabled_widgets', DEFAULT_ENABLED))
            if 'widget_settings' in prof:
                settings['widget_settings'] = copy.deepcopy(prof.get('widget_settings', {}))
            save_settings(settings)
            print(json.dumps({
                "status": "profile_switched",
                "active_profile": target_name,
                "positions": settings['positions'],
                "enabled_widgets": settings['enabled_widgets'],
                "widget_settings": settings.get('widget_settings', {})
            }))
        else:
            print(json.dumps({"status": "error", "error": f"Profile '{target_name}' not found"}))
    elif action == 'save_profile' and len(sys.argv) >= 3:
        target_name = sys.argv[2]
        profs = settings.get('layout_profiles', {})
        profs[target_name] = {
            "name": target_name,
            "description": f"Custom layout profile saved on {target_name}",
            "positions": copy.deepcopy(settings.get('positions', {})),
            "enabled_widgets": list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
            "widget_settings": copy.deepcopy(settings.get('widget_settings', {}))
        }
        settings['layout_profiles'] = profs
        settings['active_profile'] = target_name
        save_settings(settings)
        print(json.dumps({
            "status": "profile_saved",
            "active_profile": target_name,
            "profile": profs[target_name]
        }))
    elif action == 'save_profile_dialog':
        name = prompt_text_dialog(title="Save Layout Preset", text="Enter a name for this preset:", default="Custom Preset")
        if name:
            profs = settings.get('layout_profiles', {})
            profs[name] = {
                "name": name,
                "description": f"Custom layout preset '{name}'",
                "positions": copy.deepcopy(settings.get('positions', {})),
                "enabled_widgets": list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
                "widget_settings": copy.deepcopy(settings.get('widget_settings', {}))
            }
            settings['layout_profiles'] = profs
            settings['active_profile'] = name
            save_settings(settings)
            print(json.dumps({
                "status": "profile_saved",
                "active_profile": name,
                "profile": profs[name]
            }))
        else:
            print(json.dumps({"status": "cancelled"}))
    elif action == 'delete_profile' and len(sys.argv) >= 3:
        target_name = sys.argv[2]
        if target_name in BUILTIN_PROFILES:
            print(json.dumps({"status": "error", "error": f"Cannot delete built-in profile '{target_name}'"}))
        else:
            profs = settings.get('layout_profiles', {})
            if target_name in profs:
                del profs[target_name]
                settings['layout_profiles'] = profs
                if settings.get('active_profile') == target_name:
                    settings['active_profile'] = "Default"
                save_settings(settings)
                print(json.dumps({"status": "profile_deleted", "deleted": target_name, "active_profile": settings['active_profile']}))
            else:
                print(json.dumps({"status": "error", "error": f"Profile '{target_name}' not found"}))
    elif action == 'export_profile':
        target_name = sys.argv[2] if len(sys.argv) >= 3 else settings.get('active_profile', 'Default')
        dest_path = sys.argv[3] if len(sys.argv) >= 4 else None
        profs = settings.get('layout_profiles', {})
        prof = profs.get(target_name)
        if not prof:
            prof = {
                "name": target_name,
                "positions": copy.deepcopy(settings.get('positions', {})),
                "enabled_widgets": list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
                "widget_settings": copy.deepcopy(settings.get('widget_settings', {}))
            }
        export_payload = {
            "version": "1.0",
            "type": "omarchy-desktop-widgets-profile",
            "profile": prof
        }
        if not dest_path:
            dest_path = pick_file_dialog(title=f"Export Profile '{target_name}'", extensions="json", save=True)
        if dest_path:
            dest_path = os.path.abspath(os.path.expanduser(dest_path))
            if not dest_path.endswith('.json'):
                dest_path += '.json'
            try:
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                with open(dest_path, 'w') as f:
                    json.dump(export_payload, f, indent=2)
                print(json.dumps({"status": "exported", "path": dest_path, "name": target_name}))
            except Exception as e:
                print(json.dumps({"status": "error", "error": str(e)}))
        else:
            print(json.dumps({"status": "cancelled"}))
    elif action == 'import_profile':
        src_path = sys.argv[2] if len(sys.argv) >= 3 else None
        if not src_path:
            src_path = pick_file_dialog(title="Import Layout Profile", extensions="json")
        if src_path:
            src_path = os.path.abspath(os.path.expanduser(src_path))
            try:
                with open(src_path, 'r') as f:
                    data = json.load(f)
                prof = data.get('profile', data)
                name = prof.get('name') or os.path.splitext(os.path.basename(src_path))[0]
                profs = settings.get('layout_profiles', {})
                profs[name] = {
                    "name": name,
                    "description": prof.get('description', f"Imported from {os.path.basename(src_path)}"),
                    "positions": copy.deepcopy(prof.get('positions', {})),
                    "enabled_widgets": list(prof.get('enabled_widgets', DEFAULT_ENABLED)),
                    "widget_settings": copy.deepcopy(prof.get('widget_settings', {}))
                }
                settings['layout_profiles'] = profs
                settings['active_profile'] = name
                settings['positions'] = copy.deepcopy(profs[name]['positions'])
                settings['enabled_widgets'] = list(profs[name]['enabled_widgets'])
                if 'widget_settings' in profs[name]:
                    settings['widget_settings'] = copy.deepcopy(profs[name]['widget_settings'])
                save_settings(settings)
                print(json.dumps({
                    "status": "imported",
                    "name": name,
                    "path": src_path,
                    "positions": settings['positions'],
                    "enabled_widgets": settings['enabled_widgets']
                }))
            except Exception as e:
                print(json.dumps({"status": "error", "error": str(e)}))
        else:
            print(json.dumps({"status": "cancelled"}))
    elif action == 'add_custom_widget' and len(sys.argv) >= 3:
        file_path = os.path.abspath(os.path.expanduser(sys.argv[2]))
        name = sys.argv[3] if len(sys.argv) >= 4 else os.path.splitext(os.path.basename(file_path))[0]
        customs = settings.get('custom_widgets', [])
        existing = next((c for c in customs if os.path.abspath(c.get('path', '')) == file_path), None)
        if existing:
            existing['name'] = name
            widget_id = existing['id']
        else:
            widget_id = "custom_" + str(len(customs) + 1)
            customs.append({"path": file_path, "name": name, "id": widget_id})
            settings['custom_widgets'] = customs
        enabled = settings.get('enabled_widgets', [])
        if widget_id not in enabled:
            enabled.append(widget_id)
        settings['enabled_widgets'] = enabled
        save_settings(settings)
        print(json.dumps({"status": "custom_added", "id": widget_id, "path": file_path, "name": name, "custom_widgets": customs}))
    elif action == 'remove_custom_widget' and len(sys.argv) >= 3:
        target = sys.argv[2]
        customs = settings.get('custom_widgets', [])
        customs = [c for c in customs if c.get('id') != target and os.path.abspath(c.get('path', '')) != os.path.abspath(os.path.expanduser(target))]
        settings['custom_widgets'] = customs
        enabled = [e for e in settings.get('enabled_widgets', []) if e != target]
        settings['enabled_widgets'] = enabled
        save_settings(settings)
        print(json.dumps({"status": "custom_removed", "id": target, "custom_widgets": customs}))
    elif action == 'pick_widget_dialog':
        try:
            picked = pick_file_dialog(title='Import Custom QML Widget', extensions='qml')
            if picked:
                selected_file = os.path.abspath(os.path.expanduser(picked))
                name = os.path.splitext(os.path.basename(selected_file))[0]
                customs = settings.get('custom_widgets', [])
                existing = next((c for c in customs if os.path.abspath(c.get('path', '')) == selected_file), None)
                if existing:
                    existing['name'] = name
                    new_id = existing['id']
                else:
                    new_id = "custom_" + str(len(customs) + 1)
                    customs.append({"path": selected_file, "name": name, "id": new_id})
                    settings['custom_widgets'] = customs
                enabled = settings.get('enabled_widgets', [])
                if new_id not in enabled:
                    enabled.append(new_id)
                settings['enabled_widgets'] = enabled
                save_settings(settings)
                print(json.dumps({"status": "imported", "id": new_id, "path": selected_file, "name": name}))
            else:
                print(json.dumps({"status": "cancelled"}))
        except Exception as e:
            print(json.dumps({"status": "error", "error": str(e)}))
    elif action == 'save_layout_backup':
        backup = {
            'positions': copy.deepcopy(settings.get('positions', {})),
            'enabled_widgets': list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
            'widget_settings': copy.deepcopy(settings.get('widget_settings', {}))
        }
        settings['saved_layout'] = backup
        active = settings.get('active_profile', 'Default')
        profs = settings.get('layout_profiles', {})
        profs[active] = {
            "name": active,
            "description": f"Saved layout profile for {active}",
            "positions": copy.deepcopy(backup['positions']),
            "enabled_widgets": list(backup['enabled_widgets']),
            "widget_settings": copy.deepcopy(backup['widget_settings'])
        }
        settings['layout_profiles'] = profs
        save_settings(settings)
        print(json.dumps({
            "status": "layout_backup_saved",
            "has_saved_layout": True,
            "saved_layout": backup,
            "active_profile": active
        }))
    elif action in ('reset', 'revert_layout'):
        saved = settings.get('saved_layout')
        if saved and isinstance(saved, dict) and ('positions' in saved or 'enabled_widgets' in saved):
            settings['positions'] = copy.deepcopy(saved.get('positions', {}))
            settings['enabled_widgets'] = list(saved.get('enabled_widgets', DEFAULT_ENABLED))
            if 'widget_settings' in saved:
                settings['widget_settings'] = copy.deepcopy(saved.get('widget_settings', {}))
            reverted = True
        else:
            settings['positions'] = {}
            settings['enabled_widgets'] = list(DEFAULT_ENABLED)
            reverted = False
        save_settings(settings)
        print(json.dumps({
            "status": "reset",
            "reverted_to_saved": reverted,
            "has_saved_layout": bool(saved),
            "positions": settings['positions'],
            "enabled_widgets": settings['enabled_widgets'],
            "widget_settings": settings.get('widget_settings', {})
        }))
    elif action == 'reset_factory':
        settings.pop('saved_layout', None)
        settings['positions'] = {}
        settings['enabled_widgets'] = list(DEFAULT_ENABLED)
        settings['appearance'] = copy.deepcopy(DEFAULT_APPEARANCE)
        settings['active_profile'] = "Default"
        settings['layout_profiles'] = copy.deepcopy(BUILTIN_PROFILES)
        save_settings(settings)
        print(json.dumps({
            "status": "factory_reset",
            "has_saved_layout": False,
            "positions": {},
            "enabled_widgets": list(DEFAULT_ENABLED),
            "active_profile": "Default"
        }))
    else: # load
        profs = settings.get('layout_profiles', {})
        active = settings.get('active_profile', 'Default')
        profile_list = []
        for name, pdata in profs.items():
            profile_list.append({
                "name": name,
                "description": pdata.get("description", ""),
                "widget_count": len(pdata.get("enabled_widgets", [])),
                "is_active": (name == active),
                "is_builtin": (name in BUILTIN_PROFILES)
            })
        print(json.dumps({
            "status": "ok",
            "positions": settings.get('positions', {}),
            "enabled_widgets": settings.get('enabled_widgets', DEFAULT_ENABLED),
            "custom_widgets": settings.get('custom_widgets', []),
            "gallery_folder": settings.get('gallery_folder', 'ALL'),
            "network_iface": settings.get('network_iface', 'AUTO'),
            "widget_settings": settings.get('widget_settings', {}),
            "has_saved_layout": bool(settings.get('saved_layout')),
            "active_profile": active,
            "profiles": profile_list,
            "appearance": settings.get('appearance', DEFAULT_APPEARANCE),
            "monitor_positions": settings.get('monitor_positions', {})
        }))

if __name__ == '__main__':
    main()
