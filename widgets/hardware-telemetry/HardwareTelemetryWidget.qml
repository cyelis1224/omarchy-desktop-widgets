import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

// Import base WidgetCard from the shared repository link
import "../../shared"

WidgetCard {
  id: hwWidgetRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Placement Settings
  // ---------------------------------------------------------------------------
  widgetId: "hardware_telemetry"
  title: "Hardware Thermals"
  icon: "\uf2db"
  showHeader: false // Custom integrated header with live thermal badge & controls

  defaultX: Style.space(24)
  defaultY: 340

  width: 360
  height: 480
  menuWidth: 320

  // ---------------------------------------------------------------------------
  // 🌡️ Telemetry State & Customization Options
  // ---------------------------------------------------------------------------
  property bool useFahrenheit: false
  property var disabledSensorIds: []
  property real alertThresholdDeg: 75.0
  property int pollIntervalMs: 3000

  property real cpuTemp: 40.0
  property int cpuCores: 20
  property real cpuAvgGhz: 3.5
  property int gpuMhz: 0
  property int gpuMaxMhz: 1950
  property string statusBadge: "Optimal"
  property color statusColor: "#10b981"
  property var sensorsList: []

  function formatTemp(celsius) {
    if (useFahrenheit) {
      var f = Math.round(celsius * 9 / 5 + 32)
      return f + "°F"
    }
    return (Math.round(celsius * 10) / 10) + "°C"
  }

  function getTempColor(temp, high) {
    var ratio = temp / high
    if (ratio >= 0.95 || temp >= alertThresholdDeg) return Color.urgent
    if (ratio >= 0.80) return "#f59e0b" // Amber
    if (ratio >= 0.65) return "#06b6d4" // Cyan
    return "#10b981" // Emerald
  }

  // Backend Process calling telemetry_collector.py
  Process {
    id: telemetryProc
    command: ["/home/dagyr/Projects/desktop-widgets/widgets/hardware-telemetry/telemetry_collector.py"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.cpu_temp !== undefined) {
            hwWidgetRoot.cpuTemp = data.cpu_temp
            cpuArc.requestPaint()
          }
          if (data.cpu_cores !== undefined) hwWidgetRoot.cpuCores = data.cpu_cores
          if (data.cpu_avg_ghz !== undefined) {
            hwWidgetRoot.cpuAvgGhz = data.cpu_avg_ghz
            clockArc.requestPaint()
          }
          if (data.gpu_mhz !== undefined) hwWidgetRoot.gpuMhz = data.gpu_mhz
          if (data.gpu_max_mhz !== undefined) hwWidgetRoot.gpuMaxMhz = data.gpu_max_mhz
          if (data.status_badge) hwWidgetRoot.statusBadge = data.status_badge
          if (data.status_color) hwWidgetRoot.statusColor = data.status_color
          if (Array.isArray(data.sensors)) hwWidgetRoot.sensorsList = data.sensors
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: hwWidgetRoot.pollIntervalMs
    running: true
    repeat: true
    onTriggered: {
      if (!telemetryProc.running) telemetryProc.running = true
    }
  }

  // ---------------------------------------------------------------------------
  // 📂 Robust & Functional Right-Click Context Menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      // 1. Temperature Scale Section
      Text {
        text: "TEMPERATURE SCALE"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: [
            { label: "Celsius (°C)", isFahr: false, icon: "\uf2c9" },
            { label: "Fahrenheit (°F)", isFahr: true, icon: "\uf2c7" }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 6
            readonly property bool isSelected: hwWidgetRoot.useFahrenheit === modelData.isFahr
            color: unitMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : Qt.rgba(1, 1, 1, 0.06))
            border.color: isSelected ? Color.accent : "transparent"
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: modelData.icon
                font.family: Style.font.family
                font.pixelSize: 10
                color: isSelected ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
              }
              Text {
                text: modelData.label
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: isSelected ? Font.Bold : Font.Normal
                color: isSelected ? Color.accent : Color.foreground
              }
            }

            MouseArea {
              id: unitMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                hwWidgetRoot.useFahrenheit = modelData.isFahr
                cpuArc.requestPaint()
              }
            }
          }
        }
      }

      // 2. Monitored Sensors Checklist
      Text {
        text: "MONITORED SUBSYSTEMS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      Repeater {
        model: hwWidgetRoot.sensorsList

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          readonly property bool isMonitored: hwWidgetRoot.disabledSensorIds.indexOf(modelData.id) === -1
          color: sCheckMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              text: isMonitored ? "\uf14a" : "\uf0c8"
              font.family: Style.font.family
              font.pixelSize: 12
              color: isMonitored ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
            }

            Text {
              text: modelData.icon || "\uf2db"
              font.family: Style.font.family
              font.pixelSize: 11
              color: isMonitored ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
            }

            Text {
              Layout.fillWidth: true
              text: modelData.name
              font.family: Style.font.family
              font.pixelSize: 11
              color: isMonitored ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
              elide: Text.ElideRight
            }

            Text {
              text: hwWidgetRoot.formatTemp(modelData.temp)
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.DemiBold
              color: isMonitored ? hwWidgetRoot.getTempColor(modelData.temp, modelData.high) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
            }
          }

          MouseArea {
            id: sCheckMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var arr = hwWidgetRoot.disabledSensorIds.slice()
              var idx = arr.indexOf(modelData.id)
              if (idx === -1) {
                arr.push(modelData.id)
              } else {
                arr.splice(idx, 1)
              }
              hwWidgetRoot.disabledSensorIds = arr
            }
          }
        }
      }

      // 3. Thermal Warning Alert Threshold
      Text {
        text: "ALERT THRESHOLD"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: [
            { label: "65°C Silent", val: 65.0 },
            { label: "75°C Normal", val: 75.0 },
            { label: "85°C Max", val: 85.0 }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 24
            radius: 6
            readonly property bool isSelected: Math.abs(hwWidgetRoot.alertThresholdDeg - modelData.val) < 1.0
            color: thMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : Qt.rgba(1, 1, 1, 0.06))
            border.color: isSelected ? Color.accent : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: isSelected ? Font.Bold : Font.Normal
              color: isSelected ? Color.accent : Color.foreground
            }

            MouseArea {
              id: thMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: hwWidgetRoot.alertThresholdDeg = modelData.val
            }
          }
        }
      }

      // 4. Quick Actions
      Text {
        text: "ACTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Launch btop
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: btopLaunchMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

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
            text: "Open System Monitor (btop)"
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
          id: btopLaunchMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            hwWidgetRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-terminal-exec", "btop"])
          }
        }
      }

      // Launch sensors monitor
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: sensorsLaunchMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf06e"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Live Sensor Stream (watch sensors)"
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
          id: sensorsLaunchMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            hwWidgetRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-terminal-exec", "watch", "-n", "1", "sensors"])
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 Main Widget Body
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(12)

    // -------------------------------------------------------------------------
    // 🏷️ Header: Icon, Title, Thermal Badge & Edit Controls
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Rectangle {
        width: 28
        height: 28
        radius: 14
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf2db"
          font.family: Style.font.family
          font.pixelSize: 12
          color: Color.accent
        }
      }

      ColumnLayout {
        spacing: 0
        Text {
          text: "Hardware Thermals"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Color.foreground
        }
        Text {
          text: hwWidgetRoot.cpuCores + " Cores · DDR5 · NVMe"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
      }

      Item { Layout.fillWidth: true }

      // Live Status Badge
      Rectangle {
        implicitWidth: badgeRow.implicitWidth + 14
        implicitHeight: 20
        radius: 10
        color: Qt.rgba(hwWidgetRoot.statusColor.r, hwWidgetRoot.statusColor.g, hwWidgetRoot.statusColor.b, 0.18)
        border.color: Qt.rgba(hwWidgetRoot.statusColor.r, hwWidgetRoot.statusColor.g, hwWidgetRoot.statusColor.b, 0.5)
        border.width: 1

        RowLayout {
          id: badgeRow
          anchors.centerIn: parent
          spacing: 4
          Rectangle {
            width: 6
            height: 6
            radius: 3
            color: hwWidgetRoot.statusColor
          }
          Text {
            text: hwWidgetRoot.statusBadge
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: hwWidgetRoot.statusColor
          }
        }
      }

      // Close Button (Edit Mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(hwWidgetRoot.widgetId, false)
            }
          }
        }
      }

      // Move Grip Button (Edit Mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        implicitWidth: gripRow.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: customGripMouse.drag.active ? Color.accent : (customGripMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
        border.width: 1

        RowLayout {
          id: gripRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "\uf0b2"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.accent
          }
          Text {
            text: "Move"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }

        MouseArea {
          id: customGripMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: hwWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, hwWidgetRoot.screenWidth - hwWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, hwWidgetRoot.screenHeight - hwWidgetRoot.height - 10)

          onPressed: hwWidgetRoot.customGripDragging = true
          onReleased: function() {
            hwWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, hwWidgetRoot.screenWidth - hwWidgetRoot.width - 10)
            var maxY = Math.max(10, hwWidgetRoot.screenHeight - hwWidgetRoot.height - 10)
            var snappedX = Math.round(hwWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(hwWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            hwWidgetRoot.targetItem.x = snappedX
            hwWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(hwWidgetRoot.widgetId, snappedX, snappedY)
            }
          }
          onCanceled: hwWidgetRoot.customGripDragging = false
        }
      }
    }

    // -------------------------------------------------------------------------
    // ⭕ Dual Circular Thermal & Clock Gauges
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(12)

      // 1. CPU Package Temperature Gauge
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 130
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Item {
            width: 78
            height: 78
            Layout.alignment: Qt.AlignHCenter

            Canvas {
              id: cpuArc
              anchors.fill: parent
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2
                var cy = height / 2
                var radius = (width - 12) / 2
                var startAngle = 0.75 * Math.PI
                var endAngle = 2.25 * Math.PI

                // Track
                ctx.beginPath()
                ctx.arc(cx, cy, radius, startAngle, endAngle)
                ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
                ctx.lineWidth = 6
                ctx.lineCap = "round"
                ctx.stroke()

                // Progress Arc
                var pct = Math.max(0.0, Math.min(1.0, (hwWidgetRoot.cpuTemp - 20) / (hwWidgetRoot.alertThresholdDeg - 20)))
                var currentAngle = startAngle + pct * (endAngle - startAngle)

                ctx.beginPath()
                ctx.arc(cx, cy, radius, startAngle, currentAngle)
                var arcColor = hwWidgetRoot.getTempColor(hwWidgetRoot.cpuTemp, 85.0)
                ctx.strokeStyle = arcColor.toString()
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
                text: hwWidgetRoot.formatTemp(hwWidgetRoot.cpuTemp)
                font.family: Style.font.family
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Color.foreground
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "TEMP"
                font.family: Style.font.family
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "CPU Package"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }
      }

      // 2. CPU Clock Frequency Gauge
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 130
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Item {
            width: 78
            height: 78
            Layout.alignment: Qt.AlignHCenter

            Canvas {
              id: clockArc
              anchors.fill: parent
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2
                var cy = height / 2
                var radius = (width - 12) / 2
                var startAngle = 0.75 * Math.PI
                var endAngle = 2.25 * Math.PI

                // Track
                ctx.beginPath()
                ctx.arc(cx, cy, radius, startAngle, endAngle)
                ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
                ctx.lineWidth = 6
                ctx.lineCap = "round"
                ctx.stroke()

                // Progress Arc
                var pct = Math.max(0.0, Math.min(1.0, hwWidgetRoot.cpuAvgGhz / 5.2))
                var currentAngle = startAngle + pct * (endAngle - startAngle)

                ctx.beginPath()
                ctx.arc(cx, cy, radius, startAngle, currentAngle)
                ctx.strokeStyle = Color.accent.toString()
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
                text: hwWidgetRoot.cpuAvgGhz + "G"
                font.family: Style.font.family
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Color.foreground
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "AVG CLOCK"
                font.family: Style.font.family
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "All-Core Clock"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📊 Subsystem Hardware Thermals Breakdown
    // -------------------------------------------------------------------------
    Text {
      text: "MONITORED SUBSYSTEMS"
      font.family: Style.font.family
      font.pixelSize: 9
      font.weight: Font.Bold
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      Layout.leftMargin: 2
      Layout.topMargin: 2
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Repeater {
        model: hwWidgetRoot.sensorsList

        Rectangle {
          required property var modelData
          visible: hwWidgetRoot.disabledSensorIds.indexOf(modelData.id) === -1
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
              text: modelData.icon || "\uf2db"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.accent
            }

            Text {
              Layout.preferredWidth: 120
              text: modelData.name
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.foreground
              elide: Text.ElideRight
            }

            // Temperature Visual Heat Bar
            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: Qt.rgba(1, 1, 1, 0.08)

              Rectangle {
                width: Math.max(4, parent.width * Math.min(1.0, (modelData.temp / modelData.high)))
                height: parent.height
                radius: 3
                color: hwWidgetRoot.getTempColor(modelData.temp, modelData.high)
              }
            }

            Text {
              Layout.preferredWidth: 44
              horizontalAlignment: Text.AlignRight
              text: hwWidgetRoot.formatTemp(modelData.temp)
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: hwWidgetRoot.getTempColor(modelData.temp, modelData.high)
            }
          }
        }
      }
    }

    Item { Layout.fillHeight: true }

    // -------------------------------------------------------------------------
    // 🎮 GPU / Graphic Acceleration Sub-Row
    // -------------------------------------------------------------------------
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 28
      radius: 8
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: "\uf108"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Color.accent
        }

        Text {
          Layout.fillWidth: true
          text: "Graphics Engine (Intel Arrow Lake)"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.foreground
          elide: Text.ElideRight
        }

        Text {
          text: hwWidgetRoot.gpuMhz + " MHz" + (hwWidgetRoot.gpuMaxMhz > 0 ? (" / " + hwWidgetRoot.gpuMaxMhz + " MHz") : "")
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.DemiBold
          color: Color.accent
        }
      }
    }
  }
}
