#!/usr/bin/env python3
import glob
import json
import os
import re

WIFI_DRIVERS = ("iwlwifi", "mt7", "ath", "rtw", "brcm")


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def read_temp(path):
    v = read(path)
    return round(int(v) / 1000.0, 1) if v and v.lstrip("-").isdigit() else None


def hwmons():
    for h in sorted(glob.glob("/sys/class/hwmon/hwmon*"), key=lambda p: int(p.rsplit("hwmon", 1)[1])):
        yield h, read(f"{h}/name", "")


def labeled_temp(h, label):
    for lp in glob.glob(f"{h}/temp*_label"):
        if read(lp) == label:
            return read_temp(lp.replace("_label", "_input"))
    return None


def sensor(sid, name, temp, high, icon):
    return {"id": sid, "name": name, "temp": temp, "high": high, "icon": icon}


def collect_cpu(result):
    with open("/proc/cpuinfo") as f:
        text = f.read()
    freqs = [float(x) for x in re.findall(r"^cpu MHz\s*:\s*([0-9.]+)", text, re.M)]
    cores = set()
    for block in text.strip().split("\n\n"):
        phys = re.search(r"^physical id\s*:\s*(\d+)", block, re.M)
        core = re.search(r"^core id\s*:\s*(\d+)", block, re.M)
        if core:
            cores.add((phys.group(1) if phys else "0", core.group(1)))
    model = re.search(r"^model name\s*:\s*(.+)$", text, re.M)

    result["cpu_threads"] = len(freqs)
    result["cpu_cores"] = len(cores) or len(freqs)
    if model:
        result["cpu_model"] = re.sub(r"\s+w/.*$", "", model.group(1)).strip()
        igpu = re.search(r"w/\s+(.+?)(\s+Graphics)?$", model.group(1))
        if igpu:
            result["igpu_model"] = igpu.group(1).strip()
    if freqs:
        avg = sum(freqs) / len(freqs)
        result["cpu_avg_mhz"] = round(avg)
        result["cpu_avg_ghz"] = round(avg / 1000.0, 2)


def collect_gpu(result):
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]")):
        dev = f"{card}/device"
        driver = os.path.basename(os.path.realpath(f"{dev}/driver"))
        if driver == "amdgpu":
            hw = next(iter(glob.glob(f"{dev}/hwmon/hwmon*")), None)
            hz = read(f"{hw}/freq1_input") if hw else None
            if hz:
                result["gpu_mhz"] = int(hz) // 1_000_000
            levels = re.findall(r"(\d+)Mhz", read(f"{dev}/pp_dpm_sclk", ""))
            if levels:
                result["gpu_max_mhz"] = max(int(x) for x in levels)
            result["gpu_name"] = result.get("igpu_model") or "Radeon iGPU"
            return
        if driver in ("i915", "xe"):
            result["gpu_mhz"] = int(read(f"{card}/gt_act_freq_mhz", "0"))
            result["gpu_max_mhz"] = int(read(f"{card}/gt_max_freq_mhz", "0"))
            result["gpu_name"] = "Intel Graphics"
            return


def collect_sensors(result):
    s = result["sensors"]
    nvme_idx = 0
    spd = []
    for h, name in hwmons():
        if name in ("k10temp", "zenpower"):
            t = labeled_temp(h, "Tctl") or labeled_temp(h, "Tdie") or read_temp(f"{h}/temp1_input")
            if t is not None:
                result["cpu_temp"] = t
                result["cpu_high"] = 95.0
        elif name == "coretemp":
            t = labeled_temp(h, "Package id 0") or labeled_temp(h, "Core 0")
            if t is not None:
                result["cpu_temp"] = t
                result["cpu_high"] = 85.0
        elif name == "amdgpu":
            t = labeled_temp(h, "edge")
            if t is not None:
                s.append(sensor("igpu", "Radeon iGPU", t, 90.0, "\uf108"))
        elif name == "nvme":
            t = labeled_temp(h, "Composite") or read_temp(f"{h}/temp1_input")
            if t is not None:
                nvme_idx += 1
                model = read(f"{h}/device/model", "")
                label = f"SSD {nvme_idx}" + (f" · {model.split()[0].capitalize()}" if model else "")
                pci = os.path.basename(os.path.realpath(f"{h}/device/device"))
                s.append(sensor(f"nvme_{pci}", label, t, 75.0, "\uf0a0"))
        elif name in ("spd5118", "jc42"):
            t = read_temp(f"{h}/temp1_input")
            if t is not None:
                spd.append(t)
        elif name.startswith(WIFI_DRIVERS) or os.path.isdir(f"{h}/device/ieee80211"):
            t = read_temp(f"{h}/temp1_input")
            if t is not None:
                s.append(sensor("wifi", f"Wi-Fi ({name.split('_')[0].upper()})", t, 80.0, "\uf1eb"))

    if spd:
        s.append(sensor("ram", f"RAM ({len(spd)} DIMMs)", round(sum(spd) / len(spd), 1), 55.0, "\uf538"))


def collect_telemetry():
    result = {
        "cpu_temp": 0.0,
        "cpu_high": 95.0,
        "cpu_cores": 0,
        "cpu_threads": 0,
        "cpu_model": "",
        "cpu_avg_ghz": 0.0,
        "cpu_avg_mhz": 0,
        "gpu_name": "Graphics Engine",
        "gpu_mhz": 0,
        "gpu_max_mhz": 0,
        "gpu_pct": 0.0,
        "sensors": [],
    }

    for step in (collect_cpu, collect_gpu, collect_sensors):
        try:
            step(result)
        except Exception:
            pass

    if result["gpu_max_mhz"] > 0:
        result["gpu_pct"] = round(result["gpu_mhz"] / result["gpu_max_mhz"], 2)

    max_ratio = max([result["cpu_temp"] / result["cpu_high"]] + [x["temp"] / x["high"] for x in result["sensors"]])
    if max_ratio >= 0.95:
        result["status_badge"], result["status_color"] = "Critical", "#ef4444"
    elif max_ratio >= 0.80:
        result["status_badge"], result["status_color"] = "Warm", "#f59e0b"
    else:
        result["status_badge"], result["status_color"] = "Optimal", "#10b981"

    print(json.dumps(result))


if __name__ == "__main__":
    collect_telemetry()
