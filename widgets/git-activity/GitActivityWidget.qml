import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

// Import base WidgetCard from the shared repository link
import "../../shared"

WidgetCard {
  id: gitWidgetRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Placement Settings
  // ---------------------------------------------------------------------------
  widgetId: "git_activity"
  title: "Git Contribution Radar"
  icon: "\uf126"
  showHeader: false // Custom integrated header with branch badge & status

  defaultX: screenWidth - width - Style.space(24)
  defaultY: 340

  width: 380
  height: 460
  menuWidth: 320

  // ---------------------------------------------------------------------------
  // 🌿 Git State & Data
  // ---------------------------------------------------------------------------
  property string activeRepoName: "No Tracked Repos"
  property string activeRepoPath: ""
  property string branchName: ""
  property int uncommittedCount: 0
  property int totalCommits: 0
  property int streakDays: 0
  property var heatmapMatrix: []
  property var recentCommitsList: []
  property var detectedReposList: []
  property string hoveredCellInfo: ""
  property bool showRecentCommits: true
  property bool hasRepos: detectedReposList.length > 0

  function selectRepo(path) {
    activeRepoPath = path
    gitPulseProc.command = ["/home/dagyr/Projects/desktop-widgets/widgets/git-activity/git_pulse.py", path]
    if (!gitPulseProc.running) gitPulseProc.running = true
  }

  function removeRepo(path) {
    gitPulseProc.command = ["/home/dagyr/Projects/desktop-widgets/widgets/git-activity/git_pulse.py", "remove:" + path]
    if (!gitPulseProc.running) gitPulseProc.running = true
  }

  function getLevelColor(level) {
    if (level === 4) return "#34d399" // Electric mint
    if (level === 3) return "#10b981" // Emerald
    if (level === 2) return Qt.rgba(16/255, 185/255, 129/255, 0.65)
    if (level === 1) return Qt.rgba(16/255, 185/255, 129/255, 0.35)
    return Qt.rgba(1, 1, 1, 0.06)      // Blank cell
  }

  Process {
    id: gitPulseProc
    command: ["/home/dagyr/Projects/desktop-widgets/widgets/git-activity/git_pulse.py"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          if (data.repo_name !== undefined) gitWidgetRoot.activeRepoName = data.repo_name
          if (data.repo_path !== undefined) gitWidgetRoot.activeRepoPath = data.repo_path
          if (data.branch !== undefined) gitWidgetRoot.branchName = data.branch
          if (data.uncommitted_count !== undefined) gitWidgetRoot.uncommittedCount = data.uncommitted_count
          if (data.total_commits !== undefined) gitWidgetRoot.totalCommits = data.total_commits
          if (data.streak_days !== undefined) gitWidgetRoot.streakDays = data.streak_days
          if (Array.isArray(data.heatmap)) gitWidgetRoot.heatmapMatrix = data.heatmap
          if (Array.isArray(data.recent_commits)) gitWidgetRoot.recentCommitsList = data.recent_commits
          if (Array.isArray(data.detected_repos)) {
            gitWidgetRoot.detectedReposList = data.detected_repos
            gitWidgetRoot.hasRepos = data.has_repos !== undefined ? data.has_repos : (data.detected_repos.length > 0)
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 15000 // Poll git pulse every 15s
    running: true
    repeat: true
    onTriggered: {
      if (!gitPulseProc.running) gitPulseProc.running = true
    }
  }

  // ---------------------------------------------------------------------------
  // 📂 Robust & Functional Right-Click Context Menu
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      // 1. Tracked Repositories Header
      Text {
        text: "TRACKED REPOSITORIES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Empty placeholder when no repos are added
      Text {
        visible: gitWidgetRoot.detectedReposList.length === 0
        text: "No repositories added yet"
        font.family: Style.font.family
        font.pixelSize: 11
        font.italic: true
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
        Layout.leftMargin: 8
        Layout.topMargin: 2
        Layout.bottomMargin: 2
      }

      // All Repositories Option (only shown when 2+ repos tracked)
      Rectangle {
        visible: gitWidgetRoot.detectedReposList.length > 1
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        readonly property bool isCurrent: gitWidgetRoot.activeRepoPath === "ALL"
        color: allRepoMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (isCurrent ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf005"
            font.family: Style.font.family
            font.pixelSize: 11
            color: isCurrent ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "All Repositories (Combined Radar)"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: isCurrent ? Font.Bold : Font.Normal
            color: isCurrent ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8)
            elide: Text.ElideRight
          }

          Text {
            visible: isCurrent
            text: "\uf00c"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.accent
          }
        }

        MouseArea {
          id: allRepoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gitWidgetRoot.selectRepo("ALL")
        }
      }

      Repeater {
        model: gitWidgetRoot.detectedReposList

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          readonly property bool isCurrent: gitWidgetRoot.activeRepoPath === modelData.path
          color: rMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (isCurrent ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(6)

            Text {
              text: "\uf126"
              font.family: Style.font.family
              font.pixelSize: 11
              color: isCurrent ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }

            Text {
              Layout.fillWidth: true
              text: modelData.name
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: isCurrent ? Font.Bold : Font.Normal
              color: isCurrent ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8)
              elide: Text.ElideRight
            }

            Text {
              visible: isCurrent
              text: "\uf00c"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.accent
            }

            // Remove button for this repo
            Rectangle {
              width: 20
              height: 20
              radius: 4
              color: delMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : "transparent"

              Text {
                anchors.centerIn: parent
                text: "\uf1f8"
                font.family: Style.font.family
                font.pixelSize: 10
                color: delMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
              }

              MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  gitWidgetRoot.removeRepo(modelData.path)
                }
              }
            }
          }

          MouseArea {
            id: rMouse
            anchors.fill: parent
            anchors.rightMargin: 26 // Leave room for trash button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gitWidgetRoot.selectRepo(modelData.path)
          }
        }
      }

      // Add Repository Option
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: customRepoMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf067"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Add Repository..."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            elide: Text.ElideRight
          }

          Text {
            text: "\uf07c"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: customRepoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            gitWidgetRoot.contextMenuOpen = false
            gitWidgetRoot.selectRepo("pick_dialog")
          }
        }
      }

      // 2. Display Preferences
      Text {
        text: "DISPLAY PREFERENCES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Toggle Recent Commits Timeline
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: comMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf017"
            font.family: Style.font.family
            font.pixelSize: 11
            color: gitWidgetRoot.showRecentCommits ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Show Recent Commits Timeline"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: gitWidgetRoot.showRecentCommits ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: gitWidgetRoot.showRecentCommits ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: comMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gitWidgetRoot.showRecentCommits = !gitWidgetRoot.showRecentCommits
        }
      }

      // 3. Quick Actions
      Text {
        text: "ACTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Open Repository in Terminal (visible when a valid single repo is selected)
      Rectangle {
        visible: gitWidgetRoot.hasRepos && gitWidgetRoot.activeRepoPath !== "" && gitWidgetRoot.activeRepoPath !== "ALL"
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: edMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf120"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Open Repo in Terminal"
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
          id: edMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            gitWidgetRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-terminal-exec", "--dir", gitWidgetRoot.activeRepoPath])
          }
        }
      }

      // Refresh Git Pulse
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refGitMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

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
            text: "Refresh Git Pulse"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: refGitMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!gitPulseProc.running) gitPulseProc.running = true
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 Main Widget Body
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(12)

    // -------------------------------------------------------------------------
    // 🏷️ Header: Icon, Repo Title, Branch Badge & Edit Controls
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Rectangle {
        width: 30
        height: 30
        radius: 15
        color: Qt.rgba(16/255, 185/255, 129/255, 0.18)
        border.color: Qt.rgba(16/255, 185/255, 129/255, 0.45)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf126"
          font.family: Style.font.family
          font.pixelSize: 13
          color: "#10b981"
        }
      }

      ColumnLayout {
        spacing: 0
        Text {
          text: gitWidgetRoot.hasRepos ? gitWidgetRoot.activeRepoName : "Git Tracker"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Color.foreground
          elide: Text.ElideRight
        }
        RowLayout {
          spacing: 4
          visible: gitWidgetRoot.hasRepos && gitWidgetRoot.branchName !== "" && gitWidgetRoot.branchName !== "none"
          Text {
            text: "\uf418"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Color.accent
          }
          Text {
            text: gitWidgetRoot.branchName
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Uncommitted Status Pill
      Rectangle {
        visible: gitWidgetRoot.hasRepos && gitWidgetRoot.activeRepoPath !== "ALL" && gitWidgetRoot.activeRepoPath !== ""
        implicitWidth: uncomRow.implicitWidth + 12
        implicitHeight: 20
        radius: 10
        color: gitWidgetRoot.uncommittedCount > 0 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.06)
        border.color: gitWidgetRoot.uncommittedCount > 0 ? Color.accent : "transparent"
        border.width: 1

        RowLayout {
          id: uncomRow
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: gitWidgetRoot.uncommittedCount > 0 ? "\uf044" : "\uf00c"
            font.family: Style.font.family
            font.pixelSize: 8
            color: gitWidgetRoot.uncommittedCount > 0 ? Color.accent : "#10b981"
          }

          Text {
            text: gitWidgetRoot.uncommittedCount > 0 ? (gitWidgetRoot.uncommittedCount + " diffs") : "clean"
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: gitWidgetRoot.uncommittedCount > 0 ? Color.accent : "#10b981"
          }
        }
      }

      // Close Button (Edit Mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(gitWidgetRoot.widgetId, false)
            }
          }
        }
      }

      // Move Grip Button (Edit Mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        implicitWidth: gripRow.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: customGripMouse.drag.active ? Color.accent : (customGripMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
        border.width: 1

        RowLayout {
          id: gripRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "\uf0b2"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.accent
          }
          Text {
            text: "Move"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Color.foreground
          }
        }

        MouseArea {
          id: customGripMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: gitWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, gitWidgetRoot.screenWidth - gitWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, gitWidgetRoot.screenHeight - gitWidgetRoot.height - 10)

          onPressed: gitWidgetRoot.customGripDragging = true
          onReleased: function() {
            gitWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, gitWidgetRoot.screenWidth - gitWidgetRoot.width - 10)
            var maxY = Math.max(10, gitWidgetRoot.screenHeight - gitWidgetRoot.height - 10)
            var snappedX = Math.round(gitWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(gitWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            gitWidgetRoot.targetItem.x = snappedX
            gitWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(gitWidgetRoot.widgetId, snappedX, snappedY)
            }
          }
          onCanceled: gitWidgetRoot.customGripDragging = false
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📭 Empty State: Displayed when no repositories are tracked
    // -------------------------------------------------------------------------
    Rectangle {
      visible: !gitWidgetRoot.hasRepos || gitWidgetRoot.detectedReposList.length === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: Qt.rgba(1, 1, 1, 0.03)
      border.color: Qt.rgba(1, 1, 1, 0.07)
      border.width: 1

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.space(12)

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: 52
          height: 52
          radius: 26
          color: Qt.rgba(16/255, 185/255, 129/255, 0.15)
          border.color: Qt.rgba(16/255, 185/255, 129/255, 0.35)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf126"
            font.family: Style.font.family
            font.pixelSize: 22
            color: "#10b981"
          }
        }

        ColumnLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.space(4)

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Tracked Repositories"
            font.family: Style.font.family
            font.pixelSize: 14
            font.weight: Font.Bold
            color: Color.foreground
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 260
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: "Add your local git repositories to monitor commit streaks, activity radars, and branch changes."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          implicitWidth: addBtnRow.implicitWidth + 24
          implicitHeight: 32
          radius: 16
          color: addBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
          border.color: Color.accent
          border.width: 1

          RowLayout {
            id: addBtnRow
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: "\uf067"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.accent
            }

            Text {
              text: "Add Repository..."
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Color.foreground
            }
          }

          MouseArea {
            id: addBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              gitWidgetRoot.selectRepo("pick_dialog")
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🟩 12-Week Git Contribution Radar Heatmap Grid (when repos exist)
    // -------------------------------------------------------------------------
    Rectangle {
      visible: gitWidgetRoot.hasRepos && gitWidgetRoot.detectedReposList.length > 0
      Layout.fillWidth: true
      implicitHeight: 140
      radius: 12
      color: Qt.rgba(1, 1, 1, 0.04)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(8)

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "12-WEEK CONTRIBUTION RADAR"
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
          }
          Item { Layout.fillWidth: true }
          Text {
            text: gitWidgetRoot.hoveredCellInfo !== "" ? gitWidgetRoot.hoveredCellInfo : (gitWidgetRoot.totalCommits + " commits")
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: Color.accent
          }
        }

        // 7 Rows x 12 Columns Grid
        GridLayout {
          Layout.alignment: Qt.AlignHCenter
          columns: 12
          rows: 7
          rowSpacing: 4
          columnSpacing: 4
          flow: GridLayout.TopToBottom // Days vertically (Sun-Sat), weeks horizontally

          Repeater {
            model: gitWidgetRoot.heatmapMatrix

            Rectangle {
              required property var modelData
              width: 20
              height: 10
              radius: 2
              color: gitWidgetRoot.getLevelColor(modelData.level)
              border.color: modelData.is_today ? Color.accent : (cellMouse.containsMouse ? "#ffffff" : "transparent")
              border.width: modelData.is_today || cellMouse.containsMouse ? 1 : 0

              MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  gitWidgetRoot.hoveredCellInfo = modelData.date + ": " + modelData.count + (modelData.count === 1 ? " commit" : " commits")
                }
                onExited: {
                  gitWidgetRoot.hoveredCellInfo = ""
                }
              }
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🔥 Streaks & Stats Metric Cards
    // -------------------------------------------------------------------------
    RowLayout {
      visible: gitWidgetRoot.hasRepos && gitWidgetRoot.detectedReposList.length > 0
      Layout.fillWidth: true
      spacing: Style.space(8)

      // Streak Metric
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf06d"
            font.family: Style.font.family
            font.pixelSize: 16
            color: "#f59e0b" // Amber flame
          }

          ColumnLayout {
            spacing: 0
            Text {
              text: gitWidgetRoot.streakDays + (gitWidgetRoot.streakDays === 1 ? " Day" : " Days")
              font.family: Style.font.family
              font.pixelSize: 12
              font.weight: Font.Bold
              color: Color.foreground
            }
            Text {
              text: "Current Streak"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }
          }
        }
      }

      // Total Commits Metric
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf0c9"
            font.family: Style.font.family
            font.pixelSize: 14
            color: "#10b981" // Emerald
          }

          ColumnLayout {
            spacing: 0
            Text {
              text: gitWidgetRoot.totalCommits.toString()
              font.family: Style.font.family
              font.pixelSize: 12
              font.weight: Font.Bold
              color: Color.foreground
            }
            Text {
              text: "Total Commits"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🕒 Recent Commit Timeline
    // -------------------------------------------------------------------------
    Text {
      visible: gitWidgetRoot.hasRepos && gitWidgetRoot.showRecentCommits && gitWidgetRoot.recentCommitsList.length > 0
      text: "RECENT COMMIT ACTIVITY"
      font.family: Style.font.family
      font.pixelSize: 9
      font.weight: Font.Bold
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
      Layout.leftMargin: 2
      Layout.topMargin: 2
    }

    ColumnLayout {
      visible: gitWidgetRoot.hasRepos && gitWidgetRoot.showRecentCommits && gitWidgetRoot.recentCommitsList.length > 0
      Layout.fillWidth: true
      spacing: Style.space(6)

      Repeater {
        model: gitWidgetRoot.recentCommitsList

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 38
          radius: 8
          color: Qt.rgba(1, 1, 1, 0.04)
          border.color: Qt.rgba(1, 1, 1, 0.06)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            // Hash Badge
            Rectangle {
              implicitWidth: hashText.implicitWidth + 8
              implicitHeight: 18
              radius: 4
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)

              Text {
                id: hashText
                anchors.centerIn: parent
                text: modelData.hash
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: Color.accent
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                Layout.fillWidth: true
                text: modelData.msg
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.foreground
                elide: Text.ElideRight
              }

              Text {
                text: modelData.time
                font.family: Style.font.family
                font.pixelSize: 9
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
              }
            }
          }
        }
      }
    }

    Item { Layout.fillHeight: true }
  }
}
