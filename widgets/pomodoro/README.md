# Flow Pomodoro Widget (`PomodoroWidget.qml`)

A circular desktop flow state timer for Omarchy on Hyprland.

---

## 🌟 Features

- **3 Interval Modes**:
  - 🍅 **Deep Focus**: 25 minutes (Theme Accent / Warm Ember)
  - 🌿 **Short Break**: 5 minutes (Emerald Mint `#10b981`)
  - 🌊 **Long Break**: 15 minutes (Electric Cyan `#06b6d4`)
- **Real-Time Circular Arc Dial**:
  - Smooth anti-aliased HTML5/QML Canvas arc rendering with rounded line caps.
  - Large monospace countdown display (`MM:SS`) with live pulsating status dot.
- **Audible & Visual Cues**:
  - System sound chimes (`paplay`) on session completion.
  - Desktop notifications via `notify-send`.
- **Flow Cycle Tracker**:
  - 4-dot cycle indicator (`● ● ○ ○`) tracking sets of 4 work sessions before a long break.
  - Daily completed sessions streak counter (`🔥 X sessions completed`).
- **Standard Desktop Integration**:
  - Right-click context menu (Lock/Unlock layout, Widget Selector, Reset).
  - Move mode grip button (⬡) and close button (✕).
  - Drag-and-drop placement with persistence.
