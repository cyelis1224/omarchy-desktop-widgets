import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

WidgetCard {
  id: launcherWidgetRoot

  widgetId: "app_launcher"
  title: "App Launcher"
  icon: "\uf108"
  showHeader: false

  defaultX: 1140
  defaultY: 140

  width: 380
  height: 420
  minWidth: 280
  minHeight: 280
  maxWidth: 800
  maxHeight: 750

  property string searchQuery: ""
  property string selectedCategory: "All"
  property var allApps: []
  property bool isLoading: false

  readonly property bool hasInputFocus: (typeof searchInput !== "undefined" && searchInput && searchInput.activeFocus)

  onHasInputFocusChanged: {
    if (rootRef && "keyboardFocusRequested" in rootRef) {
      rootRef.keyboardFocusRequested = hasInputFocus
    }
  }

  Connections {
    target: (rootRef && "keyboardFocusRequested" in rootRef) ? rootRef : null
    ignoreUnknownSignals: true
    function onKeyboardFocusRequestedChanged() {
      if (rootRef && !rootRef.keyboardFocusRequested) {
        if (typeof searchInput !== "undefined" && searchInput && searchInput.activeFocus) searchInput.focus = false
      }
    }
  }

  Component.onDestruction: {
    if (rootRef && "keyboardFocusRequested" in rootRef && rootRef.keyboardFocusRequested) {
      rootRef.keyboardFocusRequested = false
    }
  }

  function applySavedSettings() {
    var cat = getSetting("selectedCategory", undefined)
    if (cat !== undefined && typeof cat === "string") {
      selectedCategory = cat
    }
  }

  onSettingsLoaded: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    loadApps()
  }

  readonly property string appsScriptPath: {
    var u = Qt.resolvedUrl("../get-apps.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function loadApps() {
    if (appsProc.running) return
    isLoading = true
    appsProc.running = true
  }

  function launchApp(execCommand) {
    if (!execCommand) return
    Quickshell.execDetached([launcherWidgetRoot.appsScriptPath, "launch", execCommand])
    // Drop keyboard focus so the desktop layer falls back below the new window
    if (typeof searchInput !== "undefined" && searchInput) searchInput.focus = false
    if (rootRef && "keyboardFocusRequested" in rootRef) {
      rootRef.keyboardFocusRequested = false
    }
  }

  function getCategoryIcon(cat) {
    switch (cat) {
      case "Internet": return "\uf0ac"
      case "Dev": return "\uf121"
      case "Media": return "\uf001"
      case "System": return "\uf2db"
      case "Utilities": return "\uf0ad"
      case "Games": return "\uf11b"
      default: return "\uf108"
    }
  }

  Process {
    id: appsProc
    command: [launcherWidgetRoot.appsScriptPath]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (Array.isArray(data)) {
            launcherWidgetRoot.allApps = data
          }
        } catch (e) {
          console.warn("[AppLauncherWidget] Parse error:", e)
        }
        launcherWidgetRoot.isLoading = false
      }
    }
    onExited: {
      launcherWidgetRoot.isLoading = false
    }
  }

  readonly property var filteredApps: {
    var list = launcherWidgetRoot.allApps
    if (!list || list.length === 0) return []
    var query = launcherWidgetRoot.searchQuery.trim().toLowerCase()
    var cat = launcherWidgetRoot.selectedCategory

    var result = []
    for (var i = 0; i < list.length; i++) {
      var app = list[i]
      if (cat !== "All" && app.category !== cat) {
        continue
      }
      if (query !== "") {
        var nameMatch = app.name && app.name.toLowerCase().indexOf(query) !== -1
        var commentMatch = app.comment && app.comment.toLowerCase().indexOf(query) !== -1
        var execMatch = app.exec && app.exec.toLowerCase().indexOf(query) !== -1
        if (!nameMatch && !commentMatch && !execMatch) {
          continue
        }
      }
      result.push(app)
    }
    return result
  }

  // ---------------------------------------------------------------------------
  // 🎛️ Custom Context Menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 280
      spacing: Style.space(4)

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: reloadOptMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf021"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Reload Installed Applications"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: reloadOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            launcherWidgetRoot.contextMenuOpen = false
            launcherWidgetRoot.loadApps()
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: clearSearchOptMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : "transparent"
        visible: launcherWidgetRoot.searchQuery !== ""

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.urgent
          }

          Text {
            Layout.fillWidth: true
            text: "Clear Search Filter"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: clearSearchOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            launcherWidgetRoot.contextMenuOpen = false
            searchInput.text = ""
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🚀 Main Widget Content
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(14)
    spacing: Style.space(10)

    // Top Row: Search Input Box + App Count Pill
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      // Search Field Surface
      Rectangle {
        Layout.fillWidth: true
        height: 34
        radius: 17
        color: launcherWidgetRoot.fgTint(0.07)
        border.color: searchInput.activeFocus ? Commons.Color.accent : launcherWidgetRoot.fgTint(0.12)
        border.width: 1

        MouseArea {
          anchors.fill: parent
          z: -1
          cursorShape: Qt.IBeamCursor
          onClicked: {
            if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
            searchInput.forceActiveFocus()
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf002"
            font.family: Style.font.family
            font.pixelSize: 12
            color: searchInput.activeFocus ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
          }

          TextInput {
            id: searchInput
            Layout.fillWidth: true
            font.family: Style.font.family
            font.pixelSize: 12
            color: Commons.Color.foreground
            clip: true
            selectByMouse: true
            text: launcherWidgetRoot.searchQuery
            onTextChanged: launcherWidgetRoot.searchQuery = text
            onAccepted: {
              if (launcherWidgetRoot.filteredApps.length > 0) {
                launcherWidgetRoot.launchApp(launcherWidgetRoot.filteredApps[0].exec)
              }
            }

            // Escape clears the query first; with an empty query it falls
            // through to the window-level Escape shortcut, which drops focus
            Keys.onShortcutOverride: function(event) {
              event.accepted = (event.key === Qt.Key_Escape && searchInput.text !== "")
            }
            Keys.onEscapePressed: function(event) {
              searchInput.text = ""
              event.accepted = true
            }

            Text {
              anchors.fill: parent
              visible: !searchInput.text && !searchInput.activeFocus
              text: "Search applications..."
              font.family: Style.font.family
              font.pixelSize: 12
              color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.35)
            }
          }

          // Clear Button
          Rectangle {
            visible: searchInput.text !== ""
            width: 20
            height: 20
            radius: 10
            color: clearHover.containsMouse ? launcherWidgetRoot.fgTint(0.2) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "\uf00d"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
            }

            MouseArea {
              id: clearHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: searchInput.text = ""
            }
          }
        }
      }

      // App count badge
      Rectangle {
        height: 26
        implicitWidth: countText.implicitWidth + 16
        radius: 13
        color: launcherWidgetRoot.fgTint(0.05)
        border.color: launcherWidgetRoot.fgTint(0.08)
        border.width: 1

        Text {
          id: countText
          anchors.centerIn: parent
          text: launcherWidgetRoot.filteredApps.length + " apps"
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.DemiBold
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
        }
      }

      // Remove / Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeAppMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35) : launcherWidgetRoot.fgTint(0.08)
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
          id: closeAppMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(launcherWidgetRoot.widgetId, false, launcherWidgetRoot.monitorName)
            }
          }
        }
      }

      // Move Grip Button (when in edit mode)
      Rectangle {
        id: appGripButton
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: appGripArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : launcherWidgetRoot.fgTint(0.08)
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
          id: appGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: launcherWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, launcherWidgetRoot.screenWidth - launcherWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, launcherWidgetRoot.screenHeight - launcherWidgetRoot.height - 10)

          onPressed: launcherWidgetRoot.customGripDragging = true
          onReleased: function() {
            launcherWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, launcherWidgetRoot.screenWidth - launcherWidgetRoot.width - 10)
            var maxY = Math.max(10, launcherWidgetRoot.screenHeight - launcherWidgetRoot.height - 10)
            var snappedX = launcherWidgetRoot.snapVal(launcherWidgetRoot.targetItem.x)
            var snappedY = launcherWidgetRoot.snapVal(launcherWidgetRoot.targetItem.y)
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            launcherWidgetRoot.targetItem.x = snappedX
            launcherWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(launcherWidgetRoot.widgetId, snappedX, snappedY, launcherWidgetRoot.snapVal(launcherWidgetRoot.width), launcherWidgetRoot.snapVal(launcherWidgetRoot.height), launcherWidgetRoot.monitorName)
            }
          }
          onCanceled: launcherWidgetRoot.customGripDragging = false
        }
      }
    }

    // Category Tabs Strip
    Flickable {
      Layout.fillWidth: true
      height: 28
      contentWidth: catRow.implicitWidth
      contentHeight: 28
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      RowLayout {
        id: catRow
        spacing: Style.space(6)

        Repeater {
          model: [
            { name: "All", icon: "\uf009" },
            { name: "Internet", icon: "\uf0ac" },
            { name: "Dev", icon: "\uf121" },
            { name: "Media", icon: "\uf001" },
            { name: "System", icon: "\uf2db" },
            { name: "Utilities", icon: "\uf0ad" },
            { name: "Games", icon: "\uf11b" }
          ]

          Rectangle {
            required property var modelData
            implicitWidth: catItemRow.implicitWidth + 18
            height: 26
            radius: 13
            readonly property bool isSelected: launcherWidgetRoot.selectedCategory === modelData.name
            color: isSelected ? Commons.Color.accent : (catItemHover.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : launcherWidgetRoot.fgTint(0.06))
            border.color: isSelected ? launcherWidgetRoot.bgTint(0.25) : launcherWidgetRoot.fgTint(0.08)
            border.width: 1

            RowLayout {
              id: catItemRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: modelData.icon
                font.family: Style.font.family
                font.pixelSize: 10
                color: isSelected ? Commons.Color.background : Commons.Color.accent
              }

              Text {
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: isSelected ? Font.Bold : Font.Normal
                color: isSelected ? Commons.Color.background : Commons.Color.foreground
              }
            }

            MouseArea {
              id: catItemHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                launcherWidgetRoot.selectedCategory = modelData.name
                launcherWidgetRoot.saveSetting("selectedCategory", modelData.name)
              }
            }
          }
        }
      }
    }

    // Grid of Applications
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Empty State
      ColumnLayout {
        anchors.centerIn: parent
        visible: launcherWidgetRoot.filteredApps.length === 0 && !launcherWidgetRoot.isLoading
        spacing: Style.space(8)

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "\uf002"
          font.family: Style.font.family
          font.pixelSize: 32
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: launcherWidgetRoot.searchQuery !== "" ? "No applications found" : "No applications"
          font.family: Style.font.family
          font.pixelSize: 12
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
        }
      }

      GridView {
        id: appGridView
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        readonly property int cols: Math.max(3, Math.floor(width / 86))
        cellWidth: Math.floor(width / cols)
        cellHeight: 88

        model: launcherWidgetRoot.filteredApps

        delegate: Rectangle {
          id: appTile
          required property var modelData
          width: appGridView.cellWidth
          height: appGridView.cellHeight
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 12
            color: appMouse.containsMouse ? launcherWidgetRoot.fgTint(0.12) : launcherWidgetRoot.fgTint(0.03)
            border.color: appMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4) : "transparent"
            border.width: 1
            scale: appMouse.pressed ? 0.95 : (appMouse.containsMouse ? 1.04 : 1.0)

            Behavior on scale {
              NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on color {
              ColorAnimation { duration: 150 }
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 6
              spacing: 4

              // App Icon with Fallback Glyph
              Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                Image {
                  id: appIconImage
                  anchors.fill: parent
                  source: (modelData.icon && modelData.icon.startsWith("/")) ? ("file://" + modelData.icon) : (modelData.icon ? Quickshell.iconPath(modelData.icon, true) : "")
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  smooth: true
                }

                Text {
                  visible: appIconImage.status !== Image.Ready
                  anchors.centerIn: parent
                  text: launcherWidgetRoot.getCategoryIcon(modelData.category)
                  font.family: Style.font.family
                  font.pixelSize: 22
                  color: Commons.Color.accent
                }
              }

              // App Name
              Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: modelData.name || "App"
                font.family: Style.font.family
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: appMouse.containsMouse ? Commons.Color.accent : Commons.Color.foreground
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
              }
            }

            MouseArea {
              id: appMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                launcherWidgetRoot.launchApp(modelData.exec)
              }
            }
          }
        }
      }
    }
  }
}
