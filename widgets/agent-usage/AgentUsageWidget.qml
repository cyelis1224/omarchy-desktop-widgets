import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
// Qt 6.12 adds a QtQuick "Color" singleton that wins over qs.Commons.Color in
// these subfolder widgets; reference the shell colours through an alias.
import qs.Commons as Sh
import qs.Ui

import "../../shared"
import ".."

// Agent Usage — rate limits, tokens and models for every AI coding account.
//
// Reads the records Omarchy's agent collectors write (the same data the stock
// Agents bar panel shows) through get-agent-usage.sh, which also collects any
// extra Claude Code / Codex accounts (e.g. ~/.claude-personal) so two logins
// of the same tool show up side by side.
WidgetCard {
  id: agentRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Placement Settings
  // ---------------------------------------------------------------------------
  widgetId: "agent_usage"
  title: "Agent Usage"
  icon: ""
  showHeader: false

  defaultX: Math.round((screenWidth - width) / 2)
  defaultY: 120

  width: 360
  height: cardLayout.implicitHeight + Style.space(32)
  minWidth: 320
  minHeight: 260
  menuWidth: 300
  // Height follows the content (more limits or accounts grow the card), so
  // the saved geometry must not pin it.
  resizable: false

  // ---------------------------------------------------------------------------
  // 📊 Usage State
  // ---------------------------------------------------------------------------
  property var records: []
  property var hiddenAccounts: []
  property string selectedId: ""
  property int refreshIntervalMin: 15
  property bool refreshing: false
  property real nowMs: Date.now()

  readonly property string scriptPath: Qt.resolvedUrl("get-agent-usage.sh").toString().replace(/^file:\/\//, "")

  // Accounts worth a tab: enabled, and either limits or local stats to show.
  readonly property var accounts: {
    var list = []
    for (var i = 0; i < records.length; i++) {
      var r = records[i]
      if (hiddenAccounts.indexOf(r.id) !== -1) continue
      if (!r.ready && !r.hasLocalStats) continue
      list.push(r)
    }
    // Keep a tool's accounts next to each other: claude, claude-personal, codex…
    list.sort(function(a, b) {
      if (a.kind !== b.kind) return a.kind < b.kind ? -1 : 1
      if (a.id === a.kind) return -1
      if (b.id === b.kind) return 1
      return a.id < b.id ? -1 : 1
    })
    return list
  }

  readonly property var current: {
    for (var i = 0; i < accounts.length; i++) {
      if (accounts[i].id === selectedId) return accounts[i]
    }
    return accounts.length > 0 ? accounts[0] : null
  }

  readonly property var sessionLimit: findLimit(current, /session|5-hour/i)
  readonly property var weeklyLimit: findLimit(current, /^weekly|7-day/i)
  readonly property var extraLimits: {
    if (!current || !current.limits) return []
    var list = []
    for (var i = 0; i < current.limits.length; i++) {
      var l = current.limits[i]
      if (l !== sessionLimit && l !== weeklyLimit) list.push(l)
    }
    return list
  }

  readonly property var days: current && current.recentDays ? current.recentDays : []
  readonly property real maxDay: {
    var m = 0
    for (var i = 0; i < days.length; i++) m = Math.max(m, Number(days[i].messageCount) || 0)
    return m
  }

  readonly property var topModels: {
    if (!current || !current.modelUsage) return []
    var list = []
    for (var name in current.modelUsage) {
      var u = current.modelUsage[name] || {}
      var total = (Number(u.inputTokens) || 0) + (Number(u.outputTokens) || 0)
        + (Number(u.cacheCreationInputTokens) || 0) + (Number(u.cacheReadInputTokens) || 0)
      if (total > 0) list.push({ name: name, total: total })
    }
    list.sort(function(a, b) { return b.total - a.total })
    return list.slice(0, 3)
  }

  readonly property string statusText: {
    if (!current) return "NO DATA"
    if (current.usageStatusText) return current.usageStatusText.toUpperCase()
    if (!current.ready) return "OFFLINE"
    return "LIVE"
  }
  readonly property color statusColor: {
    if (!current || !current.ready) return Sh.Color.urgent
    if (current.usageStatusText) return "#f59e0b"
    return "#10b981"
  }

  // ---------------------------------------------------------------------------
  // 🧮 Helpers
  // ---------------------------------------------------------------------------
  function findLimit(rec, pattern) {
    if (!rec || !rec.limits) return null
    for (var i = 0; i < rec.limits.length; i++) {
      if (pattern.test(String(rec.limits[i].label || ""))) return rec.limits[i]
    }
    return null
  }

  function levelColor(pct) {
    if (pct >= 0.9) return Sh.Color.urgent
    if (pct >= 0.75) return "#f59e0b"
    if (pct >= 0.5) return "#06b6d4"
    return "#10b981"
  }

  function fmtTokens(n) {
    n = Number(n) || 0
    if (n >= 1e9) return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "K"
    return String(Math.round(n))
  }

  function parseTime(iso) {
    if (!iso) return NaN
    // V4's Date parser rejects microseconds; keep milliseconds only.
    return Date.parse(String(iso).replace(/\.(\d{3})\d+/, ".$1"))
  }

  function fmtReset(iso) {
    var t = parseTime(iso)
    if (!isFinite(t)) return ""
    var mins = Math.max(0, Math.round((t - nowMs) / 60000))
    if (mins >= 1440) return Math.floor(mins / 1440) + "d " + Math.floor((mins % 1440) / 60) + "h"
    if (mins >= 60) return Math.floor(mins / 60) + "h " + (mins % 60) + "m"
    return mins + "m"
  }

  function fmtAgo(iso) {
    var t = parseTime(iso)
    if (!isFinite(t)) return "never"
    var mins = Math.max(0, Math.round((nowMs - t) / 60000))
    if (mins < 1) return "just now"
    if (mins < 60) return mins + "m ago"
    return Math.floor(mins / 60) + "h ago"
  }

  function prettyModel(name) {
    var n = String(name)
    if (/^gpt/i.test(n)) return n.toUpperCase().replace("GPT-", "GPT-")
    n = n.replace(/^claude-/, "").replace(/-\d{8}$/, "")
    var parts = n.split("-")
    var word = parts.shift()
    var label = word.charAt(0).toUpperCase() + word.slice(1)
    return parts.length ? label + " " + parts.join(".") : label
  }

  function markFor(rec) {
    var kind = rec ? String(rec.kind || rec.id || "") : ""
    if (kind === "claude" || kind === "codex" || kind === "fireworks") return Qt.resolvedUrl("assets/" + kind + ".svg")
    return ""
  }

  function shortName(rec) {
    if (!rec) return ""
    if (rec.id === rec.kind) {
      if (rec.kind === "claude") return "Claude"
      if (rec.kind === "codex") return "Codex"
    }
    return rec.name || rec.id
  }

  function dayLetter(date) {
    var d = new Date(String(date) + "T12:00:00")
    return ["S", "M", "T", "W", "T", "F", "S"][d.getDay()] || "·"
  }

  function selectAccount(id) {
    selectedId = id
    saveSetting("selectedId", id)
  }

  function toggleHidden(id) {
    var list = hiddenAccounts.slice()
    var idx = list.indexOf(id)
    if (idx === -1) list.push(id); else list.splice(idx, 1)
    hiddenAccounts = list
    saveSetting("hiddenAccounts", list)
  }

  function runFeed(mode) {
    if (feedProc.running) return
    refreshing = mode !== "read"
    feedProc.command = ["bash", scriptPath, mode]
    feedProc.running = true
  }

  function applySavedSettings() {
    if (!rootRef || !rootRef.settingsReady) return
    var s = getSetting("selectedId", undefined)
    if (typeof s === "string") selectedId = s
    var h = getSetting("hiddenAccounts", undefined)
    if (Array.isArray(h)) hiddenAccounts = h
    var r = getSetting("refreshIntervalMin", undefined)
    if (typeof r === "number" && r > 0) refreshIntervalMin = r
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    runFeed("read")
    Qt.callLater(function() { agentRoot.runFeed("refresh") })
  }

  // ---------------------------------------------------------------------------
  // 🔌 Data Feed
  // ---------------------------------------------------------------------------
  Process {
    id: feedProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          if (Array.isArray(parsed)) agentRoot.records = parsed
        } catch (e) {
          console.warn("agent-usage: bad feed output", e)
        }
      }
    }
    onExited: {
      agentRoot.refreshing = false
      agentRoot.nowMs = Date.now()
    }
  }

  // Cheap re-read: picks up records the stock Agents panel refreshes.
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: {
      agentRoot.nowMs = Date.now()
      agentRoot.runFeed("read")
    }
  }

  // Full collection, including the extra accounts nothing else refreshes.
  Timer {
    interval: Math.max(1, agentRoot.refreshIntervalMin) * 60000
    running: true
    repeat: true
    onTriggered: agentRoot.runFeed("refresh")
  }

  // ---------------------------------------------------------------------------
  // 📋 Context Menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "ACCOUNTS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      Repeater {
        model: agentRoot.records.filter(function(r) { return r.ready || r.hasLocalStats })

        MenuRow {
          required property var modelData
          readonly property bool shown: agentRoot.hiddenAccounts.indexOf(modelData.id) === -1
          glyph: shown ? "" : ""
          glyphColor: shown ? Sh.Color.accent : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.4)
          label: agentRoot.shortName(modelData) + (modelData.account ? "  ·  " + modelData.account : "")
          onClicked: agentRoot.toggleHidden(modelData.id)
        }
      }

      Text {
        text: "REFRESH EVERY"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 6
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: Style.space(4)

        Repeater {
          model: [5, 15, 30, 60]

          Rectangle {
            required property int modelData
            readonly property bool active: agentRoot.refreshIntervalMin === modelData
            implicitWidth: 46
            implicitHeight: 24
            radius: 12
            color: active ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.25) : (intervalMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
            border.color: active ? Sh.Color.accent : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData < 60 ? modelData + "m" : "1h"
              font.family: Style.font.family
              font.pixelSize: 10
              color: active ? Sh.Color.accent : Sh.Color.foreground
            }

            MouseArea {
              id: intervalMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                agentRoot.refreshIntervalMin = modelData
                agentRoot.saveSetting("refreshIntervalMin", modelData)
              }
            }
          }
        }
      }

      Text {
        text: "ACTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 6
      }

      MenuRow {
        glyph: ""
        label: "Refresh now"
        onClicked: {
          agentRoot.contextMenuOpen = false
          agentRoot.runFeed("force")
        }
      }

      MenuRow {
        glyph: ""
        label: "Open usage records folder"
        onClicked: {
          agentRoot.contextMenuOpen = false
          Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage"])
        }
      }
    }
  }

  component MenuRow: Rectangle {
    id: menuRow
    property string glyph: ""
    property color glyphColor: Sh.Color.accent
    property string label: ""
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 28
    radius: 6
    color: rowMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.2) : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: menuRow.glyph
        font.family: Style.font.family
        font.pixelSize: 12
        color: menuRow.glyphColor
      }

      Text {
        Layout.fillWidth: true
        text: menuRow.label
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: 11
        color: Sh.Color.foreground
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: menuRow.clicked()
    }
  }

  // ---------------------------------------------------------------------------
  // ⭕ Limit gauge (session / weekly)
  // ---------------------------------------------------------------------------
  component UsageGauge: Rectangle {
    id: gauge
    property string caption: ""
    property var limit: null
    readonly property real pct: limit ? Math.max(0, Math.min(1, Number(limit.percent) || 0)) : 0
    readonly property color arcColor: agentRoot.levelColor(pct)

    Layout.fillWidth: true
    implicitHeight: 128
    radius: 14
    color: Qt.rgba(1, 1, 1, 0.04)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    onPctChanged: arc.requestPaint()
    onArcColorChanged: arc.requestPaint()

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 2

      Item {
        width: 74
        height: 74
        Layout.alignment: Qt.AlignHCenter

        Canvas {
          id: arc
          anchors.fill: parent
          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2
            var cy = height / 2
            var radius = (width - 12) / 2
            var start = 0.75 * Math.PI
            var end = 2.25 * Math.PI

            ctx.beginPath()
            ctx.arc(cx, cy, radius, start, end)
            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
            ctx.lineWidth = 6
            ctx.lineCap = "round"
            ctx.stroke()

            if (!gauge.limit) return
            ctx.beginPath()
            ctx.arc(cx, cy, radius, start, start + Math.max(0.005, gauge.pct) * (end - start))
            ctx.strokeStyle = gauge.arcColor.toString()
            ctx.lineWidth = 6
            ctx.lineCap = "round"
            ctx.stroke()
          }
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 0

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: gauge.limit ? Math.round(gauge.pct * 100) + "%" : "—"
            font.family: Style.font.family
            font.pixelSize: 15
            font.weight: Font.Bold
            color: Sh.Color.foreground
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "USED"
            font.family: Style.font.family
            font.pixelSize: 8
            font.weight: Font.DemiBold
            color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.5)
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: gauge.caption
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Sh.Color.foreground
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: gauge.limit && gauge.limit.resetsAt ? "resets in " + agentRoot.fmtReset(gauge.limit.resetsAt) : "no limit data"
        font.family: Style.font.family
        font.pixelSize: 9
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.5)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 Main Widget Body
  // ---------------------------------------------------------------------------
  ColumnLayout {
    id: cardLayout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(16)
    spacing: Style.space(12)

    // -------------------------------------------------------------------------
    // 🏷️ Header: tool mark, account, status badge, refresh & edit controls
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Rectangle {
        width: 28
        height: 28
        radius: 14
        color: Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.18)
        border.color: Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.4)
        border.width: 1

        Image {
          id: headerMark
          anchors.centerIn: parent
          width: 16
          height: 16
          source: agentRoot.markFor(agentRoot.current)
          sourceSize.width: 32
          sourceSize.height: 32
          fillMode: Image.PreserveAspectFit
          visible: status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: !headerMark.visible
          text: agentRoot.icon
          font.family: Style.font.family
          font.pixelSize: 12
          color: Sh.Color.accent
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          text: agentRoot.current ? agentRoot.shortName(agentRoot.current) : "Agent Usage"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Sh.Color.foreground
        }

        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          text: {
            var c = agentRoot.current
            if (!c) return "No agent usage recorded yet"
            var bits = []
            if (c.account) bits.push(c.account)
            if (c.tierLabel) bits.push(c.tierLabel)
            return bits.length ? bits.join(" · ") : (c.name || "")
          }
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.5)
        }
      }

      // Live status badge
      Rectangle {
        implicitWidth: badgeRow.implicitWidth + 14
        implicitHeight: 20
        radius: 10
        color: Qt.rgba(agentRoot.statusColor.r, agentRoot.statusColor.g, agentRoot.statusColor.b, 0.18)
        border.color: Qt.rgba(agentRoot.statusColor.r, agentRoot.statusColor.g, agentRoot.statusColor.b, 0.5)
        border.width: 1

        RowLayout {
          id: badgeRow
          anchors.centerIn: parent
          spacing: 4

          Rectangle {
            width: 6
            height: 6
            radius: 3
            color: agentRoot.statusColor
          }

          Text {
            text: agentRoot.statusText
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: agentRoot.statusColor
          }
        }
      }

      // Refresh
      Rectangle {
        width: 22
        height: 22
        radius: 11
        color: refreshMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Text {
          id: refreshGlyph
          anchors.centerIn: parent
          text: ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: agentRoot.refreshing ? Sh.Color.accent : Sh.Color.foreground

          RotationAnimation on rotation {
            running: agentRoot.refreshing
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
          }
        }

        MouseArea {
          id: refreshMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: agentRoot.runFeed("force")
        }
      }

      // Close (edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeMouse.containsMouse ? Qt.rgba(Sh.Color.urgent.r, Sh.Color.urgent.g, Sh.Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Sh.Color.urgent.r, Sh.Color.urgent.g, Sh.Color.urgent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: Sh.Color.urgent
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled)
              rootRef.toggleWidgetEnabled(agentRoot.widgetId, false, agentRoot.monitorName)
          }
        }
      }

      // Move grip (edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: gripMouse.drag.active ? Sh.Color.accent : (gripMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: ""
          font.family: Style.font.family
          font.pixelSize: 10
          color: gripMouse.drag.active ? Sh.Color.background : Sh.Color.accent
        }

        MouseArea {
          id: gripMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: agentRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, agentRoot.screenWidth - agentRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, agentRoot.screenHeight - agentRoot.height - 10)

          onPressed: agentRoot.customGripDragging = true
          onReleased: function() {
            agentRoot.customGripDragging = false
            var maxX = Math.max(10, agentRoot.screenWidth - agentRoot.width - 10)
            var maxY = Math.max(10, agentRoot.screenHeight - agentRoot.height - 10)
            var x = Math.max(10, Math.min(maxX, agentRoot.snapVal(agentRoot.targetItem.x)))
            var y = Math.max(10, Math.min(maxY, agentRoot.snapVal(agentRoot.targetItem.y)))
            agentRoot.targetItem.x = x
            agentRoot.targetItem.y = y
            if (rootRef && rootRef.saveWidgetPos)
              rootRef.saveWidgetPos(agentRoot.widgetId, x, y, agentRoot.snapVal(agentRoot.width), agentRoot.snapVal(agentRoot.height), agentRoot.monitorName)
          }
          onCanceled: agentRoot.customGripDragging = false
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🔀 Account switcher — one chip per account, two logins of a tool included
    // -------------------------------------------------------------------------
    Flow {
      Layout.fillWidth: true
      visible: agentRoot.accounts.length > 1
      spacing: Style.space(6)

      Repeater {
        model: agentRoot.accounts

        Rectangle {
          required property var modelData
          readonly property bool active: agentRoot.current && agentRoot.current.id === modelData.id
          implicitWidth: chipRow.implicitWidth + 18
          implicitHeight: 24
          radius: 12
          color: active ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.22) : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
          border.color: active ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.6) : Qt.rgba(1, 1, 1, 0.08)
          border.width: 1

          RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            Image {
              width: 12
              height: 12
              Layout.preferredWidth: 12
              Layout.preferredHeight: 12
              source: agentRoot.markFor(modelData)
              sourceSize.width: 24
              sourceSize.height: 24
              fillMode: Image.PreserveAspectFit
            }

            Text {
              text: agentRoot.shortName(modelData)
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: active ? Font.Bold : Font.Normal
              color: active ? Sh.Color.foreground : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.7)
            }
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: agentRoot.selectAccount(modelData.id)
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // ⚠️ Auth / availability notice
    // -------------------------------------------------------------------------
    Rectangle {
      Layout.fillWidth: true
      visible: agentRoot.current !== null && (!agentRoot.current.ready || !!agentRoot.current.usageStatusText) && !!agentRoot.current.authHelpText
      implicitHeight: noticeText.implicitHeight + Style.space(14)
      radius: 8
      color: Qt.rgba(0.96, 0.62, 0.04, 0.1)
      border.color: Qt.rgba(0.96, 0.62, 0.04, 0.35)
      border.width: 1

      Text {
        id: noticeText
        anchors.fill: parent
        anchors.margins: Style.space(7)
        wrapMode: Text.WordWrap
        text: agentRoot.current ? String(agentRoot.current.authHelpText || "") : ""
        font.family: Style.font.family
        font.pixelSize: 10
        color: "#f59e0b"
      }
    }

    // -------------------------------------------------------------------------
    // ⭕ Session & weekly limits
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      visible: agentRoot.current !== null
      spacing: Style.space(12)

      UsageGauge {
        caption: "Session · 5h"
        limit: agentRoot.sessionLimit
      }

      UsageGauge {
        caption: "Weekly · 7d"
        limit: agentRoot.weeklyLimit
      }
    }

    // Any other limit the account reports (model-specific weekly caps, etc.)
    Repeater {
      model: agentRoot.extraLimits

      Rectangle {
        required property var modelData
        readonly property real pct: Math.max(0, Math.min(1, Number(modelData.percent) || 0))
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            Layout.preferredWidth: 96
            text: modelData.title || modelData.label
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: 11
            color: Sh.Color.foreground
          }

          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
              width: Math.max(4, parent.width * pct)
              height: parent.height
              radius: 3
              color: agentRoot.levelColor(pct)
            }
          }

          Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(pct * 100) + "%"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.Bold
            color: agentRoot.levelColor(pct)
          }

          Text {
            Layout.preferredWidth: 46
            horizontalAlignment: Text.AlignRight
            text: agentRoot.fmtReset(modelData.resetsAt)
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.5)
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📈 Tokens over the last seven days
    // -------------------------------------------------------------------------
    Rectangle {
      Layout.fillWidth: true
      visible: agentRoot.days.length > 0
      implicitHeight: 118
      radius: 14
      color: Qt.rgba(1, 1, 1, 0.04)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "TOKENS · 7 DAYS"
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
          }

          Item { Layout.fillWidth: true }

          Text {
            text: {
              var c = agentRoot.current
              if (!c) return ""
              var s = "Today " + agentRoot.fmtTokens(c.todayTotalTokens)
              if (c.todayPrompts) s += " · " + c.todayPrompts + " prompts"
              return s
            }
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Sh.Color.foreground
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(6)

          Repeater {
            model: agentRoot.days

            ColumnLayout {
              required property var modelData
              required property int index
              readonly property real value: Number(modelData.messageCount) || 0
              readonly property bool isToday: index === agentRoot.days.length - 1
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 3

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Math.min(parent.width, 22)
                  height: value > 0 && agentRoot.maxDay > 0 ? Math.max(4, parent.height * value / agentRoot.maxDay) : 3
                  radius: 4
                  color: value <= 0 ? Qt.rgba(1, 1, 1, 0.08)
                    : (isToday ? Sh.Color.accent : Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.45))

                  MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    anchors.topMargin: -20
                    hoverEnabled: true
                  }
                }

                Text {
                  visible: dayMouse.containsMouse || (isToday && value > 0)
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  text: agentRoot.fmtTokens(value)
                  font.family: Style.font.family
                  font.pixelSize: 9
                  font.weight: Font.Bold
                  color: Sh.Color.foreground
                }
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: agentRoot.dayLetter(modelData.date)
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: isToday ? Font.Bold : Font.Normal
                color: isToday ? Sh.Color.foreground : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
              }
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🧠 Heaviest models (all time)
    // -------------------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      visible: agentRoot.topModels.length > 0
      spacing: Style.space(5)

      Text {
        text: "TOP MODELS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
        Layout.leftMargin: 2
      }

      Repeater {
        model: agentRoot.topModels

        RowLayout {
          required property var modelData
          required property int index
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            Layout.preferredWidth: 96
            text: agentRoot.prettyModel(modelData.name)
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: 11
            color: Sh.Color.foreground
          }

          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
              width: Math.max(4, parent.width * modelData.total / agentRoot.topModels[0].total)
              height: parent.height
              radius: 3
              color: Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, index === 0 ? 0.9 : 0.5)
            }
          }

          Text {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: agentRoot.fmtTokens(modelData.total)
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Sh.Color.foreground
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Footer
    // -------------------------------------------------------------------------
    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      text: agentRoot.current ? "updated " + agentRoot.fmtAgo(agentRoot.current.updatedAt) : ""
      font.family: Style.font.family
      font.pixelSize: 9
      color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.4)
    }
  }
}
