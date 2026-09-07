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
  // 📍 Desktop Widgets State, Positions, Profiles, Registry & Persistence
  // ---------------------------------------------------------------------------
  property var widgetPositions: ({})
  property var enabledWidgets: ["clock", "gallery", "network", "media", "system"]
  property var widgetSettings: ({})
  property real screenWidth: 1920
  property real screenHeight: 1080
  property bool layoutEditMode: false
  property bool selectorOpen: false
  property bool preferencesOpen: false
  property bool presetsSubmenuOpen: false
  property bool manualHide: false
  property bool overlayActive: false
  property bool keyboardFocusRequested: false
  property bool menuOpenRequested: false
  property int activeDragCount: 0
  readonly property bool isAnyWidgetDragging: activeDragCount > 0
  readonly property bool showSnapGrid: layoutEditMode || isAnyWidgetDragging

  // Multi-Profile Layouts & Appearance State
  property string activeProfile: "Default"
  property var layoutProfiles: []
  property var appearance: ({
    bg_opacity: 0.85,
    corner_radius: 18,
    grid_snap: 20,
    auto_hide_mode: "tiled",
    shadows_enabled: true,
    animations_enabled: true,
    blur_enabled: false,
    screensaver_enabled: false,
    screensaver_timeout_mins: 5
  })
  property int preferencesTab: 0
  property bool surfaceRemapActive: true

  Timer {
    id: remapDelayTimer
    interval: 120
    repeat: false
    onTriggered: root.remapLayerSurface()
  }

  Timer {
    id: remapTimer
    interval: 60
    repeat: false
    onTriggered: root.surfaceRemapActive = true
  }

  function remapLayerSurface() {
    root.surfaceRemapActive = false
    remapTimer.restart()
  }
  property var monitorPositions: ({})
  property string profileNoticeText: ""
  property bool profileNoticeVisible: false

  Timer {
    id: profileNoticeTimer
    interval: 2500
    repeat: false
    onTriggered: root.profileNoticeVisible = false
  }

  function showProfileNotice(txt) {
    root.profileNoticeText = txt
    root.profileNoticeVisible = true
    profileNoticeTimer.restart()
  }

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

  readonly property string manageScriptPath: Qt.resolvedUrl("manage-positions.sh").toString().replace(/^file:\/\//, "")

  property bool hasSavedLayout: false
  property bool layoutSavedFeedback: false

  Timer {
    id: savedFeedbackTimer
    interval: 2200
    repeat: false
    onTriggered: root.layoutSavedFeedback = false
  }

  Process {
    id: posProc
    command: [root.manageScriptPath, "load"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.positions) root.widgetPositions = res.positions
          if (Array.isArray(res.enabled_widgets)) root.enabledWidgets = res.enabled_widgets
          if (Array.isArray(res.custom_widgets)) widgetRegistry.customWidgets = res.custom_widgets
          if (res.widget_settings) root.widgetSettings = res.widget_settings
          if (res.has_saved_layout !== undefined) root.hasSavedLayout = res.has_saved_layout
          if (res.active_profile) root.activeProfile = res.active_profile
          if (Array.isArray(res.profiles)) root.layoutProfiles = res.profiles
          if (res.appearance) root.appearance = res.appearance
          if (res.monitor_positions) root.monitorPositions = res.monitor_positions
        } catch (e) {}
      }
    }
  }

  function saveWidgetPos(id, x, y, w, h, monitorName) {
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
      if (monitorName) {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString(), targetW.toString(), targetH.toString(), monitorName])
      } else {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString(), targetW.toString(), targetH.toString()])
      }
    } else {
      if (current.w) entry.w = current.w
      if (current.h) entry.h = current.h
      p[id] = entry
      root.widgetPositions = p
      if (monitorName) {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString(), monitorName])
      } else {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString()])
      }
    }
  }

  function saveWidgetSetting(id, key, val) {
    var ws = Object.assign({}, root.widgetSettings)
    if (!ws[id]) ws[id] = {}
    ws[id][key] = val
    root.widgetSettings = ws
    Quickshell.execDetached([root.manageScriptPath, "save_setting", id, key, JSON.stringify(val)])
  }

  function saveWidgetSettings(id, valMap) {
    var ws = Object.assign({}, root.widgetSettings)
    if (!ws[id]) ws[id] = {}
    for (var k in valMap) {
      ws[id][k] = valMap[k]
    }
    root.widgetSettings = ws
    Quickshell.execDetached([root.manageScriptPath, "save_widget_settings", id, JSON.stringify(ws[id])])
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
    Quickshell.execDetached([root.manageScriptPath, "toggle_widget", id, enable ? "true" : "false"])
  }

  function saveCurrentLayout() {
    root.layoutSavedFeedback = true
    savedFeedbackTimer.restart()
    saveBackupProc.command = [root.manageScriptPath, "save_layout_backup"]
    if (!saveBackupProc.running) saveBackupProc.running = true
  }

  function resetWidgetPositions() {
    resetProc.command = [root.manageScriptPath, "reset"]
    if (!resetProc.running) resetProc.running = true
  }

  function switchProfile(name) {
    switchProfileProc.command = [root.manageScriptPath, "switch_profile", name]
    if (!switchProfileProc.running) switchProfileProc.running = true
  }

  function saveCurrentProfile(name) {
    saveProfileProc.command = [root.manageScriptPath, "save_profile", name || root.activeProfile]
    if (!saveProfileProc.running) saveProfileProc.running = true
  }

  function saveNewProfileDialog() {
    saveProfileDialogProc.command = [root.manageScriptPath, "save_profile_dialog"]
    if (!saveProfileDialogProc.running) saveProfileDialogProc.running = true
  }

  function exportCurrentProfile(name) {
    exportProfileProc.command = [root.manageScriptPath, "export_profile", name || root.activeProfile]
    if (!exportProfileProc.running) exportProfileProc.running = true
  }

  function importProfile() {
    importProfileProc.command = [root.manageScriptPath, "import_profile"]
    if (!importProfileProc.running) importProfileProc.running = true
  }

  function updateAppearance(key, val) {
    var app = Object.assign({}, root.appearance)
    app[key] = val
    root.appearance = app
    Quickshell.execDetached([root.manageScriptPath, "save_appearance", JSON.stringify(app)])
    if (key === "blur_enabled") {
      remapDelayTimer.restart()
    }
  }

  function setAppearanceAll(app) {
    var blurChanged = (root.appearance && root.appearance.blur_enabled !== app.blur_enabled)
    root.appearance = app
    Quickshell.execDetached([root.manageScriptPath, "save_appearance", JSON.stringify(app)])
    if (blurChanged) {
      remapDelayTimer.restart()
    }
  }

  Process {
    id: switchProfileProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "profile_switched") {
            root.activeProfile = res.active_profile
            if (res.positions) root.widgetPositions = res.positions
            if (Array.isArray(res.enabled_widgets)) root.enabledWidgets = res.enabled_widgets
            if (res.widget_settings) root.widgetSettings = res.widget_settings
            root.showProfileNotice("Switched to '" + res.active_profile + "' preset")
            if (!posProc.running) posProc.running = true
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: saveProfileProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "profile_saved") {
            root.activeProfile = res.active_profile
            root.showProfileNotice("Saved preset '" + res.active_profile + "'")
            if (!posProc.running) posProc.running = true
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: saveProfileDialogProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "profile_saved") {
            root.activeProfile = res.active_profile
            root.showProfileNotice("Created preset '" + res.active_profile + "'")
            if (!posProc.running) posProc.running = true
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: exportProfileProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "exported") {
            root.showProfileNotice("Exported preset to " + (res.path ? res.path.split("/").pop() : "file"))
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: importProfileProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "imported") {
            root.activeProfile = res.name
            if (res.positions) root.widgetPositions = res.positions
            if (Array.isArray(res.enabled_widgets)) root.enabledWidgets = res.enabled_widgets
            if (res.widget_settings) root.widgetSettings = res.widget_settings
            root.showProfileNotice("Imported preset '" + res.name + "'")
            if (!posProc.running) posProc.running = true
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: saveBackupProc
    command: [root.manageScriptPath, "save_layout_backup"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.has_saved_layout !== undefined) root.hasSavedLayout = res.has_saved_layout
          else if (res.status === "layout_backup_saved") root.hasSavedLayout = true
        } catch (e) {}
      }
    }
  }

  Process {
    id: resetProc
    command: [root.manageScriptPath, "reset"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.positions !== undefined) root.widgetPositions = res.positions
          if (Array.isArray(res.enabled_widgets)) root.enabledWidgets = res.enabled_widgets
          if (res.widget_settings) root.widgetSettings = res.widget_settings
          if (res.has_saved_layout !== undefined) root.hasSavedLayout = res.has_saved_layout
        } catch (e) {}
      }
    }
  }

  function importCustomWidget() {
    customImportProc.command = [root.manageScriptPath, "pick_widget_dialog"]
    if (!customImportProc.running) customImportProc.running = true
  }

  Process {
    id: customImportProc
    command: [root.manageScriptPath, "pick_widget_dialog"]
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

  // 🔄 Automatically handle workspace navigation:
  // Close the widget overlay unconditionally whenever the workspace changes.
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  onFocusedWorkspaceChanged: {
    if (root.overlayActive) {
      root.closeOverlay()
    }
    root.manualHide = false
  }

  function isMediaPlaying() {
    try {
      var players = Mpris.players ? Mpris.players.values : []
      for (var i = 0; i < players.length; i++) {
        if (players[i].playbackState === MprisPlaybackState.Playing) return true
      }
    } catch (e) {}
    return false
  }

  function triggerScreensaver(force) {
    if (!force) {
      if (!root.appearance || !root.appearance.screensaver_enabled) return "disabled"
      if (root.overlayActive || root.preferencesOpen) return "already_open"
      if (root.isMediaPlaying()) return "media_inhibited"
    }

    root.overlayActive = true
    return "activated"
  }

  IdleMonitor {
    id: screensaverIdleMonitor
    enabled: (root.appearance && root.appearance.screensaver_enabled === true)
    timeout: Math.max(30, ((root.appearance && root.appearance.screensaver_timeout_mins) ? root.appearance.screensaver_timeout_mins : 5) * 60)
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) {
        root.triggerScreensaver(false)
      }
    }
  }

  function handleToggleOrJump() {
    if (root.overlayActive) {
      root.closeOverlay()
    } else {
      var ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
      var hasWindows = ws && ws.toplevels && ws.toplevels.values.length > 0
      if (hasWindows) {
        root.overlayActive = true
        root.manualHide = false
      } else {
        root.manualHide = !root.manualHide
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
      root.menuOpenRequested = true
    }

    function preferences(tab: int) {
      if (tab !== undefined && tab >= 0) {
        root.preferencesTab = tab
        root.preferencesOpen = true
      } else {
        root.preferencesOpen = !root.preferencesOpen
      }
    }

    function toggleBlur(): string {
      var cur = (root.appearance && root.appearance.blur_enabled) ? true : false
      root.updateAppearance("blur_enabled", !cur)
      return !cur ? "blur enabled" : "blur disabled"
    }

    function profile(name: string): string {
      if (name) root.switchProfile(name)
      return "switched to " + name
    }

    function screensaver(): string {
      return root.triggerScreensaver(false)
    }

    function triggerScreensaver(): string {
      return root.triggerScreensaver(false)
    }

    function triggerScreensaverForce(): string {
      return root.triggerScreensaver(true)
    }

    function debugScreensaver(): string {
      var ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
      var players = Mpris.players ? Mpris.players.values : []
      var playerList = []
      for (var i = 0; i < players.length; i++) {
        var isPlaying = (players[i].playbackState === MprisPlaybackState.Playing)
        playerList.push((players[i].identity || "unknown") + " (" + (isPlaying ? "PLAYING" : "paused/stopped") + ")")
      }
      return JSON.stringify({
        screensaver_enabled: (root.appearance && root.appearance.screensaver_enabled),
        screensaver_timeout_mins: (root.appearance && root.appearance.screensaver_timeout_mins),
        overlayActive: root.overlayActive,
        preferencesOpen: root.preferencesOpen,
        mediaPlaying: root.isMediaPlaying(),
        players: playerList,
        workspaceId: ws ? ws.id : null,
        hasWindows: !!(ws && ws.toplevels && ws.toplevels.values.length > 0),
        idleMonitorTimeout: screensaverIdleMonitor.timeout,
        idleMonitorIsIdle: screensaverIdleMonitor.isIdle
      }, null, 2)
    }

    function setAppearance(key: string, val: string): string {
      try {
        var parsed = JSON.parse(val)
        root.updateAppearance(key, parsed)
      } catch (e) {
        root.updateAppearance(key, val)
      }
      return key + " set to " + val
    }
  }

  // ---------------------------------------------------------------------------
  // 🌓 Shaded Transparent Overlay Backdrop Window (Covers full screen & top bar)
  // ---------------------------------------------------------------------------
  Variants {
    model: Quickshell.screens

    delegate: Component {
      id: scrimDelegate

      PanelWindow {
        id: scrimWindow
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
        WlrLayershell.namespace: "omarchy-desktop-shade"
        WlrLayershell.layer: WlrLayer.Top
        visible: root.overlayActive || root.preferencesOpen

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(10/255, 10/255, 16/255, 0.72)
          opacity: (root.overlayActive || root.preferencesOpen) ? 1.0 : 0.0

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: {
            if (root.preferencesOpen) root.preferencesOpen = false
            if (root.overlayActive) root.closeOverlay()
          }
        }
      }
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
        visible: root.surfaceRemapActive

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-desktop-widgets"
        WlrLayershell.layer: (root.overlayActive || root.preferencesOpen) ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: (root.overlayActive || root.preferencesOpen) ? WlrKeyboardFocus.OnDemand : ((!desktopWindow.hasOpenWindows && (root.selectorOpen || root.keyboardFocusRequested)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

        Shortcut {
          sequence: "Escape"
          enabled: root.overlayActive || root.preferencesOpen
          onActivated: {
            if (root.preferencesOpen) root.preferencesOpen = false
            if (root.overlayActive) root.closeOverlay()
          }
        }

        onWidthChanged: if (width > 0) root.screenWidth = width
        onHeightChanged: if (height > 0) root.screenHeight = height
        Component.onCompleted: {
          if (width > 0) root.screenWidth = width
          if (height > 0) root.screenHeight = height
        }

        readonly property string monitorName: (modelData && modelData.name) ? modelData.name : ""

        readonly property string autoHideMode: (root.appearance && root.appearance.auto_hide_mode) ? root.appearance.auto_hide_mode : "tiled"

        readonly property bool hasOpenWindows: {
          var dummy = ToplevelManager.toplevels.values.length
          var ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
          return !!(ws && ws.toplevels && ws.toplevels.values.length > 0)
        }

        readonly property bool hasFullscreenWindows: {
          var dummy = ToplevelManager.toplevels.values.length
          var ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace : null
          if (!ws || !ws.toplevels) return false
          for (var i = 0; i < ws.toplevels.values.length; i++) {
            if (ws.toplevels.values[i].fullscreen) return true
          }
          return false
        }

        readonly property bool isAutoHidden: {
          if (autoHideMode === "tiled") return desktopWindow.hasOpenWindows
          if (autoHideMode === "fullscreen") return desktopWindow.hasFullscreenWindows
          if (autoHideMode === "always") return false
          if (autoHideMode === "manual") return false
          return desktopWindow.hasOpenWindows
        }

        // Workspace Transitions
        property real wsSlideOffset: 0
        property real wsAnimOpacity: 1.0

        Connections {
          target: typeof Hyprland !== "undefined" ? Hyprland : null
          ignoreUnknownSignals: true
          function onFocusedWorkspaceChanged() {
            if (root.appearance && root.appearance.animations_enabled === false) return
            wsAnimOpacity = 0.35
            wsSlideOffset = 18
            wsResetAnim.restart()
          }
        }

        ParallelAnimation {
          id: wsResetAnim
          NumberAnimation {
            target: desktopWindow
            property: "wsSlideOffset"
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: desktopWindow
            property: "wsAnimOpacity"
            to: 1.0
            duration: 280
            easing.type: Easing.OutCubic
          }
        }

        // 🖱️ Desktop Background Click & Context Menu Handler
        MouseArea {
          id: desktopBgMouse
          anchors.fill: parent
          z: 0
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
              root.handleToggleOrJump()
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
          x: desktopWindow.wsSlideOffset
          z: 1

          readonly property bool shouldShow: root.overlayActive || (!root.manualHide && !desktopWindow.isAutoHidden)
          opacity: shouldShow ? (1.0 * desktopWindow.wsAnimOpacity) : 0.0
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
            minorGridSize: (root.appearance && root.appearance.grid_snap !== undefined) ? (root.appearance.grid_snap > 0 ? root.appearance.grid_snap : 0) : 20
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
                text: "Move Mode"
                font.family: Style.font.family
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Color.foreground
              }

              Rectangle {
                width: 1
                height: 18
                color: Qt.rgba(1, 1, 1, 0.15)
              }

              // Presets Pill Bar
              RowLayout {
                spacing: Style.space(4)

                Text {
                  text: "Preset:"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
                }

                Repeater {
                  model: root.layoutProfiles.length > 0 ? root.layoutProfiles : [
                    { name: "Default" }, { name: "Minimal" }, { name: "Productivity" }, { name: "Full Dashboard" }, { name: "Gaming" }
                  ]

                  Rectangle {
                    required property var modelData
                    implicitWidth: presetPillText.implicitWidth + 16
                    implicitHeight: 26
                    radius: 13
                    color: (modelData.name === root.activeProfile)
                      ? Color.accent
                      : (presetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))

                    Text {
                      id: presetPillText
                      anchors.centerIn: parent
                      text: modelData.name
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.weight: (modelData.name === root.activeProfile) ? Font.Bold : Font.Normal
                      color: (modelData.name === root.activeProfile) ? Color.background : Color.foreground
                    }

                    MouseArea {
                      id: presetMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.switchProfile(modelData.name)
                    }
                  }
                }

                // + New Preset Button
                Rectangle {
                  implicitWidth: newPresetText.implicitWidth + 14
                  implicitHeight: 26
                  radius: 13
                  color: newPresetMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                  border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
                  border.width: 1

                  RowLayout {
                    id: newPresetText
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                      text: "\uf067"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Color.accent
                    }
                    Text {
                      text: "Preset"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: Color.foreground
                    }
                  }

                  MouseArea {
                    id: newPresetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveNewProfileDialog()
                  }
                }
              }

              Rectangle {
                width: 1
                height: 18
                color: Qt.rgba(1, 1, 1, 0.15)
              }

              // ⚙️ Appearance Preferences Button
              Rectangle {
                implicitWidth: prefsBtnText.implicitWidth + 18
                implicitHeight: 28
                radius: 14
                color: prefsBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.1)
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
                border.width: 1

                RowLayout {
                  id: prefsBtnText
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: "\uf013"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Color.accent
                  }
                  Text {
                    text: "Preferences"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Color.foreground
                  }
                }

                MouseArea {
                  id: prefsBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.preferencesOpen = true
                }
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

              // 💾 Save Layout Button
              Rectangle {
                implicitWidth: saveBtnText.implicitWidth + 22
                implicitHeight: 28
                radius: 14
                color: root.layoutSavedFeedback
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
                  : (saveMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.1))
                border.color: root.layoutSavedFeedback
                  ? Color.accent
                  : (saveMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6) : Qt.rgba(1, 1, 1, 0.18))
                border.width: 1

                RowLayout {
                  id: saveBtnText
                  anchors.centerIn: parent
                  spacing: Style.space(5)

                  Text {
                    text: root.layoutSavedFeedback ? "\uf00c" : "\uf0c7"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: root.layoutSavedFeedback ? Color.accent : (saveMouse.containsMouse ? Color.accent : Color.foreground)
                  }

                  Text {
                    text: root.layoutSavedFeedback ? "Layout Saved!" : "Save Layout"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: root.layoutSavedFeedback ? Color.accent : Color.foreground
                  }
                }

                MouseArea {
                  id: saveMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.saveCurrentLayout()
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

              readonly property string monitorName: desktopWindow.monitorName
              readonly property var monitorPos: (root.monitorPositions && monitorName && root.monitorPositions[monitorName] && root.monitorPositions[monitorName][modelData.id]) ? root.monitorPositions[monitorName][modelData.id] : null
              readonly property var savedPos: monitorPos ? monitorPos : ((root.widgetPositions && root.widgetPositions[modelData.id]) ? root.widgetPositions[modelData.id] : null)
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
                  item.monitorName = desktopWindow.monitorName
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

              // 3. Layout Presets (Expandable Submenu)
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: presetsItemMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (root.presetsSubmenuOpen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent")

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
                      text: "\uf0c9"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Layout Presets"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.presetsSubmenuOpen ? "\uf107" : "\uf105"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
                  }
                }

                MouseArea {
                  id: presetsItemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.presetsSubmenuOpen = !root.presetsSubmenuOpen
                }
              }

              // Presets Expanded List
              ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 4
                visible: root.presetsSubmenuOpen
                spacing: 2

                Repeater {
                  model: root.layoutProfiles.length > 0 ? root.layoutProfiles : [
                    { name: "Default" }, { name: "Minimal" }, { name: "Productivity" }, { name: "Full Dashboard" }, { name: "Gaming" }
                  ]

                  Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 28
                    radius: 6
                    color: (modelData.name === root.activeProfile)
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                      : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 8
                      anchors.rightMargin: 8
                      spacing: 8

                      Text {
                        text: (modelData.name === root.activeProfile) ? "\uf00c" : "\uf111"
                        font.family: Style.font.family
                        font.pixelSize: (modelData.name === root.activeProfile) ? 10 : 6
                        color: (modelData.name === root.activeProfile) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
                        Layout.preferredWidth: 12
                        horizontalAlignment: Text.AlignHCenter
                      }

                      Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.family: Style.font.family
                        font.pixelSize: 11
                        font.weight: (modelData.name === root.activeProfile) ? Font.Bold : Font.Normal
                        color: (modelData.name === root.activeProfile) ? Color.accent : Color.foreground
                        elide: Text.ElideRight
                      }
                    }

                    MouseArea {
                      id: rowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        desktopContextMenu.isOpen = false
                        root.switchProfile(modelData.name)
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 1
                  color: Qt.rgba(1, 1, 1, 0.06)
                  Layout.topMargin: 2
                  Layout.bottomMargin: 2
                }

                // Save As New Preset
                Rectangle {
                  Layout.fillWidth: true
                  height: 26
                  radius: 6
                  color: saveNewMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8
                    Text { text: "\uf067"; font.family: Style.font.family; font.pixelSize: 10; color: Color.accent }
                    Text { text: "Save As New Preset..."; font.family: Style.font.family; font.pixelSize: 11; color: Color.foreground }
                  }
                  MouseArea {
                    id: saveNewMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      desktopContextMenu.isOpen = false
                      root.saveNewProfileDialog()
                    }
                  }
                }

                // Import Preset
                Rectangle {
                  Layout.fillWidth: true
                  height: 26
                  radius: 6
                  color: importMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8
                    Text { text: "\uf093"; font.family: Style.font.family; font.pixelSize: 10; color: Color.accent }
                    Text { text: "Import Preset JSON..."; font.family: Style.font.family; font.pixelSize: 11; color: Color.foreground }
                  }
                  MouseArea {
                    id: importMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      desktopContextMenu.isOpen = false
                      root.importProfile()
                    }
                  }
                }

                // Export Preset
                Rectangle {
                  Layout.fillWidth: true
                  height: 26
                  radius: 6
                  color: exportMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8
                    Text { text: "\uf019"; font.family: Style.font.family; font.pixelSize: 10; color: Color.accent }
                    Text { text: "Export Current Preset..."; font.family: Style.font.family; font.pixelSize: 11; color: Color.foreground }
                  }
                  MouseArea {
                    id: exportMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      desktopContextMenu.isOpen = false
                      root.exportCurrentProfile()
                    }
                  }
                }
              }

              // 4. Widget Preferences Dialog
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: prefsMenuMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"

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
                      text: "\uf013"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Widget Preferences..."
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: prefsMenuMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    root.preferencesOpen = true
                  }
                }
              }

              // 5. Save Layout
              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: saveDesktopLayoutMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"

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
                      text: "\uf0c7"
                      font.family: Style.font.family
                      font.pixelSize: 12
                      color: saveDesktopLayoutMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Save Current Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: saveDesktopLayoutMouse.containsMouse ? Color.accent : Color.foreground
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: saveDesktopLayoutMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    desktopContextMenu.isOpen = false
                    root.saveCurrentLayout()
                  }
                }
              }

              // 6. Revert / Reset Layout
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
                    text: root.hasSavedLayout ? "Revert to Saved Layout" : "Reset Widget Layout"
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

        // ⚙️ Global Widget Preferences Dialog
        PreferencesDialog {
          id: prefsDialog
          rootRef: root
          isOpen: root.preferencesOpen
          activeTab: root.preferencesTab
          onCloseRequested: root.preferencesOpen = false
        }

        // 🍞 Floating Profile Notification Toast
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(36)
          anchors.horizontalCenter: parent.horizontalCenter
          z: 650
          visible: opacity > 0
          opacity: root.profileNoticeVisible ? 1.0 : 0.0
          implicitWidth: noticeRow.implicitWidth + Style.space(28)
          implicitHeight: 38
          radius: 19
          color: Qt.rgba(18/255, 18/255, 26/255, 0.96)
          border.color: Color.accent
          border.width: 1.5

          Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
          }

          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.85)
            shadowBlur: 0.9
            shadowVerticalOffset: 4
          }

          RowLayout {
            id: noticeRow
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              text: "\uf058"
              font.family: Style.font.family
              font.pixelSize: 13
              color: Color.accent
            }
            Text {
              text: root.profileNoticeText
              font.family: Style.font.family
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: Color.foreground
            }
          }
        }
      }
    }
  }
}
