import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Import WidgetCard from the shared directory or the plugin directory.
// Keep custom widgets on WidgetCard when possible: it automatically preserves
// monitorName/monitorWidth/monitorHeight so positions stay per-monitor.
// Standalone widgets must pass monitorName into rootRef.saveWidgetPos(...) and
// rootRef.toggleWidgetEnabled(...) to avoid changing another monitor's layout.
import "../shared"

WidgetCard {
  id: customWidgetRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Placement Settings
  // ---------------------------------------------------------------------------
  widgetId: "custom_template"
  title: "My Custom Widget"
  icon: "\uf12e"       // FontAwesome 6 icon
  showHeader: true     // Shows standard header with title, icon, and close button

  // Default positioning (when no saved position exists)
  defaultX: Style.space(24)
  defaultY: Style.space(64)

  width: 320
  height: contentLayout.implicitHeight + (showHeader ? Style.space(48) : Style.space(24))

  // ---------------------------------------------------------------------------
  // 🎨 Widget Body Content
  // ---------------------------------------------------------------------------
  ColumnLayout {
    id: contentLayout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: showHeader ? Style.space(44) : Style.space(16)
    anchors.leftMargin: Style.space(16)
    anchors.rightMargin: Style.space(16)
    anchors.bottomMargin: Style.space(16)
    spacing: Style.space(12)

    Text {
      Layout.fillWidth: true
      text: "Custom Widget Content"
      font.family: Style.font.family
      font.pixelSize: 14
      font.weight: Font.DemiBold
      color: Commons.Color.foreground
    }

    Text {
      Layout.fillWidth: true
      text: "Edit this template in ~/Projects/desktop-widgets to build your own desktop widgets."
      font.family: Style.font.family
      font.pixelSize: 11
      color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.65)
      wrapMode: Text.WordWrap
    }

    // Example Interactive Button
    Rectangle {
      Layout.fillWidth: true
      height: 32
      radius: 16
      color: sampleMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)
      border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
      border.width: 1

      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
          text: "\uf00c"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Commons.Color.accent
        }

        Text {
          text: "Action Button"
          font.family: Style.font.family
          font.pixelSize: 11
          font.weight: Font.DemiBold
          color: Commons.Color.foreground
        }
      }

      MouseArea {
        id: sampleMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          // Put your button action here!
        }
      }
    }
  }
}
