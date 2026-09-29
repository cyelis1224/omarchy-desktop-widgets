import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Item {
  id: root

  property var bar: null

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: {
    if (!players || players.length === 0) return null
    for (var i = 0; i < players.length; i++) {
      if (players[i].playbackState === MprisPlaybackState.Playing) return players[i]
    }
    return players[0]
  }

  readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
  readonly property string trackTitle: (activePlayer && activePlayer.trackTitle) ? activePlayer.trackTitle : "No Media"
  readonly property string trackArtist: (activePlayer && activePlayer.trackArtist) ? activePlayer.trackArtist : ""

  implicitWidth: pillContainer.implicitWidth
  implicitHeight: Style.bar.statusSlot || 32

  Rectangle {
    id: pillContainer
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Math.min(parent.height - 4, 28)
    implicitWidth: rowLayout.implicitWidth + 16
    radius: Style.cornerRadius || 8
    color: bgMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.65)
    border.color: root.isPlaying ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
      id: rowLayout
      anchors.centerIn: parent
      spacing: 6

      // Static on purpose: a looping pulse redraws the bar every frame for as
      // long as music plays; the accent color already marks playback
      Text {
        text: "\uf001"
        font.family: Style.font.family
        font.pixelSize: 11
        color: root.isPlaying ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
      }

      Text {
        text: root.trackArtist !== "" ? (root.trackTitle + " — " + root.trackArtist) : root.trackTitle
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: root.isPlaying ? Font.Bold : Font.Normal
        color: Color.foreground
        elide: Text.ElideRight
        Layout.maximumWidth: 160
      }

      // Mini Play/Pause Button
      Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        radius: 9
        color: playMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : "transparent"

        Text {
          anchors.centerIn: parent
          text: root.isPlaying ? "\uf04c" : "\uf04b"
          font.family: Style.font.family
          font.pixelSize: 9
          color: root.isPlaying ? Color.accent : Color.foreground
        }

        MouseArea {
          id: playMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.activePlayer && root.activePlayer.canPlay) {
              root.activePlayer.togglePlaying()
            }
          }
        }
      }

      // Mini Next Track Button
      Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        radius: 9
        visible: root.activePlayer && root.activePlayer.canGoNext
        color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

        Text {
          anchors.centerIn: parent
          text: "\uf051"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
        }

        MouseArea {
          id: nextMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.activePlayer && root.activePlayer.canGoNext) {
              root.activePlayer.next()
            }
          }
        }
      }
    }

    MouseArea {
      id: bgMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      z: -1
      onClicked: {
        if (root.activePlayer && root.activePlayer.canPlay) {
          root.activePlayer.togglePlaying()
        }
      }
    }
  }
}
