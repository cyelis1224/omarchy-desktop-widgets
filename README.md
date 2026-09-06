# Omarchy Desktop Widgets Repository

Welcome to the **Omarchy Desktop Widgets** workspace. This repository is dedicated to designing, building, and testing custom interactive widgets for Omarchy on Hyprland.

---

## 📁 Repository Structure

```
~/Projects/desktop-widgets/
├── README.md               # This documentation
├── shared/                 # Shared base components
│   └── WidgetCard.qml      # Symlink to the core WidgetCard component
├── templates/
│   └── WidgetTemplate.qml  # Quick-start boilerplate template
├── widgets/                # Custom widgets directory
│   ├── quick-notes/        # Scratchpad & Todo Deck
│   ├── pomodoro/           # Circular Flow State Timer
│   ├── gpu-telemetry/      # Hardware Monitoring Matrix
│   └── ...                 # Additional widgets
└── scripts/
    ├── import-widget.sh    # CLI tool to register any widget into Omarchy
    └── test-widget.sh      # Syntax & diagnostic checker
```

---

## 🏗️ Architecture & Widget Anatomy

All custom desktop widgets run under **Quickshell** within the `dagyr.desktop-widgets` Omarchy plugin.

### The `WidgetCard` Base Component

Most widgets inherit from `WidgetCard.qml` (`import "../../shared"`). By inheriting `WidgetCard`, your widget automatically gains:

1. **Move Mode Drag Button (⬡)**: A clean grip button in the top-right that only appears when desktop layout is unlocked (`layoutEditMode: true`). It matches the close button styling (`rgba(1,1,1,0.08)` default, accent glow on hover).
2. **Standard Right-Click Context Menu**:
   - Right-click anywhere on the widget body to open options:
     - 🔓 *Unlock / Lock Widgets Layout (Move Mode)*
     - ➕ *Open Widget Selector / Marketplace*
     - 🔄 *Reset Widgets Layout*
   - Clicking or right-clicking anywhere outside dismisses the menu cleanly.
3. **Smooth Drag Physics & Position Persistence**: Dragging updates coordinates and automatically saves them to `~/.local/state/omarchy/dagyr.desktop-widgets.json`.
4. **Elevation & Glassmorphism**: Built-in dark translucency (`Color.bar.background`), rounded corners (`radius: 18`), and dynamic drop shadows (`MultiEffect`).

### Key Properties

| Property | Type | Description |
|---|---|---|
| `widgetId` | `string` | Unique identifier (e.g. `"quick_notes"`) |
| `title` | `string` | Title shown in the header (if `showHeader` is true) |
| `icon` | `string` | FontAwesome unicode glyph (e.g. `"\uf044"`) |
| `showHeader` | `bool` | Set `true` for standard top bar, or `false` for fully custom layouts |
| `defaultX` | `real` | Initial X coordinate before user moves it |
| `defaultY` | `real` | Initial Y coordinate before user moves it |
| `width` / `height` | `real` | Dimensions of the widget card |
| `rootRef` | `var` | Reference to desktop root (injected automatically) |
| `loaderItem` | `var` | Reference to Quickshell Loader (injected automatically) |

---

## 🎨 Omarchy Design System & Tokens

To ensure widgets match the user's active Omarchy theme:

- **Colors**:
  - `Color.accent` - Primary theme accent color (dynamic)
  - `Color.foreground` - Text & icon color
  - `Color.urgent` - Warning / destructive action color (red/orange)
  - `Color.bar.background` - Background color of shell bars and cards
- **Typography & Font**:
  - `font.family: Style.font.family`
  - FontAwesome 6 icons (e.g. `"\uf017"`, `"\uf03e"`, `"\uf0ec"`, `"\uf2db"`)
- **Spacing**:
  - `Style.space(4)`, `Style.space(8)`, `Style.space(12)`, `Style.space(16)`, `Style.space(24)`

---

## 🚀 How to Import a Widget

### Option A: From Desktop GUI (Widget Marketplace)
1. Right-click any existing desktop widget and click **Open Widget Selector (+)** (or press the Add Widgets button in Move Mode).
2. Click **Import QML Widget...** in the top-right of the drawer.
3. Select your `.qml` file (e.g. `~/Projects/desktop-widgets/widgets/quick-notes/QuickNotesWidget.qml`).
4. The widget will appear under the **Custom** tab and can be toggled onto the desktop!

### Option B: From Command Line
Run the import helper script:
```bash
~/Projects/desktop-widgets/scripts/import-widget.sh ~/Projects/desktop-widgets/widgets/quick-notes/QuickNotesWidget.qml "Quick Notes"
```

---

## 📋 Widget Roadmap

1. **QuickNotesWidget** (Scratchpad & Floating Kanban / Todo Deck)
2. **PomodoroWidget** (Circular SVG Flow State Countdown Timer)
3. **GpuTelemetryWidget** (Dual Radial Hardware Monitor Matrix)
4. **GitActivityWidget** (GitHub Contribution Radar & Repo Pulse)
5. **AudioOrbWidget** (PipeWire Reactive Audio Frequency Waveform)
6. **AmbientNoiseWidget** (Rain / Campfire / Coffee Shop Soundscapes)
7. **AppFavoritesWidget** (Floating Magnifying App Pinboard Dock)
8. **HabitRingsWidget** (Concentric Daily Habit Activity Rings)
9. **MarketTickerWidget** (Crypto & Stocks Sparkline Ticker)
10. **NewsFeedWidget** (Hacker News / Reddit Tech Pulse Marquee)
