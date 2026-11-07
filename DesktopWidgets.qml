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
import qs.Commons as Commons
import qs.Ui
import "widgets"
import "components"

Item {
  id: root

  // ---------------------------------------------------------------------------
  // 📍 Desktop Widgets State, Positions, Profiles, Registry & Persistence
  // ---------------------------------------------------------------------------
  property var widgetPositions: ({})
  property var enabledWidgets: ["clock", "gallery", "coin_tracker", "network", "media", "system"]
  property var widgetSettings: ({})
  property bool settingsReady: false
  property real screenWidth: 1920
  property real screenHeight: 1080
  property bool layoutEditMode: false
  property bool selectorOpen: false
  property bool preferencesOpen: false
  property bool presetsSubmenuOpen: false
  property bool manualHide: false
  property bool overlayActive: false
  property bool keyboardFocusRequested: false
  readonly property string autoHideMode: (root.appearance && root.appearance.auto_hide_mode) ? root.appearance.auto_hide_mode : "tiled"
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
  property var monitorEnabledWidgets: ({})
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

  property bool wasManualHiddenBeforeOverlay: false

  function closeOverlay() {
    overlayActive = false
    if (root.autoHideMode === "manual" && root.wasManualHiddenBeforeOverlay) {
      root.manualHide = true
    }
    root.wasManualHiddenBeforeOverlay = false
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
          if (res.widget_settings) {
            root.widgetSettings = res.widget_settings
            root.settingsReady = true
          }
          if (res.has_saved_layout !== undefined) root.hasSavedLayout = res.has_saved_layout
          if (res.active_profile) root.activeProfile = res.active_profile
          if (Array.isArray(res.profiles)) root.layoutProfiles = res.profiles
          if (res.appearance) root.appearance = res.appearance
          if (res.monitor_positions) root.monitorPositions = res.monitor_positions
          if (res.monitor_enabled_widgets) root.monitorEnabledWidgets = res.monitor_enabled_widgets
        } catch (e) {}
      }
    }
  }

  function saveWidgetPos(id, x, y, w, h, monitorName) {
    var screens = Quickshell.screens
    var isMulti = screens && screens.length > 1
    var p = Object.assign({}, root.widgetPositions)
    var mp = Object.assign({}, root.monitorPositions)
    var current = (monitorName && mp[monitorName] && mp[monitorName][id]) ? mp[monitorName][id] : (p[id] || {})
    var targetW = (w !== undefined && w > 0) ? w : (current.w || 0)
    var targetH = (h !== undefined && h > 0) ? h : (current.h || 0)

    var entry = { x: x, y: y }
    if (targetW > 0 && targetH > 0) {
      entry.w = targetW
      entry.h = targetH
    } else {
      if (current.w) entry.w = current.w
      if (current.h) entry.h = current.h
    }

    if (isMulti && monitorName) {
      var monitorMap = Object.assign({}, mp[monitorName] || {})
      monitorMap[id] = entry
      mp[monitorName] = monitorMap
      root.monitorPositions = mp
      if (targetW > 0 && targetH > 0) {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString(), targetW.toString(), targetH.toString(), monitorName])
      } else {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString(), monitorName])
      }
    } else {
      p[id] = entry
      root.widgetPositions = p
      if (targetW > 0 && targetH > 0) {
        Quickshell.execDetached([root.manageScriptPath, "save_pos", id, x.toString(), y.toString(), targetW.toString(), targetH.toString()])
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

  function isDefaultMonitor(mName) {
    var screens = Quickshell.screens
    return !screens || screens.length <= 1 || (screens[0] && screens[0].name === mName)
  }

  function hasMonitorPositionForWidget(id, mName) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    var pos = root.monitorPositions
    if (!pos || !mName || !pos[mName]) return false
    return !!(pos[mName][targetId] || (targetId === "coin_tracker" && pos[mName]["btc_tracker"]))
  }

  function hasAnyMonitorPositionForWidget(id) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    var pos = root.monitorPositions
    if (!pos) return false
    for (var m in pos) {
      if (pos[m] && (pos[m][targetId] || (targetId === "coin_tracker" && pos[m]["btc_tracker"]))) return true
    }
    return false
  }

  function isWidgetEnabledInList(id, list) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    return list && (list.indexOf(targetId) !== -1 || (targetId === "coin_tracker" && list.indexOf("btc_tracker") !== -1))
  }

  function isWidgetActiveOnMonitor(id, mName) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    var screens = Quickshell.screens
    var isMulti = (screens && screens.length > 1)

    if (!isMulti) {
      return root.isWidgetEnabledInList(targetId, root.enabledWidgets)
    }

    // Explicit per-monitor enabled lists have priority.
    if (mName && root.monitorEnabledWidgets && root.monitorEnabledWidgets[mName] !== undefined) {
      return root.isWidgetEnabledInList(targetId, root.monitorEnabledWidgets[mName])
    }

    // A saved monitor-local position means the widget belongs to that output.
    if (root.hasMonitorPositionForWidget(targetId, mName)) {
      return root.isWidgetEnabledInList(targetId, root.enabledWidgets)
    }

    // If any other monitor owns the widget, do not clone it through global fallback.
    if (root.hasAnyMonitorPositionForWidget(targetId)) {
      return false
    }

    // Legacy single-monitor configs fall back to one deterministic monitor only.
    return root.isDefaultMonitor(mName) && root.isWidgetEnabledInList(targetId, root.enabledWidgets)
  }

  function toggleWidgetEnabled(id, enable, monitorName) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    var screens = Quickshell.screens
    var isMulti = (screens && screens.length > 1)
    var isFirstScreen = root.isDefaultMonitor(monitorName)

    if (isMulti && monitorName) {
      var mew = Object.assign({}, root.monitorEnabledWidgets)
      if (!mew[monitorName]) {
        mew[monitorName] = isFirstScreen ? root.enabledWidgets.slice() : []
      }
      var mList = mew[monitorName].slice()
      var mIdx = mList.indexOf(targetId)
      if (enable && mIdx === -1) mList.push(targetId)
      else if (!enable && mIdx !== -1) mList.splice(mIdx, 1)
      mew[monitorName] = mList
      root.monitorEnabledWidgets = mew

      Quickshell.execDetached([root.manageScriptPath, "toggle_widget", targetId, enable ? "true" : "false", monitorName, JSON.stringify(mList)])
    } else {
      var sList = root.enabledWidgets.slice()
      var sIdx = sList.indexOf(targetId)
      if (enable && sIdx === -1) sList.push(targetId)
      else if (!enable && sIdx !== -1) sList.splice(sIdx, 1)
      root.enabledWidgets = sList
      Quickshell.execDetached([root.manageScriptPath, "toggle_widget", targetId, enable ? "true" : "false"])
    }
  }

  function moveToMonitor(id, fromMon, toMon) {
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    var mew = Object.assign({}, root.monitorEnabledWidgets)

    if (!mew[fromMon]) {
      var screens = Quickshell.screens
      var isFirst = (!screens || screens.length <= 1 || (screens[0] && screens[0].name === fromMon))
      mew[fromMon] = isFirst ? root.enabledWidgets.slice() : []
    }
    var fromList = mew[fromMon].slice()
    var fIdx = fromList.indexOf(targetId)
    if (fIdx !== -1) fromList.splice(fIdx, 1)
    mew[fromMon] = fromList

    if (!mew[toMon]) mew[toMon] = []
    var toList = mew[toMon].slice()
    if (toList.indexOf(targetId) === -1) toList.push(targetId)
    mew[toMon] = toList

    root.monitorEnabledWidgets = mew
    Quickshell.execDetached([root.manageScriptPath, "move_to_monitor", targetId, fromMon, toMon])
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

  function switchProfile(name, monitorName, monitorWidth, monitorHeight) {
    if (monitorName) {
      switchProfileProc.command = [root.manageScriptPath, "switch_profile", name, monitorName, Math.round(monitorWidth || 0).toString(), Math.round(monitorHeight || 0).toString()]
    } else {
      switchProfileProc.command = [root.manageScriptPath, "switch_profile", name]
    }
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
            root.monitorPositions = (res.monitor_positions && typeof res.monitor_positions === "object") ? res.monitor_positions : ({})
            root.monitorEnabledWidgets = (res.monitor_enabled_widgets && typeof res.monitor_enabled_widgets === "object") ? res.monitor_enabled_widgets : ({})
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
    if (root.autoHideMode !== "manual") {
      root.manualHide = false
    }
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

    root.wasManualHiddenBeforeOverlay = root.manualHide
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
      var hasWindows = !!((ws && ws.toplevels && ws.toplevels.values.length > 0) || (ws && ws.windows > 0))
      if (hasWindows) {
        root.wasManualHiddenBeforeOverlay = root.manualHide
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
        WlrLayershell.layer: (root.overlayActive || root.preferencesOpen || root.keyboardFocusRequested) ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: (root.overlayActive || root.preferencesOpen || root.keyboardFocusRequested) ? WlrKeyboardFocus.OnDemand : ((!desktopWindow.hasOpenWindows && root.selectorOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

        Shortcut {
          sequence: "Escape"
          enabled: root.overlayActive || root.preferencesOpen || root.keyboardFocusRequested || desktopContextMenu.isOpen
          onActivated: {
            if (desktopContextMenu.isOpen) desktopContextMenu.isOpen = false
            if (root.preferencesOpen) root.preferencesOpen = false
            if (root.overlayActive) root.closeOverlay()
            if (root.keyboardFocusRequested) root.keyboardFocusRequested = false
          }
        }

        onWidthChanged: if (width > 0) root.screenWidth = width
        onHeightChanged: if (height > 0) root.screenHeight = height
        Component.onCompleted: {
          if (width > 0) root.screenWidth = width
          if (height > 0) root.screenHeight = height
        }

        readonly property string monitorName: (modelData && modelData.name) ? modelData.name : ""
        readonly property var hyprMonitor: (typeof Hyprland !== "undefined" && desktopWindow.screen) ? Hyprland.monitorFor(desktopWindow.screen) : null
        readonly property var monitorWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null

        readonly property string autoHideMode: (root.appearance && root.appearance.auto_hide_mode) ? root.appearance.auto_hide_mode : "tiled"

        readonly property bool hasOpenWindows: {
          var dummy = ToplevelManager.toplevels.values.length
          var ws = desktopWindow.monitorWorkspace
          return !!((ws && ws.toplevels && ws.toplevels.values.length > 0) || (ws && ws.windows > 0))
        }

        readonly property bool hasFullscreenWindows: {
          var dummy = ToplevelManager.toplevels.values.length
          var ws = desktopWindow.monitorWorkspace
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

        function isPointOverWidget(mouseX, mouseY) {
          if (root.layoutEditMode) return true
          if (!widgetContainer.shouldShow || !widgetContainer.visible) return false

          var localX = mouseX - widgetContainer.x
          var localY = mouseY - widgetContainer.y

          if (typeof widgetRepeater !== "undefined" && widgetRepeater) {
            for (var i = 0; i < widgetRepeater.count; i++) {
              var loader = widgetRepeater.itemAt(i)
              if (!loader || !loader.active || !loader.visible) continue
              var wItem = loader.item
              if (!wItem || !wItem.visible) continue

              var w = (wItem.width > 0) ? wItem.width : loader.width
              var h = (wItem.height > 0) ? wItem.height : loader.height
              if (w <= 0 || h <= 0) continue

              if (localX >= loader.x && localX <= loader.x + w &&
                  localY >= loader.y && localY <= loader.y + h) {
                return true
              }
            }
          }

          if (typeof widgetSelector !== "undefined" && widgetSelector && widgetSelector.isOpen && widgetSelector.visible) {
            if (localX >= widgetSelector.x && localX <= widgetSelector.x + widgetSelector.width &&
                localY >= widgetSelector.y && localY <= widgetSelector.y + widgetSelector.height) {
              return true
            }
          }

          if (typeof desktopContextMenu !== "undefined" && desktopContextMenu && desktopContextMenu.isOpen && desktopContextMenu.visible) {
            if (mouseX >= desktopContextMenu.x && mouseX <= desktopContextMenu.x + desktopContextMenu.width &&
                mouseY >= desktopContextMenu.y && mouseY <= desktopContextMenu.y + desktopContextMenu.height) {
              return true
            }
          }

          return false
        }

        // 🖱️ Desktop Background Click & Context Menu Handler
        MouseArea {
          id: desktopBgMouse
          anchors.fill: parent
          z: 0
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
              if (desktopWindow.isPointOverWidget(mouse.x, mouse.y)) {
                return
              }
              root.handleToggleOrJump()
            }
          }
          onClicked: function(mouse) {
            if (desktopWindow.isPointOverWidget(mouse.x, mouse.y)) {
              return
            }
            if (mouse.button === Qt.LeftButton) {
              if (root.overlayActive) {
                root.closeOverlay()
                return
              }
              desktopContextMenu.isOpen = false
            } else if (mouse.button === Qt.RightButton) {
              root.menuOpenRequested = false
              var menuH = desktopContextMenu.implicitHeight > 0 ? desktopContextMenu.implicitHeight : 380
              desktopContextMenu.x = Math.max(16, Math.min(mouse.x, desktopWindow.width - 256))
              desktopContextMenu.y = Math.max(16, Math.min(mouse.y, desktopWindow.height - menuH - 16))
              desktopContextMenu.isOpen = true
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
            id: editBanner
            property bool presetMenuOpen: false
            anchors.top: parent.top
            anchors.topMargin: Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            z: 300
            visible: root.layoutEditMode
            onVisibleChanged: if (!visible) presetMenuOpen = false
            implicitWidth: editBannerRow.implicitWidth + Style.space(32)
            implicitHeight: 42
            radius: 21
            color: Qt.rgba(14/255, 14/255, 20/255, 0.96)
            border.color: Commons.Color.accent
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
                color: Commons.Color.accent
              }

              Text {
                text: "Move Mode"
                font.family: Style.font.family
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Commons.Color.foreground
              }

              Rectangle {
                width: 1
                height: 18
                color: Qt.rgba(1, 1, 1, 0.15)
              }

              // Presets Dropdown
              RowLayout {
                id: presetsRow
                spacing: Style.space(4)

                Text {
                  text: "Preset:"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
                }

                // Dropdown Trigger (list panel lives outside the banner so its layer doesn't clip it)
                Rectangle {
                  id: presetTrigger
                  implicitWidth: Math.max(110, presetTriggerRow.implicitWidth + 20)
                  implicitHeight: 26
                  radius: 13
                  color: editBanner.presetMenuOpen
                    ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
                    : (presetTriggerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))
                  border.color: editBanner.presetMenuOpen ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
                  border.width: 1

                  RowLayout {
                    id: presetTriggerRow
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    Text {
                      Layout.fillWidth: true
                      text: root.activeProfile
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: Commons.Color.foreground
                      elide: Text.ElideRight
                    }

                    Text {
                      text: editBanner.presetMenuOpen ? "" : ""
                      font.family: Style.font.family
                      font.pixelSize: 11
                      color: Commons.Color.accent
                    }
                  }

                  MouseArea {
                    id: presetTriggerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editBanner.presetMenuOpen = !editBanner.presetMenuOpen
                  }
                }

                // + New Preset Button
                Rectangle {
                  implicitWidth: newPresetText.implicitWidth + 14
                  implicitHeight: 26
                  radius: 13
                  color: newPresetMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                  border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
                  border.width: 1

                  RowLayout {
                    id: newPresetText
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                      text: "\uf067"
                      font.family: Style.font.family
                      font.pixelSize: 9
                      color: Commons.Color.accent
                    }
                    Text {
                      text: "Preset"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: Commons.Color.foreground
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
                color: prefsBtnMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.1)
                border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
                border.width: 1

                RowLayout {
                  id: prefsBtnText
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: "\uf013"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Commons.Color.accent
                  }
                  Text {
                    text: "Preferences"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
                color: addMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.1)
                border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
                border.width: 1

                RowLayout {
                  id: addBtnText
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: "\uf067"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Commons.Color.accent
                  }
                  Text {
                    text: "Add Widgets"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
                  ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
                  : (saveMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.1))
                border.color: root.layoutSavedFeedback
                  ? Commons.Color.accent
                  : (saveMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.6) : Qt.rgba(1, 1, 1, 0.18))
                border.width: 1

                RowLayout {
                  id: saveBtnText
                  anchors.centerIn: parent
                  spacing: Style.space(5)

                  Text {
                    text: root.layoutSavedFeedback ? "\uf00c" : "\uf0c7"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: root.layoutSavedFeedback ? Commons.Color.accent : (saveMouse.containsMouse ? Commons.Color.accent : Commons.Color.foreground)
                  }

                  Text {
                    text: root.layoutSavedFeedback ? "Layout Saved!" : "Save Layout"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: root.layoutSavedFeedback ? Commons.Color.accent : Commons.Color.foreground
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
                color: doneMouse.containsMouse ? Qt.lighter(Commons.Color.accent, 1.15) : Commons.Color.accent

                Text {
                  id: doneBtnText
                  anchors.centerIn: parent
                  text: "Done / Lock"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.Bold
                  color: Commons.Color.background
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

          // Presets Dropdown Panel (sibling of the banner so its shadow layer doesn't clip the list)
          MouseArea {
            anchors.fill: parent
            z: 301
            visible: editBanner.visible && editBanner.presetMenuOpen
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: editBanner.presetMenuOpen = false
          }

          Rectangle {
            id: presetMenu
            z: 302
            visible: editBanner.visible && editBanner.presetMenuOpen
            x: editBanner.x + editBannerRow.x + presetsRow.x + presetTrigger.x
            y: editBanner.y + editBanner.height + 6
            width: Math.max(presetTrigger.width, 180)
            height: presetMenuFlick.height + Style.space(12)
            radius: 12
            color: Qt.rgba(18/255, 18/255, 24/255, 0.96)
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
            border.width: 1.5

            layer.enabled: true
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.85)
              shadowBlur: 0.9
              shadowVerticalOffset: 6
            }

            Flickable {
              id: presetMenuFlick
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(6)
              height: Math.min(contentHeight, 300)
              contentHeight: presetMenuCol.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              ColumnLayout {
                id: presetMenuCol
                width: presetMenuFlick.width
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
                      ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
                      : (presetOptionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 8
                      anchors.rightMargin: 8
                      spacing: 8

                      Text {
                        text: (modelData.name === root.activeProfile) ? "" : ""
                        font.family: Style.font.family
                        font.pixelSize: (modelData.name === root.activeProfile) ? 10 : 6
                        color: (modelData.name === root.activeProfile) ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
                        Layout.preferredWidth: 12
                        horizontalAlignment: Text.AlignHCenter
                      }

                      Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.family: Style.font.family
                        font.pixelSize: 11
                        font.weight: (modelData.name === root.activeProfile) ? Font.Bold : Font.Normal
                        color: (modelData.name === root.activeProfile) ? Commons.Color.accent : Commons.Color.foreground
                        elide: Text.ElideRight
                      }
                    }

                    MouseArea {
                      id: presetOptionMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        editBanner.presetMenuOpen = false
                        root.switchProfile(modelData.name, desktopWindow.monitorName, desktopWindow.width, desktopWindow.height)
                      }
                    }
                  }
                }
              }
            }
          }

          // -------------------------------------------------------------------
          // 📦 Dynamic Desktop Widgets Instantiation via Registry
          // -------------------------------------------------------------------
          Repeater {
            id: widgetRepeater
            model: widgetRegistry.allWidgets

            Loader {
              id: widgetLoader
              required property var modelData
              active: root.isWidgetActiveOnMonitor(modelData.id, desktopWindow.monitorName)
              source: modelData.componentUrl
              z: 10

              property real defaultX: item && item.defaultX !== undefined ? item.defaultX : Style.space(24)
              property real defaultY: item && item.defaultY !== undefined ? item.defaultY : Style.space(64)
              property bool isDragging: item && item.isDragging ? true : false

              readonly property string monitorName: desktopWindow.monitorName
              readonly property bool isMultiScreen: Quickshell.screens && Quickshell.screens.length > 1
              readonly property var monitorPos: (root.monitorPositions && monitorName && root.monitorPositions[monitorName] && (root.monitorPositions[monitorName][modelData.id] || (modelData.id === "coin_tracker" ? root.monitorPositions[monitorName]["btc_tracker"] : null))) ? (root.monitorPositions[monitorName][modelData.id] || root.monitorPositions[monitorName]["btc_tracker"]) : null
              readonly property var savedPos: monitorPos ? monitorPos : ((root.widgetPositions && (root.widgetPositions[modelData.id] || (modelData.id === "coin_tracker" ? root.widgetPositions["btc_tracker"] : null))) ? (root.widgetPositions[modelData.id] || root.widgetPositions["btc_tracker"]) : null)
              readonly property real savedWidth: (savedPos && savedPos.w !== undefined) ? savedPos.w : 0
              readonly property real savedHeight: (savedPos && savedPos.h !== undefined) ? savedPos.h : 0

              readonly property real effectiveWidth: (item && item.width > 0) ? item.width : (savedWidth > 0 ? savedWidth : 320)
              readonly property real effectiveHeight: (item && item.height > 0) ? item.height : (savedHeight > 0 ? savedHeight : 240)
              readonly property real maxX: Math.max(10, desktopWindow.width - effectiveWidth - 10)
              readonly property real maxY: Math.max(10, desktopWindow.height - effectiveHeight - 10)

              readonly property real rawX: (savedPos && savedPos.x !== undefined) ? savedPos.x : defaultX
              readonly property real rawY: (savedPos && savedPos.y !== undefined) ? savedPos.y : defaultY

              readonly property real targetX: (desktopWindow.width > 0) ? Math.max(10, Math.min(maxX, rawX)) : rawX
              readonly property real targetY: (desktopWindow.height > 0) ? Math.max(10, Math.min(maxY, rawY)) : rawY

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
                  if ("monitorName" in item) item.monitorName = desktopWindow.monitorName
                  if ("monitorWidth" in item) item.monitorWidth = desktopWindow.width
                  if ("monitorHeight" in item) item.monitorHeight = desktopWindow.height
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
                  if (typeof item.applySavedSettings === "function") {
                    item.applySavedSettings()
                  }
                }
              }

              Connections {
                target: desktopWindow
                function onWidthChanged() {
                  if (widgetLoader.item && "monitorWidth" in widgetLoader.item) {
                    widgetLoader.item.monitorWidth = desktopWindow.width
                  }
                  if (!widgetLoader.isDragging && desktopWindow.width > 0) {
                    widgetLoader.x = targetX
                  }
                }
                function onHeightChanged() {
                  if (widgetLoader.item && "monitorHeight" in widgetLoader.item) {
                    widgetLoader.item.monitorHeight = desktopWindow.height
                  }
                  if (!widgetLoader.isDragging && desktopWindow.height > 0) {
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
            targetMonitorName: desktopWindow.monitorName
          }
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
          x: 100
          y: 100
          visible: isOpen || root.menuOpenRequested
          z: 500
          width: 240
          implicitHeight: desktopMenuCol.implicitHeight + Style.space(16)
          radius: 14
          color: Qt.rgba(18/255, 18/255, 24/255, 0.96)
          border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
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
                  color: Commons.Color.accent
                }
              }
              Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: "Desktop Controls"
                font.family: Style.font.family
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Qt.rgba(1, 1, 1, 0.08)
            }

            // 1. Show / Hide Widgets
            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 8
              color: toggleWidgetsMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                    text: widgetContainer.shouldShow ? "\uf070" : "\uf06e"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    color: Commons.Color.accent
                  }
                }

                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  text: widgetContainer.shouldShow ? "Hide Widgets" : "Show Widgets"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.weight: Font.DemiBold
                  color: Commons.Color.foreground
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: toggleWidgetsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  desktopContextMenu.isOpen = false
                  if (widgetContainer.shouldShow) {
                    root.manualHide = true
                    if (root.overlayActive) {
                      root.closeOverlay()
                    }
                  } else {
                    root.manualHide = false
                    if (desktopWindow.hasOpenWindows) {
                      root.overlayActive = true
                    }
                  }
                }
              }
            }

            // 2. Unlock / Lock Layout (Moved to top)
            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 8
              color: toggleLayoutMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                      color: Commons.Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.layoutEditMode ? "Lock Layout" : "Unlock Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
                color: addWidgetsMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                      color: Commons.Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Add / Browse Widgets"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
                color: presetsItemMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : (root.presetsSubmenuOpen ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12) : "transparent")

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
                      color: Commons.Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Layout Presets"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.presetsSubmenuOpen ? "\uf107" : "\uf105"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
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
                      ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
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
                        color: (modelData.name === root.activeProfile) ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
                        Layout.preferredWidth: 12
                        horizontalAlignment: Text.AlignHCenter
                      }

                      Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.family: Style.font.family
                        font.pixelSize: 11
                        font.weight: (modelData.name === root.activeProfile) ? Font.Bold : Font.Normal
                        color: (modelData.name === root.activeProfile) ? Commons.Color.accent : Commons.Color.foreground
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
                        root.switchProfile(modelData.name, desktopWindow.monitorName, desktopWindow.width, desktopWindow.height)
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
                  color: saveNewMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8
                    Text { text: "\uf067"; font.family: Style.font.family; font.pixelSize: 10; color: Commons.Color.accent }
                    Text { text: "Save As New Preset..."; font.family: Style.font.family; font.pixelSize: 11; color: Commons.Color.foreground }
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
                  color: importMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8
                    Text { text: "\uf093"; font.family: Style.font.family; font.pixelSize: 10; color: Commons.Color.accent }
                    Text { text: "Import Preset JSON..."; font.family: Style.font.family; font.pixelSize: 11; color: Commons.Color.foreground }
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
                  color: exportMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8
                    Text { text: "\uf019"; font.family: Style.font.family; font.pixelSize: 10; color: Commons.Color.accent }
                    Text { text: "Export Current Preset..."; font.family: Style.font.family; font.pixelSize: 11; color: Commons.Color.foreground }
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
                color: prefsMenuMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                      color: Commons.Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Widget Preferences..."
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
                color: saveDesktopLayoutMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                      color: saveDesktopLayoutMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Save Current Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: saveDesktopLayoutMouse.containsMouse ? Commons.Color.accent : Commons.Color.foreground
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
                color: resetLayoutMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.22) : "transparent"

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
                      color: resetLayoutMouse.containsMouse ? Commons.Color.urgent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.hasSavedLayout ? "Revert to Saved Layout" : "Reset Widget Layout"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: resetLayoutMouse.containsMouse ? Commons.Color.urgent : Commons.Color.foreground
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
                color: bgSwitchMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                      color: Commons.Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Change Wallpaper"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
                color: themeSwitchMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22) : "transparent"

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
                      color: Commons.Color.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Switch Theme"
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Commons.Color.foreground
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
          border.color: Commons.Color.accent
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
              color: Commons.Color.accent
            }
            Text {
              text: root.profileNoticeText
              font.family: Style.font.family
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: Commons.Color.foreground
            }
          }
        }
      }
    }
  }
}
