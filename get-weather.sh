#!/usr/bin/env python3
import urllib.request
import urllib.parse
import json
import datetime
import os
import subprocess

def get_weather():
    try:
        lat = None
        lon = None
        name = ""

        # 1. Read Omarchy weather settings file
        settings_paths = [
            os.path.expanduser("~/.local/state/omarchy/settings/weather.json"),
            os.path.expanduser("~/.config/omarchy/weather.json")
        ]

        for p in settings_paths:
            if os.path.exists(p):
                try:
                    with open(p, "r") as f:
                        data = json.load(f)
                        if data.get("latitude") is not None and data.get("longitude") is not None:
                            lat = data["latitude"]
                            lon = data["longitude"]
                        if data.get("name"):
                            name = data["name"]
                        break
                except Exception:
                    pass

        # 2. Fallback to omarchy-weather-location CLI
        if not lat and not name:
            try:
                proc = subprocess.run(["omarchy-weather-location"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2)
                loc_out = proc.stdout.strip()
                if loc_out:
                    name = loc_out
            except Exception:
                pass

        # 3. Form URL with coordinates if available, otherwise name
        if lat is not None and lon is not None:
            query = f"{lat},{lon}"
        elif name:
            query = urllib.parse.quote(name)
        else:
            query = ""

        url = f"https://wttr.in/{query}?format=j1" if query else "https://wttr.in/?format=j1"
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            curr = data.get("current_condition", [{}])[0]
            temp_f = curr.get("temp_F", "")
            temp_c = curr.get("temp_C", "")
            code = int(curr.get("weatherCode", 113))
            desc = curr.get("weatherDesc", [{}])[0].get("value", "").strip()

            hour = datetime.datetime.now().hour
            is_night = hour < 6 or hour >= 20

            # Universal FontAwesome core unicode glyphs (F000-F2FF)
            if code == 113: # Clear / Sunny
                icon = "\uf186" if is_night else "\uf185" # fa-moon / fa-sun
            elif code in (116, 119, 122): # Partly cloudy / Cloudy / Overcast
                icon = "\uf0c2" # fa-cloud
            elif code in (143, 248, 260): # Fog / Mist
                icon = "\uf0c2" # fa-cloud
            elif code in (176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359): # Rain / Drizzle
                icon = "\uf0e9" # fa-umbrella
            elif code in (179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371): # Snow
                icon = "\uf2dc" # fa-snowflake
            elif code in (200, 386, 389, 392, 395): # Thunderstorm
                icon = "\uf0e7" # fa-bolt
            else:
                icon = "\uf186" if is_night else "\uf185"

            print(json.dumps({
                "location": name or "Local",
                "temp": f"{temp_f}°F" if temp_f else "",
                "tempC": f"{temp_c}°C" if temp_c else "",
                "desc": desc,
                "code": code,
                "icon": icon,
                "isNight": is_night
            }))
            return
    except Exception as e:
        pass

    hour = datetime.datetime.now().hour
    is_night = hour < 6 or hour >= 20
    print(json.dumps({
        "location": "",
        "temp": "",
        "tempC": "",
        "desc": "Clear",
        "code": 113,
        "icon": "\uf186" if is_night else "\uf185",
        "isNight": is_night
    }))

if __name__ == "__main__":
    get_weather()
