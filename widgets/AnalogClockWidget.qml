import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

WidgetCard {
  id: analogClockRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Sizing
  // ---------------------------------------------------------------------------
  widgetId: "analog_clock"
  title: "Analog Clock"
  icon: "\uf017"
  showHeader: false // Border-to-border clock face

  defaultX: 700
  defaultY: 40

  width: 280
  height: 280
  minWidth: 200
  minHeight: 200
  maxWidth: 600
  maxHeight: 600
  menuWidth: 290

  // ---------------------------------------------------------------------------
  // ⚙️ Custom Preferences & Persistence
  // ---------------------------------------------------------------------------
  property string clockStyle: "chronograph" // "chronograph" | "bauhaus" | "flieger" | "cyber"
  property bool smoothSweep: true
  property bool showComplications: true
  property bool showSubDials: true

  function applySavedSettings() {
    var s = getSetting("clockStyle", undefined)
    if (s !== undefined && typeof s === "string") clockStyle = s
    var sw = getSetting("smoothSweep", undefined)
    if (sw !== undefined) smoothSweep = Boolean(sw)
    var c = getSetting("showComplications", undefined)
    if (c !== undefined) showComplications = Boolean(c)
    var sd = getSetting("showSubDials", undefined)
    if (sd !== undefined) showSubDials = Boolean(sd)
    var fl = getSetting("frameless", undefined)
    if (fl !== undefined) frameless = Boolean(fl)
  }

  onSettingsLoaded: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  // ---------------------------------------------------------------------------
  // ⏰ Precise Time Engine
  property var now: new Date()
  property real continuousSeconds: 0.0

  function updateCurrentTime() {
    var d = new Date()
    now = d
    if (smoothSweep) {
      continuousSeconds = d.getSeconds() + (d.getMilliseconds() / 1000.0)
    } else {
      continuousSeconds = d.getSeconds()
    }
  }

  onSmoothSweepChanged: updateCurrentTime()

  // Smooth sweep frame timer (10 FPS when smoothSweep is active). Every tick
  // repaints the whole desktop-widgets layer, so 60 FPS cost real GPU time for
  // sub-pixel hand movement. Both timers pause while the card is off screen
  // (auto-hidden behind windows, manually hidden) -- visible is effective
  // visibility, so it follows the widget container.
  Timer {
    interval: 100
    running: analogClockRoot.smoothSweep && analogClockRoot.visible && (!analogClockRoot.rootRef || !analogClockRoot.rootRef.manualHide)
    repeat: true
    triggeredOnStart: true
    onTriggered: analogClockRoot.updateCurrentTime()
  }

  // 1-second interval timer when stepping mode is active
  Timer {
    interval: 1000
    running: !analogClockRoot.smoothSweep && analogClockRoot.visible && (!analogClockRoot.rootRef || !analogClockRoot.rootRef.manualHide)
    repeat: true
    triggeredOnStart: true
    onTriggered: analogClockRoot.updateCurrentTime()
  }

  readonly property int currentHours: now.getHours()
  readonly property int currentMinutes: now.getMinutes()
  readonly property int currentSeconds: now.getSeconds()
  readonly property int currentDay: now.getDate()
  readonly property string currentDayName: Qt.formatDate(now, "ddd").toUpperCase()
  readonly property string currentMonthName: Qt.formatDate(now, "MMM").toUpperCase()

  readonly property real secondAngle: continuousSeconds * 6.0
  readonly property real minuteAngle: (currentMinutes + (continuousSeconds / 60.0)) * 6.0
  readonly property real hourAngle: ((currentHours % 12) + (currentMinutes / 60.0) + (continuousSeconds / 3600.0)) * 30.0
  readonly property real utc24Angle: ((now.getUTCHours() + (now.getUTCMinutes() / 60.0) + (continuousSeconds / 3600.0)) / 24.0) * 360.0

  // Center & Dial Geometry
  readonly property real dialDiameter: Math.min(width - 24, height - 24)
  readonly property real dialRadius: dialDiameter / 2.0
  readonly property real centerX: width / 2.0
  readonly property real centerY: height / 2.0

  // ---------------------------------------------------------------------------
  // 🎨 Dial Surface
  // ---------------------------------------------------------------------------
  Item {
    id: dialContainer
    anchors.centerIn: parent
    width: analogClockRoot.dialDiameter
    height: analogClockRoot.dialDiameter

    // Bezel Outer Shadow / Ring
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: {
        if (clockStyle === "cyber") return Qt.rgba(10/255, 15/255, 24/255, 0.92)
        if (clockStyle === "bauhaus") return Qt.rgba(18/255, 20/255, 26/255, 0.90)
        if (clockStyle === "flieger") return Qt.rgba(8/255, 10/255, 14/255, 0.95)
        return Qt.rgba(14/255, 16/255, 22/255, 0.94) // chronograph
      }
      border.width: clockStyle === "cyber" ? 1.5 : 1
      border.color: {
        if (clockStyle === "cyber") return Color.accent
        if (clockStyle === "chronograph") return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
        return Qt.rgba(1, 1, 1, 0.12)
      }

      // Inner Concentric Texture (Chronograph)
      Rectangle {
        anchors.fill: parent
        anchors.margins: 14
        radius: width / 2
        visible: clockStyle === "chronograph" || clockStyle === "cyber"
        color: "transparent"
        border.width: 1
        border.color: clockStyle === "cyber" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
      }
    }

    // -------------------------------------------------------------------------
    // 🧭 Hour Indices (12 markers around dial)
    // -------------------------------------------------------------------------
    Repeater {
      model: 12

      Item {
        id: hourPipItem
        required property int index
        anchors.centerIn: parent
        width: dialContainer.width
        height: dialContainer.height
        rotation: index * 30

        // Primary Hour Baton / Pip
        Rectangle {
          anchors.top: parent.top
          anchors.topMargin: (clockStyle === "bauhaus" || clockStyle === "flieger") ? 8 : 10
          anchors.horizontalCenter: parent.horizontalCenter
          width: {
            if (clockStyle === "bauhaus") return (hourPipItem.index % 3 === 0) ? 3 : 1.5
            if (clockStyle === "flieger") return (hourPipItem.index === 0) ? 0 : 2.5
            if (clockStyle === "cyber") return (hourPipItem.index % 3 === 0) ? 3 : 1.5
            return (hourPipItem.index % 3 === 0) ? 3.5 : 2
          }
          height: {
            if (clockStyle === "bauhaus") return (hourPipItem.index % 3 === 0) ? 14 : 9
            if (clockStyle === "flieger") return 11
            if (clockStyle === "cyber") return (hourPipItem.index % 3 === 0) ? 12 : 7
            return (hourPipItem.index % 3 === 0) ? 13 : 8
          }
          radius: 1
          color: {
            if (clockStyle === "cyber") return (hourPipItem.index % 3 === 0) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            if (hourPipItem.index % 3 === 0) return Color.accent
            return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
          }
        }

        // Flieger 12-o'clock Triangle marker
        Item {
          visible: clockStyle === "flieger" && hourPipItem.index === 0
          anchors.top: parent.top
          anchors.topMargin: 8
          anchors.horizontalCenter: parent.horizontalCenter
          width: 14
          height: 12

          Text {
            anchors.centerIn: parent
            text: "\uf0d8" // Triangle
            font.family: Style.font.family
            font.pixelSize: 13
            color: Color.accent
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🔢 Numerals (Flieger & Chronograph styles)
    // -------------------------------------------------------------------------
    Repeater {
      model: (clockStyle === "flieger") ? [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] : (clockStyle === "chronograph" ? [12, 3, 6, 9] : [])

      Item {
        id: numItem
        required property var modelData
        anchors.centerIn: parent
        width: dialContainer.width
        height: dialContainer.height

        readonly property real numAngle: (Number(modelData) % 12) * (Math.PI / 6.0) - (Math.PI / 2.0)
        readonly property real numDist: dialContainer.width / 2.0 - ((clockStyle === "flieger") ? 26 : 28)

        Text {
          x: (dialContainer.width / 2.0) + Math.cos(numItem.numAngle) * numItem.numDist - (width / 2.0)
          y: (dialContainer.height / 2.0) + Math.sin(numItem.numAngle) * numItem.numDist - (height / 2.0)
          text: (numItem.modelData === 12 && clockStyle === "flieger") ? "" : String(numItem.modelData)
          font.family: Style.font.family
          font.pixelSize: (clockStyle === "flieger") ? 11 : 12
          font.weight: Font.Bold
          color: (numItem.modelData % 3 === 0) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📊 Complications: Sub-Dials (Chronograph & Cyber styles)
    // -------------------------------------------------------------------------
    // 1. Top Sub-dial: 24-Hour UTC / Military dial
    Item {
      id: topSubDial
      visible: analogClockRoot.showSubDials && (clockStyle === "chronograph" || clockStyle === "cyber")
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: dialContainer.height * 0.17
      width: dialContainer.width * 0.28
      height: width

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: clockStyle === "cyber" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : Qt.rgba(1, 1, 1, 0.08)

        Text {
          anchors.top: parent.top
          anchors.topMargin: 2
          anchors.horizontalCenter: parent.horizontalCenter
          text: "24"
          font.family: Style.font.family
          font.pixelSize: 7
          font.weight: Font.Bold
          color: Color.accent
        }

        Text {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 2
          anchors.horizontalCenter: parent.horizontalCenter
          text: "12"
          font.family: Style.font.family
          font.pixelSize: 7
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
      }

      // 24H Hand
      Item {
        anchors.centerIn: parent
        width: 0
        height: 0
        rotation: analogClockRoot.utc24Angle

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: 1.5
          height: topSubDial.height * 0.38
          radius: 0.75
          color: Color.accent
          antialiasing: true
        }
      }
    }

    // 2. Bottom Sub-dial: Small Seconds (Chronograph style)
    Item {
      id: bottomSubDial
      visible: analogClockRoot.showSubDials && (clockStyle === "chronograph")
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: dialContainer.height * 0.17
      width: dialContainer.width * 0.28
      height: width

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Text {
          anchors.top: parent.top
          anchors.topMargin: 2
          anchors.horizontalCenter: parent.horizontalCenter
          text: "60"
          font.family: Style.font.family
          font.pixelSize: 7
          font.weight: Font.Bold
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }

        Text {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 2
          anchors.horizontalCenter: parent.horizontalCenter
          text: "30"
          font.family: Style.font.family
          font.pixelSize: 7
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
      }

      // Small seconds Hand
      Item {
        anchors.centerIn: parent
        width: 0
        height: 0
        rotation: analogClockRoot.secondAngle

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: 1.5
          height: bottomSubDial.height * 0.38
          radius: 0.75
          color: Color.accent
          antialiasing: true
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📅 Date & Day Complication (3 o'clock aperture)
    // -------------------------------------------------------------------------
    Rectangle {
      id: dateAperture
      visible: analogClockRoot.showComplications
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      anchors.rightMargin: (clockStyle === "bauhaus") ? 18 : 22
      width: (clockStyle === "bauhaus") ? 26 : 46
      height: 20
      radius: 4
      color: Qt.rgba(0, 0, 0, 0.45)
      border.width: 1
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 3

        Text {
          visible: clockStyle !== "bauhaus"
          text: analogClockRoot.currentDayName
          font.family: Style.font.family
          font.pixelSize: 8
          font.weight: Font.Bold
          color: Color.accent
        }

        Rectangle {
          visible: clockStyle !== "bauhaus"
          width: 1
          Layout.fillHeight: true
          Layout.topMargin: 2
          Layout.bottomMargin: 2
          color: Qt.rgba(1, 1, 1, 0.1)
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: String(analogClockRoot.currentDay)
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.DemiBold
          color: Color.foreground
        }
      }
    }

    // -------------------------------------------------------------------------
    // ⌚ Clock Hands: Hour, Minute, Seconds
    // -------------------------------------------------------------------------

    // 1. Hour Hand
    Item {
      id: hourHandPivot
      anchors.centerIn: parent
      width: 0
      height: 0
      rotation: analogClockRoot.hourAngle
      z: 10

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -6
        width: (clockStyle === "bauhaus") ? 4 : (clockStyle === "flieger" ? 5.5 : 4.5)
        height: dialContainer.height * 0.28 + 6
        radius: 2
        color: (clockStyle === "cyber") ? Color.accent : Color.foreground
        antialiasing: true
      }
    }

    // 2. Minute Hand
    Item {
      id: minuteHandPivot
      anchors.centerIn: parent
      width: 0
      height: 0
      rotation: analogClockRoot.minuteAngle
      z: 12

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -8
        width: (clockStyle === "bauhaus") ? 2.5 : 3.5
        height: dialContainer.height * 0.40 + 8
        radius: 1.5
        color: Color.foreground
        antialiasing: true
      }
    }

    // Center Pin Cap (above hour & minute hands)
    Rectangle {
      anchors.centerIn: parent
      width: 10
      height: 10
      radius: 5
      color: Color.accent
      border.width: 1.5
      border.color: Color.foreground
      z: 15
    }

    // 3. Second Hand (Sweeping or Stepping)
    Item {
      id: secondHandPivot
      anchors.centerIn: parent
      width: 0
      height: 0
      rotation: analogClockRoot.secondAngle
      z: 20

      // Main second needle pointing up toward 12
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 1.5
        height: dialContainer.height * 0.44
        radius: 0.75
        color: (clockStyle === "cyber") ? "#38bdf8" : Color.accent
        antialiasing: true
      }

      // Counter-balance tail pointing down toward 6
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 3.5
        height: 14
        radius: 1.5
        color: (clockStyle === "cyber") ? "#38bdf8" : Color.accent
        antialiasing: true
      }
    }

    // Center Jewel Pip (uppermost cap)
    Rectangle {
      anchors.centerIn: parent
      width: 4
      height: 4
      radius: 2
      color: (clockStyle === "cyber") ? "#38bdf8" : Color.urgent
      z: 25
    }
  }

  // ---------------------------------------------------------------------------
  // ⚙️ Custom Context Menu Settings
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 260
      spacing: Style.space(6)

      Text {
        text: "ANALOG CLOCK STYLES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(8)
      }

      // Style Selector Buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: [
            { label: "Chrono", id: "chronograph" },
            { label: "Bauhaus", id: "bauhaus" },
            { label: "Flieger", id: "flieger" },
            { label: "Cyber", id: "cyber" }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            height: 24
            radius: 4
            color: (analogClockRoot.clockStyle === modelData.id) ? Color.accent : (styleBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: (analogClockRoot.clockStyle === modelData.id) ? Font.Bold : Font.Normal
              color: (analogClockRoot.clockStyle === modelData.id) ? "#0a0a0f" : Color.foreground
            }

            MouseArea {
              id: styleBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                analogClockRoot.clockStyle = modelData.id
                analogClockRoot.saveSetting("clockStyle", modelData.id)
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
      }

      // Smooth Sweep Toggle
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: sweepMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf01e"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Smooth 60 FPS Sweep"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: analogClockRoot.smoothSweep ? "\uf205" : "\uf204"
            font.family: Style.font.family
            font.pixelSize: 13
            color: analogClockRoot.smoothSweep ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: sweepMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            analogClockRoot.smoothSweep = !analogClockRoot.smoothSweep
            analogClockRoot.saveSetting("smoothSweep", analogClockRoot.smoothSweep)
          }
        }
      }

      // Date Complication Toggle
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: compMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf073"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Show Date Window"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: analogClockRoot.showComplications ? "\uf205" : "\uf204"
            font.family: Style.font.family
            font.pixelSize: 13
            color: analogClockRoot.showComplications ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: compMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            analogClockRoot.showComplications = !analogClockRoot.showComplications
            analogClockRoot.saveSetting("showComplications", analogClockRoot.showComplications)
          }
        }
      }

      // Sub-Dials Toggle
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: subDialMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf192"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Show Sub-Dials"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: analogClockRoot.showSubDials ? "\uf205" : "\uf204"
            font.family: Style.font.family
            font.pixelSize: 13
            color: analogClockRoot.showSubDials ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: subDialMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            analogClockRoot.showSubDials = !analogClockRoot.showSubDials
            analogClockRoot.saveSetting("showSubDials", analogClockRoot.showSubDials)
          }
        }
      }

      // Frame / Border Toggle (Clock Only vs Box)
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: frameMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf2d0"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: analogClockRoot.frameless ? "Frameless (Clock Only)" : "Card Frame (In a Box)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: !analogClockRoot.frameless ? "\uf205" : "\uf204"
            font.family: Style.font.family
            font.pixelSize: 13
            color: !analogClockRoot.frameless ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: frameMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            analogClockRoot.frameless = !analogClockRoot.frameless
            analogClockRoot.saveSetting("frameless", analogClockRoot.frameless)
          }
        }
      }
    }
  }
}
