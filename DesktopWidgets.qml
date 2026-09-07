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
  property bool overlayActive: false
  property bool keyboardFocusRequested: false
  property bool menuOpenRequested: false
  property int activeDragCount: 0
  readonly property bool isAnyWidgetDragging: activeDragCount > 0
  readonly property bool showSnapGrid: layoutEditMode || isAnyWidgetDragging

  function closeOverlay() {
    overlayActive = false
  }

  property real activeDragCenterX: -1
  property real activeDragCenterY: -1
  property real activeDragWidth: 0
  property real activeDragHeight: 0

  function updateActiveDrag(cx, cy, w, h) {
    activeDragCenterX = cx
    activeDragCenterY = cy
    activeDragWidth = w
    activeDragHeight = h
  }

  function clearActiveDrag() {
    activeDragCenterX = -1
    activeDragCenterY = -1
    activeDragWidth = 0
    activeDragHeight = 0
  }

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

  function saveWidgetPos(id, x, y, w, h) {
    var p = Object.assign({}, root.widgetPositions)
    var current = p[id] || {}
    var targetW = (w !== undefined && w > 0) ? w : (current.w || 0)
    var targetH = (h !== undefined && h > 0) ? h : (current.h || 0)

    var entry = { x: x, y: y }
    if (targetW > 0 && targetH > 0) {
      entry.w = targetW
      entry.h = targetH
      p[id] = entry
      root.widgetPositions = p
      Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "save_pos", id, x.toString(), y.toString(), targetW.toString(), targetH.toString()])
    } else {
      if (current.w) entry.w = current.w
      if (current.h) entry.h = current.h
      p[id] = entry
      root.widgetPositions = p
      Quickshell.execDetached(["/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/manage-positions.sh", "save_pos", id, x.toString(), y.toString()])
    }
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
    var ws = root.focusedWorkspace
    var hasWindows = ws && ws.toplevels && ws.toplevels.values.length > 0
    if (!hasWindows) {
      root.manualHide = false
    }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() {
      var ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
      var hasWindows = ws && ws.toplevels && ws.toplevels.values.length > 0
      if (!hasWindows) {
        root.manualHide = false
      }
    }
  }

  function handleToggleOrJump() {
    if (root.overlayActive) {
      root.closeOverlay()
      return
    }

    var currentWs = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
    var hasWindows = currentWs && currentWs.toplevels && currentWs.toplevels.values.length > 0

    if (hasWindows) {
      root.overlayActive = true
      root.manualHide = false
    } else {
      if (root.manualHide) {
        root.manualHide = false
      } else {
        root.overlayActive = true
      }
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

    function menu() {
      root.menuOpenRequested = !root.menuOpenRequested
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
        WlrLayershell.layer: root.overlayActive ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: root.overlayActive ? WlrKeyboardFocus.Exclusive : ((!desktopWindow.hasOpenWindows && (root.selectorOpen || root.keyboardFocusRequested)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

        Shortcut {
          sequence: "Escape"
          enabled: root.overlayActive
          onActivated: root.closeOverlay()
        }

        onWidthChanged: if (width > 0) root.screenWidth = width
        onHeightChanged: if (height > 0) root.screenHeight = height
        Component.onCompleted: {
          if (width > 0) root.screenWidth = width
          if (height > 0) root.screenHeight = height
        }

        readonly property bool hasOpenWindows: {
          var dummy = ToplevelManager.toplevels.values.length
          var ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
          return !!(ws && ws.toplevels && ws.toplevels.values.length > 0)
        }

        // 🌓 Shaded Transparent Overlay Backdrop
        Rectangle {
          id: shadedOverlayBackdrop
          anchors.fill: parent
          z: 0
          color: Qt.rgba(10/255, 10/255, 16/255, 0.62)
          opacity: root.overlayActive ? 1.0 : 0.0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }
        }

        // 🖱️ Desktop Background Click & Context Menu Handler
        MouseArea {
          id: desktopBgMouse
          anchors.fill: parent
          z: 0
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onDoubleClicked: function(mouse) {
            if (root.overlayActive) {
              root.closeOverlay()
              return
            }
            if (mouse.button === Qt.LeftButton) {
              Quickshell.execDetached(["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""])
            }
          }
          onClicked: function(mouse) {
            if (root.overlayActive) {
              root.closeOverlay()
              return
            }
            root.menuOpenRequested = false
            if (mouse.button === Qt.RightButton) {
              desktopContextMenu.x = Math.max(16, Math.min(mouse.x, desktopWindow.width - 256))
              desktopContextMenu.y = Math.max(16, Math.min(mouse.y, desktopWindow.height - 240))
              desktopContextMenu.isOpen = true
            } else {
              desktopContextMenu.isOpen = false
            }
          }
        }

        Item {
          id: widgetContainer
          anchors.fill: parent
          z: 1

          readonly property bool shouldShow: root.overlayActive || (!root.manualHide && !desktopWindow.hasOpenWindows)
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
          // 📐 Themed Snap Grid Layer (Visible during drag or layout edit mode)
          // -------------------------------------------------------------------
          SnapGridLayer {
            id: snapGridLayer
            z: 0
            active: root.showSnapGrid && widgetContainer.shouldShow
            highlightCenterX: root.activeDragCenterX
            highlightCenterY: root.activeDragCenterY
            highlightWidth: root.activeDragWidth
            highlightHeight: root.activeDragHeight
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
              z: 10

              property real defaultX: item && item.defaultX !== undefined ? item.defaultX : Style.space(24)
              property real defaultY: item && item.defaultY !== undefined ? item.defaultY : Style.space(64)
              property bool isDragging: item && item.isDragging ? true : false

              readonly property var savedPos: (root.widgetPositions && root.widgetPositions[modelData.id]) ? root.widgetPositions[modelData.id] : null
              readonly property real targetX: (savedPos && savedPos.x !== undefined) ? savedPos.x : defaultX
              readonly property real targetY: (savedPos && savedPos.y !== undefined) ? savedPos.y : defaultY
              readonly property real savedWidth: (savedPos && savedPos.w !== undefined) ? savedPos.w : 0
              readonly property real savedHeight: (savedPos && savedPos.h !== undefined) ? savedPos.h : 0

              onTargetXChanged: {
                if (!widgetLoader.isDragging) widgetLoader.x = targetX
              }
              onTargetYChanged: {
                if (!widgetLoader.isDragging) widgetLoader.y = targetY
              }
              onSavedWidthChanged: {
                if (savedWidth > 0 && item && item.resizable && !item.isResizing) {
                  item.width = savedWidth
                }
              }
              onSavedHeightChanged: {
                if (savedHeight > 0 && item && item.resizable && !item.isResizing) {
                  item.height = savedHeight
                }
              }

              onLoaded: {
                if (item) {
                  item.rootRef = root
                  item.widgetId = modelData.id
                  item.loaderItem = widgetLoader
                  if (savedWidth > 0 && item.resizable) {
                    item.width = savedWidth
                  }
                  if (savedHeight > 0 && item.resizable) {
                    item.height = savedHeight
                  }
                  if (!widgetLoader.isDragging) {
                    widgetLoader.x = targetX
                    widgetLoader.y = targetY
                  }
                }
              }

              onXChanged: {
                if (widgetLoader.item && (widgetLoader.item.isDragging || widgetLoader.item.isResizing)) {
                  root.updateActiveDrag(widgetLoader.x + (widgetLoader.item.width || 300) / 2, widgetLoader.y + (widgetLoader.item.height || 200) / 2, widgetLoader.item.width || 300, widgetLoader.item.height || 200)
                }
              }
              onYChanged: {
                if (widgetLoader.item && (widgetLoader.item.isDragging || widgetLoader.item.isResizing)) {
                  root.updateActiveDrag(widgetLoader.x + (widgetLoader.item.width || 300) / 2, widgetLoader.y + (widgetLoader.item.height || 200) / 2, widgetLoader.item.width || 300, widgetLoader.item.height || 200)
                }
              }

              Connections {
                target: widgetLoader.item || null
                ignoreUnknownSignals: true
                function onIsDraggingChanged() {
                  if (widgetLoader.item && widgetLoader.item.isDragging) {
                    root.activeDragCount = (root.activeDragCount || 0) + 1
                    root.updateActiveDrag(widgetLoader.x + (widgetLoader.item.width || 300) / 2, widgetLoader.y + (widgetLoader.item.height || 200) / 2, widgetLoader.item.width || 300, widgetLoader.item.height || 200)
                  } else {
                    root.activeDragCount = Math.max(0, (root.activeDragCount || 0) - 1)
                    if (root.activeDragCount === 0) root.clearActiveDrag()
                  }
                }
                function onIsResizingChanged() {
                  if (widgetLoader.item && widgetLoader.item.isResizing) {
                    root.activeDragCount = (root.activeDragCount || 0) + 1
                    root.updateActiveDrag(widgetLoader.x + (widgetLoader.item.width || 300) / 2, widgetLoader.y + (widgetLoader.item.height || 200) / 2, widgetLoader.item.width || 300, widgetLoader.item.height || 200)
                  } else {
                    root.activeDragCount = Math.max(0, (root.activeDragCount || 0) - 1)
                    if (root.activeDragCount === 0) root.clearActiveDrag()
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

          // -------------------------------------------------------------------
          // 🖥️ Desktop Background Right-Click Context Menu
          // -------------------------------------------------------------------
          MouseArea {
            anchors.fill: parent
            z: 490
            visible: desktopContextMenu.isOpen || root.menuOpenRequested
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
              desktopContextMenu.isOpen = false
              root.menuOpenRequested = false
            }
          }

          Rectangle {
            id: desktopContextMenu
            property bool isOpen: false
            visible: (isOpen || root.menuOpenRequested) && widgetContainer.shouldShow
            z: 500
            width: 240
            implicitHeight: desktopMenuCol.implicitHeight + Style.space(16)
            radius: 14
            color: Qt.rgba(18/255, 18/255, 24/255, 0.96)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
            border.width: 1.5

            layer.enabled: true
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.85)
              shadowBlur: 0.9
              shadowVerticalOffset: 6
            }

            ColumnLayout {
              id: desktopMenuCol
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(4)

              // Header
              RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 8
                Item {
                  Layout.preferredWidth: 18
                  Layout.preferredHeight: 18
                  Layout.alignment: Qt.AlignVCenter
                  Text {
                    anchors.centerIn: parent
                    text: "\uf108"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Color.accent
                  }
                }
                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  text: "Desktop Controls"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.Bold
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
              }

              // 1. Unlock / Lock Layout (Moved to top)
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: toggleLayoutMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: root.layoutEditMode ? "\uf023" : "\uf0b2"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.layoutEditMode ? "Lock Layout" : "Unlock Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: toggleLayoutMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    root.layoutEditMode = !root.layoutEditMode
                  }
                }
              }

              // 2. Add / Browse Widgets
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: addWidgetsMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: "\uf067"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Add / Browse Widgets"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: addWidgetsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    root.selectorOpen = true
                  }
                }
              }

              // 3. Reset Layout
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: resetLayoutMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.22) : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: "\uf0e2"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: resetLayoutMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Reset Widget Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: resetLayoutMouse.containsMouse ? Color.urgent : Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: resetLayoutMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    root.resetWidgetPositions()
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
              }

              // 4. Change Wallpaper
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: bgSwitchMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: "\uf03e"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Change Wallpaper"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: bgSwitchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    Quickshell.execDetached(["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""])
                  }
                }
              }

              // 5. Theme Switcher
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: themeSwitchMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      anchors.centerIn: parent
                      text: "\uf53f"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Switch Theme"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: themeSwitchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    Quickshell.execDetached(["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\""])
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
