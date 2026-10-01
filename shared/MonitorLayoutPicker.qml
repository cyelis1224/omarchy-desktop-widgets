import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

// Miniature map of the connected displays. Each display is a toggle that shows
// or hides the widget on that output; "All" puts it on every connected display.
ColumnLayout {
  id: pickerRoot

  property var rootRef: null
  property string widgetId: ""
  property string currentMonitor: ""
  property real maxMapHeight: 110

  spacing: Style.space(6)

  readonly property var screenRects: {
    var list = []
    var screens = Quickshell.screens
    if (!screens) return list
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (s && s.name) list.push({ name: s.name, x: s.x, y: s.y, width: s.width, height: s.height })
    }
    return list
  }

  readonly property var bounds: {
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (var i = 0; i < screenRects.length; i++) {
      var r = screenRects[i]
      minX = Math.min(minX, r.x)
      minY = Math.min(minY, r.y)
      maxX = Math.max(maxX, r.x + r.width)
      maxY = Math.max(maxY, r.y + r.height)
    }
    if (minX === Infinity) return { x: 0, y: 0, w: 1, h: 1 }
    return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
  }

  readonly property var activeNames: {
    var list = []
    if (!rootRef || !rootRef.isWidgetActiveOnMonitor) return list
    for (var i = 0; i < screenRects.length; i++) {
      if (rootRef.isWidgetActiveOnMonitor(widgetId, screenRects[i].name)) list.push(screenRects[i].name)
    }
    return list
  }

  readonly property bool onAll: screenRects.length > 0 && activeNames.length === screenRects.length

  function applyMonitors(names) {
    if (rootRef && rootRef.setWidgetMonitors) {
      rootRef.setWidgetMonitors(widgetId, names, currentMonitor)
    }
  }

  function toggleMonitor(name) {
    var list = activeNames.slice()
    var idx = list.indexOf(name)
    if (idx !== -1) {
      // Keep the widget on at least one display; the close button removes it.
      if (list.length <= 1) return
      list.splice(idx, 1)
    } else {
      list.push(name)
    }
    applyMonitors(list)
  }

  function toggleAll() {
    if (onAll) {
      if (currentMonitor !== "") applyMonitors([currentMonitor])
      return
    }
    var list = []
    for (var i = 0; i < screenRects.length; i++) list.push(screenRects[i].name)
    applyMonitors(list)
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: Style.space(10)
    Layout.rightMargin: Style.space(2)
    spacing: Style.space(8)

    Item {
      Layout.preferredWidth: 16
      Layout.preferredHeight: 16
      Layout.alignment: Qt.AlignVCenter

      Text {
        anchors.centerIn: parent
        text: ""
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.accent
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: "Displays"
      font.family: Style.font.family
      font.pixelSize: 11
      font.weight: Font.Bold
      color: Color.foreground
      elide: Text.ElideRight
    }

    Rectangle {
      implicitWidth: allLabel.implicitWidth + Style.space(18)
      implicitHeight: 20
      radius: 6
      color: pickerRoot.onAll
        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, allMouse.containsMouse ? 0.40 : 0.25)
        : (allMouse.containsMouse ? Util.alpha(Color.foreground, 0.15) : Util.alpha(Color.foreground, 0.06))
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, pickerRoot.onAll ? 0.9 : 0.4)
      border.width: 1

      Text {
        id: allLabel
        anchors.centerIn: parent
        text: "All"
        font.family: Style.font.family
        font.pixelSize: 10
        font.weight: Font.Bold
        color: pickerRoot.onAll ? Color.accent : Color.foreground
      }

      MouseArea {
        id: allMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pickerRoot.toggleAll()
      }
    }
  }

  Item {
    id: mapArea
    Layout.fillWidth: true
    Layout.preferredHeight: Math.ceil(pickerRoot.bounds.h * mapScale)
    Layout.bottomMargin: Style.space(2)

    readonly property real mapScale: Math.min(width / pickerRoot.bounds.w, pickerRoot.maxMapHeight / pickerRoot.bounds.h)
    readonly property real offsetX: (width - pickerRoot.bounds.w * mapScale) / 2

    Repeater {
      model: pickerRoot.screenRects

      Rectangle {
        id: screenTile
        required property var modelData

        readonly property bool selected: pickerRoot.activeNames.indexOf(modelData.name) !== -1
        readonly property bool isCurrent: modelData.name === pickerRoot.currentMonitor

        x: mapArea.offsetX + (modelData.x - pickerRoot.bounds.x) * mapArea.mapScale + 1.5
        y: (modelData.y - pickerRoot.bounds.y) * mapArea.mapScale + 1.5
        width: Math.max(0, modelData.width * mapArea.mapScale - 3)
        height: Math.max(0, modelData.height * mapArea.mapScale - 3)
        radius: 4
        color: selected
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, tileMouse.containsMouse ? 0.50 : 0.35)
          : (tileMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : Util.alpha(Color.foreground, 0.06))
        border.color: selected ? Color.accent : Util.alpha(Color.foreground, 0.28)
        border.width: selected ? 1.5 : 1

        Text {
          anchors.centerIn: parent
          width: parent.width - 6
          horizontalAlignment: Text.AlignHCenter
          text: screenTile.modelData.name
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: screenTile.selected ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          elide: Text.ElideRight
        }

        // Marks the display this menu was opened on
        Rectangle {
          visible: screenTile.isCurrent
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: 4
          width: 4
          height: 4
          radius: 2
          color: Color.foreground
        }

        MouseArea {
          id: tileMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pickerRoot.toggleMonitor(screenTile.modelData.name)
        }
      }
    }
  }
}
