# Omarchy Desktop Widgets

A suite of high-performance, aesthetic desktop widgets for [Omarchy Linux](https://github.com/omarchy) running on Hyprland and Quickshell.

Featuring a 3D photo stack gallery, real-time network traffic sparklines, CPU/GPU hardware telemetry, an 84-day git activity radar, a Pomodoro timer, scratchpad notes, an ambient hero clock, MPRIS media controls, and multi-disk system monitors.

---

## ✨ Included Widgets

### Core Built-in Widgets
1. **🕒 Hero Clock & Weather** (`HeroClockWidget.qml`)
   - Centered clock with expansive ambient radial drop shadow backdrop.
   - Live weather status (temperature, condition icon, descriptions via wttr.in).
   - Dynamic time-of-day greeting ("Good morning", "Late night vibes").
   - Configurable 12h/24h time, seconds display (`:SS`), and compact date format.
2. **📸 3D Layered Photo Stack Gallery** (`PhotoGalleryWidget.qml`)
   - Realistic multi-angle 3D photo deck with full-bleed images and hardware-accelerated rounded corners (`MultiEffect`).
   - Natural depth shading, drop shadows, and interactive hover fan-out.
   - Folder selector (Wallpapers, Pictures, custom directories with Zenity file dialog).
   - Configurable auto-cycle timing (10s, 30s, 1m, 5m, 15m, or paused) and manual shuffle button.
3. **🌐 Real-time Network Traffic Monitor** (`NetworkTrafficWidget.qml`)
   - Dual real-time sparkline area chart graphing upload and download bandwidth simultaneously.
   - Current upload/download speeds and cumulative session byte counters.
   - **Popout Device Selector**: Right-click context menu flyout to choose which network device is actively monitored (Wi-Fi, Ethernet, Tailscale VPN, Docker/bridge, Loopback, or Auto-detect).
4. **💾 System Resources & Storage Matrix** (`SystemResourcesWidget.qml`)
   - Live RAM memory usage gauge with optional compact percentage format.
   - Multi-drive storage monitor tracking Root (`/`), external drives, and secondary mount points.
   - Monitored drive checkboxes to select which drives are displayed on the desktop.
5. **🎵 MPRIS Media Player** (`MediaPlayerWidget.qml`)
   - Seamless media playback control (Play/Pause, Next, Prev) with album artwork and track metadata.
   - Integrated live audio spectrum visualizer bar.
   - MPRIS audio source picker to switch between active media players (Spotify, Firefox, Chromium, mpv).

### Custom Interactive Widgets
6. **📝 Quick Notes & Todo Deck** (`widgets/quick-notes/`)
   - Floating Kanban-style todo deck with tag pills (`#work`, `#todo`, `#idea`, `#done`).
   - Markdown scratchpad instantly synchronized to local markdown and JSON files.
7. **⏱️ Circular Pomodoro Timer** (`widgets/pomodoro/`)
   - Flow-state countdown timer with SVG circular progress ring.
   - Focus sessions (25m), short breaks (5m), and long breaks (15m) with audio chimes.
8. **⚡ Hardware Telemetry Monitor** (`widgets/hardware-telemetry/`)
   - Dual radial gauge matrix for CPU and GPU utilization, clock frequencies, temperatures, and VRAM.
   - Native integration with NVIDIA, AMD, and Intel hardware sensors.
9. **🌿 Git Activity & Contribution Radar** (`widgets/git-activity/`)
   - 84-day GitHub-style contribution heatmap and commit pulse.
   - Branch status, uncommitted diff counter, and recent commit history log.
   - **Repository Switcher**: Monitor specific local projects or toggle **All Repositories** aggregate mode.

---

## 🚀 Installation

### Option 1: Install as Omarchy Plugin (Recommended)
Clone directly into your Omarchy plugins directory and reload the shell:

```bash
git clone https://github.com/cyelis1224/omarchy-desktop-widgets ~/.config/omarchy/plugins/dagyr.desktop-widgets
/usr/share/omarchy/bin/omarchy-restart-shell
```

### Option 2: Custom Widget Development Workspace
If you are developing custom widgets, clone to your projects directory:

```bash
git clone https://github.com/cyelis1224/omarchy-desktop-widgets ~/Projects/desktop-widgets
```

To register any custom widget with Omarchy:
```bash
~/Projects/desktop-widgets/scripts/import-widget.sh ~/Projects/desktop-widgets/widgets/pomodoro/PomodoroWidget.qml "Pomodoro Timer"
```

---

## 🎮 Controls & Interaction

- **Right-Click Context Menu**:
  - Right-click anywhere on any widget body to open its options.
  - Selecting any setting option automatically saves your preference and dismisses the context menu.
- **Move Mode (Layout Lock/Unlock)**:
  - Select **Unlock Widgets Layout (Move Mode)** from any widget's context menu.
  - Drag widgets freely across your desktop with smooth physics and 20px grid snapping.
  - Click **Done / Lock** in the floating top banner when finished.
- **Persistent Preferences**:
  - All widget positions, enabled states, and right-click menu settings (seconds display, disabled drive mounts, network interface selection, graph fill styles, visualizers, cycle timers) persist across Omarchy shell restarts in `~/.local/state/omarchy/dagyr.desktop-widgets.json`.
- **Smart Auto-Hide**:
  - Desktop widgets automatically conceal when application windows are focused and smoothly re-appear when navigating to an empty workspace.

---

## 🛠️ Developing Custom Widgets

All widgets inherit from the base `WidgetCard` (`shared/WidgetCard.qml`), giving them glassmorphic cards, drag physics, right-click menus, and persistent settings out of the box:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "../../shared"

WidgetCard {
  id: myWidgetRoot
  widgetId: "my_custom_widget"
  title: "My Custom Widget"
  icon: "\uf005"
  width: 320
  height: 200

  // Persisted setting helper:
  // saveSetting("myOption", true)
  // getSetting("myOption", defaultValue)

  Text {
    anchors.centerIn: parent
    text: "Hello Omarchy!"
    color: Color.foreground
    font.family: Style.font.family
  }
}
```

Validate and test your widget before loading:
```bash
~/Projects/desktop-widgets/scripts/test-widget.sh ~/Projects/desktop-widgets/widgets/my-widget/MyWidget.qml
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
