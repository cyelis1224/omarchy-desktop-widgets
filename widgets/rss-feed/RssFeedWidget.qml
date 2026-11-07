import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
// Qt 6.12 adds a QtQuick "Color" singleton that wins over qs.Commons.Color in
// these subfolder widgets; reference the shell colours through an alias.
import qs.Commons as Sh
import qs.Ui

// Import base WidgetCard from shared or parent widgets directory
import "../../shared"
import ".."

WidgetCard {
  id: rssWidgetRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Sizing
  // ---------------------------------------------------------------------------
  widgetId: "rss_feed"
  title: "RSS Feed Radar"
  icon: "\uf09e"
  showHeader: false

  defaultX: 380
  defaultY: 560

  width: 380
  height: 480
  minWidth: 320
  minHeight: 350
  maxWidth: 600
  maxHeight: 750
  menuWidth: 300

  // ---------------------------------------------------------------------------
  // ⚙️ Feed Channels & State
  // ---------------------------------------------------------------------------
  readonly property var defaultFeeds: [
    { name: "Hacker News", url: "https://news.ycombinator.com/rss", isDefault: true },
    { name: "Arch Linux", url: "https://archlinux.org/feeds/news/", isDefault: true },
    { name: "The Verge", url: "https://www.theverge.com/rss/index.xml", isDefault: true },
    { name: "Phoronix", url: "https://www.phoronix.com/rss.php", isDefault: true }
  ]

  property var customFeeds: []
  readonly property var allFeeds: defaultFeeds.concat(customFeeds)

  property int activeFeedIndex: 0
  readonly property var currentFeed: (allFeeds && allFeeds.length > activeFeedIndex) ? allFeeds[activeFeedIndex] : defaultFeeds[0]
  readonly property string currentFeedUrl: currentFeed ? currentFeed.url : ""

  property var articlesList: []
  property bool isLoading: false
  property int refreshIntervalMinutes: 15
  property string lastStatus: ""

  readonly property string scriptPath: {
    var u = Qt.resolvedUrl("get-rss.py").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function applySavedSettings() {
    var cf = getSetting("customFeeds", undefined)
    if (cf !== undefined && Array.isArray(cf)) customFeeds = cf

    var idx = getSetting("activeFeedIndex", undefined)
    if (idx !== undefined && typeof idx === "number" && idx >= 0 && idx < allFeeds.length) {
      activeFeedIndex = idx
    }

    var rim = getSetting("refreshIntervalMinutes", undefined)
    if (rim !== undefined && typeof rim === "number") refreshIntervalMinutes = rim
  }

  onSettingsLoaded: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    fetchFeed(false)
  }

  function fetchFeed(force) {
    if (!currentFeedUrl) return
    rssWidgetRoot.isLoading = true
    var args = [rssWidgetRoot.currentFeedUrl]
    if (force) args.push("--force")
    fetchProc.command = [rssWidgetRoot.scriptPath].concat(args)
    if (!fetchProc.running) fetchProc.running = true
  }

  function openAddDialog() {
    actionProc.command = [rssWidgetRoot.scriptPath, "add_dialog"]
    if (!actionProc.running) actionProc.running = true
  }

  function addCustomFeed(name, url) {
    if (!url) return
    var list = customFeeds.slice()
    var title = name || url.replace('https://', '').replace('http://', '').split('/')[0]
    list.push({ name: title, url: url, isDefault: false })
    customFeeds = list
    saveSetting("customFeeds", list)
    activeFeedIndex = allFeeds.length - 1
    saveSetting("activeFeedIndex", activeFeedIndex)
    fetchFeed(true)
  }

  function removeCustomFeed(urlToRemove) {
    var list = customFeeds.filter(function(f) { return f.url !== urlToRemove })
    customFeeds = list
    saveSetting("customFeeds", list)
    if (activeFeedIndex >= allFeeds.length) {
      activeFeedIndex = Math.max(0, allFeeds.length - 1)
      saveSetting("activeFeedIndex", activeFeedIndex)
    }
    fetchFeed(false)
  }

  function selectFeed(idx) {
    if (idx >= 0 && idx < allFeeds.length) {
      activeFeedIndex = idx
      saveSetting("activeFeedIndex", idx)
      fetchFeed(false)
    }
  }

  // 1. Regular Feed Fetcher Process
  Process {
    id: fetchProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "ok" && Array.isArray(res.items)) {
            rssWidgetRoot.articlesList = res.items
            rssWidgetRoot.lastStatus = "Updated " + Qt.formatTime(new Date(), "hh:mm AP")
          } else if (res.status === "error") {
            rssWidgetRoot.lastStatus = "Error loading feed"
          }
        } catch (e) {}
      }
    }
    onExited: function(code) {
      rssWidgetRoot.isLoading = false
    }
  }

  // 2. Dedicated Dialog Process
  Process {
    id: actionProc
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.status === "feed_added" && res.url) {
            rssWidgetRoot.addCustomFeed(res.name, res.url)
          }
        } catch (e) {}
      }
    }
  }

  // Periodic Auto-refresh Timer
  Timer {
    interval: Math.max(1, rssWidgetRoot.refreshIntervalMinutes) * 60 * 1000
    running: true
    repeat: true
    onTriggered: rssWidgetRoot.fetchFeed(false)
  }

  // ---------------------------------------------------------------------------
  // 🖥️ Content Layout
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    // Top Integrated Header
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "\uf09e"
        font.family: Style.font.family
        font.pixelSize: 13
        color: Sh.Color.accent
      }

      Text {
        text: "RSS Feed Radar"
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Sh.Color.foreground
      }

      Item { Layout.fillWidth: true }

      // Add Feed Button (+)
      Rectangle {
        height: 22
        width: 22
        radius: 4
        color: addFeedHeaderMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)

        Text {
          anchors.centerIn: parent
          text: "\uf067"
          font.family: Style.font.family
          font.pixelSize: 10
          color: addFeedHeaderMouse.containsMouse ? Sh.Color.accent : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.7)
        }

        MouseArea {
          id: addFeedHeaderMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: rssWidgetRoot.openAddDialog()
        }
      }

      // Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: rssCloseMouse.containsMouse ? Qt.rgba(Sh.Color.urgent.r, Sh.Color.urgent.g, Sh.Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Sh.Color.urgent.r, Sh.Color.urgent.g, Sh.Color.urgent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf00d"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Sh.Color.urgent
        }

        MouseArea {
          id: rssCloseMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(rssWidgetRoot.widgetId, false, rssWidgetRoot.monitorName)
            }
          }
        }
      }

      // Move Grip Handle (when in edit mode)
      Rectangle {
        id: rssGripButton
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: rssGripArea.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0b2"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Sh.Color.accent
        }

        MouseArea {
          id: rssGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: rssWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, rssWidgetRoot.screenWidth - rssWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, rssWidgetRoot.screenHeight - rssWidgetRoot.height - 10)

          onPressed: {
            rssWidgetRoot.customGripDragging = true
          }

          onReleased: function() {
            rssWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, rssWidgetRoot.screenWidth - rssWidgetRoot.width - 10)
            var maxY = Math.max(10, rssWidgetRoot.screenHeight - rssWidgetRoot.height - 10)
            var snappedX = rssWidgetRoot.snapVal(rssWidgetRoot.targetItem.x)
            var snappedY = rssWidgetRoot.snapVal(rssWidgetRoot.targetItem.y)
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            rssWidgetRoot.targetItem.x = snappedX
            rssWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(rssWidgetRoot.widgetId, snappedX, snappedY, rssWidgetRoot.snapVal(rssWidgetRoot.width), rssWidgetRoot.snapVal(rssWidgetRoot.height), rssWidgetRoot.monitorName)
            }
          }
        }
      }
    }

    // Channel Pills Tab Bar
    Flickable {
      Layout.fillWidth: true
      Layout.preferredHeight: 28
      contentWidth: channelRow.implicitWidth
      contentHeight: 28
      clip: true
      flickableDirection: Flickable.HorizontalFlick

      RowLayout {
        id: channelRow
        spacing: 6

        Repeater {
          model: rssWidgetRoot.allFeeds

          Rectangle {
            required property var modelData
            required property int index
            height: 26
            radius: 6
            width: tabRowLayout.implicitWidth + 14

            readonly property bool isSelected: (rssWidgetRoot.activeFeedIndex === index)

            color: isSelected ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.25) : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
            border.width: isSelected ? 1 : 0
            border.color: isSelected ? Sh.Color.accent : "transparent"

            RowLayout {
              id: tabRowLayout
              anchors.centerIn: parent
              spacing: 5

              Text {
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: 11
                font.weight: isSelected ? Font.Bold : Font.Normal
                color: isSelected ? Sh.Color.accent : Sh.Color.foreground
              }

              // Close icon for custom feeds
              Text {
                visible: !modelData.isDefault
                text: "\uf00d"
                font.family: Style.font.family
                font.pixelSize: 9
                color: delFeedMouse.containsMouse ? Sh.Color.urgent : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.4)

                MouseArea {
                  id: delFeedMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: rssWidgetRoot.removeCustomFeed(modelData.url)
                }
              }
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: rssWidgetRoot.selectFeed(index)
            }
          }
        }

        // Add Feed Button (+)
        Rectangle {
          height: 26
          width: 26
          radius: 6
          color: addFeedMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)

          Text {
            anchors.centerIn: parent
            text: "\uf067"
            font.family: Style.font.family
            font.pixelSize: 10
            color: addFeedMouse.containsMouse ? Sh.Color.accent : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.6)
          }

          MouseArea {
            id: addFeedMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rssWidgetRoot.openAddDialog()
          }
        }
      }
    }

    // Divider Line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Qt.rgba(1, 1, 1, 0.06)
    }

    // Feed Metadata & Quick Refresh Row
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: rssWidgetRoot.currentFeed ? rssWidgetRoot.currentFeed.name : "Feed"
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Sh.Color.accent
      }

      Text {
        text: "• " + (rssWidgetRoot.articlesList ? (rssWidgetRoot.articlesList.length + " stories") : "0 stories")
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.4)
      }

      Item { Layout.fillWidth: true }

      Text {
        text: rssWidgetRoot.lastStatus
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.4)
      }

      // Manual Refresh Button
      Rectangle {
        width: 20
        height: 20
        radius: 4
        color: refMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.2) : "transparent"

        Text {
          anchors.centerIn: parent
          text: "\uf021"
          font.family: Style.font.family
          font.pixelSize: 10
          color: rssWidgetRoot.isLoading ? Sh.Color.accent : (refMouse.containsMouse ? Sh.Color.accent : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.5))
          rotation: rssWidgetRoot.isLoading ? 180 : 0

          Behavior on rotation {
            NumberAnimation { duration: 400; easing.type: Easing.Linear }
          }
        }

        MouseArea {
          id: refMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: rssWidgetRoot.fetchFeed(true)
        }
      }
    }

    // Articles List
    ListView {
      id: articlesListView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 6
      model: rssWidgetRoot.articlesList

      delegate: Rectangle {
        id: articleCard
        required property var modelData
        width: articlesListView.width
        implicitHeight: articleCol.implicitHeight + 14
        radius: 8
        color: cardMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.12) : Qt.rgba(1, 1, 1, 0.03)

        Behavior on color {
          ColorAnimation { duration: 150 }
        }

        ColumnLayout {
          id: articleCol
          anchors.fill: parent
          anchors.margins: 7
          spacing: 3

          // Headline Row
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
              Layout.fillWidth: true
              text: modelData.title || "Untitled"
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: cardMouse.containsMouse ? Sh.Color.accent : Sh.Color.foreground
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Text {
              text: "\uf08e"
              font.family: Style.font.family
              font.pixelSize: 9
              color: cardMouse.containsMouse ? Sh.Color.accent : Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.3)
            }
          }

          // Snippet (if available)
          Text {
            visible: !!(modelData.snippet && modelData.snippet !== "Comments" && modelData.snippet.length > 5)
            Layout.fillWidth: true
            text: modelData.snippet || ""
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.5)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }

          // Metadata row (Time ago & Author)
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
              text: modelData.time_ago || ""
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.DemiBold
              color: Sh.Color.accent
            }

            Text {
              visible: !!(modelData.author)
              text: "by " + modelData.author
              font.family: Style.font.family
              font.pixelSize: 9
              color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.35)
              elide: Text.ElideRight
            }
          }
        }

        MouseArea {
          id: cardMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (modelData.link) {
              Quickshell.execDetached(["xdg-open", modelData.link])
            }
          }
        }
      }

      // Empty / Loading State
      Item {
        anchors.fill: parent
        visible: rssWidgetRoot.articlesList.length === 0

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: rssWidgetRoot.isLoading ? "\uf021" : "\uf09e"
            font.family: Style.font.family
            font.pixelSize: 20
            color: Sh.Color.accent
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: rssWidgetRoot.isLoading ? "Fetching latest feed items..." : "No articles found in this feed"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.4)
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ⚙️ Custom Context Menu Settings
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 270
      spacing: Style.space(6)

      Text {
        text: "RSS FEED OPTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(8)
      }

      // Add Custom Feed Option
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: addOptMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf067"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Sh.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Add Custom RSS URL..."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Sh.Color.foreground
          }
        }

        MouseArea {
          id: addOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            rssWidgetRoot.contextMenuOpen = false
            rssWidgetRoot.openAddDialog()
          }
        }
      }

      // Force Refresh Feed
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: refOptMouse.containsMouse ? Qt.rgba(Sh.Color.accent.r, Sh.Color.accent.g, Sh.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf021"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Sh.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Force Refresh Feed"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Sh.Color.foreground
          }
        }

        MouseArea {
          id: refOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            rssWidgetRoot.contextMenuOpen = false
            rssWidgetRoot.fetchFeed(true)
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
      }

      Text {
        text: "AUTO-REFRESH INTERVAL"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Sh.Color.foreground.r, Sh.Color.foreground.g, Sh.Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(8)
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: [
            { label: "15m", mins: 15 },
            { label: "30m", mins: 30 },
            { label: "1h", mins: 60 },
            { label: "2h", mins: 120 }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            height: 24
            radius: 4
            color: (rssWidgetRoot.refreshIntervalMinutes === modelData.mins) ? Sh.Color.accent : (intMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: (rssWidgetRoot.refreshIntervalMinutes === modelData.mins) ? Font.Bold : Font.Normal
              color: (rssWidgetRoot.refreshIntervalMinutes === modelData.mins) ? "#0a0a0f" : Sh.Color.foreground
            }

            MouseArea {
              id: intMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                rssWidgetRoot.refreshIntervalMinutes = modelData.mins
                rssWidgetRoot.saveSetting("refreshIntervalMinutes", modelData.mins)
              }
            }
          }
        }
      }
    }
  }
}
