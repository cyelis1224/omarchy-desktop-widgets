import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetCard {
  id: folderWidgetRoot

  widgetId: "folder_view"
  title: "Folder View"
  icon: "\uf07b"
  showHeader: false
  transparentBg: true

  defaultX: 760
  defaultY: 140

  width: 360
  height: 380
  minWidth: 240
  minHeight: 220
  maxWidth: 900
  maxHeight: 800

  property string currentFolder: ""
  property string currentFolderName: "Desktop"
  property string parentFolder: ""
  property var folderItems: []
  property bool isLoading: false

  // Display options (right-click menu)
  property string viewMode: "icons"   // "icons" | "details"
  property string sortBy: "name"      // "name" | "date" | "size" | "type"
  property bool sortDesc: false
  property bool foldersTop: true      // folders grouped above files
  property string folderSortBy: "name" // "name" | "date", used while foldersTop
  property bool folderSortDesc: false
  property int itemSpacing: 8         // gap between items in px
  readonly property int spacingMin: 0
  readonly property int spacingMax: 32
  readonly property bool detailsView: viewMode === "details"

  function applySavedSettings() {
    if (!rootRef || !rootRef.settingsReady) return
    var p = getSetting("folder_path", undefined)
    var target = (p !== undefined && typeof p === "string" && p !== "") ? p : "~/Desktop"
    if (currentFolder !== target) {
      currentFolder = target
      loadFolder(currentFolder)
    }
    var t = getSetting("transparentBg", undefined)
    if (t !== undefined) {
      transparentBg = Boolean(t)
    }
    var v = getSetting("view_mode", undefined)
    if (v === "icons" || v === "details") viewMode = v
    var s = getSetting("sort_by", undefined)
    if (s === "name" || s === "date" || s === "size" || s === "type") sortBy = s
    var d = getSetting("sort_desc", undefined)
    if (d !== undefined) sortDesc = Boolean(d)
    var ft = getSetting("folders_top", undefined)
    if (ft !== undefined) foldersTop = Boolean(ft)
    var fs = getSetting("folder_sort_by", undefined)
    if (fs === "name" || fs === "date") folderSortBy = fs
    var fd = getSetting("folder_sort_desc", undefined)
    if (fd !== undefined) folderSortDesc = Boolean(fd)
    var sp = getSetting("item_spacing", undefined)
    if (sp !== undefined && !isNaN(Number(sp))) {
      itemSpacing = Math.max(spacingMin, Math.min(spacingMax, Math.round(Number(sp))))
    }
  }

  function setViewMode(mode) {
    viewMode = mode
    saveSetting("view_mode", mode)
  }

  // Picking the active key again flips direction; a new key starts in its
  // natural direction (newest / largest first for date and size)
  function setSort(key) {
    var desc = (key === sortBy) ? !sortDesc : (key === "date" || key === "size")
    sortBy = key
    sortDesc = desc
    saveSettings({ "sort_by": key, "sort_desc": desc })
  }

  function setFolderSort(key) {
    var desc = (key === folderSortBy) ? !folderSortDesc : (key === "date")
    folderSortBy = key
    folderSortDesc = desc
    saveSettings({ "folder_sort_by": key, "folder_sort_desc": desc })
  }

  function setFoldersTop(on) {
    foldersTop = on
    saveSetting("folders_top", on)
  }

  function fileType(item) {
    if (item.is_dir) return ""
    var name = item.name || ""
    var dot = name.lastIndexOf(".")
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : ""
  }

  // Ties fall back to name, A-Z
  function compareItems(a, b, key, desc) {
    var c = 0
    if (key === "date") c = (a.mtime || 0) - (b.mtime || 0)
    else if (key === "size") c = (a.size_bytes || 0) - (b.size_bytes || 0)
    else if (key === "type") c = fileType(a).localeCompare(fileType(b))
    if (c !== 0) return desc ? -c : c
    var n = (a.display_name || a.name || "").toLowerCase().localeCompare((b.display_name || b.name || "").toLowerCase())
    return (key === "name" && desc) ? -n : n
  }

  // With folders on top they get their own sort; otherwise everything mixes
  // under the main sort
  function sortItems(items, key, desc, dirsTop, dirKey, dirDesc) {
    var list = items.slice()
    list.sort(function(a, b) {
      if (dirsTop) {
        if (a.is_dir !== b.is_dir) return a.is_dir ? -1 : 1
        if (a.is_dir) return folderWidgetRoot.compareItems(a, b, dirKey, dirDesc)
      }
      return folderWidgetRoot.compareItems(a, b, key, desc)
    })
    return list
  }

  readonly property var sortedItems: sortItems(folderItems, sortBy, sortDesc, foldersTop, folderSortBy, folderSortDesc)

  function formatModified(mtime) {
    if (!mtime) return ""
    var d = new Date(mtime * 1000)
    var now = new Date()
    if (d.toDateString() === now.toDateString()) return d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
    if (d.getFullYear() === now.getFullYear()) return Qt.formatDate(d, "MMM d")
    return Qt.formatDate(d, "MMM d, yyyy")
  }

  function iconSource(item) {
    if (!item.icon) return ""
    if (item.icon.startsWith("/")) return "file://" + item.icon
    return Quickshell.iconPath(item.icon, true)
  }

  Connections {
    target: rootRef || null
    ignoreUnknownSignals: true
    function onSettingsReadyChanged() {
      if (rootRef && rootRef.settingsReady) {
        folderWidgetRoot.applySavedSettings()
      }
    }
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: {
    if (rootRef && rootRef.settingsReady) applySavedSettings()
  }
  Component.onCompleted: {
    if (rootRef && rootRef.settingsReady) {
      applySavedSettings()
    }
  }

  // Fallback timer if rootRef or widgetSettings never arrives
  Timer {
    id: fallbackLoadTimer
    interval: 1500
    running: folderWidgetRoot.currentFolder === ""
    repeat: false
    onTriggered: {
      if (folderWidgetRoot.currentFolder === "") {
        folderWidgetRoot.currentFolder = "~/Desktop"
        folderWidgetRoot.loadFolder(folderWidgetRoot.currentFolder)
      }
    }
  }

  readonly property string folderScriptPath: {
    var u = Qt.resolvedUrl("../get-folder.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  // A new array resets the GridView (every delegate and icon is rebuilt and the
  // scroll position is lost), so polls only assign listings that changed
  property string folderItemsJson: "[]"
  function setFolderItems(items) {
    var list = Array.isArray(items) ? items : []
    var json = JSON.stringify(list)
    if (json === folderItemsJson) return
    folderItemsJson = json
    folderItems = list
  }

  function loadFolder(path) {
    if (!path) return
    currentFolder = path
    if (folderProc.running) {
      folderProc.kill()
    }
    folderProc.command = [folderWidgetRoot.folderScriptPath, path]
    isLoading = true
    folderProc.running = true
  }

  function pickFolder() {
    if (pickProc.running) return
    isLoading = true
    pickProc.running = true
  }

  function openItem(item) {
    if (!item) return
    if (item.is_dir) {
      loadFolder(item.path)
      folderWidgetRoot.saveSetting("folder_path", item.path)
      return
    }
    Quickshell.execDetached([folderWidgetRoot.folderScriptPath, "open", item.path])
  }

  function navigateUp() {
    if (parentFolder && parentFolder !== "") {
      loadFolder(parentFolder)
      folderWidgetRoot.saveSetting("folder_path", parentFolder)
    }
  }

  function openInFileManager() {
    Quickshell.execDetached(["xdg-open", (currentFolder || "~/Desktop").replace(/^~/, Quickshell.env("HOME") || "")])
  }

  Process {
    id: folderProc
    command: [folderWidgetRoot.folderScriptPath, folderWidgetRoot.currentFolder || "~/Desktop"]
    running: false
    onStarted: folderWidgetRoot.lastListMs = Date.now()
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok") {
            folderWidgetRoot.currentFolder = data.folder || folderWidgetRoot.currentFolder
            folderWidgetRoot.currentFolderName = data.folder_name || "Folder"
            folderWidgetRoot.parentFolder = data.parent || ""
            folderWidgetRoot.setFolderItems(data.items)
          }
        } catch (e) {
          console.warn("[FolderViewWidget] Parse error:", e)
        }
        folderWidgetRoot.isLoading = false
      }
    }
    onExited: {
      folderWidgetRoot.isLoading = false
    }
  }

  Process {
    id: pickProc
    command: [folderWidgetRoot.folderScriptPath, "pick"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok") {
            folderWidgetRoot.currentFolder = data.folder || folderWidgetRoot.currentFolder
            folderWidgetRoot.currentFolderName = data.folder_name || "Folder"
            folderWidgetRoot.parentFolder = data.parent || ""
            folderWidgetRoot.setFolderItems(data.items)
            folderWidgetRoot.saveSetting("folder_path", folderWidgetRoot.currentFolder)
          } else if (data.status === "cancelled") {
            // Pick dialog was cancelled
          }
        } catch (e) {
          console.warn("[FolderViewWidget] Pick parse error:", e)
        }
        folderWidgetRoot.isLoading = false
      }
    }
    onExited: {
      folderWidgetRoot.isLoading = false
    }
  }

  function refreshFolder() {
    if (!folderProc.running && folderWidgetRoot.currentFolder !== "") {
      folderProc.command = [folderWidgetRoot.folderScriptPath, folderWidgetRoot.currentFolder]
      folderProc.running = true
    }
  }

  // Auto-refresh folder every 10 seconds while on screen; when it comes back,
  // refresh right away only if the listing is already older than the interval
  property real lastListMs: 0
  onVisibleChanged: {
    if (visible && Date.now() - lastListMs >= folderRefreshTimer.interval && !folderWidgetRoot.isLoading && !pickProc.running) {
      refreshFolder()
    }
  }

  Timer {
    id: folderRefreshTimer
    interval: 10000
    running: folderWidgetRoot.visible && !folderWidgetRoot.isLoading && !folderWidgetRoot.contextMenuOpen && !pickProc.running && folderWidgetRoot.currentFolder !== ""
    repeat: true
    onTriggered: folderWidgetRoot.refreshFolder()
  }

  function getFileGlyph(item) {
    if (item.is_dir) return "\uf07b"
    if (item.is_desktop) return "\uf108"
    var ext = (item.name || "").split('.').pop().toLowerCase()
    switch (ext) {
      case "png":
      case "jpg":
      case "jpeg":
      case "webp":
      case "svg": return "\uf03e"
      case "mp4":
      case "mkv":
      case "webm": return "\uf03d"
      case "mp3":
      case "flac":
      case "wav": return "\uf001"
      case "zip":
      case "tar":
      case "gz": return "\uf1c6"
      case "py":
      case "sh":
      case "js":
      case "ts":
      case "qml": return "\uf121"
      case "pdf":
      case "doc":
      case "docx":
      case "md":
      case "txt": return "\uf15c"
      default: return "\uf15b"
    }
  }

  function glyphColor(item) {
    if (item.is_dir) return "#FBBF24"
    if (item.is_desktop) return Color.accent
    return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8)
  }

  // Details view columns; Modified drops out when the card is narrow
  readonly property int sizeColWidth: 56
  readonly property int dateColWidth: 84
  readonly property bool showDateCol: width >= 300

  // Icons view tile: icon + gap + two reserved name lines, with no padding, so
  // itemSpacing alone sets the gap between tiles. The hover highlight reaches
  // up to 4px past the content, borrowed from the gap so it stays in its cell.
  readonly property int tileIconSize: 38
  readonly property int tileIconGap: 3
  readonly property real tileHoverPad: Math.min(4, itemSpacing / 2)
  readonly property int tileContentHeight: tileIconSize + tileIconGap + Math.ceil(nameMetrics.lineSpacing * 2)

  FontMetrics {
    id: nameMetrics
    font.family: Style.font.family
    font.pixelSize: 10
    font.weight: Font.DemiBold
  }

  // ---------------------------------------------------------------------------
  // 🎛️ Custom Context Menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 280
      spacing: Style.space(4)

      // Choose Folder...
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: pickOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf07c"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Choose Folder..."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: pickOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            folderWidgetRoot.contextMenuOpen = false
            folderWidgetRoot.pickFolder()
          }
        }
      }

      // Open in File Manager
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: openOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf07b"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Open in File Manager"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: openOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            folderWidgetRoot.contextMenuOpen = false
            folderWidgetRoot.openInFileManager()
          }
        }
      }

      // Quick Location: Desktop
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: deskOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf108"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Go to ~/Desktop"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: deskOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            folderWidgetRoot.contextMenuOpen = false
            folderWidgetRoot.loadFolder("~/Desktop")
            folderWidgetRoot.saveSetting("folder_path", "~/Desktop")
          }
        }
      }

      // Quick Location: Downloads
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: downOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf019"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Go to ~/Downloads"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: downOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            folderWidgetRoot.contextMenuOpen = false
            folderWidgetRoot.loadFolder("~/Downloads")
            folderWidgetRoot.saveSetting("folder_path", "~/Downloads")
          }
        }
      }

      // Toggle Glass / Transparent Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: glassOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf06e"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: folderWidgetRoot.transparentBg ? "Enable Frosted Glass Card" : "Enable Pure Transparent Card"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: glassOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            folderWidgetRoot.contextMenuOpen = false
            folderWidgetRoot.transparentBg = !folderWidgetRoot.transparentBg
            folderWidgetRoot.saveSetting("transparentBg", folderWidgetRoot.transparentBg)
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.rgba(1, 1, 1, 0.06)
        Layout.topMargin: 2
        Layout.bottomMargin: 2
      }

      // View Mode Selector
      Text {
        text: "VIEW"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(10)
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(6)
        Layout.rightMargin: Style.space(6)
        spacing: 4

        Repeater {
          model: [
            { label: "Icons", icon: "", id: "icons" },
            { label: "Details", icon: "", id: "details" }
          ]

          Rectangle {
            required property var modelData
            readonly property bool isActive: folderWidgetRoot.viewMode === modelData.id
            Layout.fillWidth: true
            implicitHeight: 24
            radius: 4
            color: isActive ? Color.accent : (viewBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))

            Text {
              anchors.centerIn: parent
              text: modelData.icon + "  " + modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isActive ? Font.Bold : Font.Normal
              color: isActive ? "#0a0a0f" : Color.foreground
            }

            MouseArea {
              id: viewBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: folderWidgetRoot.setViewMode(modelData.id)
            }
          }
        }
      }

      // Sort Selector (click the active key again to reverse)
      Text {
        text: "SORT BY"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(10)
        Layout.topMargin: 2
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(6)
        Layout.rightMargin: Style.space(6)
        spacing: 4

        Repeater {
          model: [
            { label: "Name", id: "name" },
            { label: "Date", id: "date" },
            { label: "Size", id: "size" },
            { label: "Type", id: "type" }
          ]

          Rectangle {
            required property var modelData
            readonly property bool isActive: folderWidgetRoot.sortBy === modelData.id
            Layout.fillWidth: true
            implicitHeight: 24
            radius: 4
            color: isActive ? Color.accent : (sortBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))

            Text {
              anchors.centerIn: parent
              text: modelData.label + (isActive ? (folderWidgetRoot.sortDesc ? " " : " ") : "")
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isActive ? Font.Bold : Font.Normal
              color: isActive ? "#0a0a0f" : Color.foreground
            }

            MouseArea {
              id: sortBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: folderWidgetRoot.setSort(modelData.id)
            }
          }
        }
      }

      // Folders: keep on top, and how they sort while there
      Text {
        text: "FOLDERS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(10)
        Layout.topMargin: 2
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(6)
        Layout.rightMargin: Style.space(6)
        spacing: 4

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 24
          radius: 4
          color: foldersTopMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

          Text {
            anchors.centerIn: parent
            text: (folderWidgetRoot.foldersTop ? "" : "") + "  Top"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: folderWidgetRoot.foldersTop ? Font.Bold : Font.Normal
            color: folderWidgetRoot.foldersTop ? Color.accent : Color.foreground
          }

          MouseArea {
            id: foldersTopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: folderWidgetRoot.setFoldersTop(!folderWidgetRoot.foldersTop)
          }
        }

        Repeater {
          model: [
            { label: "Name", id: "name" },
            { label: "Date", id: "date" }
          ]

          // Only applies while folders are grouped on top
          Rectangle {
            required property var modelData
            readonly property bool isActive: folderWidgetRoot.folderSortBy === modelData.id
            Layout.fillWidth: true
            implicitHeight: 24
            radius: 4
            opacity: folderWidgetRoot.foldersTop ? 1.0 : 0.35
            color: isActive ? Color.accent : (folderSortMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))

            Text {
              anchors.centerIn: parent
              text: modelData.label + (isActive ? (folderWidgetRoot.folderSortDesc ? " " : " ") : "")
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isActive ? Font.Bold : Font.Normal
              color: isActive ? "#0a0a0f" : Color.foreground
            }

            MouseArea {
              id: folderSortMouse
              anchors.fill: parent
              enabled: folderWidgetRoot.foldersTop
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: folderWidgetRoot.setFolderSort(modelData.id)
            }
          }
        }
      }

      // Item Spacing Slider
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(10)
        Layout.rightMargin: Style.space(10)
        Layout.topMargin: 2

        Text {
          text: "ITEM SPACING"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        }

        Item { Layout.fillWidth: true }

        Text {
          text: folderWidgetRoot.itemSpacing + " px"
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.Bold
          color: Color.accent
        }
      }

      Rectangle {
        id: spacingTrack
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(14)
        Layout.rightMargin: Style.space(14)
        Layout.topMargin: 4
        Layout.bottomMargin: 6
        implicitHeight: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.12)

        readonly property real frac: (folderWidgetRoot.itemSpacing - folderWidgetRoot.spacingMin) / (folderWidgetRoot.spacingMax - folderWidgetRoot.spacingMin)

        Rectangle {
          height: parent.height
          width: Math.max(parent.height, spacingKnob.x + spacingKnob.width / 2)
          radius: 3
          color: Color.accent
        }

        Rectangle {
          id: spacingKnob
          x: spacingTrack.frac * (spacingTrack.width - width)
          anchors.verticalCenter: parent.verticalCenter
          width: 14
          height: 14
          radius: 7
          color: Color.accent
          border.color: "#ffffff"
          border.width: 2
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -8
          cursorShape: Qt.PointingHandCursor
          function setVal(mx) {
            var f = Math.max(0, Math.min(1, (mx - 8) / spacingTrack.width))
            var v = folderWidgetRoot.spacingMin + f * (folderWidgetRoot.spacingMax - folderWidgetRoot.spacingMin)
            folderWidgetRoot.itemSpacing = Math.round(v / 2) * 2
          }
          onPressed: function(mouse) { setVal(mouse.x) }
          onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x) }
          // Persist once on release; each save spawns a write and reloads every widget's settings
          onReleased: folderWidgetRoot.saveSetting("item_spacing", folderWidgetRoot.itemSpacing)
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📁 Main Widget Content
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    // Top Navigation & Location Header
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      // Back Button (shown if parent exists)
      Rectangle {
        visible: folderWidgetRoot.parentFolder !== "" && folderWidgetRoot.parentFolder !== folderWidgetRoot.currentFolder
        width: 26
        height: 26
        radius: 13
        color: backHover.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf060"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Color.foreground
        }

        MouseArea {
          id: backHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: folderWidgetRoot.navigateUp()
        }
      }

      // Folder Icon
      Text {
        text: "\uf07b"
        font.family: Style.font.family
        font.pixelSize: 14
        color: Color.accent
      }

      // Folder Name Title
      Text {
        Layout.fillWidth: true
        text: folderWidgetRoot.currentFolderName
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Color.foreground
        style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.8)
        elide: Text.ElideRight
      }

      // Pick / Change Folder Button
      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: pickBtnHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf07c"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Color.accent
        }

        MouseArea {
          id: pickBtnHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: folderWidgetRoot.pickFolder()
        }
      }

      // Open in File Manager Button
      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: fmBtnHover.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf08e"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }

        MouseArea {
          id: fmBtnHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: folderWidgetRoot.openInFileManager()
        }
      }

      // Remove / Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeFolderMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeFolderMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(folderWidgetRoot.widgetId, false, folderWidgetRoot.monitorName)
            }
          }
        }
      }

      // Move Grip Button (when in edit mode)
      Rectangle {
        id: folderGripButton
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: folderGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: folderGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: folderWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, folderWidgetRoot.screenWidth - folderWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, folderWidgetRoot.screenHeight - folderWidgetRoot.height - 10)

          onPressed: folderWidgetRoot.customGripDragging = true
          onReleased: function() {
            folderWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, folderWidgetRoot.screenWidth - folderWidgetRoot.width - 10)
            var maxY = Math.max(10, folderWidgetRoot.screenHeight - folderWidgetRoot.height - 10)
            var snappedX = folderWidgetRoot.snapVal(folderWidgetRoot.targetItem.x)
            var snappedY = folderWidgetRoot.snapVal(folderWidgetRoot.targetItem.y)
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            folderWidgetRoot.targetItem.x = snappedX
            folderWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(folderWidgetRoot.widgetId, snappedX, snappedY, folderWidgetRoot.snapVal(folderWidgetRoot.width), folderWidgetRoot.snapVal(folderWidgetRoot.height), folderWidgetRoot.monitorName)
            }
          }
          onCanceled: folderWidgetRoot.customGripDragging = false
        }
      }
    }

    // Details Column Headers (click to sort)
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 6
      Layout.rightMargin: 6
      visible: folderWidgetRoot.detailsView && folderWidgetRoot.folderItems.length > 0
      spacing: Style.space(8)

      // Lines the Name header up with the names past the row icons
      Item { Layout.preferredWidth: 18 }

      Repeater {
        model: [
          { key: "name", label: "Name", width: -1, shown: true },
          { key: "size", label: "Size", width: folderWidgetRoot.sizeColWidth, shown: true },
          { key: "date", label: "Modified", width: folderWidgetRoot.dateColWidth, shown: folderWidgetRoot.showDateCol }
        ]

        Item {
          required property var modelData
          readonly property bool isActive: folderWidgetRoot.sortBy === modelData.key
          visible: modelData.shown
          Layout.fillWidth: modelData.width < 0
          Layout.preferredWidth: modelData.width
          implicitHeight: 16

          Text {
            anchors.fill: parent
            horizontalAlignment: modelData.width < 0 ? Text.AlignLeft : Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: modelData.label + (isActive ? (folderWidgetRoot.sortDesc ? " " : " ") : "")
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: (isActive || headerMouse.containsMouse) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
            style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
            styleColor: Qt.rgba(0, 0, 0, 0.8)
            elide: Text.ElideRight
          }

          MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: folderWidgetRoot.setSort(modelData.key)
          }
        }
      }
    }

    // Grid of Items in Folder
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Empty State
      ColumnLayout {
        anchors.centerIn: parent
        z: 2
        visible: folderWidgetRoot.folderItems.length === 0 && !folderWidgetRoot.isLoading
        spacing: Style.space(6)

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "\uf115"
          font.family: Style.font.family
          font.pixelSize: 32
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Folder is empty"
          font.family: Style.font.family
          font.pixelSize: 12
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
          styleColor: Qt.rgba(0, 0, 0, 0.8)
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          implicitWidth: emptyPickRow.implicitWidth + 24
          implicitHeight: 30
          radius: 15
          color: emptyPickMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.10)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
          border.width: 1

          RowLayout {
            id: emptyPickRow
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: "\uf07c"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.accent
            }
            Text {
              text: "Choose Folder..."
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Color.foreground
            }
          }

          MouseArea {
            id: emptyPickMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: folderWidgetRoot.pickFolder()
          }
        }
      }

      GridView {
        id: folderGridView
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: !folderWidgetRoot.detailsView && folderWidgetRoot.folderItems.length > 0

        // Tiles stay a fixed size; spacing only widens the gap between them
        readonly property int cols: Math.max(2, Math.floor(width / (80 + folderWidgetRoot.itemSpacing)))
        cellWidth: Math.floor(width / cols)
        cellHeight: folderWidgetRoot.tileContentHeight + folderWidgetRoot.itemSpacing

        // Hidden view gets no model so it builds no delegates
        model: folderWidgetRoot.detailsView ? [] : folderWidgetRoot.sortedItems

        delegate: Rectangle {
          id: itemTile
          required property var modelData
          width: folderGridView.cellWidth
          height: folderGridView.cellHeight
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            anchors.margins: folderWidgetRoot.itemSpacing / 2 - folderWidgetRoot.tileHoverPad
            radius: 12
            color: itemMouse.containsMouse ? (folderWidgetRoot.transparentBg ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.10)) : "transparent"
            border.color: itemMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : "transparent"
            border.width: 1
            scale: itemMouse.pressed ? 0.94 : (itemMouse.containsMouse ? 1.03 : 1.0)

            Behavior on scale {
              NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on color {
              ColorAnimation { duration: 150 }
            }

            // Icon pinned to the top and the name hung below it, so icons line
            // up across a row whether names take one line or two
            Item {
              id: tileIcon
              anchors.top: parent.top
              anchors.topMargin: folderWidgetRoot.tileHoverPad
              anchors.horizontalCenter: parent.horizontalCenter
              width: folderWidgetRoot.tileIconSize
              height: folderWidgetRoot.tileIconSize

              // Image icon (from system icon theme e.g. Papirus via Quickshell icon provider)
              Image {
                id: fileIconImage
                anchors.fill: parent
                source: folderWidgetRoot.iconSource(modelData)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
              }

              // Fallback Font Glyph if image provider doesn't have it
              Text {
                visible: fileIconImage.status !== Image.Ready
                anchors.centerIn: parent
                text: folderWidgetRoot.getFileGlyph(modelData)
                font.family: Style.font.family
                font.pixelSize: 24
                color: folderWidgetRoot.glyphColor(modelData)
              }
            }

            // Display Name
            Text {
              anchors.top: tileIcon.bottom
              anchors.topMargin: folderWidgetRoot.tileIconGap
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: folderWidgetRoot.tileHoverPad
              anchors.rightMargin: folderWidgetRoot.tileHoverPad
              text: modelData.display_name || modelData.name || ""
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.DemiBold
              color: itemMouse.containsMouse ? Color.accent : Color.foreground
              style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
              styleColor: Qt.rgba(0, 0, 0, 0.85)
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.Wrap
            }
          }

          // On the cell rather than the highlight, so the hit area doesn't
          // grow and shrink with the hover/press scale
          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              folderWidgetRoot.openItem(modelData)
            }
          }
        }
      }

      // Details List (icon, name, size, modified)
      ListView {
        id: folderListView
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: folderWidgetRoot.detailsView && folderWidgetRoot.folderItems.length > 0
        spacing: Math.round(folderWidgetRoot.itemSpacing / 2)

        model: folderWidgetRoot.detailsView ? folderWidgetRoot.sortedItems : []

        delegate: Rectangle {
          id: itemRow
          required property var modelData
          width: folderListView.width
          height: 28
          radius: 6
          color: rowMouse.containsMouse ? (folderWidgetRoot.transparentBg ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.10)) : "transparent"
          border.color: rowMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : "transparent"
          border.width: 1

          Behavior on color {
            ColorAnimation { duration: 150 }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: Style.space(8)

            Item {
              Layout.preferredWidth: 18
              Layout.preferredHeight: 18

              Image {
                id: rowIconImage
                anchors.fill: parent
                source: folderWidgetRoot.iconSource(modelData)
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
              }

              Text {
                visible: rowIconImage.status !== Image.Ready
                anchors.centerIn: parent
                text: folderWidgetRoot.getFileGlyph(modelData)
                font.family: Style.font.family
                font.pixelSize: 12
                color: folderWidgetRoot.glyphColor(modelData)
              }
            }

            Text {
              Layout.fillWidth: true
              text: modelData.display_name || modelData.name || ""
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: rowMouse.containsMouse ? Color.accent : Color.foreground
              style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
              styleColor: Qt.rgba(0, 0, 0, 0.85)
              elide: Text.ElideRight
            }

            Text {
              Layout.preferredWidth: folderWidgetRoot.sizeColWidth
              text: modelData.is_dir ? "—" : (modelData.size || "")
              font.family: Style.font.family
              font.pixelSize: 10
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
              style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
              styleColor: Qt.rgba(0, 0, 0, 0.85)
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }

            Text {
              visible: folderWidgetRoot.showDateCol
              Layout.preferredWidth: folderWidgetRoot.dateColWidth
              text: folderWidgetRoot.formatModified(modelData.mtime)
              font.family: Style.font.family
              font.pixelSize: 10
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
              style: folderWidgetRoot.transparentBg ? Text.Outline : Text.Normal
              styleColor: Qt.rgba(0, 0, 0, 0.85)
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: folderWidgetRoot.openItem(modelData)
          }
        }
      }
    }
  }
}
