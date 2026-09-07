import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetCard {
  id: systemWidgetRoot

  widgetId: "system"
  title: "System Resources"
  icon: "\uf2db"
  showHeader: false
  defaultX: screenWidth - width - Style.space(24)
  defaultY: screenHeight - height - Style.space(28)

  width: 360
  height: sysCardLayout.implicitHeight + Style.space(36)
  minWidth: 300
  minHeight: 200

  // ---------------------------------------------------------------------------
  // RAM Usage State (/proc/meminfo)
  // ---------------------------------------------------------------------------
  property real memTotalGB: 0
  property real memUsedGB: 0
  property real memUsedPct: 0

  FileView {
    id: memInfoFile
    path: "/proc/meminfo"
    watchChanges: true
    onLoaded: {
      var lines = text().split("\n")
      var total = 0
      var avail = 0
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        if (l.indexOf("MemTotal:") === 0) {
          total = parseInt(l.replace(/[^0-9]/g, ""))
        } else if (l.indexOf("MemAvailable:") === 0) {
          avail = parseInt(l.replace(/[^0-9]/g, ""))
        }
      }
      if (total > 0) {
        var used = total - avail
        systemWidgetRoot.memTotalGB = Math.round((total / 1024 / 1024) * 10) / 10
        systemWidgetRoot.memUsedGB = Math.round((used / 1024 / 1024) * 10) / 10
        systemWidgetRoot.memUsedPct = used / total
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: memInfoFile.reload()
  }

  property var diskList: []
  property var disabledMounts: []
  property bool compactMemory: false

  function applySavedSettings() {
    if (!rootRef || !rootRef.widgetSettings) return
    var s = rootRef.widgetSettings[widgetId]
    if (!s) return
    if (Array.isArray(s.disabledMounts)) disabledMounts = s.disabledMounts
    if (s.compactMemory !== undefined) compactMemory = s.compactMemory
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  readonly property var visibleDisks: {
    var list = []
    for (var i = 0; i < diskList.length; i++) {
      var d = diskList[i]
      if (disabledMounts.indexOf(d.mount) === -1) {
        list.push(d)
      }
    }
    return list
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "MONITORED STORAGE DRIVES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      Repeater {
        model: systemWidgetRoot.diskList

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          readonly property bool isMonitored: systemWidgetRoot.disabledMounts.indexOf(modelData.mount) === -1
          color: diskMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

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
              Layout.fillWidth: true
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              color: isMonitored ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
              elide: Text.ElideRight
            }

            Text {
              text: modelData.size || ""
              font.family: Style.font.family
              font.pixelSize: 10
              color: isMonitored ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
            }
          }

          MouseArea {
            id: diskMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var list = systemWidgetRoot.disabledMounts.slice()
              var idx = list.indexOf(modelData.mount)
              if (idx === -1) {
                list.push(modelData.mount)
              } else {
                list.splice(idx, 1)
              }
              systemWidgetRoot.disabledMounts = list
              systemWidgetRoot.saveSetting("disabledMounts", list)
              systemWidgetRoot.contextMenuOpen = false
            }
          }
        }
      }

      Text {
        text: "MEMORY & POLLING"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Compact Memory Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: memFmtMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf538"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Compact Memory (Pct Only)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: systemWidgetRoot.compactMemory ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: systemWidgetRoot.compactMemory ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: memFmtMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            systemWidgetRoot.compactMemory = !systemWidgetRoot.compactMemory
            systemWidgetRoot.saveSetting("compactMemory", systemWidgetRoot.compactMemory)
            systemWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Refresh Disks Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refDisksMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

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
            text: "Refresh Storage Disks"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: refDisksMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!disksProc.running) disksProc.running = true
            systemWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Open Task Manager (btop) Action Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: btopMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

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
            text: "Open Task Manager (btop)"
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
          id: btopMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            systemWidgetRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-terminal-exec", "btop"])
          }
        }
      }
    }
  }

  readonly property string disksScriptPath: {
    var u = Qt.resolvedUrl("../get-disks.sh").toString()
    if (u.indexOf("file://") === 0) return u.substring(7)
    return "/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/get-disks.sh"
  }

  Process {
    id: disksProc
    command: [systemWidgetRoot.disksScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (Array.isArray(data)) {
            systemWidgetRoot.diskList = data
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: {
      if (!disksProc.running) disksProc.running = true
    }
  }

  ColumnLayout {
    id: sysCardLayout
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
        text: "\uf2db"
        font.family: Style.font.family
        font.pixelSize: 15
        color: Color.accent
      }

      Text {
        text: "System Resources"
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
        color: Color.accent
      }

      Text {
        text: "Live"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
      }

      // Close / Hide Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeSysMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeSysMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(systemWidgetRoot.widgetId, false)
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
        color: sysGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: sysGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: systemWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, systemWidgetRoot.screenWidth - systemWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, systemWidgetRoot.screenHeight - systemWidgetRoot.height - 10)

          onPressed: systemWidgetRoot.customGripDragging = true
          onReleased: function() {
            systemWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, systemWidgetRoot.screenWidth - systemWidgetRoot.width - 10)
            var maxY = Math.max(10, systemWidgetRoot.screenHeight - systemWidgetRoot.height - 10)
            var snappedX = Math.round(systemWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(systemWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            systemWidgetRoot.targetItem.x = snappedX
            systemWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(systemWidgetRoot.widgetId, snappedX, snappedY)
            }
          }
          onCanceled: systemWidgetRoot.customGripDragging = false
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Qt.rgba(1, 1, 1, 0.08)
    }

    // 🧠 RAM Usage Item
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      RowLayout {
        Layout.fillWidth: true

        Text {
          text: "Memory (RAM)"
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.Medium
          color: Color.foreground
        }

        Item { Layout.fillWidth: true }

        Text {
          text: systemWidgetRoot.compactMemory ? (Math.round(systemWidgetRoot.memUsedPct * 100) + "%") : (systemWidgetRoot.memUsedGB + " / " + systemWidgetRoot.memTotalGB + " GB (" + Math.round(systemWidgetRoot.memUsedPct * 100) + "%)")
          font.family: Style.font.family
          font.pixelSize: 11
          font.weight: Font.DemiBold
          color: Color.accent
        }
      }

      // RAM Progress Bar
      Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.08)

        Rectangle {
          width: Math.max(6, parent.width * Math.min(1.0, systemWidgetRoot.memUsedPct))
          height: parent.height
          radius: 3
          color: systemWidgetRoot.memUsedPct > 0.85 ? Color.urgent : (systemWidgetRoot.memUsedPct > 0.65 ? Qt.lighter(Color.accent, 1.25) : Color.accent)

          Behavior on width {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
          }
        }
      }
    }

    // 💽 Multi-Disk Drives Section
    Repeater {
      model: systemWidgetRoot.visibleDisks

      ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: Style.space(4)

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: modelData.label
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Color.foreground
          }

          Item { Layout.fillWidth: true }

          Text {
            text: modelData.avail + " Free (" + modelData.size + " total)"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Color.accent
          }
        }

        // Disk Progress Bar
        Rectangle {
          Layout.fillWidth: true
          height: 6
          radius: 3
          color: Qt.rgba(1, 1, 1, 0.08)

          Rectangle {
            width: Math.max(6, parent.width * Math.min(1.0, modelData.pct))
            height: parent.height
            radius: 3
            color: modelData.pct > 0.90 ? Color.urgent : Color.accent

            Behavior on width {
              NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }
  }
}
