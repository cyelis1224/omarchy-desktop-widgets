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
  id: pomodoroWidgetRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Placement Settings
  // ---------------------------------------------------------------------------
  widgetId: "pomodoro"
  title: "Flow State Pomodoro"
  icon: "\uf252"
  showHeader: false // Custom integrated header with session indicators & grips

  defaultX: screenWidth - width - Style.space(24)
  defaultY: screenHeight - height - Style.space(64)

  width: 320
  height: 410
  minWidth: 260
  minHeight: 280

  // ---------------------------------------------------------------------------
  // ⏱️ Pomodoro State & Durations
  // ---------------------------------------------------------------------------
  property string currentMode: "FOCUS" // "FOCUS" | "SHORT" | "LONG"
  property bool isTimerRunning: false

  property int focusDurationSec: 25 * 60  // 25 minutes
  property int shortDurationSec: 5 * 60   // 5 minutes
  property int longDurationSec: 15 * 60   // 15 minutes

  property int totalSeconds: focusDurationSec
  property int secondsLeft: focusDurationSec

  property int completedSessions: 0
  property int cycleStep: 1 // 1, 2, 3, 4
  property string activePreset: "25/5"
  property bool soundAlerts: true
  property bool showNotifications: true
  menuWidth: 320

  function applyPreset(preset) {
    activePreset = preset
    if (preset === "25/5") {
      focusDurationSec = 25 * 60
      shortDurationSec = 5 * 60
      longDurationSec = 15 * 60
    } else if (preset === "50/10") {
      focusDurationSec = 50 * 60
      shortDurationSec = 10 * 60
      longDurationSec = 20 * 60
    } else if (preset === "15/3") {
      focusDurationSec = 15 * 60
      shortDurationSec = 3 * 60
      longDurationSec = 10 * 60
    }
    setMode(currentMode, false)
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "INTERVAL PRESETS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      Repeater {
        model: [
          { id: "25/5", label: "Standard: 25m Focus / 5m Break", icon: "\uf252" },
          { id: "50/10", label: "Deep Work: 50m Focus / 10m Break", icon: "\uf0e7" },
          { id: "15/3", label: "Sprint: 15m Focus / 3m Break", icon: "\uf135" }
        ]

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          readonly property bool isSelected: pomodoroWidgetRoot.activePreset === modelData.id
          color: pMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (isSelected ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              text: modelData.icon
              font.family: Style.font.family
              font.pixelSize: 11
              color: isSelected ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }

            Text {
              Layout.fillWidth: true
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: isSelected ? Font.Bold : Font.Normal
              color: isSelected ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8)
              elide: Text.ElideRight
            }

            Text {
              visible: isSelected
              text: "\uf00c"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.accent
            }
          }

          MouseArea {
            id: pMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pomodoroWidgetRoot.applyPreset(modelData.id)
          }
        }
      }

      Text {
        text: "ALERTS & NOTIFICATIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Play Sound Chimes Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: sndMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: pomodoroWidgetRoot.soundAlerts ? "\uf028" : "\uf6a9"
            font.family: Style.font.family
            font.pixelSize: 11
            color: pomodoroWidgetRoot.soundAlerts ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Completion Audio Chimes"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: pomodoroWidgetRoot.soundAlerts ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: pomodoroWidgetRoot.soundAlerts ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: sndMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pomodoroWidgetRoot.soundAlerts = !pomodoroWidgetRoot.soundAlerts
        }
      }

      // Desktop Notification Banners Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: notifMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0f3"
            font.family: Style.font.family
            font.pixelSize: 11
            color: pomodoroWidgetRoot.showNotifications ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Desktop Notification Banners"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: pomodoroWidgetRoot.showNotifications ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: pomodoroWidgetRoot.showNotifications ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: notifMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pomodoroWidgetRoot.showNotifications = !pomodoroWidgetRoot.showNotifications
        }
      }

      Text {
        text: "SESSION MANAGEMENT"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Restart Current Timer Action
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: restartMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf2f9"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Restart Current Interval"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: restartMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            pomodoroWidgetRoot.contextMenuOpen = false
            pomodoroWidgetRoot.resetCurrentTimer()
          }
        }
      }

      // Reset Streak Action
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: resetStreakMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0e2"
            font.family: Style.font.family
            font.pixelSize: 11
            color: resetStreakMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }

          Text {
            Layout.fillWidth: true
            text: "Reset Completed Sessions Streak"
            font.family: Style.font.family
            font.pixelSize: 11
            color: resetStreakMouse.containsMouse ? Color.urgent : Color.foreground
          }
        }

        MouseArea {
          id: resetStreakMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            pomodoroWidgetRoot.contextMenuOpen = false
            pomodoroWidgetRoot.completedSessions = 0
            pomodoroWidgetRoot.cycleStep = 1
          }
        }
      }
    }
  }

  readonly property color modeColor: {
    if (currentMode === "SHORT") return "#10b981" // Emerald Mint
    if (currentMode === "LONG") return "#06b6d4"  // Electric Cyan
    return Color.accent                           // Theme Accent / Focus Red
  }

  readonly property string modeTitle: {
    if (currentMode === "SHORT") return "Short Break"
    if (currentMode === "LONG") return "Long Break"
    return "Deep Focus"
  }

  readonly property real progressFraction: {
    if (totalSeconds <= 0) return 0
    return Math.max(0.0, Math.min(1.0, 1.0 - (secondsLeft / totalSeconds)))
  }

  function formatTime(secs) {
    var m = Math.floor(secs / 60)
    var s = secs % 60
    return (m < 10 ? "0" + m : m.toString()) + ":" + (s < 10 ? "0" + s : s.toString())
  }

  function setMode(mode, autoStart) {
    currentMode = mode
    isTimerRunning = autoStart ? true : false
    if (mode === "FOCUS") totalSeconds = focusDurationSec
    else if (mode === "SHORT") totalSeconds = shortDurationSec
    else if (mode === "LONG") totalSeconds = longDurationSec
    secondsLeft = totalSeconds
    progressArc.requestPaint()
  }

  function togglePlayPause() {
    isTimerRunning = !isTimerRunning
  }

  function resetCurrentTimer() {
    isTimerRunning = false
    secondsLeft = totalSeconds
    progressArc.requestPaint()
  }

  function skipToNextSession() {
    isTimerRunning = false
    if (currentMode === "FOCUS") {
      completedSessions++
      if (cycleStep >= 4) {
        cycleStep = 1
        setMode("LONG", false)
      } else {
        cycleStep++
        setMode("SHORT", false)
      }
    } else {
      setMode("FOCUS", false)
    }
  }

  function onSessionFinished() {
    isTimerRunning = false
    if (currentMode === "FOCUS") {
      completedSessions++
      if (pomodoroWidgetRoot.showNotifications) {
        Quickshell.execDetached(["notify-send", "-i", "appointment-soon", "🍅 Focus Session Complete!", "Great job! Take a well-deserved break."])
      }
      if (pomodoroWidgetRoot.soundAlerts) {
        Quickshell.execDetached(["bash", "-c", "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null"])
      }

      if (cycleStep >= 4) {
        cycleStep = 1
        setMode("LONG", true)
      } else {
        cycleStep++
        setMode("SHORT", true)
      }
    } else {
      if (pomodoroWidgetRoot.showNotifications) {
        Quickshell.execDetached(["notify-send", "-i", "appointment-soon", "⚡ Break Finished!", "Time to dive back into flow state."])
      }
      if (pomodoroWidgetRoot.soundAlerts) {
        Quickshell.execDetached(["bash", "-c", "paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null"])
      }
      setMode("FOCUS", true)
    }
  }

  // 1-second countdown clock ticker
  Timer {
    interval: 1000
    repeat: true
    running: pomodoroWidgetRoot.isTimerRunning
    onTriggered: {
      if (pomodoroWidgetRoot.secondsLeft > 1) {
        pomodoroWidgetRoot.secondsLeft--
        progressArc.requestPaint()
      } else {
        pomodoroWidgetRoot.secondsLeft = 0
        progressArc.requestPaint()
        pomodoroWidgetRoot.onSessionFinished()
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 Widget Body & Controls
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(12)

    // -------------------------------------------------------------------------
    // 🏷️ Top Header: Icon, Title & Edit/Move Controls
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Rectangle {
        width: 30
        height: 30
        radius: 15
        color: Qt.rgba(pomodoroWidgetRoot.modeColor.r, pomodoroWidgetRoot.modeColor.g, pomodoroWidgetRoot.modeColor.b, 0.2)
        border.color: Qt.rgba(pomodoroWidgetRoot.modeColor.r, pomodoroWidgetRoot.modeColor.g, pomodoroWidgetRoot.modeColor.b, 0.45)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf252"
          font.family: Style.font.family
          font.pixelSize: 13
          color: pomodoroWidgetRoot.modeColor
        }
      }

      ColumnLayout {
        spacing: 0
        Text {
          text: "Flow Pomodoro"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Color.foreground
        }
        Text {
          text: pomodoroWidgetRoot.modeTitle + " · Step " + pomodoroWidgetRoot.cycleStep + " of 4"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        }
      }

      Item { Layout.fillWidth: true }

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
              rootRef.toggleWidgetEnabled(pomodoroWidgetRoot.widgetId, false)
            }
          }
        }
      }

      // Move Grip Button (Edit Mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: customGripMouse.drag.active ? Color.accent : (customGripMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0b2"
          font.family: Style.font.family
          font.pixelSize: 10
          color: customGripMouse.drag.active ? Color.background : Color.accent
        }

        MouseArea {
          id: customGripMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: screenWidth - pomodoroWidgetRoot.width - 10
          drag.minimumY: 10
          drag.maximumY: screenHeight - pomodoroWidgetRoot.height - 10
          onPressed: pomodoroWidgetRoot.customGripDragging = true
          onReleased: {
            pomodoroWidgetRoot.customGripDragging = false
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(pomodoroWidgetRoot.widgetId, Math.round(targetItem.x), Math.round(targetItem.y))
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🔘 Mode Selector Pills
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Repeater {
        model: [
          { mode: "FOCUS", label: "Focus 25m", color: Color.accent },
          { mode: "SHORT", label: "Short 5m", color: "#10b981" },
          { mode: "LONG", label: "Long 15m", color: "#06b6d4" }
        ]

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          height: 26
          radius: 13
          readonly property bool isSelected: pomodoroWidgetRoot.currentMode === modelData.mode
          color: isSelected ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.28) : (modePillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
          border.color: isSelected ? modelData.color : Qt.rgba(1, 1, 1, 0.1)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: modelData.label
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: isSelected ? Font.Bold : Font.Normal
            color: isSelected ? modelData.color : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
          }

          MouseArea {
            id: modePillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pomodoroWidgetRoot.setMode(modelData.mode, false)
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // ⭕ Circular Progress Ring & Time Readout
    // -------------------------------------------------------------------------
    Item {
      Layout.alignment: Qt.AlignHCenter
      width: 190
      height: 190

      // Static Background Ring Track
      Canvas {
        id: trackCanvas
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var c = width / 2
          var r = c - 10
          ctx.lineWidth = 10
          ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
          ctx.beginPath()
          ctx.arc(c, c, r, 0, Math.PI * 2)
          ctx.stroke()
        }
      }

      // Dynamic Active Progress Arc
      Canvas {
        id: progressArc
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var c = width / 2
          var r = c - 10
          var progress = pomodoroWidgetRoot.progressFraction

          if (progress > 0) {
            ctx.lineWidth = 10
            ctx.lineCap = "round"
            ctx.strokeStyle = pomodoroWidgetRoot.modeColor
            ctx.beginPath()
            ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * progress))
            ctx.stroke()
          }
        }
      }

      // Center Time & Label Stack
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: pomodoroWidgetRoot.formatTime(pomodoroWidgetRoot.secondsLeft)
          font.family: "Monospace"
          font.pixelSize: 32
          font.weight: Font.Bold
          color: Color.foreground
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: 5

          Rectangle {
            width: 6
            height: 6
            radius: 3
            color: pomodoroWidgetRoot.isTimerRunning ? pomodoroWidgetRoot.modeColor : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Text {
            text: pomodoroWidgetRoot.isTimerRunning ? pomodoroWidgetRoot.currentMode : "PAUSED"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: pomodoroWidgetRoot.isTimerRunning ? pomodoroWidgetRoot.modeColor : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🎮 Controls: Reset, Play/Pause, Skip
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.space(12)

      Item { Layout.fillWidth: true }

      // Reset Button
      Rectangle {
        width: 36
        height: 36
        radius: 18
        color: resetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0e2"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.foreground
        }

        MouseArea {
          id: resetMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pomodoroWidgetRoot.resetCurrentTimer()
        }
      }

      // Primary Start / Pause Pill Button
      Rectangle {
        implicitWidth: playPillRow.implicitWidth + 28
        implicitHeight: 38
        radius: 19
        color: playMouse.containsMouse ? Qt.lighter(pomodoroWidgetRoot.modeColor, 1.15) : pomodoroWidgetRoot.modeColor

        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: Qt.rgba(pomodoroWidgetRoot.modeColor.r, pomodoroWidgetRoot.modeColor.g, pomodoroWidgetRoot.modeColor.b, 0.5)
          shadowBlur: 0.6
          shadowVerticalOffset: 2
        }

        RowLayout {
          id: playPillRow
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            text: pomodoroWidgetRoot.isTimerRunning ? "\uf04c" : "\uf04b"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Color.background
          }

          Text {
            text: pomodoroWidgetRoot.isTimerRunning ? "Pause" : (pomodoroWidgetRoot.secondsLeft < pomodoroWidgetRoot.totalSeconds ? "Resume" : "Start " + (pomodoroWidgetRoot.currentMode === "FOCUS" ? "Focus" : "Break"))
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.Bold
            color: Color.background
          }
        }

        MouseArea {
          id: playMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pomodoroWidgetRoot.togglePlayPause()
        }
      }

      // Skip Button
      Rectangle {
        width: 36
        height: 36
        radius: 18
        color: skipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf051"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.foreground
        }

        MouseArea {
          id: skipMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pomodoroWidgetRoot.skipToNextSession()
        }
      }

      Item { Layout.fillWidth: true }
    }

    // -------------------------------------------------------------------------
    // 🍅 Cycle Step Dots & Daily Sessions Streak
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: Style.space(4)

      // 4 Cycle Dots
      RowLayout {
        spacing: 5

        Repeater {
          model: 4
          Rectangle {
            required property int index
            width: 8
            height: 8
            radius: 4
            color: (index + 1) <= pomodoroWidgetRoot.cycleStep ? pomodoroWidgetRoot.modeColor : Qt.rgba(1, 1, 1, 0.15)
            border.color: (index + 1) === pomodoroWidgetRoot.cycleStep ? Qt.lighter(pomodoroWidgetRoot.modeColor, 1.3) : "transparent"
            border.width: 1
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Streak Tally Badge
      RowLayout {
        spacing: 4
        Text {
          text: "\uf06d"
          font.family: Style.font.family
          font.pixelSize: 10
          color: "#f59e0b" // Amber flame
        }
        Text {
          text: pomodoroWidgetRoot.completedSessions + (pomodoroWidgetRoot.completedSessions === 1 ? " session" : " sessions") + " completed"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
        }
      }
    }
  }
}
