import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.Commons
import qs.Ui
import "widgets"
import "components"

Item {
  id: root

  // ---------------------------------------------------------------------------
  // 📍 Desktop Widgets State, Positions, Registry & Persistence
  // ---------------------------------------------------------------------------
  property var widgetPositions: ({})
  property var enabledWidgets: ["clock", "gallery", "network", "media", "system"]
  property var widgetSettings: ({})
  property real screenWidth: 1920
  property real screenHeight: 1080
  property bool layoutEditMode: false
  property bool selectorOpen: false
  property bool manualHide: false

  WidgetRegistry {
    id: widgetRegistry
  }

  Process {
    id: posProc
    command: ["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "load"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.positions) root.widgetPositions = res.positions
          if (Array.isArray(res.enabled_widgets)) root.enabledWidgets = res.enabled_widgets
          if (Array.isArray(res.custom_widgets)) widgetRegistry.customWidgets = res.custom_widgets
          if (res.widget_settings) root.widgetSettings = res.widget_settings
        } catch (e) {}
      }
    }
  }

  function saveWidgetPos(id, x, y) {
    var p = Object.assign({}, root.widgetPositions)
    p[id] = { x: x, y: y }
    root.widgetPositions = p
    Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "save_pos", id, x.toString(), y.toString()])
  }

  function saveWidgetSetting(id, key, val) {
    var ws = Object.assign({}, root.widgetSettings)
    if (!ws[id]) ws[id] = {}
    ws[id][key] = val
    root.widgetSettings = ws
    Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "save_setting", id, key, JSON.stringify(val)])
  }

  function saveWidgetSettings(id, valMap) {
    var ws = Object.assign({}, root.widgetSettings)
    if (!ws[id]) ws[id] = {}
    for (var k in valMap) {
      ws[id][k] = valMap[k]
    }
    root.widgetSettings = ws
    Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "save_widget_settings", id, JSON.stringify(ws[id])])
  }

  function toggleWidgetEnabled(id, enable) {
    var list = root.enabledWidgets.slice()
    var idx = list.indexOf(id)
    if (enable && idx === -1) {
      list.push(id)
    } else if (!enable && idx !== -1) {
      list.splice(idx, 1)
    }
    root.enabledWidgets = list
    Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "toggle_widget", id, enable ? "true" : "false"])
  }

  function resetWidgetPositions() {
    root.widgetPositions = ({})
    root.enabledWidgets = ["clock", "gallery", "network", "media", "system"]
    Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "reset"])
  }

  function importCustomWidget() {
    customImportProc.command = ["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "pick_widget_dialog"]
    if (!customImportProc.running) customImportProc.running = true
  }

  Process {
    id: customImportProc
    command: ["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "pick_widget_dialog"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.status === "imported") {
            // Reload settings
            if (!posProc.running) posProc.running = true
          }
        } catch (e) {}
      }
    }
  }

  // 🔄 Automatically re-enable widgets when switching to an empty workspace
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  onFocusedWorkspaceChanged: {
    Qt.callLater(function() {
      if (ToplevelManager.activeToplevel === null) {
        root.manualHide = false
      }
    })
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() {
      if (ToplevelManager.activeToplevel === null) {
        root.manualHide = false
      }
    }
  }

  // 🔍 Smart Navigation: Jump to first empty workspace if windows are active
  function findEmptyWorkspaceId() {
    var occupied = {}
    var list = (typeof Hyprland !== "undefined" && Hyprland.workspaces) ? Hyprland.workspaces.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i].toplevels && list[i].toplevels.values.length > 0) {
        occupied[list[i].id] = true
      }
    }
    var currentId = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace.id : 1
    for (var id = 1; id <= 10; id++) {
      if (!occupied[id] && id !== currentId) {
        return id
      }
    }
    return 10
  }

  function handleToggleOrJump() {
    var currentWs = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
    var hasWindows = currentWs && currentWs.toplevels && currentWs.toplevels.values.length > 0

    if (hasWindows) {
      var target = root.findEmptyWorkspaceId()
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + target + "\" })"])
      root.manualHide = false
    } else {
      root.manualHide = !root.manualHide
    }
  }

  // 📡 IPC Handler for toggling widgets or opening selector
  IpcHandler {
    target: "dagyr.desktop-widgets"

    function toggle() {
      root.handleToggleOrJump()
    }

    function edit() {
      root.layoutEditMode = !root.layoutEditMode
    }

    function selector() {
      root.selectorOpen = !root.selectorOpen
    }

    function reset() {
      root.resetWidgetPositions()
    }
  }

  // ---------------------------------------------------------------------------
  // 🖥️ Desktop Layer Shell Canvas Window
  // ---------------------------------------------------------------------------
  Variants {
    model: Quickshell.screens

    delegate: Component {
      id: screenDelegate

      PanelWindow {
        id: desktopWindow
        required property var modelData
        screen: modelData

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-desktop-widgets"
        WlrLayershell.layer: WlrLayer.Bottom

        onWidthChanged: if (width > 0) root.screenWidth = width
        onHeightChanged: if (height > 0) root.screenHeight = height
        Component.onCompleted: {
          if (width > 0) root.screenWidth = width
          if (height > 0) root.screenHeight = height
        }

        readonly property bool hasOpenWindows: ToplevelManager.activeToplevel !== null

        // 🖱️ Double-click anywhere on empty wallpaper to open background switcher
        MouseArea {
          anchors.fill: parent
          z: 0
          acceptedButtons: Qt.LeftButton
          onDoubleClicked: function(mouse) {
            Quickshell.execDetached(["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""])
          }
        }

        Item {
          id: widgetContainer
          anchors.fill: parent
          z: 1

          readonly property bool shouldShow: !root.manualHide && !desktopWindow.hasOpenWindows
          opacity: shouldShow ? 1.0 : 0.0
          scale: shouldShow ? 1.0 : 0.96
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
          }
          Behavior on scale {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
          }

          // -------------------------------------------------------------------
          // 🎨 Top Floating Banner when Layout Edit / Move Mode is Active
          // -------------------------------------------------------------------
          Rectangle {
            anchors.top: parent.top
            anchors.topMargin: Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            z: 300
            visible: root.layoutEditMode
            implicitWidth: editBannerRow.implicitWidth + Style.space(32)
            implicitHeight: 42
            radius: 21
            color: Qt.rgba(14/255, 14/255, 20/255, 0.96)
            border.color: Color.accent
            border.width: 1.5

            layer.enabled: true
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.8)
              shadowBlur: 0.8
              shadowVerticalOffset: 4
            }

            RowLayout {
              id: editBannerRow
              anchors.centerIn: parent
              spacing: Style.space(14)

              Text {
                text: "\uf0b2"
                font.family: Style.font.family
                font.pixelSize: 14
                color: Color.accent
              }

              Text {
                text: "Layout Move Mode Active · Drag any widget to place"
                font.family: Style.font.family
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Color.foreground
              }

              // ➕ Add Widget Button (Opens Selector)
              Rectangle {
                implicitWidth: addBtnText.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                color: addMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.1)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
                border.width: 1

                RowLayout {
                  id: addBtnText
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: "\uf067"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Color.accent
                  }
                  Text {
                    text: "Add Widgets"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Color.foreground
                  }
                }

                MouseArea {
                  id: addMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectorOpen = true
                }
              }

              // Done / Lock Button
              Rectangle {
                implicitWidth: doneBtnText.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                color: doneMouse.containsMouse ? Qt.lighter(Color.accent, 1.15) : Color.accent

                Text {
                  id: doneBtnText
                  anchors.centerIn: parent
                  text: "Done / Lock"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.Bold
                  color: Color.background
                }

                MouseArea {
                  id: doneMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.layoutEditMode = false
                }
              }
            }
          }

          // -------------------------------------------------------------------
          // 📦 Dynamic Desktop Widgets Instantiation via Registry
          // -------------------------------------------------------------------
          Repeater {
            model: widgetRegistry.allWidgets

            Loader {
              id: widgetLoader
              required property var modelData
              active: root.enabledWidgets.indexOf(modelData.id) !== -1
              source: modelData.componentUrl

              property real defaultX: item && item.defaultX !== undefined ? item.defaultX : Style.space(24)
              property real defaultY: item && item.defaultY !== undefined ? item.defaultY : Style.space(64)
              property bool isDragging: item && item.isDragging ? true : false

              readonly property var savedPos: (root.widgetPositions && root.widgetPositions[modelData.id]) ? root.widgetPositions[modelData.id] : null
              readonly property real targetX: (savedPos && savedPos.x !== undefined) ? savedPos.x : defaultX
              readonly property real targetY: (savedPos && savedPos.y !== undefined) ? savedPos.y : defaultY

              onTargetXChanged: {
                if (!widgetLoader.isDragging) widgetLoader.x = targetX
              }
              onTargetYChanged: {
                if (!widgetLoader.isDragging) widgetLoader.y = targetY
              }

              onLoaded: {
                if (item) {
                  item.rootRef = root
                  item.widgetId = modelData.id
                  item.loaderItem = widgetLoader
                  if (!widgetLoader.isDragging) {
                    widgetLoader.x = targetX
                    widgetLoader.y = targetY
                  }
                }
              }

              Behavior on x {
                enabled: !widgetLoader.isDragging
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
              }
              Behavior on y {
                enabled: !widgetLoader.isDragging
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
              }
            }
          }

          // -------------------------------------------------------------------
          // 📂 Widget Selector / Marketplace Drawer
          // -------------------------------------------------------------------
          WidgetSelector {
            id: widgetSelector
            rootRef: root
            registry: widgetRegistry
          }
        }
      }
    }
  }
}
