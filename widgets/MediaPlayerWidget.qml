import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

WidgetCard {
  id: mediaWidgetRoot

  widgetId: "media"
  title: "Media Player"
  icon: "\uf001"
  showHeader: false
  defaultX: Style.space(24)
  defaultY: screenHeight - height - Style.space(28)

  width: 360
  height: mediaCardLayout.implicitHeight + Style.space(36)

  // ---------------------------------------------------------------------------
  // 🎵 MPRIS Media Player State & Audio Source Selection
  // ---------------------------------------------------------------------------
  property string preferredPlayerIdentity: ""
  property bool showVisualizer: true

  function applySavedSettings() {
    if (!rootRef || !rootRef.widgetSettings) return
    var s = rootRef.widgetSettings[widgetId]
    if (!s) return
    if (s.preferredPlayerIdentity !== undefined) preferredPlayerIdentity = s.preferredPlayerIdentity
    if (s.showVisualizer !== undefined) showVisualizer = s.showVisualizer
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: {
    if (!players || players.length === 0) return null
    if (preferredPlayerIdentity !== "") {
      for (var k = 0; k < players.length; k++) {
        var iden = players[k].identity || players[k].desktopEntry || ""
        if (iden === preferredPlayerIdentity) return players[k]
      }
    }
    for (var i = 0; i < players.length; i++) {
      if (players[i].playbackState === MprisPlaybackState.Playing) return players[i]
    }
    return players[0]
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "AUDIO SOURCES (MPRIS)"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      Text {
        visible: mediaWidgetRoot.players.length === 0
        text: "No active media players"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        Layout.leftMargin: 8
        Layout.bottomMargin: 4
      }

      Repeater {
        model: mediaWidgetRoot.players

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          readonly property bool isCurrent: mediaWidgetRoot.activePlayer === modelData
          color: playerMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (isCurrent ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              text: "\uf001"
              font.family: Style.font.family
              font.pixelSize: 11
              color: isCurrent ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }

            Text {
              Layout.fillWidth: true
              text: modelData.identity || modelData.desktopEntry || "Media Player"
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: isCurrent ? Font.Bold : Font.Normal
              color: isCurrent ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.8)
              elide: Text.ElideRight
            }

            Text {
              text: (modelData.playbackState === MprisPlaybackState.Playing) ? "\uf04b" : "\uf04c"
              font.family: Style.font.family
              font.pixelSize: 9
              color: (modelData.playbackState === MprisPlaybackState.Playing) ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
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
            id: playerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var iden = modelData.identity || modelData.desktopEntry || ""
              mediaWidgetRoot.preferredPlayerIdentity = (mediaWidgetRoot.preferredPlayerIdentity === iden ? "" : iden)
              mediaWidgetRoot.saveSetting("preferredPlayerIdentity", mediaWidgetRoot.preferredPlayerIdentity)
              mediaWidgetRoot.contextMenuOpen = false
            }
          }
        }
      }

      Text {
        text: "VISUALIZER & DISPLAY"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 4
      }

      // Visualizer Spectrum Toggle
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: visMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf080"
            font.family: Style.font.family
            font.pixelSize: 11
            color: mediaWidgetRoot.showVisualizer ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          Text {
            Layout.fillWidth: true
            text: "Audio Spectrum Visualizer"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          Text {
            text: mediaWidgetRoot.showVisualizer ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: mediaWidgetRoot.showVisualizer ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: visMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            mediaWidgetRoot.showVisualizer = !mediaWidgetRoot.showVisualizer
            mediaWidgetRoot.saveSetting("showVisualizer", mediaWidgetRoot.showVisualizer)
            mediaWidgetRoot.contextMenuOpen = false
          }
        }
      }
    }
  }

  readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
  readonly property string trackTitle: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : "No media playing"
  readonly property string trackArtist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : "Play something to see controls"
  readonly property string trackAlbum: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""

  // ---------------------------------------------------------------------------
  // 📊 Audio Spectrum Visualizer Data (24 dynamic frequency bars)
  // ---------------------------------------------------------------------------
  property var visualizerHeights: [
    8, 12, 18, 26, 32, 28, 22, 35, 42, 48, 38, 30, 24, 36, 44, 40, 32, 26, 18, 24, 20, 14, 10, 6
  ]
  property real animPhase: 0

  Timer {
    interval: 65
    running: true
    repeat: true
    onTriggered: {
      mediaWidgetRoot.animPhase += 0.25
      var heights = []
      var count = 24
      var playing = mediaWidgetRoot.isPlaying

      for (var i = 0; i < count; i++) {
        if (!playing) {
          heights.push(4)
        } else {
          var sin1 = Math.sin(mediaWidgetRoot.animPhase + i * 0.45)
          var sin2 = Math.cos(mediaWidgetRoot.animPhase * 1.3 - i * 0.3)
          var raw = (sin1 + sin2 + 2) / 4 // 0 to 1
          var pulse = (Math.sin(mediaWidgetRoot.animPhase * 2.2) + 1) * 0.15
          var h = Math.round(6 + (raw + pulse) * 46 + (Math.random() * 8))
          heights.push(Math.min(58, Math.max(6, h)))
        }
      }
      mediaWidgetRoot.visualizerHeights = heights
    }
  }

  ColumnLayout {
    id: mediaCardLayout
    anchors.fill: parent
    anchors.topMargin: Style.space(18)
    anchors.bottomMargin: Style.space(18)
    anchors.leftMargin: Style.space(20)
    anchors.rightMargin: Style.space(20)
    spacing: Style.space(12)

    // Track Info + Album Art + Controls + Move Grip
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      // Album Art (Compact 48x48)
      Rectangle {
        width: 48
        height: 48
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.08)
        clip: true
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        Image {
          id: artImage
          anchors.fill: parent
          source: mediaWidgetRoot.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: status === Image.Ready && mediaWidgetRoot.artUrl !== ""
        }

        Text {
          anchors.centerIn: parent
          visible: !artImage.visible
          text: "\uf001"
          font.family: Style.font.family
          font.pixelSize: 20
          color: Color.accent
        }
      }

      // Title & Artist
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)

        Text {
          Layout.fillWidth: true
          text: mediaWidgetRoot.trackTitle
          font.family: Style.font.family
          font.pixelSize: 14
          font.weight: Font.Bold
          color: Color.foreground
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: mediaWidgetRoot.trackArtist
          font.family: Style.font.family
          font.pixelSize: 12
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
          elide: Text.ElideRight
        }
      }

      // Close / Hide Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeMediaMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeMediaMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(mediaWidgetRoot.widgetId, false)
            }
          }
        }
      }

      // Move Grip Handle Button
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 24
        height: 24
        radius: 12
        color: mediaGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: mediaGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: mediaWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, mediaWidgetRoot.screenWidth - mediaWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, mediaWidgetRoot.screenHeight - mediaWidgetRoot.height - 10)

          onPressed: mediaWidgetRoot.customGripDragging = true
          onReleased: function() {
            mediaWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, mediaWidgetRoot.screenWidth - mediaWidgetRoot.width - 10)
            var maxY = Math.max(10, mediaWidgetRoot.screenHeight - mediaWidgetRoot.height - 10)
            var snappedX = Math.round(mediaWidgetRoot.targetItem.x / 20) * 20
            var snappedY = Math.round(mediaWidgetRoot.targetItem.y / 20) * 20
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            mediaWidgetRoot.targetItem.x = snappedX
            mediaWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(mediaWidgetRoot.widgetId, snappedX, snappedY)
            }
          }
          onCanceled: mediaWidgetRoot.customGripDragging = false
        }
      }

      // Compact Interactive Player Controls
      RowLayout {
        spacing: Style.space(4)
        visible: mediaWidgetRoot.activePlayer !== null

        // Previous Button
        Rectangle {
          width: 28
          height: 28
          radius: 14
          color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
          border.color: Qt.rgba(1, 1, 1, 0.1)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf048"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (mediaWidgetRoot.activePlayer) mediaWidgetRoot.activePlayer.previous()
          }
        }

        // Play/Pause Button
        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: playMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)
          border.color: Qt.rgba(255, 255, 255, 0.3)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: mediaWidgetRoot.isPlaying ? "\uf04c" : "\uf04b"
            font.family: Style.font.family
            font.pixelSize: 13
            color: Color.background
          }

          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (mediaWidgetRoot.activePlayer) mediaWidgetRoot.activePlayer.togglePlaying()
          }
        }

        // Next Button
        Rectangle {
          width: 28
          height: 28
          radius: 14
          color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
          border.color: Qt.rgba(1, 1, 1, 0.1)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf051"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (mediaWidgetRoot.activePlayer) mediaWidgetRoot.activePlayer.next()
          }
        }
      }
    }

    // 📊 SOLID BLUE AUDIO SPECTRUM VISUALIZER BARS
    Item {
      Layout.fillWidth: true
      implicitHeight: 32
      visible: mediaWidgetRoot.showVisualizer

      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(4)

        Repeater {
          model: mediaWidgetRoot.visualizerHeights

          Rectangle {
            required property int modelData
            required property int index

            width: 7
            height: Math.max(3, Math.round(modelData * 0.55))
            radius: 3.5
            color: Color.accent
            opacity: mediaWidgetRoot.isPlaying ? 0.95 : 0.40

            Behavior on height {
              NumberAnimation { duration: 75; easing.type: Easing.OutQuad }
            }
            Behavior on opacity {
              NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }
  }
}
