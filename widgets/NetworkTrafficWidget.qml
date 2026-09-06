import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
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
  height: netCardLayout.implicitHeight + Style.space(36)

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
  property var netRxHistory: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
  property var netTxHistory: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

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
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  onContextMenuOpenChanged: {
    if (!contextMenuOpen) {
      devicePopoutOpen = false
    }
  }

  function selectNetworkDevice(devId) {
    selectedDeviceId = devId
    netRxHistory = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    netTxHistory = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    netCanvas.requestPaint()
    netInfoProc.command = ["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/get-network.sh", devId]
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
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Device Selection Popout Trigger Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: (devTriggerMouse.containsMouse || networkWidgetRoot.devicePopoutOpen)
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
          : Qt.rgba(1, 1, 1, 0.05)
        border.color: networkWidgetRoot.devicePopoutOpen
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)
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
            color: Color.accent
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
              color: Color.foreground
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: networkWidgetRoot.devicePopoutOpen ? "Click to close list" : "Click to select device"
              font.family: Style.font.family
              font.pixelSize: 9
              color: networkWidgetRoot.devicePopoutOpen
                ? Color.accent
                : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
              elide: Text.ElideRight
            }
          }

          Text {
            text: "\uf054" // chevron-right
            font.family: Style.font.family
            font.pixelSize: 10
            color: (devTriggerMouse.containsMouse || networkWidgetRoot.devicePopoutOpen)
              ? Color.accent
              : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
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
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Fill Graph Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: fillMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf201"
            font.family: Style.font.family
            font.pixelSize: 11
            color: networkWidgetRoot.fillGraph ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Filled Area Chart"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: networkWidgetRoot.fillGraph ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: networkWidgetRoot.fillGraph ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
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
        color: totMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0ec"
            font.family: Style.font.family
            font.pixelSize: 11
            color: networkWidgetRoot.showTotals ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Show Session Totals"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: networkWidgetRoot.showTotals ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: networkWidgetRoot.showTotals ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
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

      // Refresh Network Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refNetMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf021"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Refresh Network Interface"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
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
    command: ["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/get-network.sh"]
    running: true
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
    anchors.topMargin: Style.space(18)
    anchors.bottomMargin: Style.space(18)
    anchors.leftMargin: Style.space(20)
    anchors.rightMargin: Style.space(20)
    spacing: Style.space(12)

    // Header Row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "\uf0ec"
        font.family: Style.font.family
        font.pixelSize: 15
        color: Color.accent
      }

      Text {
        text: "Network Traffic"
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Color.foreground
      }

      Item { Layout.fillWidth: true }

      Rectangle {
        width: 7
        height: 7
        radius: 3.5
        color: networkWidgetRoot.netRxSpeed > 0 || networkWidgetRoot.netTxSpeed > 0 ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
      }

      Text {
        text: networkWidgetRoot.netIface
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        elide: Text.ElideRight
        Layout.maximumWidth: 100
      }

      // Remove / Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeNetMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeNetMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(networkWidgetRoot.widgetId, false)
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
        color: netGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
              rootRef.saveWidgetPos(networkWidgetRoot.widgetId, snappedX, snappedY)
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
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf063"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.accent
          }
        }

        ColumnLayout {
          spacing: 0
          Text {
            text: "Down"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }
          Text {
            text: networkWidgetRoot.netRxSpeedStr
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Color.accent
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
            color: Color.foreground
          }
        }

        ColumnLayout {
          spacing: 0
          Text {
            text: "Up"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }
          Text {
            text: networkWidgetRoot.netTxSpeedStr
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }
      }
    }

    // 📈 Real-Time Dual Sparkline Area Graph
    Rectangle {
      Layout.fillWidth: true
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

          var maxVal = 1024 * 10 // Minimum 10KB/s ceiling for smooth normalization
          for (var i = 0; i < count; i++) {
            if (rxArr[i] > maxVal) maxVal = rxArr[i]
            if (txArr[i] > maxVal) maxVal = txArr[i]
          }

          // Horizontal subtle guideline
          ctx.strokeStyle = "rgba(255, 255, 255, 0.06)"
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(0, h * 0.5)
          ctx.lineTo(w, h * 0.5)
          ctx.stroke()

          var stepX = w / (count - 1)

          // 1. Draw TX (Upload) Area & Line
          ctx.save()
          ctx.beginPath()
          ctx.moveTo(0, h)
          for (var t = 0; t < count; t++) {
            var tY = h - (txArr[t] / maxVal) * (h - 6)
            ctx.lineTo(t * stepX, tY)
          }
          ctx.lineTo(w, h)
          ctx.closePath()

          if (networkWidgetRoot.fillGraph) {
            var txGrad = ctx.createLinearGradient(0, 0, 0, h)
            txGrad.addColorStop(0.0, "rgba(255, 255, 255, 0.18)")
            txGrad.addColorStop(1.0, "rgba(255, 255, 255, 0.01)")
            ctx.fillStyle = txGrad
            ctx.fill()
          }

          // Stroke TX Line
          ctx.beginPath()
          for (var t2 = 0; t2 < count; t2++) {
            var t2Y = h - (txArr[t2] / maxVal) * (h - 6)
            if (t2 === 0) ctx.moveTo(0, t2Y)
            else ctx.lineTo(t2 * stepX, t2Y)
          }
          ctx.strokeStyle = Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.restore()

          // 2. Draw RX (Download) Area & Line
          ctx.save()
          ctx.beginPath()
          ctx.moveTo(0, h)
          for (var r = 0; r < count; r++) {
            var rxY = h - (rxArr[r] / maxVal) * (h - 6)
            ctx.lineTo(r * stepX, rxY)
          }
          ctx.lineTo(w, h)
          ctx.closePath()

          if (networkWidgetRoot.fillGraph) {
            var rxGrad = ctx.createLinearGradient(0, 0, 0, h)
            rxGrad.addColorStop(0.0, Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45))
            rxGrad.addColorStop(1.0, Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.02))
            ctx.fillStyle = rxGrad
            ctx.fill()
          }

          // Stroke RX Line
          ctx.beginPath()
          for (var r2 = 0; r2 < count; r2++) {
            var rY = h - (rxArr[r2] / maxVal) * (h - 6)
            if (r2 === 0) ctx.moveTo(0, rY)
            else ctx.lineTo(r2 * stepX, rY)
          }
          ctx.strokeStyle = Color.accent
          ctx.lineWidth = 2
          ctx.stroke()
          ctx.restore()
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
        color: Color.accent
      }
      Text {
        text: "Total Down: " + networkWidgetRoot.netRxTotalStr
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "\uf093"
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
      }
      Text {
        text: "Total Up: " + networkWidgetRoot.netTxTotalStr
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
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
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
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
          color: Color.accent
        }

        Text {
          text: "SELECT DEVICE"
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.Bold
          color: Color.foreground
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
            color: Color.foreground
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
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                : (isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1) : "transparent")
              border.color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : "transparent"
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
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                    : Qt.rgba(1, 1, 1, 0.06)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon || "\uf0ec"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: isSelected
                      ? Color.accent
                      : (modelData.is_up ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35))
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
                    color: isSelected ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.85)
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: modelData.detail !== ""
                    Layout.fillWidth: true
                    text: modelData.detail
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: isSelected
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)
                      : (modelData.is_up ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3))
                    elide: Text.ElideRight
                  }
                }

                // Checkmark for selected item
                Text {
                  visible: isSelected
                  text: "\uf00c"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Color.accent
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
