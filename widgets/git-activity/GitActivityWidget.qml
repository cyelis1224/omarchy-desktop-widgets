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

  width: 390
  height: 490
  menuWidth: 320

  // ---------------------------------------------------------------------------
  // 🌿 Git State & Data
  // ---------------------------------------------------------------------------
  property string activeRepoName: "No Tracked Repos"
  property string activeRepoPath: ""
  property string branchName: ""
  property bool isRemoteRepo: false
  property string statusLabel: "clean"
  property int uncommittedCount: 0
  property int totalCommits: 0
  property int streakDays: 0
  property var heatmapMatrix: []
  property var recentCommitsList: []
  property var pullRequestsList: []
  property var issuesList: []
  property bool hasGithub: false
  property string githubSlug: ""
  property string activeTab: "commits" // "commits" | "prs" | "issues"
  property var detectedReposList: []
  property string hoveredCellInfo: ""
  property bool showRecentCommits: true
  property bool hasRepos: detectedReposList.length > 0

  function selectRepo(path) {
    gitWidgetRoot.contextMenuOpen = false
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
          if (data.is_remote !== undefined) gitWidgetRoot.isRemoteRepo = data.is_remote
          if (data.status_label !== undefined) gitWidgetRoot.statusLabel = data.status_label
          if (data.uncommitted_count !== undefined) gitWidgetRoot.uncommittedCount = data.uncommitted_count
          if (data.total_commits !== undefined) gitWidgetRoot.totalCommits = data.total_commits
          if (data.streak_days !== undefined) gitWidgetRoot.streakDays = data.streak_days
          if (Array.isArray(data.heatmap)) gitWidgetRoot.heatmapMatrix = data.heatmap
          if (Array.isArray(data.recent_commits)) gitWidgetRoot.recentCommitsList = data.recent_commits
          if (Array.isArray(data.pull_requests)) gitWidgetRoot.pullRequestsList = data.pull_requests
          if (Array.isArray(data.issues)) gitWidgetRoot.issuesList = data.issues
          if (data.has_github !== undefined) gitWidgetRoot.hasGithub = data.has_github
          if (data.github_slug !== undefined) gitWidgetRoot.githubSlug = data.github_slug
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
          onClicked: {
            gitWidgetRoot.contextMenuOpen = false
            gitWidgetRoot.selectRepo("ALL")
          }
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
              text: modelData.is_remote ? "\uf0ac" : "\uf126"
              font.family: Style.font.family
              font.pixelSize: 11
              color: isCurrent ? Color.accent : (modelData.is_remote ? "#38bdf8" : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5))
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
            onClicked: {
              gitWidgetRoot.contextMenuOpen = false
              gitWidgetRoot.selectRepo(modelData.path)
            }
          }
        }
      }

      // Add Local Repo Option
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
            text: "\uf07c"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Add Local Repository..."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            elide: Text.ElideRight
          }

          Text {
            text: "\uf054"
            font.family: Style.font.family
            font.pixelSize: 9
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

      // Add Remote Git URL Option
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: remoteRepoMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0c1"
            font.family: Style.font.family
            font.pixelSize: 11
            color: "#38bdf8" // Sky blue for remote URL
          }

          Text {
            Layout.fillWidth: true
            text: "Add Remote Git URL..."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            elide: Text.ElideRight
          }

          Text {
            text: "\uf054"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: remoteRepoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            gitWidgetRoot.contextMenuOpen = false
            gitWidgetRoot.selectRepo("pick_remote_dialog")
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

      // Toggle Activity Stream
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
            text: "Show Activity Stream (Commits/PRs/Issues)"
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

      // Open in Terminal (for local repos)
      Rectangle {
        visible: gitWidgetRoot.hasRepos && !gitWidgetRoot.isRemoteRepo && gitWidgetRoot.activeRepoPath !== "" && gitWidgetRoot.activeRepoPath !== "ALL"
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

      // Open in Browser (for remote URLs or GitHub repos)
      Rectangle {
        visible: gitWidgetRoot.hasRepos && (gitWidgetRoot.isRemoteRepo || gitWidgetRoot.hasGithub) && gitWidgetRoot.activeRepoPath !== ""
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: openBrowserMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0ac"
            font.family: Style.font.family
            font.pixelSize: 11
            color: "#38bdf8"
          }

          Text {
            Layout.fillWidth: true
            text: "Open Repo in Browser"
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
          id: openBrowserMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            gitWidgetRoot.contextMenuOpen = false
            var url = gitWidgetRoot.activeRepoPath
            if (gitWidgetRoot.hasGithub && gitWidgetRoot.githubSlug) {
              url = "https://github.com/" + gitWidgetRoot.githubSlug
            } else if (url.startsWith("git@")) {
              url = "https://" + url.replace("git@", "").replace(":", "/")
            }
            if (url.endsWith(".git")) {
              url = url.substring(0, url.length - 4)
            }
            Qt.openUrlExternally(url)
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
            gitWidgetRoot.contextMenuOpen = false
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
    anchors.margins: Style.space(14)
    spacing: Style.space(10)

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
        color: gitWidgetRoot.isRemoteRepo ? Qt.rgba(56/255, 189/255, 248/255, 0.18) : Qt.rgba(16/255, 185/255, 129/255, 0.18)
        border.color: gitWidgetRoot.isRemoteRepo ? Qt.rgba(56/255, 189/255, 248/255, 0.45) : Qt.rgba(16/255, 185/255, 129/255, 0.45)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: gitWidgetRoot.isRemoteRepo ? "\uf0ac" : "\uf126"
          font.family: Style.font.family
          font.pixelSize: 13
          color: gitWidgetRoot.isRemoteRepo ? "#38bdf8" : "#10b981"
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

      // Status Pill (Diffs for local, Remote / Online for remote URLs)
      Rectangle {
        visible: gitWidgetRoot.hasRepos && gitWidgetRoot.activeRepoPath !== "ALL" && gitWidgetRoot.activeRepoPath !== ""
        implicitWidth: uncomRow.implicitWidth + 12
        implicitHeight: 20
        radius: 10
        color: gitWidgetRoot.isRemoteRepo ? Qt.rgba(56/255, 189/255, 248/255, 0.15) : (gitWidgetRoot.uncommittedCount > 0 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.06))
        border.color: gitWidgetRoot.isRemoteRepo ? Qt.rgba(56/255, 189/255, 248/255, 0.4) : (gitWidgetRoot.uncommittedCount > 0 ? Color.accent : "transparent")
        border.width: 1

        RowLayout {
          id: uncomRow
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: gitWidgetRoot.isRemoteRepo ? "\uf0c1" : (gitWidgetRoot.uncommittedCount > 0 ? "\uf044" : "\uf00c")
            font.family: Style.font.family
            font.pixelSize: 8
            color: gitWidgetRoot.isRemoteRepo ? "#38bdf8" : (gitWidgetRoot.uncommittedCount > 0 ? Color.accent : "#10b981")
          }

          Text {
            text: gitWidgetRoot.statusLabel
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: gitWidgetRoot.isRemoteRepo ? "#38bdf8" : (gitWidgetRoot.uncommittedCount > 0 ? Color.accent : "#10b981")
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
            text: "Track local git folders or remote Git URLs (GitHub, GitLab) to monitor commit streaks and radar activity."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.space(8)

          // Add Local Repo Button
          Rectangle {
            implicitWidth: addBtnRow.implicitWidth + 20
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
                text: "\uf07c"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.accent
              }

              Text {
                text: "Local Repo..."
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
              onClicked: gitWidgetRoot.selectRepo("pick_dialog")
            }
          }

          // Add Remote URL Button
          Rectangle {
            implicitWidth: addRemoteBtnRow.implicitWidth + 20
            implicitHeight: 32
            radius: 16
            color: addRemoteBtnMouse.containsMouse ? Qt.rgba(56/255, 189/255, 248/255, 0.3) : Qt.rgba(56/255, 189/255, 248/255, 0.18)
            border.color: "#38bdf8"
            border.width: 1

            RowLayout {
              id: addRemoteBtnRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                text: "\uf0c1"
                font.family: Style.font.family
                font.pixelSize: 10
                color: "#38bdf8"
              }

              Text {
                text: "Remote URL..."
                font.family: Style.font.family
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Color.foreground
              }
            }

            MouseArea {
              id: addRemoteBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: gitWidgetRoot.selectRepo("pick_remote_dialog")
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
      implicitHeight: 124
      radius: 12
      color: Qt.rgba(1, 1, 1, 0.04)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

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
          rowSpacing: 3
          columnSpacing: 3
          flow: GridLayout.TopToBottom // Days vertically (Sun-Sat), weeks horizontally

          Repeater {
            model: gitWidgetRoot.heatmapMatrix

            Rectangle {
              required property var modelData
              width: 20
              height: 9
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
        implicitHeight: 40
        radius: 8
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
            font.pixelSize: 15
            color: "#f59e0b" // Amber flame
          }

          ColumnLayout {
            spacing: 0
            Text {
              text: gitWidgetRoot.streakDays + (gitWidgetRoot.streakDays === 1 ? " Day" : " Days")
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: Color.foreground
            }
            Text {
              text: "Current Streak"
              font.family: Style.font.family
              font.pixelSize: 8
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }
          }
        }
      }

      // Total Commits Metric
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 8
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
            font.pixelSize: 13
            color: "#10b981" // Emerald
          }

          ColumnLayout {
            spacing: 0
            Text {
              text: gitWidgetRoot.totalCommits.toString()
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: Color.foreground
            }
            Text {
              text: "Total Commits"
              font.family: Style.font.family
              font.pixelSize: 8
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📑 Tabbed Activity Navigation: Commits | Pull Requests | Issues
    // -------------------------------------------------------------------------
    RowLayout {
      visible: gitWidgetRoot.hasRepos && gitWidgetRoot.showRecentCommits
      Layout.fillWidth: true
      spacing: Style.space(6)

      // Commits Tab
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        readonly property bool isActive: gitWidgetRoot.activeTab === "commits"
        color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (comTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
        border.color: isActive ? Color.accent : (comTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: "\uf126"
            font.family: Style.font.family
            font.pixelSize: 10
            color: isActive ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }

          Text {
            text: "Commits"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: isActive ? Font.Bold : Font.Normal
            color: isActive ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
          }

          Rectangle {
            visible: gitWidgetRoot.recentCommitsList.length > 0
            implicitWidth: comCountText.implicitWidth + 8
            implicitHeight: 14
            radius: 7
            color: isActive ? Color.accent : Qt.rgba(1, 1, 1, 0.1)

            Text {
              id: comCountText
              anchors.centerIn: parent
              text: gitWidgetRoot.recentCommitsList.length.toString()
              font.family: Style.font.family
              font.pixelSize: 8
              font.weight: Font.Bold
              color: isActive ? "#000000" : Color.foreground
            }
          }
        }

        MouseArea {
          id: comTabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gitWidgetRoot.activeTab = "commits"
        }
      }

      // Pull Requests Tab
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        readonly property bool isActive: gitWidgetRoot.activeTab === "prs"
        color: isActive ? Qt.rgba(168/255, 85/255, 247/255, 0.22) : (prsTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
        border.color: isActive ? "#a855f7" : (prsTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: "\uf446"
            font.family: Style.font.family
            font.pixelSize: 10
            color: isActive ? "#a855f7" : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }

          Text {
            text: "PRs"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: isActive ? Font.Bold : Font.Normal
            color: isActive ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
          }

          Rectangle {
            visible: gitWidgetRoot.pullRequestsList.length > 0
            implicitWidth: prCountText.implicitWidth + 8
            implicitHeight: 14
            radius: 7
            color: isActive ? "#a855f7" : Qt.rgba(1, 1, 1, 0.1)

            Text {
              id: prCountText
              anchors.centerIn: parent
              text: gitWidgetRoot.pullRequestsList.length.toString()
              font.family: Style.font.family
              font.pixelSize: 8
              font.weight: Font.Bold
              color: isActive ? "#ffffff" : Color.foreground
            }
          }
        }

        MouseArea {
          id: prsTabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gitWidgetRoot.activeTab = "prs"
        }
      }

      // Issues Tab
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        readonly property bool isActive: gitWidgetRoot.activeTab === "issues"
        color: isActive ? Qt.rgba(16/255, 185/255, 129/255, 0.22) : (issTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
        border.color: isActive ? "#10b981" : (issTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06))
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: "\uf41c"
            font.family: Style.font.family
            font.pixelSize: 10
            color: isActive ? "#10b981" : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }

          Text {
            text: "Issues"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: isActive ? Font.Bold : Font.Normal
            color: isActive ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
          }

          Rectangle {
            visible: gitWidgetRoot.issuesList.length > 0
            implicitWidth: issCountText.implicitWidth + 8
            implicitHeight: 14
            radius: 7
            color: isActive ? "#10b981" : Qt.rgba(1, 1, 1, 0.1)

            Text {
              id: issCountText
              anchors.centerIn: parent
              text: gitWidgetRoot.issuesList.length.toString()
              font.family: Style.font.family
              font.pixelSize: 8
              font.weight: Font.Bold
              color: isActive ? "#000000" : Color.foreground
            }
          }
        }

        MouseArea {
          id: issTabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: gitWidgetRoot.activeTab = "issues"
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📜 Scrollable Activity Stream (Last 25 Commits, PRs, or Issues)
    // -------------------------------------------------------------------------
    Item {
      visible: gitWidgetRoot.hasRepos && gitWidgetRoot.showRecentCommits
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      // Empty State for Current Tab
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 6
        visible: (gitWidgetRoot.activeTab === "commits" && gitWidgetRoot.recentCommitsList.length === 0) ||
                 (gitWidgetRoot.activeTab === "prs" && gitWidgetRoot.pullRequestsList.length === 0) ||
                 (gitWidgetRoot.activeTab === "issues" && gitWidgetRoot.issuesList.length === 0)

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: gitWidgetRoot.activeTab === "prs" ? "\uf446" : (gitWidgetRoot.activeTab === "issues" ? "\uf41c" : "\uf126")
          font.family: Style.font.family
          font.pixelSize: 20
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: gitWidgetRoot.activeTab === "prs" ? (gitWidgetRoot.hasGithub ? "No Pull Requests" : "GitHub Repo Required for PRs") :
                (gitWidgetRoot.activeTab === "issues" ? (gitWidgetRoot.hasGithub ? "No Issues Open" : "GitHub Repo Required for Issues") : "No Recent Commits")
          font.family: Style.font.family
          font.pixelSize: 11
          font.weight: Font.DemiBold
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          Layout.maximumWidth: 260
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          text: gitWidgetRoot.activeTab === "prs" ? (gitWidgetRoot.hasGithub ? "All pull requests are reviewed and merged." : "Connect a GitHub remote or URL to track pull requests.") :
                (gitWidgetRoot.activeTab === "issues" ? (gitWidgetRoot.hasGithub ? "All issues are closed or none have been opened yet." : "Connect a GitHub remote or URL to track issues.") : "No commits recorded in the selected period.")
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
        }
      }

      // Scrollable ListView
      ListView {
        id: activityListView
        anchors.fill: parent
        anchors.rightMargin: 6
        clip: true
        spacing: 5
        boundsBehavior: Flickable.StopAtBounds

        model: gitWidgetRoot.activeTab === "commits" ? gitWidgetRoot.recentCommitsList :
               (gitWidgetRoot.activeTab === "prs" ? gitWidgetRoot.pullRequestsList : gitWidgetRoot.issuesList)

        delegate: Rectangle {
          required property var modelData
          required property int index
          width: activityListView.width
          implicitHeight: 40
          radius: 8
          color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035)
          border.color: itemMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.05)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            // Badge / Icon Column
            // 1. For Commits: Hash pill
            Rectangle {
              visible: gitWidgetRoot.activeTab === "commits"
              implicitWidth: hashText.implicitWidth + 8
              implicitHeight: 18
              radius: 4
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)

              Text {
                id: hashText
                anchors.centerIn: parent
                text: modelData.hash ? modelData.hash : ""
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: Color.accent
              }
            }

            // 2. For PRs / Issues: State icon & number
            Rectangle {
              visible: gitWidgetRoot.activeTab !== "commits"
              implicitWidth: numText.implicitWidth + 12
              implicitHeight: 18
              radius: 4
              readonly property bool isOpen: (modelData.state || "").toLowerCase() === "open"
              readonly property bool isMerged: (modelData.state || "").toLowerCase() === "merged"
              color: isOpen ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : (isMerged ? Qt.rgba(168/255, 85/255, 247/255, 0.2) : Qt.rgba(1, 1, 1, 0.1))

              RowLayout {
                anchors.centerIn: parent
                spacing: 3

                Text {
                  text: gitWidgetRoot.activeTab === "prs" ? "\uf446" : (parent.parent.isOpen ? "\uf41c" : "\uf058")
                  font.family: Style.font.family
                  font.pixelSize: 8
                  color: parent.parent.isOpen ? "#10b981" : (parent.parent.isMerged ? "#a855f7" : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5))
                }

                Text {
                  id: numText
                  text: "#" + (modelData.number || "")
                  font.family: Style.font.family
                  font.pixelSize: 9
                  font.weight: Font.DemiBold
                  color: parent.parent.isOpen ? "#10b981" : (parent.parent.isMerged ? "#a855f7" : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7))
                }
              }
            }

            // Main Text Column
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: (gitWidgetRoot.activeTab === "commits" ? modelData.msg : modelData.title) || ""
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: Font.Normal
                color: Color.foreground
                elide: Text.ElideRight
              }

              Text {
                text: gitWidgetRoot.activeTab === "commits" ?
                      (modelData.time + (modelData.author ? " • " + modelData.author : "")) :
                      ("by @" + modelData.author + " • " + modelData.date)
                font.family: Style.font.family
                font.pixelSize: 8
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
                elide: Text.ElideRight
              }
            }

            // External Link Icon on Hover
            Text {
              visible: itemMouse.containsMouse && Boolean(modelData.url)
              text: "\uf08e"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Color.accent
            }
          }

          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (modelData.url) {
                Qt.openUrlExternally(modelData.url)
              }
            }
          }
        }
      }

      // Sleek Vertical Scrollbar Indicator
      Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: activityListView.contentHeight > activityListView.height

        Rectangle {
          width: 3
          radius: 1.5
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
          height: Math.max(16, (activityListView.height / activityListView.contentHeight) * activityListView.height)
          y: (activityListView.contentY / activityListView.contentHeight) * activityListView.height
        }
      }
    }

    Item {
      visible: !gitWidgetRoot.showRecentCommits
      Layout.fillHeight: true
    }
  }
}
