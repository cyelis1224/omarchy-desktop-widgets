#!/usr/bin/env python3
import urllib.request
import urllib.parse
import json
import datetime
import os
import subprocess

def get_weather_icon(code, is_night):
    # Universal FontAwesome core unicode glyphs (F000-F2FF)
    if code == 113: # Clear / Sunny
        return "\uf186" if is_night else "\uf185" # fa-moon / fa-sun
    elif code in (116, 119, 122): # Partly cloudy / Cloudy / Overcast
        return "\uf0c2" # fa-cloud
    elif code in (143, 248, 260): # Fog / Mist
        return "\uf0c2" # fa-cloud
    elif code in (176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359): # Rain / Drizzle
        return "\uf0e9" # fa-umbrella
    elif code in (179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371): # Snow
        return "\uf2dc" # fa-snowflake
    elif code in (200, 386, 389, 392, 395): # Thunderstorm
        return "\uf0e7" # fa-bolt
    else:
        return "\uf186" if is_night else "\uf185"

def get_weather():
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

    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            curr = data.get("current_condition", [{}])[0]
            temp_f = curr.get("temp_F", "")
            temp_c = curr.get("temp_C", "")
            feels_f = curr.get("FeelsLikeF", temp_f)
            feels_c = curr.get("FeelsLikeC", temp_c)
            humidity = curr.get("humidity", "0")
            wind_mph = curr.get("windspeedMiles", "0")
            wind_kmph = curr.get("windspeedKmph", "0")
            code = int(curr.get("weatherCode", 113))
            desc = curr.get("weatherDesc", [{}])[0].get("value", "").strip()

            hour = datetime.datetime.now().hour
            is_night = hour < 6 or hour >= 20
            icon = get_weather_icon(code, is_night)

            # 3-Day Forecast
            forecast = []
            for w in data.get("weather", [])[:3]:
                date_str = w.get("date", "")
                try:
                    dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
                    day_name = dt.strftime("%a")
                except Exception:
                    day_name = date_str

                max_f = w.get("maxtempF", "")
                min_f = w.get("mintempF", "")
                max_c = w.get("maxtempC", "")
                min_c = w.get("mintempC", "")

                hourly = w.get("hourly", [])
                mid_code = 113
                mid_desc = "Clear"
                if hourly:
                    mid = hourly[len(hourly) // 2]
                    mid_code = int(mid.get("weatherCode", 113))
                    mid_desc = mid.get("weatherDesc", [{}])[0].get("value", "Clear")

                forecast.append({
                    "date": date_str,
                    "day": day_name,
                    "maxF": f"{max_f}°",
                    "minF": f"{min_f}°",
                    "maxC": f"{max_c}°",
                    "minC": f"{min_c}°",
                    "code": mid_code,
                    "desc": mid_desc,
                    "icon": get_weather_icon(mid_code, False)
                })

            print(json.dumps({
                "status": "ok",
                "location": name or "Local",
                "temp": f"{temp_f}°F" if temp_f else "",
                "tempC": f"{temp_c}°C" if temp_c else "",
                "tempNumF": int(temp_f) if temp_f else 0,
                "tempNumC": int(temp_c) if temp_c else 0,
                "feelsLike": f"{feels_f}°F" if feels_f else "",
                "feelsLikeC": f"{feels_c}°C" if feels_c else "",
                "humidity": f"{humidity}%",
                "wind": f"{wind_mph} mph",
                "windKmph": f"{wind_kmph} km/h",
                "desc": desc,
                "code": code,
                "icon": icon,
                "isNight": is_night,
                "forecast": forecast
            }))
            return
    except Exception as e:
        pass

    hour = datetime.datetime.now().hour
    is_night = hour < 6 or hour >= 20
    print(json.dumps({
        "status": "fallback",
        "location": name or "Local",
        "temp": "72°F",
        "tempC": "22°C",
        "tempNumF": 72,
        "tempNumC": 22,
        "feelsLike": "72°F",
        "feelsLikeC": "22°C",
        "humidity": "45%",
        "wind": "5 mph",
        "windKmph": "8 km/h",
        "desc": "Clear",
        "code": 113,
        "icon": "\uf186" if is_night else "\uf185",
        "isNight": is_night,
        "forecast": []
    }))

if __name__ == "__main__":
    get_weather()
