import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

Item {
  id: root

  property var bar: null

  // State
  property string currentMode: "FOCUS" // "FOCUS" | "SHORT" | "LONG"
  property bool isTimerRunning: false
  property int focusDurationSec: 25 * 60
  property int shortDurationSec: 5 * 60
  property int longDurationSec: 15 * 60
  property int secondsLeft: focusDurationSec

  readonly property color modeColor: {
    if (currentMode === "SHORT") return "#10b981"
    if (currentMode === "LONG") return "#06b6d4"
    return Color.accent
  }

  function formatTime(totalSec) {
    var m = Math.floor(totalSec / 60)
    var s = totalSec % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  function toggleRunning() {
    isTimerRunning = !isTimerRunning
  }

  function resetTimer() {
    isTimerRunning = false
    if (currentMode === "FOCUS") secondsLeft = focusDurationSec
    else if (currentMode === "SHORT") secondsLeft = shortDurationSec
    else secondsLeft = longDurationSec
  }

  function cycleMode() {
    isTimerRunning = false
    if (currentMode === "FOCUS") {
      currentMode = "SHORT"
      secondsLeft = shortDurationSec
    } else if (currentMode === "SHORT") {
      currentMode = "LONG"
      secondsLeft = longDurationSec
    } else {
      currentMode = "FOCUS"
      secondsLeft = focusDurationSec
    }
  }

  // Flips each tick to blink the icon in the same frame as the countdown text,
  // instead of a looping animation redrawing the bar every frame
  property bool tickPhase: false

  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: root.isTimerRunning
    onTriggered: {
      root.tickPhase = !root.tickPhase
      if (root.secondsLeft > 0) {
        root.secondsLeft--
      } else {
        root.isTimerRunning = false
        root.cycleMode()
      }
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
    color: mouseArea.containsMouse ? Qt.rgba(root.modeColor.r, root.modeColor.g, root.modeColor.b, 0.22) : Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.65)
    border.color: root.isTimerRunning ? root.modeColor : Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
      id: rowLayout
      anchors.centerIn: parent
      spacing: 6

      // Blinking Icon (while running)
      Text {
        text: "\uf252"
        font.family: Style.font.family
        font.pixelSize: 11
        color: root.modeColor
        opacity: root.isTimerRunning && root.tickPhase ? 0.4 : 1.0
      }

      // Countdown Text
      Text {
        text: root.formatTime(root.secondsLeft)
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.Bold
        color: Color.foreground
      }

      // Small Play/Pause Indicator
      Text {
        text: root.isTimerRunning ? "\uf04c" : "\uf04b"
        font.family: Style.font.family
        font.pixelSize: 9
        color: root.isTimerRunning ? root.modeColor : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
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
          root.toggleRunning()
        } else if (mouse.button === Qt.RightButton) {
          root.cycleMode()
        }
      }
    }
  }
}
