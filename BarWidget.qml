import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "dagyr.desktop-widgets"

  property bool updateAvailable: false
  property string currentVersion: "1.0.0"
  property string currentCommit: ""
  property string newVersion: "1.0.0"
  property string newCommit: ""
  property int commitsBehind: 0
  property string commitMessage: ""
  property bool isUpdating: false
  property string updateStatusText: ""

  property bool popupOpen: false
  readonly property bool opened: popupOpen

  function open() { popupOpen = true }
  function close() { popupOpen = false; isUpdating = false; }
  function toggleDialog() { popupOpen = !popupOpen }

  readonly property string checkerScriptPath: {
    var u = Qt.resolvedUrl("scripts/check-update.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function refresh() {
    if (!checkProc.running) {
      checkProc.command = [root.checkerScriptPath, "check"]
      checkProc.running = true
    }
  }

  function applyUpdate() {
    root.isUpdating = true
    root.updateStatusText = "Applying update & syncing files..."
    applyProc.command = [root.checkerScriptPath, "apply"]
    if (!applyProc.running) {
      applyProc.running = true
    }
  }

  // Only take space and render when an update is available!
  visible: root.updateAvailable
  implicitWidth: root.updateAvailable ? button.implicitWidth : 0
  implicitHeight: root.updateAvailable ? button.implicitHeight : 0

  Behavior on implicitWidth {
    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
  }

  // ---------------------------------------------------------------------------
  // 🔔 Status Bar Button (fa-download icon with accent color & pulsing dot)
  // ---------------------------------------------------------------------------
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf019"
    active: true
    activeColor: Color.accent
    useActiveColor: true
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "Desktop Widgets update available: v" + root.currentVersion + " → v" + root.newVersion + "\n[Click to review and update]"

    onPressed: function(b) {
      if (b === Qt.LeftButton) {
        root.toggleDialog()
      }
    }

    // Subtle pulsing indicator badge in the top right corner
    Rectangle {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.space(4)
      anchors.rightMargin: Style.space(4)
      width: Style.space(6)
      height: Style.space(6)
      radius: Style.space(3)
      color: Color.accent

      SequentialAnimation on opacity {
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🪟 Update Dialog Window (Native Omarchy PopupCard)
  // ---------------------------------------------------------------------------
  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(370))
    contentHeight: popup.fittedContentHeight(mainCol.implicitHeight)

    Column {
      id: mainCol
      width: parent.width
      spacing: Style.space(12)

      // Header Row
      Row {
        width: parent.width
        spacing: Style.space(10)

        // Accent Icon Badge
        BorderSurface {
          width: Style.space(36)
          height: Style.space(36)
          radius: Style.space(18)
          color: Util.alpha(Color.accent, 0.15)
          borderSpec: Border.none()
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "\uf019"
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            color: Color.accent
          }
        }

        Column {
          width: parent.width - Style.space(76)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Desktop Widgets Update"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: "An update is ready for installation"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        // Close 'X' Button
        Rectangle {
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.space(11)
          anchors.verticalCenter: parent.verticalCenter
          color: closeMouse.containsMouse ? Util.alpha(Color.foreground, 0.2) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 10
            color: root.bar ? root.bar.foreground : Color.foreground
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }

      PanelSeparator { width: parent.width }

      // Version Comparison Cards
      BorderSurface {
        width: parent.width
        radius: Style.space(10)
        color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.05)
        borderSpec: Border.none()

        Row {
          anchors.centerIn: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(20)

          // Current Version Card
          Column {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "CURRENT"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
              font.family: Style.font.family
              font.pixelSize: 9
              font.bold: true
            }

            Text {
              text: "v" + root.currentVersion
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              visible: root.currentCommit !== ""
              text: "(" + root.currentCommit + ")"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          // Transfer Arrow
          Text {
            text: "➜"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          // Available Version Card
          Column {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              spacing: Style.space(6)

              Text {
                text: "AVAILABLE"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: 9
                font.bold: true
              }

              Rectangle {
                height: 14
                width: newBadge.implicitWidth + 8
                radius: 7
                color: Color.accent
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  id: newBadge
                  anchors.centerIn: parent
                  text: "NEW"
                  font.family: Style.font.family
                  font.pixelSize: 8
                  font.bold: true
                  color: Color.background
                }
              }
            }

            Text {
              text: "v" + root.newVersion
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              visible: root.newCommit !== ""
              text: "(" + root.newCommit + ")"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // Commit & Changelog Summary Box
      BorderSurface {
        visible: root.commitMessage !== "" || root.commitsBehind > 0
        width: parent.width
        radius: Style.space(8)
        color: Util.alpha(Color.accent, 0.08)
        borderSpec: Border.none()

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(4)

          Row {
            spacing: Style.space(6)

            Text {
              text: "\uf02b"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.accent
            }

            Text {
              text: root.commitsBehind > 0 ? (root.commitsBehind + " new commit(s) upstream") : "What's New"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.accent
            }
          }

          Text {
            width: parent.width
            text: root.commitMessage !== "" ? root.commitMessage : "Includes enhancements, bug fixes, and performance updates."
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }

      // Updating in-progress Banner
      BorderSurface {
        visible: root.isUpdating
        width: parent.width
        radius: Style.space(8)
        color: Util.alpha(Color.accent, 0.12)
        borderSpec: Border.none()

        Row {
          anchors.centerIn: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          Text {
            text: "\uf110"
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimation on rotation {
              from: 0
              to: 360
              duration: 1100
              loops: Animation.Infinite
            }
          }

          Text {
            text: root.updateStatusText || "Updating plugin and reloading shell..."
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      PanelSeparator { width: parent.width }

      // Action Buttons (Cancel and Update)
      Row {
        width: parent.width
        spacing: Style.space(10)
        visible: !root.isUpdating

        Button {
          width: (parent.width - Style.space(10)) / 2
          text: "Cancel"
          iconText: "\uf00d"
          bordered: true
          fontSize: Style.font.caption
          onClicked: root.close()
        }

        Button {
          width: (parent.width - Style.space(10)) / 2
          text: "Update Now"
          iconText: "\uf019"
          bordered: true
          selected: true
          accent: Color.accent
          fontSize: Style.font.caption
          onClicked: root.applyUpdate()
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ⚙️ Background Processes & Timers
  // ---------------------------------------------------------------------------

  // Update check process
  Process {
    id: checkProc
    command: [root.checkerScriptPath, "check"]

    property string buffer: ""

    onStarted: {
      buffer = ""
    }

    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        checkProc.buffer += str
        try {
          var data = JSON.parse(checkProc.buffer)
          var isAvail = (data.update_available === true)
          if (data.current_version && data.new_version && data.current_version === data.new_version && !data.is_mock) {
            isAvail = false
          }
          root.updateAvailable = isAvail
          if (data.current_version) root.currentVersion = data.current_version
          if (data.current_commit) root.currentCommit = data.current_commit
          if (data.new_version) root.newVersion = data.new_version
          if (data.new_commit) root.newCommit = data.new_commit
          if (data.commits_behind !== undefined) root.commitsBehind = data.commits_behind
          if (data.commit_message) root.commitMessage = data.commit_message
          checkProc.buffer = ""
        } catch (e) {}
      }
    }

    onExited: function(exitCode) {
      if (checkProc.buffer !== "") {
        try {
          var data = JSON.parse(checkProc.buffer)
          var isAvail = (data.update_available === true)
          if (data.current_version && data.new_version && data.current_version === data.new_version && !data.is_mock) {
            isAvail = false
          }
          root.updateAvailable = isAvail
          if (data.current_version) root.currentVersion = data.current_version
          if (data.current_commit) root.currentCommit = data.current_commit
          if (data.new_version) root.newVersion = data.new_version
          if (data.new_commit) root.newCommit = data.new_commit
          if (data.commits_behind !== undefined) root.commitsBehind = data.commits_behind
          if (data.commit_message) root.commitMessage = data.commit_message
        } catch (e) {}
        checkProc.buffer = ""
      }
    }
  }

  // Update execution process
  Process {
    id: applyProc
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.updateStatusText = "Update complete! Shell is reloading..."
        root.updateAvailable = false
      } else {
        root.isUpdating = false
        root.updateStatusText = "Update encountered an error. Please try again."
      }
    }
  }

  // Initial startup delay check timer (runs 4s after shell loads)
  Timer {
    interval: 4000
    running: true
    repeat: false
    onTriggered: root.refresh()
  }

  // Periodic recurring check timer (every 2 hours)
  Timer {
    interval: 7200000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // ---------------------------------------------------------------------------
  // 📡 IPC Control Handler
  // ---------------------------------------------------------------------------
  IpcHandler {
    target: "dagyr.desktop-widgets-update"

    function check(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggleDialog() }
  }
}
