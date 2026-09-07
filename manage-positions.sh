#!/usr/bin/env python3
import sys
import os
import json

STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
LEGACY_CONFIG = os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/settings.json')

DEFAULT_ENABLED = ["clock", "gallery", "network", "media", "system"]

BUILTIN_MIGRATION = {
    "GitActivityWidget.qml": "git_activity",
    "HardwareTelemetryWidget.qml": "hardware_telemetry",
    "PomodoroWidget.qml": "pomodoro",
    "QuickNotesWidget.qml": "quick_notes"
}

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
            # Transfer position
            if custom_id in positions:
                if matched_builtin not in positions:
                    positions[matched_builtin] = positions[custom_id]
                del positions[custom_id]
            # Transfer enabled status
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
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                data = json.load(f)
                if 'positions' not in data:
                    data['positions'] = {}
                if 'enabled_widgets' not in data:
                    data['enabled_widgets'] = DEFAULT_ENABLED
                if 'custom_widgets' not in data:
                    data['custom_widgets'] = []
                if 'widget_settings' not in data:
                    data['widget_settings'] = {}
                return migrate_custom_builtins(data)
        except Exception:
            pass
    elif os.path.exists(LEGACY_CONFIG):
        try:
            with open(LEGACY_CONFIG, 'r') as f:
                data = json.load(f)
                if 'positions' not in data:
                    data['positions'] = {}
                if 'enabled_widgets' not in data:
                    data['enabled_widgets'] = DEFAULT_ENABLED
                if 'custom_widgets' not in data:
                    data['custom_widgets'] = []
                if 'widget_settings' not in data:
                    data['widget_settings'] = {}
                data = migrate_custom_builtins(data)
                save_settings(data)
                return data
        except Exception:
            pass
    return {
        "gallery_folder": "ALL",
        "positions": {},
        "enabled_widgets": DEFAULT_ENABLED,
        "custom_widgets": [],
        "widget_settings": {}
    }

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
        if len(sys.argv) >= 7:
            pos_entry['w'] = int(sys.argv[5])
            pos_entry['h'] = int(sys.argv[6])
        elif widget_id in settings.get('positions', {}):
            old = settings['positions'][widget_id]
            if 'w' in old and 'h' in old:
                pos_entry['w'] = old['w']
                pos_entry['h'] = old['h']
        settings['positions'][widget_id] = pos_entry
        save_settings(settings)
        print(json.dumps({"status": "saved", "positions": settings['positions']}))
    elif action == 'save_geometry' and len(sys.argv) >= 7:
        widget_id = sys.argv[2]
        x = int(sys.argv[3])
        y = int(sys.argv[4])
        w = int(sys.argv[5])
        h = int(sys.argv[6])
        settings['positions'][widget_id] = {'x': x, 'y': y, 'w': w, 'h': h}
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
    elif action == 'add_custom_widget' and len(sys.argv) >= 3:
        file_path = os.path.abspath(os.path.expanduser(sys.argv[2]))
        name = sys.argv[3] if len(sys.argv) >= 4 else os.path.splitext(os.path.basename(file_path))[0]
        customs = settings.get('custom_widgets', [])
        
        # Check if already exists by path
        existing = next((c for c in customs if os.path.abspath(c.get('path', '')) == file_path), None)
        if existing:
            existing['name'] = name
            widget_id = existing['id']
        else:
            widget_id = "custom_" + str(len(customs) + 1)
            customs.append({"path": file_path, "name": name, "id": widget_id})
            settings['custom_widgets'] = customs
        
        # Auto-enable
        enabled = settings.get('enabled_widgets', [])
        if widget_id not in enabled:
            enabled.append(widget_id)
        settings['enabled_widgets'] = enabled
        save_settings(settings)
        print(json.dumps({"status": "custom_added", "id": widget_id, "path": file_path, "name": name, "custom_widgets": customs}))
    elif action == 'remove_custom_widget' and len(sys.argv) >= 3:
        target = sys.argv[2]
        customs = settings.get('custom_widgets', [])
        # Find by ID or path
        customs = [c for c in customs if c.get('id') != target and os.path.abspath(c.get('path', '')) != os.path.abspath(os.path.expanduser(target))]
        settings['custom_widgets'] = customs
        # Remove from enabled
        enabled = [e for e in settings.get('enabled_widgets', []) if e != target]
        settings['enabled_widgets'] = enabled
        save_settings(settings)
        print(json.dumps({"status": "custom_removed", "id": target, "custom_widgets": customs}))
    elif action == 'pick_widget_dialog':
        import subprocess
        try:
            p = subprocess.run(['zenity', '--file-selection', '--title=Import Custom QML Widget', '--file-filter=QML Files (*.qml) | *.qml'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if p.returncode == 0 and p.stdout.strip():
                selected_file = os.path.abspath(os.path.expanduser(p.stdout.strip()))
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
                
                # Auto-enable new widget
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
    elif action == 'reset':
        settings['positions'] = {}
        settings['enabled_widgets'] = DEFAULT_ENABLED
        save_settings(settings)
        print(json.dumps({"status": "reset", "positions": {}, "enabled_widgets": DEFAULT_ENABLED}))
    else: # load
        print(json.dumps({
            "status": "ok",
            "positions": settings.get('positions', {}),
            "enabled_widgets": settings.get('enabled_widgets', DEFAULT_ENABLED),
            "custom_widgets": settings.get('custom_widgets', []),
            "gallery_folder": settings.get('gallery_folder', 'ALL'),
            "network_iface": settings.get('network_iface', 'AUTO'),
            "widget_settings": settings.get('widget_settings', {})
        }))

if __name__ == '__main__':
    main()
