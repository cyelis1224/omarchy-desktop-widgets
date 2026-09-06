# 🌡️ Hardware Thermals & Telemetry Widget (`HardwareTelemetryWidget`)

A desktop telemetry dashboard engineered for Omarchy and Hyprland. Monitors CPU package thermals, multi-core frequencies, NVMe storage drive heat levels, DDR5 memory temperatures, Wi-Fi controller thermals, and GPU engine clocks.

## Features
- **Dual Radial Gauges**:
  - **CPU Thermals**: Glowing dynamic arc color transitioning smoothly (Optimal Emerald -> Warm Amber -> Urgent Red) based on temperature and configurable alert thresholds.
  - **All-Core Clock Speed**: Live frequency gauge showing aggregate GHz.
- **Monitored Subsystems Breakdown**:
  - CPU Package & individual cores.
  - Primary and secondary NVMe SSD temperatures.
  - DDR5 RAM module temperatures via onboard SPD sensors.
  - Wi-Fi controller thermals.
- **Integrated GPU Acceleration Sub-Card**:
  - Realtime GPU clock / render frequency and ceiling.
- **Robust Right-Click Context Menu**:
  - **Temperature Scale**: Instant toggle between Celsius (`°C`) and Fahrenheit (`°F`).
  - **Monitored Subsystems Checklist**: Toggle monitoring on/off per individual sensor.
  - **Alert Threshold Presets**: Silent (65°C), Normal (75°C), and High Performance (85°C).
  - **Actions**: One-click launch into `btop` system monitor or live `watch sensors` terminal stream.
  - **Layout Management**: Standard Lock/Unlock layout, Widget Selector, and Reset Layout.

## Architecture
- `HardwareTelemetryWidget.qml`: User interface and Canvas rendering inheriting `WidgetCard`.
- `telemetry_collector.py`: High-speed telemetry daemon parsing sysfs (`/sys/class/drm/`, `/proc/cpuinfo`) and `sensors`.
