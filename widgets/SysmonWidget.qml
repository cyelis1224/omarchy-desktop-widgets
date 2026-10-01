import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

// CPU / RAM / GPU utilization history on a log-time axis (ported from the
// ezp.sysmon floating panel). WidgetCard supplies positioning, resizing, the
// context menu and settings persistence; this file keeps the poller, the
// tiered history buffers, the chart and the readouts.
WidgetCard {
  id: sysmonRoot

  widgetId: "sysmon"
  title: "System Monitor"
  icon: "\uf0e4"
  showHeader: false // custom header row with live indicator
  defaultX: screenWidth - width - Style.space(24)
  defaultY: Style.space(64) + 200

  width: 360
  height: sysmonLayout.implicitHeight + sysmonLayout.anchors.topMargin + sysmonLayout.anchors.bottomMargin
  minWidth: 280
  // Content height with the graph squeezed to its minimum, so no row is ever clipped
  minHeight: Math.ceil(sysmonLayout.implicitHeight - graphCard.implicitHeight + graphCard.Layout.minimumHeight
                       + sysmonLayout.anchors.topMargin + sysmonLayout.anchors.bottomMargin)
  menuWidth: 300

  // Resize handles clamp to minHeight, but restored sizes bypass them. The check
  // is deferred until bindings settle (and skipped during construction): mid-update,
  // height can briefly lag minHeight, and assigning it would break the default
  // content-height binding.
  property bool minHeightClampReady: false
  function ensureMinHeight() {
    if (minHeightClampReady && !isResizing && height < minHeight) height = minHeight
  }
  onMinHeightChanged: Qt.callLater(ensureMinHeight)
  onHeightChanged: Qt.callLater(ensureMinHeight)

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  property bool smoothScroll: false  // repaint at 25 fps so the chart drifts between polls
  property real highThreshold: 80    // readouts turn urgent at or above this percentage
  property bool logTimeScale: true   // log-age x axis (recent samples get more width)
  property bool showTop: true        // "Top CPU / Top RAM" process line under the chart
  property int timeScaleSeconds: 3600
  property bool timeScaleMenuOpen: false
  // Same choices as the Network Traffic widget; the longest must fit the history tiers
  readonly property var timeScaleOptions: [
    { seconds: 30, label: "30 sec" },
    { seconds: 60, label: "1 min" },
    { seconds: 120, label: "2 min" },
    { seconds: 300, label: "5 min" },
    { seconds: 900, label: "15 min" },
    { seconds: 1800, label: "30 min" },
    { seconds: 3600, label: "1 hr" }
  ]

  function timeScaleLabel() {
    for (var i = 0; i < timeScaleOptions.length; i++) {
      if (timeScaleOptions[i].seconds === timeScaleSeconds) return timeScaleOptions[i].label
    }
    return timeScaleSeconds + "s"
  }

  function shortDuration(secs) {
    if (secs < 60) return secs + "s"
    if (secs < 3600) return (secs / 60) + "m"
    return (secs / 3600) + "h"
  }

  function fmt(pct) {
    return pct < 0 ? "--" : Math.round(pct) + "%"
  }

  // Top-process values are usually a few percent of the machine, so keep one decimal there
  function fmtTop(pct) {
    if (pct < 0) return "--"
    return (pct < 10 ? pct.toFixed(1) : Math.round(pct)) + "%"
  }

  function applySavedSettings() {
    if (!rootRef || !rootRef.widgetSettings) return
    var s = rootRef.widgetSettings[widgetId]
    if (!s) return
    if (typeof s.smoothScroll === "boolean") smoothScroll = s.smoothScroll
    if (typeof s.highThreshold === "number" && s.highThreshold >= 50 && s.highThreshold <= 100) highThreshold = s.highThreshold
    if (typeof s.logTimeScale === "boolean") logTimeScale = s.logTimeScale
    if (typeof s.showTop === "boolean") showTop = s.showTop
    if (s.timeScaleSeconds !== undefined) {
      for (var i = 0; i < timeScaleOptions.length; i++) {
        if (timeScaleOptions[i].seconds === s.timeScaleSeconds) timeScaleSeconds = s.timeScaleSeconds
      }
    }
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    minHeightClampReady = true
    Qt.callLater(ensureMinHeight)
  }

  onContextMenuOpenChanged: {
    if (!contextMenuOpen) timeScaleMenuOpen = false
  }

  // ---------------------------------------------------------------------------
  // Series colors: the active theme's named blue / green / yellow from its
  // colors.toml. A monochrome theme defines those as greys, so a near-grey (or
  // missing) entry falls back to a generated hue whose lightness follows the
  // theme's dark or light background.
  // ---------------------------------------------------------------------------
  property var themePalette: ({})
  readonly property bool darkTheme: Color.background.hslLightness < 0.5

  function loadThemePalette(raw) {
    var map = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})\b/)
      if (m) map[m[1]] = m[2]
    }
    themePalette = map
  }

  function seriesColor(name, fallbackHue) {
    var hex = themePalette[name]
    if (hex) {
      var c = Qt.color(hex)
      if (c.hslSaturation >= 0.12) return c
    }
    return Qt.hsla(fallbackHue, 0.7, darkTheme ? 0.68 : 0.4, 1)
  }

  readonly property color cpuColor: seriesColor("blue", 0.61)
  readonly property color memColor: seriesColor("green", 0.25)
  readonly property color gpuColor: seriesColor("yellow", 0.1)
  // Readouts at/above the threshold. Not Color.urgent: that's the theme's red,
  // which monochrome themes make a dark grey that's unreadable on the card.
  readonly property color hotColor: seriesColor("red", 0.0)

  FileView {
    id: themeColorsFile
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: sysmonRoot.loadThemePalette(text())
    onLoadFailed: sysmonRoot.themePalette = ({})
  }

  // The shell's Color singleton re-reads the same file when the theme changes
  Connections {
    target: Color
    function onBackgroundChanged() { themeColorsFile.reload() }
    function onAccentChanged() { themeColorsFile.reload() }
  }

  function stepThreshold(delta) {
    var v = Math.max(50, Math.min(100, highThreshold + delta))
    if (v === highThreshold) return
    highThreshold = v
    saveSetting("highThreshold", highThreshold)
  }

  // ---------------------------------------------------------------------------
  // Context menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "DISPLAY OPTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Smooth Scrolling Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: smoothMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf04e"
            font.family: Style.font.family
            font.pixelSize: 11
            color: sysmonRoot.smoothScroll ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Smooth Scrolling (25 fps)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: sysmonRoot.smoothScroll ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: sysmonRoot.smoothScroll ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: smoothMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            sysmonRoot.smoothScroll = !sysmonRoot.smoothScroll
            sysmonRoot.saveSetting("smoothScroll", sysmonRoot.smoothScroll)
            sysmonRoot.contextMenuOpen = false
          }
        }
      }

      // Time Scale Dropdown Trigger
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: scaleMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(6)
          spacing: Style.space(8)

          Text {
            text: "\uf017"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Time Scale"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Rectangle {
            implicitWidth: scalePillRow.implicitWidth + 16
            implicitHeight: 20
            radius: 10
            color: sysmonRoot.timeScaleMenuOpen
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
              : Qt.rgba(1, 1, 1, 0.06)
            border.color: sysmonRoot.timeScaleMenuOpen ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
            border.width: 1

            RowLayout {
              id: scalePillRow
              anchors.centerIn: parent
              spacing: 6

              Text {
                text: sysmonRoot.timeScaleLabel()
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Color.foreground
              }

              Text {
                text: sysmonRoot.timeScaleMenuOpen ? "\uf077" : "\uf078"
                font.family: Style.font.family
                font.pixelSize: 8
                color: Color.accent
              }
            }
          }
        }

        MouseArea {
          id: scaleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: sysmonRoot.timeScaleMenuOpen = !sysmonRoot.timeScaleMenuOpen
        }
      }

      // Time Scale Options List
      Rectangle {
        visible: sysmonRoot.timeScaleMenuOpen
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.rightMargin: Style.space(6)
        implicitHeight: scaleOptionsCol.implicitHeight + 8
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
        border.width: 1

        ColumnLayout {
          id: scaleOptionsCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 4
          spacing: 1

          Repeater {
            model: sysmonRoot.timeScaleOptions

            Rectangle {
              required property var modelData
              readonly property bool isSelected: modelData.seconds === sysmonRoot.timeScaleSeconds
              Layout.fillWidth: true
              implicitHeight: 24
              radius: 5
              color: isSelected
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                : (scaleOptionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                  text: isSelected ? "\uf00c" : ""
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.accent
                  Layout.preferredWidth: 12
                  horizontalAlignment: Text.AlignHCenter
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: isSelected ? Font.Bold : Font.Normal
                  color: isSelected ? Color.accent : Color.foreground
                }
              }

              MouseArea {
                id: scaleOptionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  sysmonRoot.timeScaleSeconds = modelData.seconds
                  sysmonRoot.saveSetting("timeScaleSeconds", modelData.seconds)
                  sysmonRoot.timeScaleMenuOpen = false
                  sysmonRoot.contextMenuOpen = false
                }
              }
            }
          }
        }
      }

      // Logarithmic Timeline Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: logMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf1da"
            font.family: Style.font.family
            font.pixelSize: 11
            color: sysmonRoot.logTimeScale ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Logarithmic Timeline"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: sysmonRoot.logTimeScale ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: sysmonRoot.logTimeScale ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: logMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            sysmonRoot.logTimeScale = !sysmonRoot.logTimeScale
            sysmonRoot.saveSetting("logTimeScale", sysmonRoot.logTimeScale)
            sysmonRoot.contextMenuOpen = false
          }
        }
      }

      // Show Top Processes Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: topMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0cb"
            font.family: Style.font.family
            font.pixelSize: 11
            color: sysmonRoot.showTop ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Show Top Processes"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: sysmonRoot.showTop ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: sysmonRoot.showTop ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: topMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            sysmonRoot.showTop = !sysmonRoot.showTop
            sysmonRoot.saveSetting("showTop", sysmonRoot.showTop)
            sysmonRoot.contextMenuOpen = false
          }
        }
      }

      // Alert Threshold Stepper (menu stays open while adjusting)
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf071"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Alert Threshold"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Rectangle {
            width: 20
            height: 20
            radius: 10
            color: minusMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
            opacity: sysmonRoot.highThreshold > 50 ? 1 : 0.4

            Text {
              anchors.centerIn: parent
              text: "\uf068"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Color.foreground
            }

            MouseArea {
              id: minusMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: sysmonRoot.stepThreshold(-5)
            }
          }

          Text {
            text: Math.round(sysmonRoot.highThreshold) + "%"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Color.accent
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: 34
          }

          Rectangle {
            width: 20
            height: 20
            radius: 10
            color: plusMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
            opacity: sysmonRoot.highThreshold < 100 ? 1 : 0.4

            Text {
              anchors.centerIn: parent
              text: "\uf067"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Color.foreground
            }

            MouseArea {
              id: plusMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: sysmonRoot.stepThreshold(5)
            }
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.topMargin: 4
        Layout.bottomMargin: 4
      }

      Text {
        text: "ACTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Open Task Manager (btop) Action Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: btopMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf2db"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Open Task Manager (btop)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: "\uf08e"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: btopMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            sysmonRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-terminal-exec", "btop"])
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Poller: CPU / RAM / GPU / top processes, one sh process every 2 s
  // ---------------------------------------------------------------------------
  // CPU use over the last poll interval, as a share of all cores (what btop
  // shows); -1 until the second poll, since it needs a /proc/stat delta
  property real cpuPct: -1
  property real lastTotal: -1
  property real lastIdle: -1
  // utime + stime ticks per process at the previous poll, keyed "pid_starttime"
  // so a reused pid is never mistaken for the old process
  property var procTicks: ({})

  property real memUsedPct: -1
  property real memTotalKb: 0
  property real memAvailKb: 0

  // nvidia-smi; -1 until the first successful read (GPU readout stays hidden)
  property real gpuPct: -1
  property real gpuMemUsedMb: 0
  property real gpuMemTotalMb: 0

  // Tiered in-memory history for the chart. Tier t holds up to
  // tierLengths[t] samples spaced baseInterval * decimation^t seconds apart:
  // 15 min at 2s, then 1 h at 20s. Every decimation-th sample of a tier is
  // averaged into the next coarser tier, so memory stays constant. The fine
  // tier is long enough that the linear time scales up to 15 min are drawn
  // entirely at 2s resolution; beyond that a 20s mean is still under 2px
  // wide at the default card size. Each tier array is newest-LAST. Invalid
  // samples are -1 (GPU absent, first CPU poll); the mean ignores them and
  // the chart draws them as gaps.
  readonly property int baseInterval: 2 // seconds, matches pollTimer below
  readonly property var tierLengths: [451, 181]
  readonly property int tierCount: tierLengths.length
  readonly property int decimation: 10
  property var cpuHistory: [[], []]
  property var memHistory: [[], []]
  property var gpuHistory: [[], []]
  // Finer samples waiting to be averaged into tier t+1, one accumulator per
  // tier boundary.
  property var cpuPending: [[]]
  property var memPending: [[]]
  property var gpuPending: [[]]

  property string topCpuName: ""
  property real topCpuPct: -1
  property string topMemName: ""
  property real topMemPct: -1
  // Process with the highest GPU utilization; empty while no process is using the GPU
  property string topGpuName: ""
  property real topGpuPct: -1

  function isValidSample(v) {
    return typeof v === "number" && isFinite(v) && v >= 0
  }

  function meanValid(list) {
    const ok = list.filter(sysmonRoot.isValidSample)
    return ok.length ? ok.reduce((a, b) => a + b, 0) / ok.length : -1
  }

  // Appends one sample to tier 0 and cascades a mean into each coarser tier
  // whose accumulator fills. Returns { tiers, pending } built from NEW arrays:
  // QML `var` properties only emit their change signal on assignment, never
  // on an in-place push, so callers must assign both results back.
  function pushTiered(hist, pending, value) {
    const tiers = hist.slice()
    const pend = pending.slice()
    let v = value
    for (let t = 0; t < sysmonRoot.tierCount; t++) {
      const tier = tiers[t].slice(-(sysmonRoot.tierLengths[t] - 1))
      tier.push(v)
      tiers[t] = tier
      if (t === sysmonRoot.tierCount - 1) break
      const acc = pend[t].slice()
      acc.push(v)
      if (acc.length < sysmonRoot.decimation) {
        pend[t] = acc
        break
      }
      pend[t] = []
      v = sysmonRoot.meanValid(acc)
    }
    return { tiers: tiers, pending: pend }
  }

  function parse(text) {
    const lines = text.trim().split("\n")
    // Live top CPU process: the largest tick delta since the previous poll, as
    // a share of the all-core jiffies elapsed over the same interval, so it is
    // on the same scale as cpuPct (and btop's default per-process CPU%).
    let totalDelta = 0
    let sawProcs = false
    const ticks = {}
    let bestDelta = -1
    let bestName = ""
    for (const line of lines) {
      const parts = line.trim().split(/\s+/)
      if (parts[0] === "P") {
        // "P <pid_starttime> <ticks> <comm, may contain spaces>"
        sawProcs = true
        const t = Number(parts[2])
        ticks[parts[1]] = t
        const prev = sysmonRoot.procTicks[parts[1]]
        if (prev !== undefined && t - prev > bestDelta) {
          bestDelta = t - prev
          bestName = parts.slice(3).join(" ")
        }
      } else if (parts[0] === "cpu") {
        const nums = parts.slice(1).map(Number)
        const idle = nums[3] + (nums[4] || 0)
        const total = nums.reduce((a, b) => a + b, 0)
        if (sysmonRoot.lastTotal >= 0 && total > sysmonRoot.lastTotal) {
          totalDelta = total - sysmonRoot.lastTotal
          const pct = 100 * (1 - (idle - sysmonRoot.lastIdle) / totalDelta)
          sysmonRoot.cpuPct = Math.max(0, Math.min(100, pct))
        }
        sysmonRoot.lastTotal = total
        sysmonRoot.lastIdle = idle
      } else if (parts[0] === "MemTotal:") {
        sysmonRoot.memTotalKb = Number(parts[1])
      } else if (parts[0] === "MemAvailable:") {
        sysmonRoot.memAvailKb = Number(parts[1])
      } else if (parts[0] === "GPU") {
        const nums = line.slice(4).split(",").map(Number)
        if (nums.length === 3 && nums.every(isFinite)) {
          sysmonRoot.gpuPct = nums[0]
          sysmonRoot.gpuMemUsedMb = nums[1]
          sysmonRoot.gpuMemTotalMb = nums[2]
        }
      } else if (parts[0] === "TOPMEM" && parts.length >= 3) {
        // comm may contain spaces ("Web Content"); the percentage is the last column
        sysmonRoot.topMemName = parts.slice(1, -1).join(" ")
        sysmonRoot.topMemPct = Number(parts[parts.length - 1])
      } else if (parts[0] === "TOPGPU") {
        // "TOPGPU" alone means no process reported GPU utilization this poll
        sysmonRoot.topGpuName = parts.length >= 3 ? parts.slice(1, -1).join(" ") : ""
        sysmonRoot.topGpuPct = parts.length >= 3 ? Number(parts[parts.length - 1]) : -1
      }
    }
    if (sysmonRoot.memTotalKb > 0)
      sysmonRoot.memUsedPct = 100 * (1 - sysmonRoot.memAvailKb / sysmonRoot.memTotalKb)

    if (sawProcs) {
      if (bestDelta >= 0 && totalDelta > 0) {
        sysmonRoot.topCpuName = bestName
        sysmonRoot.topCpuPct = Math.min(100, 100 * bestDelta / totalDelta)
      } else {
        // First poll with process data: no previous snapshot to diff against yet
        sysmonRoot.topCpuName = ""
        sysmonRoot.topCpuPct = -1
      }
      sysmonRoot.procTicks = ticks
    } else if (Object.keys(sysmonRoot.procTicks).length > 0) {
      // Top line hidden: drop the snapshot so re-enabling never diffs a stale one
      sysmonRoot.procTicks = ({})
    }

    // All three series are pushed every poll (GPU as -1 when unavailable) so
    // their tiers stay index-aligned and share one age sequence in the chart.
    const c = sysmonRoot.pushTiered(sysmonRoot.cpuHistory, sysmonRoot.cpuPending, sysmonRoot.cpuPct)
    sysmonRoot.cpuHistory = c.tiers
    sysmonRoot.cpuPending = c.pending
    const m = sysmonRoot.pushTiered(sysmonRoot.memHistory, sysmonRoot.memPending, sysmonRoot.memUsedPct)
    sysmonRoot.memHistory = m.tiers
    sysmonRoot.memPending = m.pending
    const g = sysmonRoot.pushTiered(sysmonRoot.gpuHistory, sysmonRoot.gpuPending, sysmonRoot.gpuPct >= 0 ? sysmonRoot.gpuPct : -1)
    sysmonRoot.gpuHistory = g.tiers
    sysmonRoot.gpuPending = g.pending
  }

  Process {
    id: statProc
    // The process scans only run while the Top line is enabled and the widget is shown
    command: ["sh", "-c",
      "head -1 /proc/stat; " +
      "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
      "echo \"GPU $(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)\"; " +
      (sysmonRoot.showTop && sysmonRoot.visible
        // One "P <pid_starttime> <utime+stime ticks> <comm>" line per process that
        // has used any CPU; parse() diffs them against the previous poll. comm is
        // everything between the first "(" and the last ")" of /proc/<pid>/stat.
        ? "awk '{ s = $0; i = 0; while ((j = index(substr(s, i + 1), \")\")) > 0) i += j; o = index(s, \"(\"); split(substr(s, i + 2), f, \" \"); t = f[12] + f[13]; if (t > 0) print \"P\", $1 \"_\" f[20], t, substr(s, o + 1, i - o - 1) }' /proc/[0-9]*/stat 2>/dev/null; " +
          "echo \"TOPMEM $(ps -eo comm,%mem --sort=-%mem --no-headers | head -1)\"; " +
          // Per-process GPU utilization ("sm" column); the header row gives the column
          // positions, which differ between driver versions
          "echo \"TOPGPU $(nvidia-smi pmon -c 1 -s u 2>/dev/null | awk 'NR == 1 { for (i = 2; i <= NF; i++) { if ($i == \"sm\") s = i - 1; if ($i == \"command\") c = i - 1 } next } /^#/ { next } s && c && $s + 0 > max { max = $s + 0; name = $c } END { if (name != \"\") print name, max }')\""
        : "")]
    stdout: StdioCollector {
      onStreamFinished: sysmonRoot.parse(this.text)
    }
  }

  // Keeps running while hidden so the history stays continuous; the canvas
  // below skips repaints until it is visible again.
  Timer {
    id: pollTimer
    interval: sysmonRoot.baseInterval * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statProc.running) statProc.running = true
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------
  ColumnLayout {
    id: sysmonLayout
    anchors.fill: parent
    anchors.topMargin: Style.space(10)
    anchors.bottomMargin: Style.space(10)
    anchors.leftMargin: Style.space(16)
    anchors.rightMargin: Style.space(16)
    spacing: Style.space(6)

    // Header Row: title on the left, live CPU / RAM / GPU values centered in the
    // remaining width (they double as the chart legend: each label is drawn in
    // its series color)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "\uf0e4"
        font.family: Style.font.family
        font.pixelSize: 15
        color: Color.accent
      }

      Text {
        text: "System Monitor"
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Color.foreground
        elide: Text.ElideRight
        // Full title when there's room; only the title shrinks (eliding) on narrow
        // cards or in edit mode, so the values are never clipped. Ceil: layouts
        // hand out whole pixels, and a fractional implicitWidth rounded down
        // would elide a title that actually fits.
        Layout.fillWidth: true
        Layout.preferredWidth: Math.ceil(implicitWidth)
        Layout.maximumWidth: Math.ceil(implicitWidth)
      }

      Item { Layout.fillWidth: true }

      RowLayout {
        id: readouts
        spacing: Style.space(10)

        Repeater {
          model: [
            { color: sysmonRoot.cpuColor, label: "CPU", value: sysmonRoot.fmt(sysmonRoot.cpuPct), hot: sysmonRoot.cpuPct >= sysmonRoot.highThreshold, on: true },
            { color: sysmonRoot.memColor, label: "RAM", value: sysmonRoot.fmt(sysmonRoot.memUsedPct), hot: sysmonRoot.memUsedPct >= sysmonRoot.highThreshold, on: true },
            { color: sysmonRoot.gpuColor, label: "GPU", value: sysmonRoot.fmt(sysmonRoot.gpuPct), hot: sysmonRoot.gpuPct >= sysmonRoot.highThreshold, on: sysmonRoot.gpuPct >= 0 }
          ]
          delegate: RowLayout {
            required property var modelData
            visible: modelData.on
            spacing: Style.space(4)
            Text {
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: modelData.color
            }
            Text {
              text: modelData.value
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: modelData.hot ? sysmonRoot.hotColor : Color.foreground
            }
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Remove / Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeSysmonMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf00d"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.urgent
        }

        MouseArea {
          id: closeSysmonMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(sysmonRoot.widgetId, false, sysmonRoot.monitorName)
            }
          }
        }
      }

      // Drag Grip Button
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: sysmonGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0b2"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.accent
        }

        MouseArea {
          id: sysmonGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: sysmonRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, sysmonRoot.screenWidth - sysmonRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, sysmonRoot.screenHeight - sysmonRoot.height - 10)

          onPressed: sysmonRoot.customGripDragging = true
          onReleased: function() {
            sysmonRoot.customGripDragging = false
            var maxX = Math.max(10, sysmonRoot.screenWidth - sysmonRoot.width - 10)
            var maxY = Math.max(10, sysmonRoot.screenHeight - sysmonRoot.height - 10)
            var snappedX = sysmonRoot.snapVal(sysmonRoot.targetItem.x)
            var snappedY = sysmonRoot.snapVal(sysmonRoot.targetItem.y)
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            sysmonRoot.targetItem.x = snappedX
            sysmonRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(sysmonRoot.widgetId, snappedX, snappedY, sysmonRoot.snapVal(sysmonRoot.width), sysmonRoot.snapVal(sysmonRoot.height), sysmonRoot.monitorName)
            }
          }
          onCanceled: sysmonRoot.customGripDragging = false
        }
      }
    }

    // History chart (absorbs spare card height, shrinks first)
    Rectangle {
      id: graphCard
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 56
      implicitHeight: 84
      radius: 10
      color: Qt.rgba(0, 0, 0, 0.35)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      clip: true

      // Percent axis on the left: a 1px rule with 100/75/50/25/0 labels, or
      // 100/50/0 when the plot is short. Shares yFor()'s vertical mapping.
      Item {
        id: percentAxis
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.top: graph.top
        anchors.bottom: graph.bottom
        anchors.bottomMargin: graph.axisStrip
        width: axisLabelMetrics.width + Style.space(4)

        TextMetrics {
          id: axisLabelMetrics
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          text: "100%"
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 1
          color: Color.muted
        }

        Repeater {
          model: graph.height >= Style.space(100) ? [100, 75, 50, 25, 0] : [100, 50, 0]
          delegate: Text {
            required property int modelData
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            y: Math.max(0, Math.min(parent.height - height,
              parent.height - (modelData / 100) * (parent.height - 2) - 1 - height / 2))
            text: modelData + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
          }
        }
      }

      // Points come from the tiered buffers (2s / 20s), each tier drawn only
      // for the ages the finer tier does not cover; samples that land in the
      // same pixel column are averaged. The x axis shows the selected time
      // scale, linear or logarithmic. A faint grid anchored to wall-clock time
      // steps left with the data. Repainted only when a tier changes (every
      // 2s), a setting changes or the canvas resizes, unless smooth mode is
      // on, which repaints at 25 fps so the drift is continuous. Static age
      // labels (10s ... 30m and the time scale at the left edge) sit in a
      // strip under the x axis so the scale is readable.
      Canvas {
        id: graph
        anchors.left: percentAxis.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 4

        property var cHist: sysmonRoot.cpuHistory
        property var mHist: sysmonRoot.memHistory
        property var gHist: sysmonRoot.gpuHistory

        // requestPaint() runs onPaint even while hidden, so sampling behind
        // windows skips the redraw and the graph catches up once visible
        function repaintIfVisible() {
          if (visible) requestPaint()
        }
        onVisibleChanged: repaintIfVisible()

        // Wall-clock time of the newest sample: the reference the time-anchored
        // grid lines are aged against, so grid and data move together. Samples
        // are index-aged (j * interval); ageOffset is the seconds elapsed since
        // the newest one and stays 0 unless smooth mode is on, in which case
        // the timer below advances it so everything drifts left continuously
        // between polls. The newest point stays pinned to the right edge either
        // way because xFrac clamps ages under one poll.
        property real lastSampleMs: Date.now()
        property real ageOffset: 0
        onCHistChanged: {
          lastSampleMs = Date.now()
          ageOffset = 0
          repaintIfVisible()
        }

        Timer {
          interval: 40 // 25 fps is plenty for sub-pixel drift
          repeat: true
          running: graph.visible && sysmonRoot.smoothScroll
          onTriggered: {
            graph.ageOffset = Math.min(sysmonRoot.baseInterval,
              (Date.now() - graph.lastSampleMs) / 1000)
            graph.requestPaint()
          }
          onRunningChanged: if (!running) { graph.ageOffset = 0; graph.repaintIfVisible() }
        }
        onMHistChanged: repaintIfVisible()
        onGHistChanged: repaintIfVisible()
        onWidthChanged: repaintIfVisible()
        onHeightChanged: repaintIfVisible()

        // Age-to-x mapping: xFrac(age) is 0 at the left edge (spanSec ago,
        // the selected time scale) and 1 at the right edge (now). Linear mode
        // spaces time evenly; log mode compresses older samples toward the
        // left, and clamps ages below one poll interval to the right edge,
        // which also keeps ln() away from zero.
        readonly property bool logScale: sysmonRoot.logTimeScale
        readonly property real spanSec: sysmonRoot.timeScaleSeconds
        readonly property real logSpan: Math.log(spanSec / sysmonRoot.baseInterval)
        onLogScaleChanged: repaintIfVisible()
        onSpanSecChanged: repaintIfVisible()

        function xFrac(age) {
          if (logScale)
            return 1 - Math.log(Math.max(age, sysmonRoot.baseInterval) / sysmonRoot.baseInterval) / logSpan
          return 1 - age / spanSec
        }

        Connections {
          target: sysmonRoot
          function onCpuColorChanged() { graph.repaintIfVisible() }
          function onMemColorChanged() { graph.repaintIfVisible() }
          function onGpuColorChanged() { graph.repaintIfVisible() }
        }

        // The bottom axisStrip pixels hold the time-scale labels; the plot
        // (grid, series, 0% line) ends at plotH so the labels sit under the
        // x axis instead of over the data.
        readonly property real axisStrip: Style.font.caption + Style.space(8)
        readonly property real plotH: Math.max(1, height - axisStrip)

        // Same vertical mapping as the percentAxis labels.
        function yFor(v) {
          return plotH - (Math.max(0, Math.min(100, v)) / 100) * (plotH - 2) - 1
        }

        function isValid(v) {
          return typeof v === "number" && isFinite(v) && v >= 0
        }

        // Flattens one series' tiers into [{age, v}] oldest-first. Tiers are
        // walked coarse to fine; tier k contributes only ages at or beyond
        // what tier k-1 covers, and nothing older than spanSec plus one extra
        // sample, which keeps the line reaching the left edge while smooth
        // mode drifts it. Age is taken from the tier index (polls are
        // regular), so a coarse point can sit up to one coarse interval off
        // its true centre right at a tier boundary.
        function agePoints(tiers) {
          if (!tiers || !tiers.length) return []
          var pts = []
          for (var k = tiers.length - 1; k >= 0; k--) {
            var tier = tiers[k]
            var interval = sysmonRoot.baseInterval * Math.pow(sysmonRoot.decimation, k)
            var minAge = k === 0 ? 0
              : tiers[k - 1].length * sysmonRoot.baseInterval * Math.pow(sysmonRoot.decimation, k - 1)
            var n = tier.length
            for (var i = 0; i < n; i++) {
              var age = (n - 1 - i) * interval
              if (age > spanSec + interval || age < minAge) continue
              pts.push({ age: age, v: tier[i] })
            }
          }
          return pts
        }

        // Cached per series so hover bindings don't rebuild on every mouse
        // move. All three are pushed every poll, so they share one age
        // sequence and one hover index.
        readonly property var cPts: agePoints(cHist)
        readonly property var mPts: agePoints(mHist)
        readonly property var gPts: agePoints(gHist)
        readonly property int sampleCount: cPts.length

        // Hover state fed by hoverArea (a no-button MouseArea, so right-clicks
        // still reach WidgetCard's context menu)
        property bool hovering: false
        property real hoverX: 0
        property real hoverY: 0

        readonly property real hoverFraction: Math.max(0, Math.min(1, hoverX / Math.max(1, width)))
        readonly property int hoverIndex: nearestIndex(cPts, hoverFraction)
        readonly property real sampleX: hoverIndex >= 0
          ? xFrac(cPts[hoverIndex].age + ageOffset) * width : width

        // Nearest visible point along the x axis; at most ~630 points.
        function nearestIndex(pts, frac) {
          var best = -1
          var bestD = Infinity
          for (var i = 0; i < pts.length; i++) {
            if (pts[i].age > spanSec) continue // off-screen lead-in sample
            var d = Math.abs(xFrac(pts[i].age) - frac)
            if (d < bestD) { bestD = d; best = i }
          }
          return best
        }

        function valueAt(pts) {
          if (hoverIndex < 0 || hoverIndex >= pts.length) return "—"
          var v = pts[hoverIndex].v
          return isValid(v) ? v.toFixed(1) + "%" : "—"
        }

        function formatAge(s) {
          if (s < 60) return Math.round(s) + "s ago"
          if (s < 3600) return Math.round(s / 60) + "m ago"
          return (s / 3600).toFixed(s % 3600 ? 1 : 0) + "h ago"
        }

        // Hover crosshair
        Rectangle {
          visible: graph.hovering && graph.sampleCount > 0
          x: Math.min(graph.width - width, graph.sampleX)
          width: 1
          height: graph.plotH
          color: Color.muted
          opacity: 0.6
        }

        // Hover tooltip
        Rectangle {
          id: sampleTooltip
          visible: graph.hovering && graph.sampleCount > 0 && !sysmonRoot.isDragging && !sysmonRoot.isResizing
          z: 10
          width: Math.min(graph.width, tooltipText.implicitWidth + Style.space(16))
          height: tooltipText.implicitHeight + Style.space(12)
          x: Math.max(0, Math.min(graph.width - width,
            graph.sampleX + Style.space(12) + width <= graph.width
              ? graph.sampleX + Style.space(12) : graph.sampleX - width - Style.space(12)))
          y: Math.max(0, Math.min(graph.height - height,
            graph.hoverY - height - Style.space(10)))
          radius: 6
          color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)
          border.width: 1

          Text {
            id: tooltipText
            anchors.centerIn: parent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.foreground
            text: (graph.hoverIndex >= 0 ? graph.formatAge(graph.cPts[graph.hoverIndex].age) + "\n" : "")
              + "CPU  " + graph.valueAt(graph.cPts)
              + "\nRAM  " + graph.valueAt(graph.mPts)
              + (sysmonRoot.gpuPct >= 0 ? "\nGPU  " + graph.valueAt(graph.gPts) : "")
          }
        }

        // Vertical grid lines are anchored to wall-clock time, one every 10s
        // of absolute time, so they slide left with the data like a
        // task-manager graph. On a log axis equal time steps bunch up with
        // age, so each line fades with the spacing of its own level: a line
        // on a 10-minute multiple is judged by the 10-minute spacing at its
        // age, a plain 10s line by the 10s spacing. Fine lines dissolve as
        // they age while coarser ones carry on, so nothing pops and the
        // density stays even. Horizontal lines sit on the 25% marks.
        readonly property var gridLevels: [3600, 1800, 600, 300, 60, 30, 10]
        readonly property real gridBase: 10   // seconds between candidate lines
        readonly property real gridFadeOut: 4 // px spacing at which a line is gone
        readonly property real gridFadeIn: 16 // px spacing at which it is fully drawn

        function drawGrid(ctx) {
          ctx.save()
          ctx.strokeStyle = Color.muted
          ctx.globalAlpha = 0.28
          ctx.lineWidth = 1
          ctx.beginPath()
          for (var pct = 0; pct <= 100; pct += 25) {
            var y = Math.round(yFor(pct)) + 0.5 // crisp 1px line
            ctx.moveTo(0, y)
            ctx.lineTo(width, y)
          }
          ctx.stroke()
          // Same clock as the samples: the newest sample's wall time plus any
          // smooth-mode drift, so grid and data move together.
          var nowSec = lastSampleMs / 1000 + ageOffset
          var t = Math.floor(nowSec / gridBase) * gridBase
          for (; nowSec - t < spanSec; t -= gridBase) {
            var age = nowSec - t
            var x = Math.round(xFrac(age) * width) + 0.5
            if (x < 1) continue // percentAxis draws the left edge rule
            var level = gridBase
            for (var l = 0; l < gridLevels.length; l++) {
              if (t % gridLevels[l] === 0) { level = gridLevels[l]; break }
            }
            var gap = (xFrac(Math.max(0, age - level)) - xFrac(age)) * width
            var a = Math.min(1, Math.max(0, (gap - gridFadeOut) / (gridFadeIn - gridFadeOut)))
            if (a <= 0) continue
            ctx.globalAlpha = 0.28 * a
            ctx.beginPath()
            ctx.moveTo(x, 0)
            ctx.lineTo(x, plotH)
            ctx.stroke()
          }
          ctx.restore()
        }

        // One polyline per series. Samples sharing a pixel column (long or
        // log time scales) are averaged into one vertex instead of drawing a
        // zigzag. An invalid point lifts the pen so the line restarts at the
        // next valid one instead of bridging. The newest value is held to the
        // right edge, which only shows in linear smooth mode, where the
        // newest sample drifts left between polls.
        function drawSeries(ctx, pts, color) {
          if (!pts || pts.length < 2) return
          ctx.strokeStyle = color
          ctx.lineWidth = 1.5
          ctx.beginPath()
          var pen = false
          var col = -1
          var n = 0
          var sumX = 0
          var sumV = 0
          var lastY = 0
          function flush() {
            if (n === 0) return
            lastY = yFor(sumV / n)
            if (pen) ctx.lineTo(sumX / n, lastY)
            else ctx.moveTo(sumX / n, lastY)
            pen = true
            n = 0
            sumX = 0
            sumV = 0
          }
          for (var i = 0; i < pts.length; i++) {
            if (!isValid(pts[i].v)) { flush(); pen = false; col = -1; continue }
            var x = xFrac(pts[i].age + ageOffset) * width
            var c = Math.floor(x)
            if (c !== col) { flush(); col = c }
            sumX += x
            sumV += pts[i].v
            n++
          }
          flush()
          if (pen) ctx.lineTo(width, lastY)
          ctx.stroke()
        }

        // Static time-scale indicators in the strip under the x axis:
        // fixed-age marks that hold position while the grid slides past them,
        // plus the selected time scale at the left edge (how far back the
        // chart reaches). Each mark has a short brighter tick so it reads as
        // an axis mark, not a grid line. Labels that would overlap a
        // neighbour or run off the right edge are skipped.
        readonly property var axisMarks: [10, 30, 60, 300, 900, 1800]

        function drawAxisLabels(ctx) {
          ctx.save()
          // Foreground (not muted) so the labels stay readable on low-contrast themes
          ctx.font = "600 " + Style.font.caption + "px '" + Style.font.family + "'"
          ctx.textBaseline = "alphabetic"
          ctx.fillStyle = Color.foreground
          ctx.strokeStyle = Color.foreground
          ctx.lineWidth = 1
          var baseline = height - 3
          var gap = Style.space(6)

          // Span at the left edge.
          ctx.textAlign = "left"
          var spanText = sysmonRoot.shortDuration(spanSec)
          ctx.globalAlpha = 0.75
          ctx.fillText(spanText, 3, baseline)
          var lastRight = 3 + ctx.measureText(spanText).width

          ctx.textAlign = "center"
          for (var i = axisMarks.length - 1; i >= 0; i--) {
            var age = axisMarks[i]
            if (age >= spanSec * 0.9) continue
            var label = sysmonRoot.shortDuration(age)
            var x = Math.round(xFrac(age) * width) + 0.5
            var w = ctx.measureText(label).width
            if (x - w / 2 < lastRight + gap || x + w / 2 > width - 1) continue
            ctx.globalAlpha = 0.75
            ctx.fillText(label, x, baseline)
            ctx.globalAlpha = 0.5
            ctx.beginPath()
            ctx.moveTo(x, plotH)
            ctx.lineTo(x, plotH + 4)
            ctx.stroke()
            lastRight = x + w / 2
          }
          ctx.restore()
        }

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          drawGrid(ctx)
          drawSeries(ctx, mPts, sysmonRoot.memColor)
          drawSeries(ctx, gPts, sysmonRoot.gpuColor)
          drawSeries(ctx, cPts, sysmonRoot.cpuColor)
          drawAxisLabels(ctx)
        }
      }

      // Interactive Hover Tracking (no buttons, so clicks still reach the card)
      MouseArea {
        id: hoverArea
        anchors.fill: graph
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onPositionChanged: function(mouse) {
          graph.hoverX = mouse.x
          graph.hoverY = mouse.y
          graph.hovering = true
        }

        onExited: graph.hovering = false
      }
    }

    // Optional top processes line (single row, like the Network widget's totals):
    // a "TOP" tag, then the busiest process per resource split by hairline
    // dividers, each labelled in its series color. The group is centered; only
    // the process names elide when the row runs out of width.
    RowLayout {
      Layout.fillWidth: true
      visible: sysmonRoot.showTop && (sysmonRoot.topCpuName !== "" || sysmonRoot.topMemName !== "")
      spacing: Style.space(10)

      Item { Layout.fillWidth: true }

      Rectangle {
        implicitWidth: topTagText.implicitWidth + 10
        implicitHeight: 15
        radius: 7.5
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1

        Text {
          id: topTagText
          anchors.centerIn: parent
          text: "TOP"
          font.family: Style.font.family
          font.pixelSize: 8
          font.weight: Font.Bold
          font.letterSpacing: 1
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
        }
      }

      Repeater {
        model: [
          { color: sysmonRoot.cpuColor, label: "CPU", name: sysmonRoot.topCpuName, value: sysmonRoot.fmtTop(sysmonRoot.topCpuPct), on: true },
          { color: sysmonRoot.memColor, label: "RAM", name: sysmonRoot.topMemName, value: sysmonRoot.fmtTop(sysmonRoot.topMemPct), on: true },
          { color: sysmonRoot.gpuColor, label: "GPU", name: sysmonRoot.topGpuName !== "" ? sysmonRoot.topGpuName : "idle",
            value: sysmonRoot.topGpuName !== "" ? sysmonRoot.fmt(sysmonRoot.topGpuPct) : "", on: sysmonRoot.gpuPct >= 0 }
        ]
        delegate: RowLayout {
          required property var modelData
          required property int index
          visible: modelData.on
          // Fill so the name can shrink, but never grow past the content width:
          // the outer spacers take the slack and keep the group centered
          Layout.fillWidth: true
          Layout.maximumWidth: Math.ceil(implicitWidth)
          spacing: Style.space(4)

          // Divider before every column but the first; the right margin plus
          // spacing matches the row spacing on its left, so it sits centered
          Rectangle {
            visible: index > 0
            Layout.preferredWidth: 1
            Layout.preferredHeight: 10
            Layout.rightMargin: Style.space(6)
            color: Qt.rgba(1, 1, 1, 0.12)
          }

          Text {
            text: modelData.label
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: modelData.color
          }

          Text {
            text: modelData.name
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8)
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.preferredWidth: Math.ceil(implicitWidth)
            Layout.maximumWidth: Math.ceil(implicitWidth)
          }

          Text {
            visible: modelData.value !== ""
            text: modelData.value
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }
      }

      Item { Layout.fillWidth: true }
    }
  }
}
