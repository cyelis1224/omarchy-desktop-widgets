import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var bar: null

  property real cpuTemp: 45.0
  property real cpuAvgGhz: 2.5
  property string statusBadge: "Normal"
  property color statusColor: Commons.Color.accent

  readonly property string telemetryScriptPath: {
    var u = Qt.resolvedUrl("telemetry_collector.py").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  Process {
    id: telemetryProc
    command: [root.telemetryScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.cpu_temp !== undefined) root.cpuTemp = data.cpu_temp
          if (data.cpu_avg_ghz !== undefined) root.cpuAvgGhz = data.cpu_avg_ghz
          if (data.status_badge) root.statusBadge = data.status_badge
          if (data.status_color) root.statusColor = data.status_color
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      if (!telemetryProc.running) telemetryProc.running = true
    }
  }

  implicitWidth: pillContainer.implicitWidth
  implicitHeight: Style.bar.statusSlot || 32

  Rectangle {
    id: pillContainer
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Math.min(parent.height - 4, 28)
    implicitWidth: rowLayout.implicitWidth + 16
    radius: Style.cornerRadius || 8
    color: mouseArea.containsMouse ? Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.22) : Qt.rgba(Commons.Color.bar.background.r, Commons.Color.bar.background.g, Commons.Color.bar.background.b, 0.65)
    border.color: root.cpuTemp > 75 ? Commons.Color.urgent : Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
      id: rowLayout
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: "\uf2db"
        font.family: Style.font.family
        font.pixelSize: 11
        color: root.statusColor
      }

      Text {
        text: Math.round(root.cpuTemp) + "°C"
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.Bold
        color: Commons.Color.foreground
      }

      Text {
        text: root.cpuAvgGhz.toFixed(1) + " GHz"
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        Quickshell.execDetached(["xdg-terminal-exec", "btop"])
      }
    }
  }
}
