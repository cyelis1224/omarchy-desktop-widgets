import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: clockWidgetRoot

  property string widgetId: "clock"
  property var rootRef: null
  readonly property real screenWidth: (rootRef && rootRef.screenWidth > 0) ? rootRef.screenWidth : 1920
  readonly property real screenHeight: (rootRef && rootRef.screenHeight > 0) ? rootRef.screenHeight : 1080
  property real defaultX: Math.round((screenWidth - width) / 2)
  property real defaultY: Math.round((screenHeight - height) / 2)

  width: centerClockColumn.implicitWidth + 40
  height: centerClockColumn.implicitHeight + 36
  property real minWidth: 280
  property real minHeight: 160

  property var loaderItem: null
  readonly property var targetItem: loaderItem ? loaderItem : clockWidgetRoot

  readonly property bool isDragging: clockGripArea.drag.active || (clockFullDragArea && clockFullDragArea.drag.active)
  scale: isDragging ? 1.03 : 1.0

  Behavior on scale {
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
  }

  // ---------------------------------------------------------------------------
  // ⏰ Real-time Clock, Date, Greeting, and Weather State
  // ---------------------------------------------------------------------------
  property var currentDate: new Date()
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: clockWidgetRoot.currentDate = new Date()
  }

  // 🕒 Clock & Weather Display Preferences
  property bool is24Hour: true
  property bool showSeconds: false
  property bool showWeather: true
  property bool showGreeting: true
  property bool compactDate: false
  property bool useCelsius: false

  function applySavedSettings() {
    if (!rootRef || !rootRef.settingsReady) return
    var s = rootRef.widgetSettings ? rootRef.widgetSettings[widgetId] : null
    if (!s) return
    if (s.is24Hour !== undefined) is24Hour = s.is24Hour
    if (s.showSeconds !== undefined) showSeconds = s.showSeconds
    if (s.compactDate !== undefined) compactDate = s.compactDate
    if (s.showWeather !== undefined) showWeather = s.showWeather
    if (s.showGreeting !== undefined) showGreeting = s.showGreeting
    if (s.useCelsius !== undefined) useCelsius = s.useCelsius
  }

  signal settingsLoaded()

  Connections {
    target: rootRef || null
    ignoreUnknownSignals: true
    function onWidgetSettingsChanged() {
      clockWidgetRoot.applySavedSettings()
    }
    function onSettingsReadyChanged() {
      if (rootRef && rootRef.settingsReady) {
        clockWidgetRoot.applySavedSettings()
      }
    }
  }

  function saveSetting(key, val) {
    if (rootRef && rootRef.saveWidgetSetting) {
      rootRef.saveWidgetSetting(clockWidgetRoot.widgetId, key, val)
    }
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: {
    if (rootRef && rootRef.settingsReady) applySavedSettings()
  }
  Component.onCompleted: {
    if (rootRef && rootRef.settingsReady) applySavedSettings()
  }

  readonly property string timeString: {
    var fmt = is24Hour ? (showSeconds ? "HH:mm:ss" : "HH:mm") : (showSeconds ? "h:mm:ss AP" : "h:mm AP")
    return Qt.formatTime(clockWidgetRoot.currentDate, fmt)
  }
  readonly property string dateString: compactDate ? Qt.formatDate(clockWidgetRoot.currentDate, "ddd, MMM d") : Qt.formatDate(clockWidgetRoot.currentDate, "dddd, MMMM d, yyyy")

  readonly property string greetingString: {
    var h = clockWidgetRoot.currentDate.getHours()
    if (h >= 5 && h < 12) return "Good morning"
    if (h >= 12 && h < 17) return "Good afternoon"
    if (h >= 17 && h < 22) return "Good evening"
    return "Late night vibes"
  }

  property string weatherTempF: ""
  property string weatherTempC: ""
  property string weatherTemp: useCelsius ? (weatherTempC ? weatherTempC : weatherTempF) : (weatherTempF ? weatherTempF : weatherTempC)
  property string weatherDesc: ""
  property string weatherIcon: "\uf185"
  readonly property string weatherScriptPath: {
    var u = Qt.resolvedUrl("../get-weather.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  Process {
    id: weatherProc
    command: [clockWidgetRoot.weatherScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.temp) clockWidgetRoot.weatherTempF = data.temp
          if (data.tempC) clockWidgetRoot.weatherTempC = data.tempC
          if (data.desc) clockWidgetRoot.weatherDesc = data.desc
          if (data.icon) clockWidgetRoot.weatherIcon = data.icon
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 600000 // Refresh weather every 10 min
    running: true
    repeat: true
    onTriggered: {
      if (!weatherProc.running) weatherProc.running = true
    }
  }

  // 🌫️ Expansive Central Radial Ambient Drop Shadow Backdrop
  Canvas {
    id: centralShadowBackdrop
    anchors.centerIn: parent
    width: centerClockColumn.width + Style.space(480)
    height: centerClockColumn.height + Style.space(280)

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var cx = width / 2
      var cy = height / 2
      var rx = width / 2
      var ry = height / 2

      ctx.save()
      ctx.translate(cx, cy)
      ctx.scale(1.0, ry / rx)

      var grad = ctx.createRadialGradient(0, 0, 0, 0, 0, rx)
      grad.addColorStop(0.0, "rgba(0, 0, 0, 0.20)")
      grad.addColorStop(0.35, "rgba(0, 0, 0, 0.12)")
      grad.addColorStop(0.70, "rgba(0, 0, 0, 0.05)")
      grad.addColorStop(1.0, "rgba(0, 0, 0, 0.0)")

      ctx.fillStyle = grad
      ctx.beginPath()
      ctx.arc(0, 0, rx, 0, 2 * Math.PI)
      ctx.fill()
      ctx.restore()
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  // Hover / Move Handle on top of clock
  Rectangle {
    id: clockGripHandle
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2
    width: 22
    height: 22
    radius: 11
    color: clockGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(14/255, 14/255, 20/255, 0.6)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
    border.width: 1
    opacity: clockGripArea.containsMouse || clockGripArea.drag.active || (rootRef && rootRef.layoutEditMode) ? 1.0 : 0.0
    visible: rootRef && rootRef.layoutEditMode
    z: 110

    Behavior on opacity {
      NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
      anchors.centerIn: parent
      text: "\uf0b2"
      font.family: Style.font.family
      font.pixelSize: 10
      color: Color.accent
    }

    MouseArea {
      id: clockGripArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.SizeAllCursor
      drag.target: clockWidgetRoot.targetItem
      drag.axis: Drag.XAndYAxis
      drag.minimumX: 10
      drag.maximumX: Math.max(10, clockWidgetRoot.screenWidth - clockWidgetRoot.width - 10)
      drag.minimumY: 10
      drag.maximumY: Math.max(10, clockWidgetRoot.screenHeight - clockWidgetRoot.height - 10)

      onReleased: function() {
        var maxX = Math.max(10, clockWidgetRoot.screenWidth - clockWidgetRoot.width - 10)
        var maxY = Math.max(10, clockWidgetRoot.screenHeight - clockWidgetRoot.height - 10)
        var snappedX = Math.round(clockWidgetRoot.targetItem.x / 20) * 20
        var snappedY = Math.round(clockWidgetRoot.targetItem.y / 20) * 20
        snappedX = Math.max(10, Math.min(maxX, snappedX))
        snappedY = Math.max(10, Math.min(maxY, snappedY))
        clockWidgetRoot.targetItem.x = snappedX
        clockWidgetRoot.targetItem.y = snappedY
        if (rootRef && rootRef.saveWidgetPos) {
          rootRef.saveWidgetPos(clockWidgetRoot.widgetId, snappedX, snappedY)
        }
      }
    }
  }

  // Close / Remove Button (when in edit mode)
  Rectangle {
    id: clockCloseButton
    anchors.left: clockGripHandle.right
    anchors.leftMargin: 8
    anchors.top: parent.top
    anchors.topMargin: 2
    width: 22
    height: 22
    radius: 11
    color: closeClockMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(14/255, 14/255, 20/255, 0.6)
    border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.5)
    border.width: 1
    opacity: clockGripArea.containsMouse || clockGripArea.drag.active || (rootRef && rootRef.layoutEditMode) ? 1.0 : 0.0
    visible: rootRef && rootRef.layoutEditMode
    z: 110

    Behavior on opacity {
      NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
      anchors.centerIn: parent
      text: "\uf00d"
      font.family: Style.font.family
      font.pixelSize: 10
      color: Color.urgent
    }

    MouseArea {
      id: closeClockMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (rootRef && rootRef.toggleWidgetEnabled) {
          rootRef.toggleWidgetEnabled(clockWidgetRoot.widgetId, false)
        }
      }
    }
  }

  ColumnLayout {
    id: centerClockColumn
    anchors.top: clockGripHandle.bottom
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(4)

    layer.enabled: false
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.95)
      shadowBlur: 0.9
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 4
    }

    // 👋 Greeting Line
    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: clockWidgetRoot.showGreeting
      text: clockWidgetRoot.greetingString
      font.family: Style.font.family
      font.pixelSize: 20
      font.weight: Font.DemiBold
      color: Color.accent
      opacity: 0.95
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.75)
    }

    // ⛅ Weather Status Line (Below greeting, click to toggle °F / °C)
    Item {
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: weatherRow.implicitWidth + 16
      implicitHeight: weatherRow.implicitHeight + 6
      visible: clockWidgetRoot.showWeather && (clockWidgetRoot.weatherTemp !== "" || clockWidgetRoot.weatherDesc !== "")

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: weatherHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"
        border.color: weatherHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45) : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
      }

      RowLayout {
        id: weatherRow
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          text: clockWidgetRoot.weatherIcon
          font.family: Style.font.family
          font.pixelSize: 16
          color: Color.accent
          opacity: 0.9
          style: Text.Outline
          styleColor: Qt.rgba(0, 0, 0, 0.75)
        }

        Text {
          text: clockWidgetRoot.weatherTemp ? (clockWidgetRoot.weatherTemp + (clockWidgetRoot.weatherDesc ? ("  ·  " + clockWidgetRoot.weatherDesc) : "")) : clockWidgetRoot.weatherDesc
          font.family: Style.font.family
          font.pixelSize: 15
          color: Color.foreground
          opacity: 0.85
          style: Text.Outline
          styleColor: Qt.rgba(0, 0, 0, 0.75)
        }
      }

      MouseArea {
        id: weatherHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          clockWidgetRoot.useCelsius = !clockWidgetRoot.useCelsius
          clockWidgetRoot.saveSetting("useCelsius", clockWidgetRoot.useCelsius)
        }
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: clockWidgetRoot.timeString
      font.family: Style.font.family
      font.pixelSize: 96
      font.weight: Font.Bold
      font.letterSpacing: 2
      color: Color.foreground
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.85)
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: clockWidgetRoot.dateString
      font.family: Style.font.family
      font.pixelSize: 20
      font.weight: Font.Medium
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.85)
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.75)
    }
  }

  // Full-body drag when in Edit Mode
  MouseArea {
    id: clockFullDragArea
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.top: parent.top
    anchors.topMargin: 30
    z: 100
    visible: rootRef && rootRef.layoutEditMode
    cursorShape: Qt.SizeAllCursor
    drag.target: clockWidgetRoot.targetItem
    drag.axis: Drag.XAndYAxis
    drag.minimumX: 10
    drag.maximumX: Math.max(10, clockWidgetRoot.screenWidth - clockWidgetRoot.width - 10)
    drag.minimumY: 10
    drag.maximumY: Math.max(10, clockWidgetRoot.screenHeight - clockWidgetRoot.height - 10)

    onPressed: function(mouse) {
      if (mouse.y <= 30) {
        mouse.accepted = false
        return
      }
    }

    onReleased: function() {
      var maxX = Math.max(10, clockWidgetRoot.screenWidth - clockWidgetRoot.width - 10)
      var maxY = Math.max(10, clockWidgetRoot.screenHeight - clockWidgetRoot.height - 10)
      var snappedX = Math.round(clockWidgetRoot.targetItem.x / 20) * 20
      var snappedY = Math.round(clockWidgetRoot.targetItem.y / 20) * 20
      snappedX = Math.max(10, Math.min(maxX, snappedX))
      snappedY = Math.max(10, Math.min(maxY, snappedY))
      clockWidgetRoot.targetItem.x = snappedX
      clockWidgetRoot.targetItem.y = snappedY
      if (rootRef && rootRef.saveWidgetPos) {
        rootRef.saveWidgetPos(clockWidgetRoot.widgetId, snappedX, snappedY)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📂 Standard Right-Click Context Menu
  // ---------------------------------------------------------------------------
  property bool contextMenuOpen: false

  // Right-click handler on the clock body (only when NOT in edit mode)
  MouseArea {
    anchors.fill: parent
    z: 50
    visible: !(rootRef && rootRef.layoutEditMode)
    acceptedButtons: Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        clockWidgetRoot.contextMenuOpen = !clockWidgetRoot.contextMenuOpen
      }
    }
  }

  // Close menu when widget starts being dragged
  onIsDraggingChanged: {
    if (isDragging && contextMenuOpen) {
      contextMenuOpen = false
    }
  }

  // Click-outside dismissal backdrop
  MouseArea {
    id: clockMenuDismissBackdrop
    parent: clockWidgetRoot.loaderItem ? clockWidgetRoot.loaderItem.parent : clockWidgetRoot
    anchors.fill: parent
    z: 999
    visible: clockWidgetRoot.contextMenuOpen
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: clockWidgetRoot.contextMenuOpen = false
  }

  // Floating context menu - reparented to widgetContainer canvas
  Rectangle {
    id: clockContextMenu
    parent: clockWidgetRoot.loaderItem ? clockWidgetRoot.loaderItem.parent : clockWidgetRoot
    z: 1000

    readonly property var widgetTarget: clockWidgetRoot.loaderItem ? clockWidgetRoot.loaderItem : clockWidgetRoot
    readonly property real menuWidth: 300
    readonly property real menuHeight: clockMenuLayout.implicitHeight + 20

    x: Math.max(10, Math.min(widgetTarget.x + (clockWidgetRoot.width - menuWidth) / 2, clockWidgetRoot.screenWidth - menuWidth - 10))
    y: {
      var desiredY = widgetTarget.y + 36
      if (desiredY + menuHeight > clockWidgetRoot.screenHeight - 10) {
        desiredY = widgetTarget.y + clockWidgetRoot.height - menuHeight - 36
      }
      return Math.max(10, Math.min(desiredY, clockWidgetRoot.screenHeight - menuHeight - 10))
    }
    width: menuWidth
    height: menuHeight

    radius: 14
    color: Qt.rgba(14/255, 14/255, 20/255, 0.96)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
    border.width: 1.5

    opacity: clockWidgetRoot.contextMenuOpen ? 1.0 : 0.0
    scale: clockWidgetRoot.contextMenuOpen ? 1.0 : 0.94
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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
      id: clockMenuLayout
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(3)

      // Menu Header
      RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Style.space(4)

        Text {
          text: "\uf017"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.accent
        }

        Text {
          text: "Clock & Weather Options"
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.Bold
          color: Color.foreground
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: clockCloseMenuMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.foreground
          }

          MouseArea {
            id: clockCloseMenuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.bottomMargin: 3
      }

      // 🕒 Clock & Weather Custom Options Header
      Text {
        text: "DISPLAY PREFERENCES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // 12h / 24h Toggle Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: clkFormatMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf017"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Time Format"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
          Rectangle {
            implicitWidth: fmtLabel.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
            Text {
              id: fmtLabel
              anchors.centerIn: parent
              text: clockWidgetRoot.is24Hour ? "24-Hour" : "12-Hour"
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Color.accent
            }
          }
        }
        MouseArea {
          id: clkFormatMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            clockWidgetRoot.is24Hour = !clockWidgetRoot.is24Hour
            clockWidgetRoot.saveSetting("is24Hour", clockWidgetRoot.is24Hour)
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Seconds Toggle Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: secMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf2f2"
            font.family: Style.font.family
            font.pixelSize: 11
            color: clockWidgetRoot.showSeconds ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
          Text {
            Layout.fillWidth: true
            text: "Show Seconds (:SS)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
          Text {
            text: clockWidgetRoot.showSeconds ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: clockWidgetRoot.showSeconds ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }
        MouseArea {
          id: secMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            clockWidgetRoot.showSeconds = !clockWidgetRoot.showSeconds
            clockWidgetRoot.saveSetting("showSeconds", clockWidgetRoot.showSeconds)
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Compact Date Toggle Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: dateFmtMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf073"
            font.family: Style.font.family
            font.pixelSize: 11
            color: clockWidgetRoot.compactDate ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
          Text {
            Layout.fillWidth: true
            text: "Compact Date Format"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
          Text {
            text: clockWidgetRoot.compactDate ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: clockWidgetRoot.compactDate ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }
        MouseArea {
          id: dateFmtMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            clockWidgetRoot.compactDate = !clockWidgetRoot.compactDate
            clockWidgetRoot.saveSetting("compactDate", clockWidgetRoot.compactDate)
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Weather Toggle Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: weaMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf185"
            font.family: Style.font.family
            font.pixelSize: 11
            color: clockWidgetRoot.showWeather ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
          Text {
            Layout.fillWidth: true
            text: "Show Weather Status"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
          Text {
            text: clockWidgetRoot.showWeather ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: clockWidgetRoot.showWeather ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }
        MouseArea {
          id: weaMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            clockWidgetRoot.showWeather = !clockWidgetRoot.showWeather
            clockWidgetRoot.saveSetting("showWeather", clockWidgetRoot.showWeather)
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Temperature Scale Row (°F / °C)
      Rectangle {
        visible: clockWidgetRoot.showWeather
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: tempUnitMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: clockWidgetRoot.useCelsius ? "\uf2c9" : "\uf2c7"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Temperature Scale"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
          Rectangle {
            implicitWidth: tempUnitLabel.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
            Text {
              id: tempUnitLabel
              anchors.centerIn: parent
              text: clockWidgetRoot.useCelsius ? "Celsius (°C)" : "Fahrenheit (°F)"
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Color.accent
            }
          }
        }
        MouseArea {
          id: tempUnitMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            clockWidgetRoot.useCelsius = !clockWidgetRoot.useCelsius
            clockWidgetRoot.saveSetting("useCelsius", clockWidgetRoot.useCelsius)
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Greeting Toggle Row
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: greetMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf086"
            font.family: Style.font.family
            font.pixelSize: 11
            color: clockWidgetRoot.showGreeting ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
          Text {
            Layout.fillWidth: true
            text: "Show Greeting Message"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
          Text {
            text: clockWidgetRoot.showGreeting ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: clockWidgetRoot.showGreeting ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }
        MouseArea {
          id: greetMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            clockWidgetRoot.showGreeting = !clockWidgetRoot.showGreeting
            clockWidgetRoot.saveSetting("showGreeting", clockWidgetRoot.showGreeting)
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Refresh Weather Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refWeaMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

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
            text: "Refresh Weather"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
        MouseArea {
          id: refWeaMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!weatherProc.running) weatherProc.running = true
            clockWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.topMargin: 3
        Layout.bottomMargin: 3
      }

      // Options List
      Repeater {
        model: [
          { label: (rootRef && rootRef.layoutEditMode) ? "Lock Layout" : "Unlock Layout", icon: (rootRef && rootRef.layoutEditMode) ? "\uf023" : "\uf0b2", value: "TOGGLE_EDIT_MODE" },
          { label: "Add / Browse Widgets", icon: "\uf067", value: "OPEN_SELECTOR" },
          { label: "Widget Preferences...", icon: "\uf013", value: "OPEN_PREFERENCES" },
          { label: "Save Current Layout", icon: "\uf0c7", value: "SAVE_LAYOUT" },
          { label: (rootRef && rootRef.hasSavedLayout) ? "Revert to Saved Layout" : "Reset Widget Layout", icon: "\uf0e2", value: "RESET_LAYOUT" }
        ]

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          color: clockOptMouse.containsMouse ? (modelData.value === "RESET_LAYOUT" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Item {
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              Layout.alignment: Qt.AlignVCenter

              Text {
                anchors.centerIn: parent
                text: modelData.icon
                font.family: Style.font.family
                font.pixelSize: 11
                color: modelData.value === "RESET_LAYOUT" ? (clockOptMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)) : Color.accent
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: modelData.value === "RESET_LAYOUT" ? (clockOptMouse.containsMouse ? Color.urgent : Color.foreground) : Color.accent
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: clockOptMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              clockWidgetRoot.contextMenuOpen = false
              if (modelData.value === "TOGGLE_EDIT_MODE") {
                if (rootRef) rootRef.layoutEditMode = !rootRef.layoutEditMode
              } else if (modelData.value === "OPEN_SELECTOR") {
                if (rootRef) rootRef.selectorOpen = true
              } else if (modelData.value === "OPEN_PREFERENCES") {
                if (rootRef) rootRef.preferencesOpen = true
              } else if (modelData.value === "SAVE_LAYOUT") {
                if (rootRef && rootRef.saveCurrentLayout) rootRef.saveCurrentLayout()
              } else if (modelData.value === "RESET_LAYOUT") {
                if (rootRef) rootRef.resetWidgetPositions()
              }
            }
          }
        }
      }
    }
  }
}
