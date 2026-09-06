#!/usr/bin/env python3
import subprocess
import json
import re
import os
import sys

def collect_telemetry():
    result = {
        "cpu_temp": 40.0,
        "cpu_cores": 0,
        "cpu_avg_ghz": 0.0,
        "cpu_avg_mhz": 0,
        "gpu_mhz": 0,
        "gpu_max_mhz": 0,
        "gpu_pct": 0.0,
        "sensors": []
    }

    # 1. CPU Frequencies and Core Count
    try:
        if os.path.exists('/proc/cpuinfo'):
            with open('/proc/cpuinfo', 'r') as f:
                lines = f.readlines()
            freqs = [float(l.split(':')[1].strip()) for l in lines if l.startswith('cpu MHz')]
            if freqs:
                result["cpu_cores"] = len(freqs)
                avg_mhz = sum(freqs) / len(freqs)
                result["cpu_avg_mhz"] = round(avg_mhz)
                result["cpu_avg_ghz"] = round(avg_mhz / 1000.0, 2)
    except Exception:
        pass

    # 2. GPU Frequency (Intel DRM or NVIDIA)
    try:
        if os.path.exists('/sys/class/drm/card1/gt_act_freq_mhz'):
            with open('/sys/class/drm/card1/gt_act_freq_mhz', 'r') as f:
                result["gpu_mhz"] = int(f.read().strip())
        elif os.path.exists('/sys/class/drm/card0/gt_act_freq_mhz'):
            with open('/sys/class/drm/card0/gt_act_freq_mhz', 'r') as f:
                result["gpu_mhz"] = int(f.read().strip())

        if os.path.exists('/sys/class/drm/card1/gt_max_freq_mhz'):
            with open('/sys/class/drm/card1/gt_max_freq_mhz', 'r') as f:
                result["gpu_max_mhz"] = int(f.read().strip())
        elif os.path.exists('/sys/class/drm/card0/gt_max_freq_mhz'):
            with open('/sys/class/drm/card0/gt_max_freq_mhz', 'r') as f:
                result["gpu_max_mhz"] = int(f.read().strip())

        if result["gpu_max_mhz"] > 0:
            result["gpu_pct"] = round(result["gpu_mhz"] / result["gpu_max_mhz"], 2)
    except Exception:
        pass

    # 3. Hardware Sensors via `sensors`
    try:
        proc = subprocess.run(['sensors'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2)
        out = proc.stdout

        # CPU Package
        m_pkg = re.search(r'Package id 0:\s+\+([0-9\.]+)°C', out)
        if m_pkg:
            c_temp = float(m_pkg.group(1))
            result["cpu_temp"] = c_temp
            result["sensors"].append({
                "id": "cpu",
                "name": "CPU Package",
                "temp": c_temp,
                "high": 85.0,
                "icon": "\uf2db"
            })
        else:
            m_core = re.search(r'Core 0:\s+\+([0-9\.]+)°C', out)
            if m_core:
                c_temp = float(m_core.group(1))
                result["cpu_temp"] = c_temp
                result["sensors"].append({
                    "id": "cpu",
                    "name": "CPU Core 0",
                    "temp": c_temp,
                    "high": 85.0,
                    "icon": "\uf2db"
                })

        # NVMe SSDs
        nvme_matches = re.findall(r'nvme-pci-([0-9a-f]+)\s+Adapter:[^\n]+\s+Composite:\s+\+([0-9\.]+)°C', out)
        for idx, (pci, temp_str) in enumerate(nvme_matches):
            result["sensors"].append({
                "id": f"nvme_{pci}",
                "name": f"NVMe SSD #{idx + 1} ({pci})",
                "temp": float(temp_str),
                "high": 75.0,
                "icon": "\uf0a0"
            })

        # DDR5 RAM SPD Sensors
        spd_matches = re.findall(r'spd5118[^\n]+\s+Adapter:[^\n]+\s+temp1:\s+\+([0-9\.]+)°C', out)
        if spd_matches:
            avg_spd = sum(float(x) for x in spd_matches) / len(spd_matches)
            result["sensors"].append({
                "id": "ram",
                "name": f"DDR5 RAM ({len(spd_matches)} DIMMs)",
                "temp": round(avg_spd, 1),
                "high": 55.0,
                "icon": "\uf538"
            })

        # Wi-Fi Controller
        wifi_m = re.search(r'iwlwifi[^\n]+\s+Adapter:[^\n]+\s+temp1:\s+\+([0-9\.]+)°C', out)
        if wifi_m:
            result["sensors"].append({
                "id": "wifi",
                "name": "Wi-Fi 7 Module",
                "temp": float(wifi_m.group(1)),
                "high": 80.0,
                "icon": "\uf1eb"
            })

    except Exception:
        pass

    # Determine thermal status level
    max_ratio = 0.0
    for s in result["sensors"]:
        ratio = s["temp"] / s["high"]
        if ratio > max_ratio:
            max_ratio = ratio

    if max_ratio >= 0.95:
        result["status_badge"] = "Critical"
        result["status_color"] = "#ef4444"
    elif max_ratio >= 0.80:
        result["status_badge"] = "Warm"
        result["status_color"] = "#f59e0b"
    else:
        result["status_badge"] = "Optimal"
        result["status_color"] = "#10b981"

    print(json.dumps(result))

if __name__ == "__main__":
    collect_telemetry()
