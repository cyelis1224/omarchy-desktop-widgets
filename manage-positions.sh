#!/usr/bin/env python3
import sys
import os
import json
import shutil
import subprocess
import copy
import fcntl
import tempfile
import time

STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
LEGACY_CONFIG = os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/settings.json')

DEFAULT_ENABLED = ["clock", "gallery", "coin_tracker", "network", "media", "system"]

BUILTIN_MIGRATION = {
    "GitActivityWidget.qml": "git_activity",
    "HardwareTelemetryWidget.qml": "hardware_telemetry",
    "PomodoroWidget.qml": "pomodoro",
    "QuickNotesWidget.qml": "quick_notes",
    "WeatherWidget.qml": "weather",
    "AppLauncherWidget.qml": "app_launcher",
    "FolderViewWidget.qml": "folder_view",
    "BtcTrackerWidget.qml": "coin_tracker",
    "CoinTrackerWidget.qml": "coin_tracker",
    "AnalogClockWidget.qml": "analog_clock",
    "CalendarWidget.qml": "calendar",
    "RssFeedWidget.qml": "rss_feed"
}

BUILTIN_PROFILES = {
    "Default": {
        "name": "Default",
        "description": "Standard balanced desktop setup with clock, photo deck, coin tracker, network sparklines, media, and system specs.",
        "enabled_widgets": ["clock", "gallery", "coin_tracker", "network", "media", "system"],
        "positions": {
            "clock": {"x": 700, "y": 20},
            "gallery": {"x": 20, "y": 40, "w": 360, "h": 220},
            "coin_tracker": {"x": 20, "y": 280, "w": 350, "h": 245},
            "network": {"x": 1520, "y": 40, "w": 360, "h": 180},
            "media": {"x": 1520, "y": 240, "w": 360, "h": 120},
            "system": {"x": 1520, "y": 860, "w": 360, "h": 200}
        },
        "widget_settings": {
            "clock": {
                "showGreeting": True
            }
        }
    },
    "Minimal": {
        "name": "Minimal",
        "description": "Clean, distraction-free glance layout featuring only the centerpiece clock and weather forecast.",
        "enabled_widgets": ["clock", "weather"],
        "positions": {
            "clock": {"x": 700, "y": 40},
            "weather": {"x": 790, "y": 240, "w": 340, "h": 250}
        },
        "widget_settings": {
            "clock": {
                "showGreeting": False
            }
        }
    },
    "Productivity": {
        "name": "Productivity",
        "description": "Focus workspace equipped with Pomodoro timer, Kanban todos, Git radar, and interactive calendar agenda.",
        "enabled_widgets": ["clock", "quick_notes", "pomodoro", "git_activity", "calendar", "folder_view"],
        "positions": {
            "clock": {"x": 700, "y": 20},
            "quick_notes": {"x": 40, "y": 280, "w": 320, "h": 340},
            "pomodoro": {"x": 40, "y": 640, "w": 320, "h": 420},
            "git_activity": {"x": 380, "y": 560, "w": 360, "h": 500},
            "calendar": {"x": 760, "y": 240, "w": 340, "h": 420},
            "folder_view": {"x": 760, "y": 680, "w": 340, "h": 380}
        },
        "widget_settings": {
            "clock": {
                "showGreeting": True
            }
        }
    },
    "Full Dashboard": {
        "name": "Full Dashboard",
        "description": "Comprehensive command center featuring all desktop widgets arranged across the screen.",
        "enabled_widgets": ["clock", "gallery", "weather", "coin_tracker", "quick_notes", "pomodoro", "git_activity", "folder_view", "app_launcher", "network", "media", "hardware_telemetry", "system", "analog_clock", "calendar", "rss_feed"],
        "positions": {
            "clock": {"x": 700, "y": 20},
            "gallery": {"x": 20, "y": 40, "w": 360, "h": 220},
            "quick_notes": {"x": 40, "y": 280, "w": 320, "h": 340},
            "pomodoro": {"x": 40, "y": 640, "w": 320, "h": 420},
            "weather": {"x": 400, "y": 140, "w": 340, "h": 250},
            "coin_tracker": {"x": 760, "y": 140, "w": 350, "h": 245},
            "git_activity": {"x": 380, "y": 420, "w": 360, "h": 440},
            "rss_feed": {"x": 380, "y": 880, "w": 360, "h": 440},
            "calendar": {"x": 760, "y": 420, "w": 340, "h": 440},
            "folder_view": {"x": 760, "y": 880, "w": 340, "h": 380},
            "analog_clock": {"x": 1140, "y": 40, "w": 280, "h": 280},
            "app_launcher": {"x": 1140, "y": 640, "w": 360, "h": 420},
            "network": {"x": 1520, "y": 40, "w": 360, "h": 180},
            "media": {"x": 1520, "y": 240, "w": 360, "h": 120},
            "hardware_telemetry": {"x": 1520, "y": 380, "w": 360, "h": 460},
            "system": {"x": 1520, "y": 860, "w": 360, "h": 200}
        },
        "widget_settings": {
            "clock": {
                "showGreeting": True
            }
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
    "animations_enabled": True,
    "blur_enabled": False,
    "screensaver_enabled": False,
    "screensaver_timeout_mins": 5
}

BLUR_TOGGLE_FILE = os.path.expanduser("~/.local/state/omarchy/toggles/hypr/dagyr-desktop-widgets-blur.lua")
OLD_BLUR_TOGGLE_FILE = os.path.expanduser("~/.local/state/omarchy/toggles/hypr/dagyr.desktop-widgets-blur.lua")

def sync_blur_toggle(blur_enabled):
    try:
        # Clean up legacy file with dot in basename that breaks Lua require_all
        if os.path.exists(OLD_BLUR_TOGGLE_FILE):
            os.remove(OLD_BLUR_TOGGLE_FILE)

        rule_content = '-- Managed dynamically by dagyr.desktop-widgets\nhl.layer_rule({ match = { namespace = "omarchy-desktop-widgets" }, blur = true, ignore_alpha = 0.30 })\n'
        if blur_enabled:
            os.makedirs(os.path.dirname(BLUR_TOGGLE_FILE), exist_ok=True)
            if not os.path.exists(BLUR_TOGGLE_FILE):
                with open(BLUR_TOGGLE_FILE, 'w') as f:
                    f.write(rule_content)
                subprocess.run(["hyprctl", "reload", "config-only"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            else:
                with open(BLUR_TOGGLE_FILE, 'r') as f:
                    curr = f.read()
                if curr != rule_content:
                    with open(BLUR_TOGGLE_FILE, 'w') as f:
                        f.write(rule_content)
                    subprocess.run(["hyprctl", "reload", "config-only"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        else:
            if os.path.exists(BLUR_TOGGLE_FILE):
                os.remove(BLUR_TOGGLE_FILE)
                subprocess.run(["hyprctl", "reload", "config-only"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    except Exception:
        pass



def adapt_positions_to_monitor(positions, monitor_width=0, monitor_height=0):
    """Map built-in 1920x1080 preset coordinates to the target monitor.

    Keeps left/top anchored widgets fixed, but preserves right/bottom margins for
    widgets that were placed near those edges in the preset. This makes presets
    land on the edge grid of wider/taller outputs instead of staying at eDP-1
    sized coordinates.
    """
    try:
        mw = int(monitor_width or 0)
        mh = int(monitor_height or 0)
    except Exception:
        mw = 0
        mh = 0
    if mw <= 0 and mh <= 0:
        return copy.deepcopy(positions)

    base_w = 1920
    base_h = 1080
    adapted = {}
    for wid, pos in (positions or {}).items():
        if not isinstance(pos, dict):
            adapted[wid] = copy.deepcopy(pos)
            continue
        entry = copy.deepcopy(pos)
        x = entry.get('x')
        y = entry.get('y')
        w = entry.get('w')
        h = entry.get('h')
        try:
            if mw > 0 and isinstance(x, (int, float)) and isinstance(w, (int, float)):
                right_margin = base_w - x - w
                if x >= base_w * 0.55 and right_margin >= 0:
                    entry['x'] = max(10, int(round(mw - w - right_margin)))
            if mh > 0 and isinstance(y, (int, float)) and isinstance(h, (int, float)):
                bottom_margin = base_h - y - h
                if y >= base_h * 0.55 and bottom_margin >= 0:
                    entry['y'] = max(10, int(round(mh - h - bottom_margin)))
        except Exception:
            pass
        adapted[wid] = entry
    return adapted

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

    # Migrate legacy btc_tracker to coin_tracker
    if 'btc_tracker' in positions or 'btc_tracker' in enabled or ('widget_settings' in data and 'btc_tracker' in data['widget_settings']):
        changed = True
        if 'btc_tracker' in positions:
            if 'coin_tracker' not in positions:
                positions['coin_tracker'] = positions['btc_tracker']
            del positions['btc_tracker']
        enabled = ['coin_tracker' if x == 'btc_tracker' else x for x in enabled]
        if 'widget_settings' in data and 'btc_tracker' in data['widget_settings']:
            if 'coin_tracker' not in data['widget_settings']:
                data['widget_settings']['coin_tracker'] = data['widget_settings']['btc_tracker']
            del data['widget_settings']['btc_tracker']
        if 'monitor_positions' in data and isinstance(data['monitor_positions'], dict):
            for m, mpos in data['monitor_positions'].items():
                if isinstance(mpos, dict) and 'btc_tracker' in mpos:
                    if 'coin_tracker' not in mpos:
                        mpos['coin_tracker'] = mpos['btc_tracker']
                    del mpos['btc_tracker']
        if 'saved_layout' in data and isinstance(data['saved_layout'], dict):
            sl = data['saved_layout']
            if 'positions' in sl and 'btc_tracker' in sl['positions']:
                if 'coin_tracker' not in sl['positions']:
                    sl['positions']['coin_tracker'] = sl['positions']['btc_tracker']
                del sl['positions']['btc_tracker']
            if 'enabled_widgets' in sl and 'btc_tracker' in sl['enabled_widgets']:
                sl['enabled_widgets'] = ['coin_tracker' if x == 'btc_tracker' else x for x in sl['enabled_widgets']]
            if 'widget_settings' in sl and 'btc_tracker' in sl['widget_settings']:
                if 'coin_tracker' not in sl['widget_settings']:
                    sl['widget_settings']['coin_tracker'] = sl['widget_settings']['btc_tracker']
                del sl['widget_settings']['btc_tracker']
        if 'monitor_enabled_widgets' in data and isinstance(data['monitor_enabled_widgets'], dict):
            for m, mew in data['monitor_enabled_widgets'].items():
                if isinstance(mew, list):
                    data['monitor_enabled_widgets'][m] = ['coin_tracker' if x == 'btc_tracker' else x for x in mew]
        if 'layout_profiles' in data and isinstance(data['layout_profiles'], dict):
            for pname, pdata in data['layout_profiles'].items():
                if isinstance(pdata, dict):
                    if 'enabled_widgets' in pdata and isinstance(pdata['enabled_widgets'], list):
                        pdata['enabled_widgets'] = ['coin_tracker' if x == 'btc_tracker' else x for x in pdata['enabled_widgets']]
                    if 'positions' in pdata and isinstance(pdata['positions'], dict) and 'btc_tracker' in pdata['positions']:
                        if 'coin_tracker' not in pdata['positions']:
                            pdata['positions']['coin_tracker'] = pdata['positions']['btc_tracker']
                        del pdata['positions']['btc_tracker']

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

def read_state_file():
    # A state file that exists but will not parse is never "no settings": it is
    # being written, or damaged. Retry briefly, then refuse to continue rather
    # than fall back to the defaults and save them over the real layout.
    for attempt in range(20):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            time.sleep(0.05)
    sys.stderr.write("manage-positions: could not read %s; leaving it untouched\n" % STATE_FILE)
    sys.exit(1)

def load_settings():
    data = None
    if os.path.exists(STATE_FILE):
        data = read_state_file()
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
        elif 'widget_settings' in prof_data:
            if 'widget_settings' not in data['layout_profiles'][prof_name] or not isinstance(data['layout_profiles'][prof_name]['widget_settings'], dict):
                data['layout_profiles'][prof_name]['widget_settings'] = {}
            for wid, wsets in prof_data['widget_settings'].items():
                if wid not in data['layout_profiles'][prof_name]['widget_settings'] or not isinstance(data['layout_profiles'][prof_name]['widget_settings'][wid], dict):
                    data['layout_profiles'][prof_name]['widget_settings'][wid] = {}
                data['layout_profiles'][prof_name]['widget_settings'][wid].update(wsets)

    if 'active_profile' not in data or not data['active_profile']:
        data['active_profile'] = "Default"

    # Initialize appearance settings
    if 'appearance' not in data or not isinstance(data['appearance'], dict):
        data['appearance'] = copy.deepcopy(DEFAULT_APPEARANCE)
    else:
        for k, v in DEFAULT_APPEARANCE.items():
            if k not in data['appearance']:
                data['appearance'][k] = v

    # Initialize multi-monitor positions and enabled widgets
    if 'monitor_positions' not in data or not isinstance(data['monitor_positions'], dict):
        data['monitor_positions'] = {}
    if 'monitor_enabled_widgets' not in data or not isinstance(data['monitor_enabled_widgets'], dict):
        data['monitor_enabled_widgets'] = {}

    sync_git_settings(data)
    return migrate_custom_builtins(data)

def sync_git_settings(data, backup_or_prof=None):
    if not isinstance(data, dict):
        return
    ws = data.setdefault('widget_settings', {})
    git_ws = ws.setdefault('git_activity', {})

    repos = data.get('git_custom_repos')
    if repos is None and isinstance(git_ws.get('custom_repos'), list):
        repos = git_ws['custom_repos']
    if repos is None and backup_or_prof and isinstance(backup_or_prof.get('git_custom_repos'), list):
        repos = backup_or_prof['git_custom_repos']
    if repos is None and backup_or_prof and isinstance(backup_or_prof.get('widget_settings', {}).get('git_activity', {}).get('custom_repos'), list):
        repos = backup_or_prof['widget_settings']['git_activity']['custom_repos']

    if repos is not None:
        data['git_custom_repos'] = copy.deepcopy(repos)
        git_ws['custom_repos'] = copy.deepcopy(repos)

    act = data.get('git_active_repo')
    if (not act) and isinstance(git_ws.get('active_repo'), str) and git_ws['active_repo']:
        act = git_ws['active_repo']
    if (not act) and backup_or_prof and backup_or_prof.get('git_active_repo'):
        act = backup_or_prof['git_active_repo']
    if (not act) and backup_or_prof and backup_or_prof.get('widget_settings', {}).get('git_activity', {}).get('active_repo'):
        act = backup_or_prof['widget_settings']['git_activity']['active_repo']

    if act:
        data['git_active_repo'] = act
        git_ws['active_repo'] = act

def save_settings(data):
    # Write a temp file and rename it over the state file, so a concurrent
    # reader sees either the old or the new settings, never a half-written file.
    tmp_path = None
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(prefix='.dagyr.desktop-widgets.', suffix='.json', dir=STATE_DIR)
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, STATE_FILE)
        tmp_path = None
    except Exception:
        pass
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)

# Actions that wait on a file dialog must not hold the lock while the person
# picks a file, or every widget save queues up behind them.
DIALOG_ACTIONS = {'save_profile_dialog', 'export_profile', 'import_profile', 'pick_widget_dialog'}

def lock_state():
    # Every widget saves through this script, and a shell restart starts them
    # all at once; serialize the read-modify-write so no update is lost.
    os.makedirs(STATE_DIR, exist_ok=True)
    lock_file = open(os.path.join(STATE_DIR, '.dagyr.desktop-widgets.lock'), 'w')
    fcntl.flock(lock_file, fcntl.LOCK_EX)
    return lock_file

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'load'
    state_lock = None if action in DIALOG_ACTIONS else lock_state()
    settings = load_settings()

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
        if monitor:
            if monitor not in settings['monitor_positions']:
                settings['monitor_positions'][monitor] = {}
            settings['monitor_positions'][monitor][widget_id] = copy.deepcopy(pos_entry)
            if widget_id not in settings.get('positions', {}):
                settings['positions'][widget_id] = copy.deepcopy(pos_entry)
        else:
            settings['positions'][widget_id] = pos_entry
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
        if monitor:
            if monitor not in settings['monitor_positions']:
                settings['monitor_positions'][monitor] = {}
            settings['monitor_positions'][monitor][widget_id] = copy.deepcopy(geom)
            if widget_id not in settings.get('positions', {}):
                settings['positions'][widget_id] = copy.deepcopy(geom)
        else:
            settings['positions'][widget_id] = geom
        save_settings(settings)
        print(json.dumps({"status": "geometry_saved", "widget_id": widget_id, "geometry": settings['positions'][widget_id]}))
    elif action == 'toggle_widget' and len(sys.argv) >= 4:
        widget_id = sys.argv[2]
        enable = sys.argv[3].lower() in ('true', '1', 'yes')
        monitor = sys.argv[4] if len(sys.argv) >= 5 else None

        if monitor:
            if 'monitor_enabled_widgets' not in settings or not isinstance(settings['monitor_enabled_widgets'], dict):
                settings['monitor_enabled_widgets'] = {}
            if len(sys.argv) >= 6:
                try:
                    explicit_list = json.loads(sys.argv[5])
                    if isinstance(explicit_list, list):
                        settings['monitor_enabled_widgets'][monitor] = explicit_list
                except Exception:
                    pass
            if monitor not in settings['monitor_enabled_widgets']:
                settings['monitor_enabled_widgets'][monitor] = []
            m_set = set(settings['monitor_enabled_widgets'][monitor])
            if enable:
                m_set.add(widget_id)
            else:
                m_set.discard(widget_id)
            settings['monitor_enabled_widgets'][monitor] = list(m_set)

        enabled = set(settings.get('enabled_widgets', []))
        if not monitor:
            if enable:
                enabled.add(widget_id)
            else:
                enabled.discard(widget_id)
            settings['enabled_widgets'] = list(enabled)

        save_settings(settings)
        print(json.dumps({
            "status": "toggled",
            "enabled_widgets": settings['enabled_widgets'],
            "monitor_enabled_widgets": settings.get('monitor_enabled_widgets', {})
        }))
    elif action == 'move_to_monitor' and len(sys.argv) >= 5:
        widget_id = sys.argv[2]
        from_mon = sys.argv[3]
        to_mon = sys.argv[4]

        if 'monitor_enabled_widgets' not in settings or not isinstance(settings['monitor_enabled_widgets'], dict):
            settings['monitor_enabled_widgets'] = {}

        if from_mon not in settings['monitor_enabled_widgets']:
            settings['monitor_enabled_widgets'][from_mon] = list(settings.get('enabled_widgets', DEFAULT_ENABLED))
        from_set = set(settings['monitor_enabled_widgets'][from_mon])
        from_set.discard(widget_id)
        settings['monitor_enabled_widgets'][from_mon] = list(from_set)

        if to_mon not in settings['monitor_enabled_widgets']:
            settings['monitor_enabled_widgets'][to_mon] = []
        to_set = set(settings['monitor_enabled_widgets'][to_mon])
        to_set.add(widget_id)
        settings['monitor_enabled_widgets'][to_mon] = list(to_set)

        if 'monitor_positions' not in settings or not isinstance(settings['monitor_positions'], dict):
            settings['monitor_positions'] = {}
        if to_mon not in settings['monitor_positions']:
            settings['monitor_positions'][to_mon] = {}

        if from_mon in settings['monitor_positions'] and widget_id in settings['monitor_positions'][from_mon]:
            settings['monitor_positions'][to_mon][widget_id] = copy.deepcopy(settings['monitor_positions'][from_mon][widget_id])
            del settings['monitor_positions'][from_mon][widget_id]
        elif widget_id in settings.get('positions', {}):
            settings['monitor_positions'][to_mon][widget_id] = copy.deepcopy(settings['positions'][widget_id])

        save_settings(settings)
        print(json.dumps({
            "status": "moved_to_monitor",
            "widget_id": widget_id,
            "from_monitor": from_mon,
            "to_monitor": to_mon,
            "monitor_enabled_widgets": settings['monitor_enabled_widgets'],
            "monitor_positions": settings['monitor_positions']
        }))
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
        sync_blur_toggle(bool(app.get('blur_enabled', False)))
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
        target_monitor = sys.argv[3] if len(sys.argv) >= 4 else None
        target_monitor_width = int(sys.argv[4]) if len(sys.argv) >= 5 and str(sys.argv[4]).lstrip('-').isdigit() else 0
        target_monitor_height = int(sys.argv[5]) if len(sys.argv) >= 6 and str(sys.argv[5]).lstrip('-').isdigit() else 0
        profs = settings.get('layout_profiles', {})
        if target_name in profs:
            prof = profs[target_name]
            current_git_repos = settings.get('git_custom_repos', [])
            current_git_active = settings.get('git_active_repo', '')

            settings['active_profile'] = target_name
            if target_monitor:
                if 'monitor_positions' not in settings or not isinstance(settings['monitor_positions'], dict):
                    settings['monitor_positions'] = {}
                if 'monitor_enabled_widgets' not in settings or not isinstance(settings['monitor_enabled_widgets'], dict):
                    settings['monitor_enabled_widgets'] = {}
                settings['monitor_positions'][target_monitor] = adapt_positions_to_monitor(prof.get('positions', {}), target_monitor_width, target_monitor_height)
                settings['monitor_enabled_widgets'][target_monitor] = list(prof.get('enabled_widgets', DEFAULT_ENABLED))
            else:
                settings['positions'] = copy.deepcopy(prof.get('positions', {}))
                settings['enabled_widgets'] = list(prof.get('enabled_widgets', DEFAULT_ENABLED))
            if 'widget_settings' in prof and isinstance(prof['widget_settings'], dict):
                if 'widget_settings' not in settings or not isinstance(settings['widget_settings'], dict):
                    settings['widget_settings'] = {}
                for wid, wsets in prof['widget_settings'].items():
                    if wid not in settings['widget_settings'] or not isinstance(settings['widget_settings'][wid], dict):
                        settings['widget_settings'][wid] = {}
                    settings['widget_settings'][wid].update(copy.deepcopy(wsets))

            # If target preset has git repos, load them; otherwise preserve current user repos
            if 'git_custom_repos' in prof and prof['git_custom_repos']:
                settings['git_custom_repos'] = copy.deepcopy(prof['git_custom_repos'])
            elif current_git_repos:
                settings['git_custom_repos'] = current_git_repos

            if 'git_active_repo' in prof and prof['git_active_repo']:
                settings['git_active_repo'] = prof['git_active_repo']
            elif current_git_active:
                settings['git_active_repo'] = current_git_active

            sync_git_settings(settings, prof)

            if not target_monitor:
                if 'monitor_enabled_widgets' in prof and isinstance(prof['monitor_enabled_widgets'], dict):
                    settings['monitor_enabled_widgets'] = copy.deepcopy(prof['monitor_enabled_widgets'])
                else:
                    settings['monitor_enabled_widgets'] = {}
                if 'monitor_positions' in prof and isinstance(prof['monitor_positions'], dict):
                    settings['monitor_positions'] = copy.deepcopy(prof['monitor_positions'])
                else:
                    settings['monitor_positions'] = {}
            save_settings(settings)
            print(json.dumps({
                "status": "profile_switched",
                "active_profile": target_name,
                "positions": settings['positions'],
                "enabled_widgets": settings['enabled_widgets'],
                "widget_settings": settings.get('widget_settings', {}),
                "monitor_positions": settings.get('monitor_positions', {}),
                "monitor_enabled_widgets": settings.get('monitor_enabled_widgets', {}),
                "target_monitor": target_monitor,
                "target_monitor_width": target_monitor_width,
                "target_monitor_height": target_monitor_height
            }))
        else:
            print(json.dumps({"status": "error", "error": f"Profile '{target_name}' not found"}))
    elif action == 'save_profile' and len(sys.argv) >= 3:
        target_name = sys.argv[2]
        sync_git_settings(settings)
        profs = settings.get('layout_profiles', {})
        profs[target_name] = {
            "name": target_name,
            "description": f"Custom layout profile saved on {target_name}",
            "positions": copy.deepcopy(settings.get('positions', {})),
            "enabled_widgets": list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
            "widget_settings": copy.deepcopy(settings.get('widget_settings', {})),
            "monitor_positions": copy.deepcopy(settings.get('monitor_positions', {})),
            "monitor_enabled_widgets": copy.deepcopy(settings.get('monitor_enabled_widgets', {})),
            "git_custom_repos": copy.deepcopy(settings.get('git_custom_repos', [])),
            "git_active_repo": settings.get('git_active_repo', '')
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
            sync_git_settings(settings)
            profs = settings.get('layout_profiles', {})
            profs[name] = {
                "name": name,
                "description": f"Custom layout preset '{name}'",
                "positions": copy.deepcopy(settings.get('positions', {})),
                "enabled_widgets": list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
                "widget_settings": copy.deepcopy(settings.get('widget_settings', {})),
                "monitor_positions": copy.deepcopy(settings.get('monitor_positions', {})),
                "monitor_enabled_widgets": copy.deepcopy(settings.get('monitor_enabled_widgets', {})),
                "git_custom_repos": copy.deepcopy(settings.get('git_custom_repos', [])),
                "git_active_repo": settings.get('git_active_repo', '')
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
            sync_git_settings(settings)
            prof = {
                "name": target_name,
                "positions": copy.deepcopy(settings.get('positions', {})),
                "enabled_widgets": list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
                "widget_settings": copy.deepcopy(settings.get('widget_settings', {})),
                "git_custom_repos": copy.deepcopy(settings.get('git_custom_repos', [])),
                "git_active_repo": settings.get('git_active_repo', '')
            }
        else:
            if 'git_custom_repos' not in prof and settings.get('git_custom_repos'):
                prof['git_custom_repos'] = copy.deepcopy(settings.get('git_custom_repos', []))
            if 'git_active_repo' not in prof and settings.get('git_active_repo'):
                prof['git_active_repo'] = settings.get('git_active_repo', '')
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
                    "widget_settings": copy.deepcopy(prof.get('widget_settings', {})),
                    "monitor_positions": copy.deepcopy(prof.get('monitor_positions', {})),
                    "monitor_enabled_widgets": copy.deepcopy(prof.get('monitor_enabled_widgets', {})),
                    "git_custom_repos": copy.deepcopy(prof.get('git_custom_repos', [])),
                    "git_active_repo": prof.get('git_active_repo', '')
                }
                settings['layout_profiles'] = profs
                settings['active_profile'] = name
                settings['positions'] = copy.deepcopy(profs[name]['positions'])
                settings['enabled_widgets'] = list(profs[name]['enabled_widgets'])
                if 'widget_settings' in profs[name]:
                    settings['widget_settings'] = copy.deepcopy(profs[name]['widget_settings'])
                if 'git_custom_repos' in profs[name] and profs[name]['git_custom_repos']:
                    settings['git_custom_repos'] = copy.deepcopy(profs[name]['git_custom_repos'])
                if 'git_active_repo' in profs[name] and profs[name]['git_active_repo']:
                    settings['git_active_repo'] = profs[name]['git_active_repo']
                sync_git_settings(settings, profs[name])
                settings['monitor_positions'] = copy.deepcopy(profs[name]['monitor_positions'])
                settings['monitor_enabled_widgets'] = copy.deepcopy(profs[name]['monitor_enabled_widgets'])
                save_settings(settings)
                print(json.dumps({
                    "status": "imported",
                    "name": name,
                    "path": src_path,
                    "positions": settings['positions'],
                    "enabled_widgets": settings['enabled_widgets'],
                    "monitor_positions": settings['monitor_positions'],
                    "monitor_enabled_widgets": settings['monitor_enabled_widgets']
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
        sync_git_settings(settings)
        backup = {
            'positions': copy.deepcopy(settings.get('positions', {})),
            'enabled_widgets': list(settings.get('enabled_widgets', DEFAULT_ENABLED)),
            'widget_settings': copy.deepcopy(settings.get('widget_settings', {})),
            'monitor_positions': copy.deepcopy(settings.get('monitor_positions', {})),
            'monitor_enabled_widgets': copy.deepcopy(settings.get('monitor_enabled_widgets', {})),
            'git_custom_repos': copy.deepcopy(settings.get('git_custom_repos', [])),
            'git_active_repo': settings.get('git_active_repo', '')
        }
        settings['saved_layout'] = backup
        active = settings.get('active_profile', 'Default')
        profs = settings.get('layout_profiles', {})
        profs[active] = {
            "name": active,
            "description": f"Saved layout profile for {active}",
            "positions": copy.deepcopy(backup['positions']),
            "enabled_widgets": list(backup['enabled_widgets']),
            "widget_settings": copy.deepcopy(backup['widget_settings']),
            "monitor_positions": copy.deepcopy(backup.get('monitor_positions', {})),
            "monitor_enabled_widgets": copy.deepcopy(backup.get('monitor_enabled_widgets', {})),
            "git_custom_repos": copy.deepcopy(backup.get('git_custom_repos', [])),
            "git_active_repo": backup.get('git_active_repo', '')
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
        current_git_repos = settings.get('git_custom_repos', [])
        current_git_active = settings.get('git_active_repo', '')
        if saved and isinstance(saved, dict) and ('positions' in saved or 'enabled_widgets' in saved):
            settings['positions'] = copy.deepcopy(saved.get('positions', {}))
            settings['enabled_widgets'] = list(saved.get('enabled_widgets', DEFAULT_ENABLED))
            if 'widget_settings' in saved:
                settings['widget_settings'] = copy.deepcopy(saved.get('widget_settings', {}))
            settings['monitor_positions'] = copy.deepcopy(saved.get('monitor_positions', {}))
            settings['monitor_enabled_widgets'] = copy.deepcopy(saved.get('monitor_enabled_widgets', {}))

            if 'git_custom_repos' in saved and saved['git_custom_repos']:
                settings['git_custom_repos'] = copy.deepcopy(saved['git_custom_repos'])
            elif current_git_repos:
                settings['git_custom_repos'] = current_git_repos

            if 'git_active_repo' in saved and saved['git_active_repo']:
                settings['git_active_repo'] = saved['git_active_repo']
            elif current_git_active:
                settings['git_active_repo'] = current_git_active

            sync_git_settings(settings, saved)
            reverted = True
        else:
            settings['positions'] = {}
            settings['enabled_widgets'] = list(DEFAULT_ENABLED)
            settings['monitor_positions'] = {}
            settings['monitor_enabled_widgets'] = {}
            if current_git_repos:
                settings['git_custom_repos'] = current_git_repos
            if current_git_active:
                settings['git_active_repo'] = current_git_active
            sync_git_settings(settings)
            reverted = False
        save_settings(settings)
        print(json.dumps({
            "status": "reset",
            "reverted_to_saved": reverted,
            "has_saved_layout": bool(saved),
            "positions": settings['positions'],
            "enabled_widgets": settings['enabled_widgets'],
            "widget_settings": settings.get('widget_settings', {}),
            "monitor_positions": settings.get('monitor_positions', {}),
            "monitor_enabled_widgets": settings.get('monitor_enabled_widgets', {})
        }))
    elif action == 'reset_factory':
        settings.pop('saved_layout', None)
        settings['positions'] = {}
        settings['enabled_widgets'] = list(DEFAULT_ENABLED)
        settings['appearance'] = copy.deepcopy(DEFAULT_APPEARANCE)
        settings['active_profile'] = "Default"
        settings['layout_profiles'] = copy.deepcopy(BUILTIN_PROFILES)
        save_settings(settings)
        sync_blur_toggle(False)
        print(json.dumps({
            "status": "factory_reset",
            "has_saved_layout": False,
            "positions": {},
            "enabled_widgets": list(DEFAULT_ENABLED),
            "active_profile": "Default"
        }))
    else: # load
        sync_blur_toggle(bool(settings.get('appearance', {}).get('blur_enabled', False)))
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
            "monitor_positions": settings.get('monitor_positions', {}),
            "monitor_enabled_widgets": settings.get('monitor_enabled_widgets', {})
        }))

if __name__ == '__main__':
    main()
