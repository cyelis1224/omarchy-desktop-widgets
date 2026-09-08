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
            folderWidgetRoot.folderItems = Array.isArray(data.items) ? data.items : []
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
            folderWidgetRoot.folderItems = Array.isArray(data.items) ? data.items : []
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

  // Auto-refresh folder every 10 seconds
  Timer {
    interval: 10000
    running: !folderWidgetRoot.isLoading && !folderWidgetRoot.contextMenuOpen && !pickProc.running && folderWidgetRoot.currentFolder !== ""
    repeat: true
    onTriggered: {
      if (!folderProc.running && folderWidgetRoot.currentFolder !== "") {
        folderProc.command = [folderWidgetRoot.folderScriptPath, folderWidgetRoot.currentFolder]
        folderProc.running = true
      }
    }
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
        visible: folderWidgetRoot.folderItems.length > 0

        readonly property int cols: Math.max(2, Math.floor(width / 88))
        cellWidth: Math.floor(width / cols)
        cellHeight: 92

        model: folderWidgetRoot.folderItems

        delegate: Rectangle {
          id: itemTile
          required property var modelData
          width: folderGridView.cellWidth
          height: folderGridView.cellHeight
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            anchors.margins: 4
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

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 6
              spacing: 3

              // Icon: App Icon for .desktop, or System Icon, or Font Glyph
              Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                // Image icon (from system icon theme e.g. Papirus via Quickshell icon provider)
                Image {
                  id: fileIconImage
                  anchors.fill: parent
                  source: {
                    if (modelData.icon) {
                      if (modelData.icon.startsWith("/")) return "file://" + modelData.icon
                      return Quickshell.iconPath(modelData.icon, true)
                    }
                    return ""
                  }
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
                  color: modelData.is_dir ? "#FBBF24" : (modelData.is_desktop ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8))
                }
              }

              // Display Name
              Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
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
      }
    }
  }
}
