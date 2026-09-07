#!/usr/bin/env python3
import time
import json
import os
import sys
import subprocess

runtime_dir = os.environ.get('XDG_RUNTIME_DIR') or '/tmp'
CACHE_FILE = os.path.join(runtime_dir, f'omarchy_net_stats_{os.getuid()}.json')
STATE_DIR = os.path.expanduser('~/.local/state/omarchy')
STATE_FILE = os.path.join(STATE_DIR, 'dagyr.desktop-widgets.json')
LEGACY_CONFIG = os.path.expanduser('~/.config/omarchy/plugins/dagyr.desktop-widgets/settings.json')

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
    return {}

def save_settings(settings):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(STATE_FILE, 'w') as f:
            json.dump(settings, f, indent=2)
    except Exception:
        pass

def format_speed(bps):
    if bps < 1024:
        return f"{bps:.0f} B/s"
    elif bps < 1024 * 1024:
        return f"{bps / 1024:.1f} KB/s"
    elif bps < 1024 * 1024 * 1024:
        return f"{bps / (1024 * 1024):.1f} MB/s"
    else:
        return f"{bps / (1024 * 1024 * 1024):.2f} GB/s"

def format_bytes(n):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if n < 1024.0:
            return f"{n:.1f} {unit}"
        n /= 1024.0
    return f"{n:.1f} PB"

def read_net_dev():
    stats = {}
    if not os.path.exists('/proc/net/dev'):
        return stats
    try:
        with open('/proc/net/dev', 'r') as f:
            for line in f:
                if ':' not in line:
                    continue
                try:
                    iface, data = line.split(':', 1)
                    iface = iface.strip()
                    cols = data.split()
                    if len(cols) >= 9:
                        rx_bytes = int(cols[0])
                        tx_bytes = int(cols[8])
                        stats[iface] = {'rx': rx_bytes, 'tx': tx_bytes}
                except Exception:
                    continue
    except Exception:
        pass
    return stats

def get_device_metadata():
    """Fetches interface metadata using ip -j addr or sysfs fallback."""
    ip_data = {}
    try:
        p = subprocess.run(['ip', '-j', 'addr', 'show'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        if p.returncode == 0 and p.stdout.strip():
            for item in json.loads(p.stdout):
                ip_data[item.get('ifname', '')] = item
    except Exception:
        pass
    return ip_data

def get_primary_iface(stats, ip_data):
    """Automatically selects the best active physical/default interface."""
    ignore_prefixes = ('lo', 'docker', 'br-', 'veth', 'virbr')
    candidates = [iface for iface in stats.keys() if not any(iface.startswith(p) for p in ignore_prefixes)]

    # Prioritize interfaces that are UP
    up_candidates = []
    for iface in candidates:
        info = ip_data.get(iface, {})
        flags = info.get('flags', [])
        operstate = str(info.get('operstate', '')).upper()
        if 'UP' in flags and operstate != 'DOWN':
            up_candidates.append(iface)

    search_list = up_candidates if up_candidates else candidates

    best_iface = None
    max_total = -1
    for iface in search_list:
        total = stats[iface]['rx'] + stats[iface]['tx']
        if total > max_total:
            max_total = total
            best_iface = iface

    if not best_iface and candidates:
        best_iface = candidates[0]

    if not best_iface and stats:
        for iface in stats:
            if iface != 'lo':
                return iface
        return 'lo'

    return best_iface or (next(iter(stats.keys())) if stats else 'lo')

def build_available_devices(stats, ip_data, active_iface, selected_iface):
    """Builds a structured list of devices for the QML popout menu."""
    devices = []
    active_display = format_display_name(active_iface)

    # 1. Add Auto-detect option
    devices.append({
        "id": "AUTO",
        "name": "Auto-detect",
        "detail": f"Active: {active_display}",
        "short_name": "AUTO",
        "type": "auto",
        "icon": "\uf0e7",
        "ip": "",
        "status": "Auto",
        "is_up": True,
        "is_selected": (selected_iface == "AUTO"),
        "order": 0
    })

    # 2. Add all physical & virtual interfaces detected in /proc/net/dev
    for dev in sorted(stats.keys()):
        if dev.startswith('veth'):
            # Skip container veth endpoints to avoid menu clutter
            continue

        info = ip_data.get(dev, {})
        operstate = str(info.get('operstate', 'UNKNOWN')).upper()
        flags = info.get('flags', [])
        is_up = 'UP' in flags and operstate != 'DOWN'

        ip_addr = ""
        for a in info.get('addr_info', []):
            if a.get('family') == 'inet':
                ip_addr = a.get('local', '')
                break

        is_wifi = dev.startswith(('wl', 'wifi')) or os.path.exists(f'/sys/class/net/{dev}/wireless')
        is_eth = dev.startswith(('en', 'eth'))
        is_vpn = dev.startswith(('tailscale', 'tun', 'tap', 'wg'))
        is_docker = 'docker' in dev or dev.startswith('br-')
        is_loop = (dev == 'lo')

        if is_wifi:
            dev_type = "wifi"
            name = f"Wi-Fi ({dev})"
            icon = "\uf1eb"
            order = 1
        elif is_eth:
            dev_type = "ethernet"
            name = f"Ethernet ({dev})"
            icon = "\uf796"
            order = 2
        elif is_vpn:
            dev_type = "vpn"
            name = f"Tailscale ({dev})" if 'tailscale' in dev else f"VPN ({dev})"
            icon = "\uf3ed"
            order = 3
        elif is_docker:
            dev_type = "virtual"
            name = f"Docker Bridge ({dev})" if 'docker' in dev else f"Bridge ({dev})"
            icon = "\uf233"
            order = 4
        elif is_loop:
            dev_type = "loopback"
            name = "Loopback (lo)"
            icon = "\uf2f1"
            order = 5
        else:
            dev_type = "other"
            name = dev
            icon = "\uf0ec"
            order = 6

        detail = ip_addr if ip_addr else ("Connected" if is_up else "Disconnected")

        devices.append({
            "id": dev,
            "name": name,
            "detail": detail,
            "short_name": dev,
            "type": dev_type,
            "icon": icon,
            "ip": ip_addr,
            "status": "Connected" if is_up else "Offline",
            "is_up": is_up,
            "is_selected": (selected_iface == dev),
            "order": order
        })

    devices.sort(key=lambda d: (d['order'], d['name']))
    return devices

def format_display_name(iface):
    if iface.startswith(('wl', 'wifi')):
        return f"Wi-Fi ({iface})"
    elif iface.startswith(('en', 'eth')):
        return f"Ethernet ({iface})"
    elif iface.startswith('tailscale'):
        return f"Tailscale ({iface})"
    elif iface == 'lo':
        return "Loopback (lo)"
    return iface

def main():
    now = time.time()
    settings = load_settings()

    # Handle argument to switch interface
    if len(sys.argv) > 1 and sys.argv[1].strip():
        new_selection = sys.argv[1].strip()
        settings["network_iface"] = new_selection
        save_settings(settings)
        # Invalidate previous speed cache so it starts fresh without delta spikes
        if os.path.exists(CACHE_FILE):
            try:
                os.remove(CACHE_FILE)
            except Exception:
                pass

    selected_iface = settings.get("network_iface", "AUTO")
    current_stats = read_net_dev()
    ip_data = get_device_metadata()

    if not current_stats:
        print(json.dumps({
            "iface": "none",
            "raw_iface": "none",
            "selected_iface": selected_iface,
            "active_iface": "none",
            "rx_speed": 0,
            "tx_speed": 0,
            "rx_speed_str": "0.0 KB/s",
            "tx_speed_str": "0.0 KB/s",
            "rx_total_str": "0 B",
            "tx_total_str": "0 B",
            "available_devices": []
        }))
        return

    # Determine active interface
    auto_primary = get_primary_iface(current_stats, ip_data)
    if selected_iface == "AUTO" or selected_iface not in current_stats:
        monitored_iface = auto_primary
    else:
        monitored_iface = selected_iface

    if monitored_iface not in current_stats and current_stats:
        monitored_iface = next(iter(current_stats.keys()))

    available_devices = build_available_devices(current_stats, ip_data, auto_primary, selected_iface)

    curr_rx = current_stats[monitored_iface]['rx'] if monitored_iface in current_stats else 0
    curr_tx = current_stats[monitored_iface]['tx'] if monitored_iface in current_stats else 0

    prev_data = {}
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, 'r') as f:
                prev_data = json.load(f)
        except Exception:
            prev_data = {}

    prev_time = prev_data.get('time', 0)
    prev_rx = prev_data.get('rx', 0)
    prev_tx = prev_data.get('tx', 0)
    prev_iface = prev_data.get('iface', '')

    dt = now - prev_time
    if dt > 0 and dt < 10 and prev_iface == monitored_iface and curr_rx >= prev_rx and curr_tx >= prev_tx:
        rx_speed = (curr_rx - prev_rx) / dt
        tx_speed = (curr_tx - prev_tx) / dt
    else:
        rx_speed = 0.0
        tx_speed = 0.0

    try:
        with open(CACHE_FILE, 'w') as f:
            json.dump({'time': now, 'rx': curr_rx, 'tx': curr_tx, 'iface': monitored_iface}, f)
    except Exception:
        pass

    display_name = format_display_name(monitored_iface)
    if selected_iface == "AUTO":
        display_name = f"Auto ({monitored_iface})"

    output = {
        "iface": display_name,
        "raw_iface": monitored_iface,
        "selected_iface": selected_iface,
        "active_iface": monitored_iface,
        "rx_speed": round(rx_speed),
        "tx_speed": round(tx_speed),
        "rx_speed_str": format_speed(rx_speed),
        "tx_speed_str": format_speed(tx_speed),
        "rx_total_str": format_bytes(curr_rx),
        "tx_total_str": format_bytes(curr_tx),
        "available_devices": available_devices
    }
    print(json.dumps(output))

if __name__ == '__main__':
    main()
