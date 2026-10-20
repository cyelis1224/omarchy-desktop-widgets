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

  property string tempF: "--"
  property string tempC: "--"
  property string weatherIcon: "\uf185"
  property string conditionDesc: "Weather"
  property bool useCelsius: false

  readonly property string weatherScriptPath: {
    var u = Qt.resolvedUrl("get-weather.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function fetchWeather() {
    if (!weatherProc.running) weatherProc.running = true
  }

  Process {
    id: weatherProc
    command: [root.weatherScriptPath]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok") {
            root.tempF = data.temp || "--"
            root.tempC = data.tempC || "--"
            root.conditionDesc = data.condition || "Weather"
            if (data.icon) root.weatherIcon = data.icon
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 600000 // 10 minutes
    running: true
    repeat: true
    onTriggered: root.fetchWeather()
  }

  Component.onCompleted: root.fetchWeather()

  implicitWidth: pillContainer.implicitWidth
  implicitHeight: Style.bar.statusSlot || 32

  Rectangle {
    id: pillContainer
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Math.min(parent.height - 4, 28)
    implicitWidth: rowLayout.implicitWidth + 16
    radius: Style.cornerRadius || 8
    color: mouseArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : Qt.rgba(Commons.Color.bar.background.r, Commons.Color.bar.background.g, Commons.Color.bar.background.b, 0.65)
    border.color: Util.alpha(Commons.Color.foreground, 0.12)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
      id: rowLayout
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: root.weatherIcon
        font.family: Style.font.family
        font.pixelSize: 11
        color: Commons.Color.accent
      }

      Text {
        text: root.useCelsius ? (root.tempC + "°C") : (root.tempF + "°F")
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.Bold
        color: Commons.Color.foreground
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor

      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
          root.useCelsius = !root.useCelsius
        } else if (mouse.button === Qt.RightButton) {
          root.fetchWeather()
        }
      }
    }
  }
}
