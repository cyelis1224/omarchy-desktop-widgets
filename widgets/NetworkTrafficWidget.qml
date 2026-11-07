import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

WidgetCard {
  id: networkWidgetRoot

  widgetId: "network"
  title: "Network Traffic"
  icon: "\uf0ec"
  showHeader: false // custom layout header with live indicator
  defaultX: screenWidth - width - Style.space(24)
  defaultY: Style.space(64)

  width: 360
  height: netCardLayout.implicitHeight + netCardLayout.anchors.topMargin + netCardLayout.anchors.bottomMargin
  minWidth: 280
  // Content height with the graph squeezed to its minimum, so no row is ever clipped
  minHeight: Math.ceil(netCardLayout.implicitHeight - graphCard.implicitHeight + graphCard.Layout.minimumHeight
                       + netCardLayout.anchors.topMargin + netCardLayout.anchors.bottomMargin)

  // Resize handles clamp to minHeight, but restored sizes and toggling Session
  // Totals on a short card bypass them. The check is deferred until bindings
  // settle (and skipped during construction): mid-update, height can briefly lag
  // minHeight, and assigning it would break the default content-height binding.
  property bool minHeightClampReady: false
  function ensureMinHeight() {
    if (minHeightClampReady && !isResizing && height < minHeight) height = minHeight
  }
  onMinHeightChanged: Qt.callLater(ensureMinHeight)
  onHeightChanged: Qt.callLater(ensureMinHeight)

  // ---------------------------------------------------------------------------
  // 🌐 Network Traffic State & Poller Process
  // ---------------------------------------------------------------------------
  property real netRxSpeed: 0
  property real netTxSpeed: 0
  property string netRxSpeedStr: "0.0 KB/s"
  property string netTxSpeedStr: "0.0 KB/s"
  property string netRxTotalStr: ""
  property string netTxTotalStr: ""
  property string netIface: "Network"
  property bool fillGraph: true
  property bool showTotals: false
  property bool logTimeScale: false
  property int timeScaleSeconds: 30
  property bool timeScaleMenuOpen: false
  readonly property var timeScaleOptions: [
    { seconds: 30, label: "30 sec" },
    { seconds: 60, label: "1 min" },
    { seconds: 120, label: "2 min" },
    { seconds: 300, label: "5 min" },
    { seconds: 900, label: "15 min" },
    { seconds: 1800, label: "30 min" },
    { seconds: 3600, label: "1 hr" }
  ]
  // Buffer sized for the longest time scale, so switching scales shows data immediately.
  // The +1 makes the oldest visible sample (left edge) exactly the time scale old.
  readonly property int historyLength: Math.round(timeScaleOptions[timeScaleOptions.length - 1].seconds * 1000 / netPollTimer.interval) + 1
  readonly property int visibleSamples: Math.max(2, Math.min(historyLength, Math.round(timeScaleSeconds * 1000 / netPollTimer.interval) + 1))
  readonly property real logTimeKnee: 4 // Samples; larger flattens the log curve
  property var netRxHistory: emptyHistory()
  property var netTxHistory: emptyHistory()
  property int hoverIndex: -1

  function emptyHistory() {
    var arr = []
    for (var i = 0; i < historyLength; i++) arr.push(0)
    return arr
  }

  // Mirrors format_speed() in get-network.sh
  function formatSpeed(bps) {
    if (bps < 1024) return bps.toFixed(0) + " B/s"
    if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s"
    if (bps < 1024 * 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + " MB/s"
    return (bps / (1024 * 1024 * 1024)).toFixed(2) + " GB/s"
  }

  function hoverTimeOffset() {
    var steps = netRxHistory.length - 1 - hoverIndex
    if (steps <= 0) return "Now"
    var secs = steps * netPollTimer.interval / 1000
    if (secs < 60) return "-" + Number(secs).toFixed(1).replace(/\.0$/, "") + "s"
    var total = Math.round(secs)
    var rem = total % 60
    return "-" + Math.floor(total / 60) + "m" + (rem > 0 ? " " + rem + "s" : "")
  }

  function timeScaleLabel() {
    for (var i = 0; i < timeScaleOptions.length; i++) {
      if (timeScaleOptions[i].seconds === timeScaleSeconds) return timeScaleOptions[i].label
    }
    return timeScaleSeconds + "s"
  }

  // ---------------------------------------------------------------------------
  // Graph X-Axis Mapping (shared by canvas, hover tracking and tooltip)
  // Both modes show the newest `visibleSamples` (the selected time scale): linear
  // mode spaces them evenly, log mode compresses older samples toward the left.
  // ---------------------------------------------------------------------------
  function firstVisibleIndex() {
    return Math.max(0, netRxHistory.length - visibleSamples)
  }

  // Horizontal position (0 = left edge, 1 = now) of a sample `age` polls old
  function ageFraction(age) {
    var maxAge = visibleSamples - 1
    if (logTimeScale) {
      var span = Math.log((maxAge + logTimeKnee) / logTimeKnee)
      return 1 - Math.log((age + logTimeKnee) / logTimeKnee) / span
    }
    return 1 - age / maxAge
  }

  function xFraction(i) {
    return ageFraction(netRxHistory.length - 1 - i)
  }

  // Inverse of xFraction(): history index nearest to a horizontal position
  function indexAtFraction(f) {
    var age
    var maxAge = visibleSamples - 1
    if (logTimeScale) {
      var span = Math.log((maxAge + logTimeKnee) / logTimeKnee)
      age = logTimeKnee * Math.exp((1 - f) * span) - logTimeKnee
    } else {
      age = (1 - f) * maxAge
    }
    var idx = netRxHistory.length - 1 - Math.round(age)
    return Math.max(firstVisibleIndex(), Math.min(netRxHistory.length - 1, idx))
  }

  function shortDuration(secs) {
    if (secs < 60) return secs + "s"
    if (secs < 3600) return (secs / 60) + "m"
    return (secs / 3600) + "h"
  }

  // Time reference marks as [{ x, label }] in canvas pixels. The left edge always
  // labels the full time scale; inner marks are thinned so label chips never
  // crowd each other or either edge at narrow widths.
  function timeMarkers(canvasWidth) {
    var minGap = 30
    var marks = [10, 30, 60, 300, 900, 1800]
    var result = []
    var lastX = canvasWidth
    for (var m = 0; m < marks.length; m++) {
      var age = marks[m] * 1000 / netPollTimer.interval
      if (age >= visibleSamples - 1) break
      var x = ageFraction(age) * canvasWidth
      if (lastX - x < minGap || x < minGap) continue
      result.push({ x: x, label: shortDuration(marks[m]) })
      lastX = x
    }
    result.push({ x: 0, label: shortDuration(timeScaleSeconds) })
    return result
  }

  // Network Device Selection State
  property var availableDevices: []
  property string selectedDeviceId: "AUTO"
  property string activeIface: ""
  property bool devicePopoutOpen: false
  menuWidth: 300

  function applySavedSettings() {
    if (!rootRef || !rootRef.widgetSettings) return
    var s = rootRef.widgetSettings[widgetId]
    if (!s) return
    if (s.fillGraph !== undefined) fillGraph = s.fillGraph
    if (s.showTotals !== undefined) showTotals = s.showTotals
    if (s.logTimeScale !== undefined) logTimeScale = s.logTimeScale
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
    if (!contextMenuOpen) {
      devicePopoutOpen = false
      timeScaleMenuOpen = false
    }
  }

  readonly property string netScriptPath: {
    var u = Qt.resolvedUrl("../get-network.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function selectNetworkDevice(devId) {
    selectedDeviceId = devId
    netRxHistory = emptyHistory()
    netTxHistory = emptyHistory()
    netCanvas.requestPaint()
    netInfoProc.command = [networkWidgetRoot.netScriptPath, devId]
    if (!netInfoProc.running) netInfoProc.running = true
    devicePopoutOpen = false
    contextMenuOpen = false
  }

  function getSelectedDeviceName() {
    if (selectedDeviceId === "AUTO") {
      return activeIface ? ("Auto (" + activeIface + ")") : "Auto-detect"
    }
    for (var i = 0; i < availableDevices.length; i++) {
      if (availableDevices[i].id === selectedDeviceId) {
        return availableDevices[i].name || selectedDeviceId
      }
    }
    return selectedDeviceId
  }

  function getSelectedDeviceIcon() {
    if (selectedDeviceId === "AUTO") return "\uf0e7"
    for (var i = 0; i < availableDevices.length; i++) {
      if (availableDevices[i].id === selectedDeviceId) {
        return availableDevices[i].icon || "\uf0ec"
      }
    }
    return "\uf0ec"
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "MONITORED INTERFACE"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Device Selection Popout Trigger Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: (devTriggerMouse.containsMouse || networkWidgetRoot.devicePopoutOpen)
          ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)
          : Qt.rgba(1, 1, 1, 0.05)
        border.color: networkWidgetRoot.devicePopoutOpen
          ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.55)
          : "transparent"
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: networkWidgetRoot.getSelectedDeviceIcon()
            font.family: Style.font.family
            font.pixelSize: 12
            color: Commons.Color.accent
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: networkWidgetRoot.getSelectedDeviceName()
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Commons.Color.foreground
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: networkWidgetRoot.devicePopoutOpen ? "Click to close list" : "Click to select device"
              font.family: Style.font.family
              font.pixelSize: 9
              color: networkWidgetRoot.devicePopoutOpen
                ? Commons.Color.accent
                : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
              elide: Text.ElideRight
            }
          }

          Text {
            text: "\uf054" // chevron-right
            font.family: Style.font.family
            font.pixelSize: 10
            color: (devTriggerMouse.containsMouse || networkWidgetRoot.devicePopoutOpen)
              ? Commons.Color.accent
              : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: devTriggerMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: networkWidgetRoot.devicePopoutOpen = !networkWidgetRoot.devicePopoutOpen
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
        text: "DISPLAY OPTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Fill Graph Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: fillMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf201"
            font.family: Style.font.family
            font.pixelSize: 11
            color: networkWidgetRoot.fillGraph ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Filled Area Chart"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }

          Text {
            text: networkWidgetRoot.fillGraph ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: networkWidgetRoot.fillGraph ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: fillMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            networkWidgetRoot.fillGraph = !networkWidgetRoot.fillGraph
            networkWidgetRoot.saveSetting("fillGraph", networkWidgetRoot.fillGraph)
            netCanvas.requestPaint()
            networkWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Show Cumulative Totals Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: totMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0ec"
            font.family: Style.font.family
            font.pixelSize: 11
            color: networkWidgetRoot.showTotals ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Show Session Totals"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }

          Text {
            text: networkWidgetRoot.showTotals ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: networkWidgetRoot.showTotals ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: totMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            networkWidgetRoot.showTotals = !networkWidgetRoot.showTotals
            networkWidgetRoot.saveSetting("showTotals", networkWidgetRoot.showTotals)
            networkWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Time Scale Dropdown Trigger (options expand inline so the menu grows to fit)
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: scaleMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(6)
          spacing: Style.space(8)

          Text {
            text: "\uf017"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Time Scale"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }

          Rectangle {
            implicitWidth: scalePillRow.implicitWidth + 16
            implicitHeight: 20
            radius: 10
            color: networkWidgetRoot.timeScaleMenuOpen
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
              : Qt.rgba(1, 1, 1, 0.06)
            border.color: networkWidgetRoot.timeScaleMenuOpen ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
            border.width: 1

            RowLayout {
              id: scalePillRow
              anchors.centerIn: parent
              spacing: 6

              Text {
                text: networkWidgetRoot.timeScaleLabel()
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Commons.Color.foreground
              }

              Text {
                text: networkWidgetRoot.timeScaleMenuOpen ? "\uf077" : "\uf078"
                font.family: Style.font.family
                font.pixelSize: 8
                color: Commons.Color.accent
              }
            }
          }
        }

        MouseArea {
          id: scaleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: networkWidgetRoot.timeScaleMenuOpen = !networkWidgetRoot.timeScaleMenuOpen
        }
      }

      // Time Scale Options List
      Rectangle {
        visible: networkWidgetRoot.timeScaleMenuOpen
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(8)
        Layout.rightMargin: Style.space(6)
        implicitHeight: scaleOptionsCol.implicitHeight + 8
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3)
        border.width: 1

        ColumnLayout {
          id: scaleOptionsCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 4
          spacing: 1

          Repeater {
            model: networkWidgetRoot.timeScaleOptions

            Rectangle {
              required property var modelData
              readonly property bool isSelected: modelData.seconds === networkWidgetRoot.timeScaleSeconds
              Layout.fillWidth: true
              implicitHeight: 24
              radius: 5
              color: isSelected
                ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
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
                  color: Commons.Color.accent
                  Layout.preferredWidth: 12
                  horizontalAlignment: Text.AlignHCenter
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: isSelected ? Font.Bold : Font.Normal
                  color: isSelected ? Commons.Color.accent : Commons.Color.foreground
                }
              }

              MouseArea {
                id: scaleOptionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  networkWidgetRoot.timeScaleSeconds = modelData.seconds
                  networkWidgetRoot.saveSetting("timeScaleSeconds", modelData.seconds)
                  netCanvas.requestPaint()
                  networkWidgetRoot.timeScaleMenuOpen = false
                  networkWidgetRoot.contextMenuOpen = false
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
        color: logMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf1da"
            font.family: Style.font.family
            font.pixelSize: 11
            color: networkWidgetRoot.logTimeScale ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Logarithmic Timeline"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }

          Text {
            text: networkWidgetRoot.logTimeScale ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: networkWidgetRoot.logTimeScale ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: logMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            networkWidgetRoot.logTimeScale = !networkWidgetRoot.logTimeScale
            networkWidgetRoot.saveSetting("logTimeScale", networkWidgetRoot.logTimeScale)
            netCanvas.requestPaint()
            networkWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Refresh Network Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refNetMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf021"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Refresh Network Interface"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: refNetMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!netInfoProc.running) netInfoProc.running = true
            networkWidgetRoot.contextMenuOpen = false
          }
        }
      }
    }
  }

  Process {
    id: netInfoProc
    command: [networkWidgetRoot.netScriptPath]
    running: true
    // Device argument is a one-shot switch request; later polls must run without it
    onStarted: command = [networkWidgetRoot.netScriptPath]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.rx_speed !== undefined) networkWidgetRoot.netRxSpeed = data.rx_speed
          if (data.tx_speed !== undefined) networkWidgetRoot.netTxSpeed = data.tx_speed
          if (data.rx_speed_str) networkWidgetRoot.netRxSpeedStr = data.rx_speed_str
          if (data.tx_speed_str) networkWidgetRoot.netTxSpeedStr = data.tx_speed_str
          if (data.rx_total_str) networkWidgetRoot.netRxTotalStr = data.rx_total_str
          if (data.tx_total_str) networkWidgetRoot.netTxTotalStr = data.tx_total_str
          if (data.iface) networkWidgetRoot.netIface = data.iface
          if (data.available_devices) networkWidgetRoot.availableDevices = data.available_devices
          if (data.selected_iface) networkWidgetRoot.selectedDeviceId = data.selected_iface
          if (data.active_iface) networkWidgetRoot.activeIface = data.active_iface

          var rxList = networkWidgetRoot.netRxHistory.slice(1)
          rxList.push(networkWidgetRoot.netRxSpeed)
          networkWidgetRoot.netRxHistory = rxList

          var txList = networkWidgetRoot.netTxHistory.slice(1)
          txList.push(networkWidgetRoot.netTxSpeed)
          networkWidgetRoot.netTxHistory = txList
        } catch (e) {}
      }
    }
  }

  Timer {
    id: netPollTimer
    interval: 1500
    running: true
    repeat: true
    onTriggered: {
      if (!netInfoProc.running) netInfoProc.running = true
    }
  }

  ColumnLayout {
    id: netCardLayout
    anchors.fill: parent
    anchors.topMargin: Style.space(14)
    anchors.bottomMargin: Style.space(14)
    anchors.leftMargin: Style.space(20)
    anchors.rightMargin: Style.space(20)
    spacing: Style.space(8)

    // Header Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "\uf0ec"
        font.family: Style.font.family
        font.pixelSize: 15
        color: Commons.Color.accent
      }

      Text {
        text: "Network Traffic"
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Commons.Color.foreground
      }

      Item { Layout.fillWidth: true }

      Rectangle {
        width: 7
        height: 7
        radius: 3.5
        color: networkWidgetRoot.netRxSpeed > 0 || networkWidgetRoot.netTxSpeed > 0 ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.3)
      }

      Text {
        text: networkWidgetRoot.netIface
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
        elide: Text.ElideRight
        // Full name when there's room; only this label shrinks (eliding) on narrow
        // cards, since the title isn't fillWidth and so keeps its natural width.
        // Ceil: layouts hand out whole pixels, and a fractional implicitWidth
        // rounded down by even 0.1px would elide a name that actually fits.
        Layout.fillWidth: true
        Layout.preferredWidth: Math.ceil(implicitWidth)
        Layout.maximumWidth: Math.ceil(implicitWidth)
      }

      // Remove / Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeNetMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf00d"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Commons.Color.urgent
        }

        MouseArea {
          id: closeNetMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(networkWidgetRoot.widgetId, false, networkWidgetRoot.monitorName)
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
        color: netGripArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0b2"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Commons.Color.accent
        }

        MouseArea {
          id: netGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: networkWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, networkWidgetRoot.screenWidth - networkWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, networkWidgetRoot.screenHeight - networkWidgetRoot.height - 10)

          onPressed: networkWidgetRoot.customGripDragging = true
          onReleased: function() {
            networkWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, networkWidgetRoot.screenWidth - networkWidgetRoot.width - 10)
            var maxY = Math.max(10, networkWidgetRoot.screenHeight - networkWidgetRoot.height - 10)
            var snappedX = Math.round(networkWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(networkWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            networkWidgetRoot.targetItem.x = snappedX
            networkWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(networkWidgetRoot.widgetId, snappedX, snappedY, networkWidgetRoot.snapVal(networkWidgetRoot.width), networkWidgetRoot.snapVal(networkWidgetRoot.height), networkWidgetRoot.monitorName)
            }
          }
          onCanceled: networkWidgetRoot.customGripDragging = false
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Speeds Metric Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(16)

      // Download Speed
      RowLayout {
        spacing: Style.space(6)
        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15)
          border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf063"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Commons.Color.accent
          }
        }

        ColumnLayout {
          spacing: 0
          Text {
            text: "Down"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
          }
          Text {
            text: networkWidgetRoot.netRxSpeedStr
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Commons.Color.accent
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Upload Speed
      RowLayout {
        spacing: Style.space(6)
        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: Qt.rgba(1, 1, 1, 0.08)
          border.color: Qt.rgba(1, 1, 1, 0.2)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf062"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Commons.Color.foreground
          }
        }

        ColumnLayout {
          spacing: 0
          Text {
            text: "Up"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
          }
          Text {
            text: networkWidgetRoot.netTxSpeedStr
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Commons.Color.foreground
          }
        }
      }
    }

    // 📈 Real-Time Dual Sparkline Area Graph (absorbs spare card height, shrinks first)
    Rectangle {
      id: graphCard
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 40
      implicitHeight: 72
      radius: 10
      color: Qt.rgba(0, 0, 0, 0.35)
      border.color: Qt.rgba(1, 1, 1, 0.06)
      border.width: 1
      clip: true

      Canvas {
        id: netCanvas
        anchors.fill: parent
        anchors.margins: 4

        Connections {
          target: networkWidgetRoot
          function onNetRxHistoryChanged() { netCanvas.requestPaint() }
          function onNetTxHistoryChanged() { netCanvas.requestPaint() }
          function onHoverIndexChanged() { netCanvas.requestPaint() }
          function onLogTimeScaleChanged() { netCanvas.requestPaint() }
          function onTimeScaleSecondsChanged() { netCanvas.requestPaint() }
        }

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var w = width
          var h = height
          if (w <= 0 || h <= 0) return

          var rxArr = networkWidgetRoot.netRxHistory
          var txArr = networkWidgetRoot.netTxHistory
          var count = rxArr.length
          if (count < 2) return
          var start = networkWidgetRoot.firstVisibleIndex()

          // Scale to the visible window only, so old spikes don't flatten the linear view
          var maxVal = 1024 * 10 // Minimum 10KB/s ceiling for smooth normalization
          for (var i = start; i < count; i++) {
            if (rxArr[i] > maxVal) maxVal = rxArr[i]
            if (txArr[i] > maxVal) maxVal = txArr[i]
          }

          function yFor(v) {
            return h - (v / maxVal) * (h - 6)
          }

          // X positions computed once per paint and shared by both series
          // (long time scales have up to thousands of visible samples)
          var xs = []
          for (var xi = start; xi < count; xi++) xs.push(networkWidgetRoot.xFraction(xi) * w)

          // Visible samples as canvas points, keeping the peak when several share a
          // pixel column (long or log time scales) instead of drawing a zigzag
          function points(arr) {
            var pts = []
            for (var p = start; p < count; p++) {
              var x = xs[p - start]
              var last = pts.length > 0 ? pts[pts.length - 1] : null
              if (last && Math.floor(last.x) === Math.floor(x)) {
                if (arr[p] > last.v) last.v = arr[p]
              } else {
                pts.push({ x: x, v: arr[p] })
              }
            }
            return pts
          }

          function drawSeries(pts, strokeStyle, lineWidth, gradTop, gradBottom) {
            ctx.save()
            if (networkWidgetRoot.fillGraph) {
              ctx.beginPath()
              ctx.moveTo(0, h)
              for (var f = 0; f < pts.length; f++) ctx.lineTo(pts[f].x, yFor(pts[f].v))
              ctx.lineTo(w, h)
              ctx.closePath()

              var grad = ctx.createLinearGradient(0, 0, 0, h)
              grad.addColorStop(0.0, gradTop)
              grad.addColorStop(1.0, gradBottom)
              ctx.fillStyle = grad
              ctx.fill()
            }

            ctx.beginPath()
            for (var s = 0; s < pts.length; s++) {
              if (s === 0) ctx.moveTo(pts[s].x, yFor(pts[s].v))
              else ctx.lineTo(pts[s].x, yFor(pts[s].v))
            }
            ctx.strokeStyle = strokeStyle
            ctx.lineWidth = lineWidth
            ctx.stroke()
            ctx.restore()
          }

          // Horizontal subtle guideline, plus log timeline time markers
          // (their labels are Text items overlaid on the canvas)
          ctx.strokeStyle = "rgba(255, 255, 255, 0.06)"
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(0, h * 0.5)
          ctx.lineTo(w, h * 0.5)
          var marks = networkWidgetRoot.timeMarkers(w)
          for (var m = 0; m < marks.length; m++) {
            if (marks[m].x <= 0) continue // Left-edge scale label needs no line
            ctx.moveTo(marks[m].x, 0)
            ctx.lineTo(marks[m].x, h)
          }
          ctx.stroke()

          // 1. Draw TX (Upload) Area & Line
          drawSeries(points(txArr),
                     Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.75), 1.5,
                     "rgba(255, 255, 255, 0.18)", "rgba(255, 255, 255, 0.01)")

          // 2. Draw RX (Download) Area & Line
          drawSeries(points(rxArr), Commons.Color.accent, 2,
                     Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45),
                     Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.02))

          // 3. Hover Crosshair & Sample Dots
          var hi = networkWidgetRoot.hoverIndex
          if (hi >= start && hi < count) {
            var hx = networkWidgetRoot.xFraction(hi) * w
            ctx.save()
            ctx.strokeStyle = "rgba(255, 255, 255, 0.25)"
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(hx, 0)
            ctx.lineTo(hx, h)
            ctx.stroke()

            ctx.strokeStyle = "rgba(0, 0, 0, 0.6)"
            ctx.lineWidth = 1.5

            ctx.beginPath()
            ctx.arc(hx, yFor(txArr[hi]), 3, 0, Math.PI * 2)
            ctx.fillStyle = Commons.Color.foreground
            ctx.fill()
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(hx, yFor(rxArr[hi]), 3.5, 0, Math.PI * 2)
            ctx.fillStyle = Commons.Color.accent
            ctx.fill()
            ctx.stroke()
            ctx.restore()
          }
        }
      }

      // Interactive Hover Tracking (no buttons, so clicks still reach the card)
      MouseArea {
        anchors.fill: netCanvas
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onPositionChanged: function(mouse) {
          if (networkWidgetRoot.netRxHistory.length < 2 || width <= 0) return
          networkWidgetRoot.hoverIndex = networkWidgetRoot.indexAtFraction(mouse.x / width)
        }

        onExited: networkWidgetRoot.hoverIndex = -1
      }

      // Time Marker Labels (theme background/foreground chip keeps them readable on
      // any theme and over the traffic lines)
      Repeater {
        model: networkWidgetRoot.timeMarkers(netCanvas.width)

        Rectangle {
          required property var modelData
          x: netCanvas.x + modelData.x + 2
          y: netCanvas.y + 1
          width: markerText.implicitWidth + 6
          height: markerText.implicitHeight + 2
          radius: 3
          color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.85)

          Text {
            id: markerText
            anchors.centerIn: parent
            text: modelData.label
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: Commons.Color.foreground
          }
        }
      }

      // Hover Tooltip Badge
      Rectangle {
        visible: networkWidgetRoot.hoverIndex >= networkWidgetRoot.firstVisibleIndex() && networkWidgetRoot.hoverIndex < networkWidgetRoot.netRxHistory.length
        z: 10
        width: netHoverLayout.implicitWidth + 12
        height: 20
        radius: 6
        color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
        border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.55)
        border.width: 1

        readonly property real targetX: netCanvas.x + networkWidgetRoot.xFraction(networkWidgetRoot.hoverIndex) * netCanvas.width
        x: Math.max(4, Math.min(parent.width - width - 4, targetX - width / 2))
        y: 4

        RowLayout {
          id: netHoverLayout
          anchors.centerIn: parent
          spacing: 5

          Text {
            text: networkWidgetRoot.hoverTimeOffset()
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
          }

          Text {
            text: " " + networkWidgetRoot.formatSpeed(networkWidgetRoot.netRxHistory[networkWidgetRoot.hoverIndex] || 0)
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Commons.Color.accent
          }

          Text {
            text: " " + networkWidgetRoot.formatSpeed(networkWidgetRoot.netTxHistory[networkWidgetRoot.hoverIndex] || 0)
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Commons.Color.foreground
          }
        }
      }
    }

    // Optional Cumulative Bandwidth Totals
    RowLayout {
      Layout.fillWidth: true
      visible: networkWidgetRoot.showTotals && networkWidgetRoot.netRxTotalStr !== ""
      spacing: Style.space(8)

      Text {
        text: "\uf019"
        font.family: Style.font.family
        font.pixelSize: 10
        color: Commons.Color.accent
      }
      Text {
        text: "Total Down: " + networkWidgetRoot.netRxTotalStr
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "\uf093"
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
      }
      Text {
        text: "Total Up: " + networkWidgetRoot.netTxTotalStr
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🖧 Floating Network Device Selection Popout Submenu
  // ---------------------------------------------------------------------------
  Rectangle {
    id: netDevicePopout
    parent: networkWidgetRoot.contextMenuCanvasParent
    z: 1010

    readonly property real popoutWidth: 260
    readonly property real headerHeight: 38
    readonly property real itemHeight: 36
    readonly property real listHeight: Math.min(280, (networkWidgetRoot.availableDevices ? networkWidgetRoot.availableDevices.length : 1) * itemHeight + 8)
    readonly property real popoutHeight: headerHeight + listHeight

    // Position: smart placement (right of context menu, or left if near screen edge)
    x: {
      var rightX = networkWidgetRoot.contextMenuX + networkWidgetRoot.contextMenuWidth + 6
      if (rightX + popoutWidth + 10 <= networkWidgetRoot.screenWidth) {
        return rightX
      } else {
        return Math.max(10, networkWidgetRoot.contextMenuX - popoutWidth - 6)
      }
    }

    y: Math.max(10, Math.min(networkWidgetRoot.contextMenuY, networkWidgetRoot.screenHeight - popoutHeight - 10))
    width: popoutWidth
    height: popoutHeight

    radius: 14
    color: Qt.rgba(14/255, 14/255, 20/255, 0.98)
    border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
    border.width: 1.5

    opacity: (networkWidgetRoot.contextMenuOpen && networkWidgetRoot.devicePopoutOpen) ? 1.0 : 0.0
    scale: (networkWidgetRoot.contextMenuOpen && networkWidgetRoot.devicePopoutOpen) ? 1.0 : 0.94
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.85)
      shadowBlur: 0.85
      shadowVerticalOffset: 8
      shadowHorizontalOffset: 2
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(8)
      spacing: Style.space(4)

      // Popout Header
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 2
        spacing: Style.space(6)

        Text {
          text: "\uf0ec"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Commons.Color.accent
        }

        Text {
          text: "SELECT DEVICE"
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.Bold
          color: Commons.Color.foreground
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 20
          height: 20
          radius: 10
          color: closePopoutMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Commons.Color.foreground
          }

          MouseArea {
            id: closePopoutMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: networkWidgetRoot.devicePopoutOpen = false
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.bottomMargin: 2
      }

      // Scrollable List of Devices
      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: devCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: devCol
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: networkWidgetRoot.availableDevices

            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 34
              radius: 6
              readonly property bool isSelected: modelData.is_selected || networkWidgetRoot.selectedDeviceId === modelData.id
              color: devItemMouse.containsMouse
                ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)
                : (isSelected ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.1) : "transparent")
              border.color: isSelected ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)

                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: isSelected
                    ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
                    : Qt.rgba(1, 1, 1, 0.06)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon || "\uf0ec"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: isSelected
                      ? Commons.Color.accent
                      : (modelData.is_up ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.75) : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.35))
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name || modelData.id
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: isSelected ? Font.Bold : Font.Normal
                    color: isSelected ? Commons.Color.foreground : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.85)
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: modelData.detail !== ""
                    Layout.fillWidth: true
                    text: modelData.detail
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: isSelected
                      ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.85)
                      : (modelData.is_up ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5) : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.3))
                    elide: Text.ElideRight
                  }
                }

                // Checkmark for selected item
                Text {
                  visible: isSelected
                  text: "\uf00c"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Commons.Color.accent
                }
              }

              MouseArea {
                id: devItemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: networkWidgetRoot.selectNetworkDevice(modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
