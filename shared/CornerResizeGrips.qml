import QtQuick
import QtQuick.Shapes
import qs.Commons

// Corner resize grips in the style of the ezp plugins: a bracket on each corner
// that traces the card's own rounded corner. Each one resizes from its corner
// and keeps the opposite corner fixed. Only a band along the card's two edges
// takes the mouse, so header buttons near a corner stay clickable.
Item {
  id: grips
  anchors.fill: parent

  // The widget root being resized: reads width/height, minWidth/maxWidth,
  // minHeight/maxHeight and screenWidth/screenHeight from it
  property Item card: null
  // The item that carries the card's position (its loader, when it has one)
  property Item target: card
  // Corner radius of the visible card
  property real radius: 18
  // Offset of the visible card from the widget's bounds, for widgets that draw
  // their card inside a margin
  property real insetX: 0
  property real insetY: 0
  property int gridSnap: 20

  property bool resizing: false
  // Emitted once the released size has been snapped; the caller persists it
  signal resized()

  function snap(v) {
    return gridSnap > 1 ? (Math.round(v / gridSnap) * gridSnap) : Math.round(v)
  }

  Repeater {
    model: [
      { ax: 0, ay: 0, cursor: Qt.SizeFDiagCursor },
      { ax: 1, ay: 0, cursor: Qt.SizeBDiagCursor },
      { ax: 0, ay: 1, cursor: Qt.SizeBDiagCursor },
      { ax: 1, ay: 1, cursor: Qt.SizeFDiagCursor }
    ]

    Item {
      id: grip
      required property var modelData

      readonly property bool atLeft: modelData.ax === 0
      readonly property bool atTop: modelData.ay === 0
      readonly property real barLength: Style.space(13)
      readonly property real barThickness: Style.space(3)
      // The stroke runs half its thickness inside the edge, so it sits on the
      // card's border along an arc concentric with the card's own corner
      readonly property real inset: barThickness / 2
      readonly property real r: Math.max(0, grips.radius - inset)
      readonly property real hitSize: grips.radius + barLength + Style.space(4)
      // How far in from each edge the grip takes the mouse
      readonly property real hitBand: Style.space(10)

      // The corner point and the direction each bar runs from it, in local
      // coordinates
      readonly property real cornerX: atLeft ? inset : hitSize - inset
      readonly property real cornerY: atTop ? inset : hitSize - inset
      readonly property real dirX: atLeft ? 1 : -1
      readonly property real dirY: atTop ? 1 : -1

      // PathArc.Clockwise/Counterclockwise only resolve when assigned as a
      // literal, so the arc always sweeps Counterclockwise and the top-right
      // and bottom-left grips trace it from the other end instead
      readonly property bool swapEnds: atLeft !== atTop
      readonly property real tipH: cornerX + dirX * (r + barLength)  // horizontal bar's outer tip
      readonly property real edgeH: cornerX + dirX * r              // arc's end on the horizontal edge
      readonly property real edgeV: cornerY + dirY * r              // arc's end on the vertical edge
      readonly property real tipV: cornerY + dirY * (r + barLength) // vertical bar's outer tip

      width: hitSize
      height: hitSize
      x: atLeft ? grips.insetX : grips.width - grips.insetX - hitSize
      y: atTop ? grips.insetY : grips.height - grips.insetY - hitSize

      Shape {
        anchors.fill: parent

        ShapePath {
          strokeColor: cornerArea.pressed || cornerArea.containsMouse ? Color.accent : Color.muted
          strokeWidth: grip.barThickness
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin

          startX: grip.swapEnds ? grip.cornerX : grip.tipH
          startY: grip.swapEnds ? grip.tipV : grip.cornerY

          PathLine {
            x: grip.swapEnds ? grip.cornerX : grip.edgeH
            y: grip.swapEnds ? grip.edgeV : grip.cornerY
          }
          PathArc {
            x: grip.swapEnds ? grip.edgeH : grip.cornerX
            y: grip.swapEnds ? grip.cornerY : grip.edgeV
            radiusX: grip.r
            radiusY: grip.r
            direction: PathArc.Counterclockwise
          }
          PathLine {
            x: grip.swapEnds ? grip.tipH : grip.cornerX
            y: grip.swapEnds ? grip.cornerY : grip.tipV
          }
        }
      }

      MouseArea {
        id: cornerArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: grip.modelData.cursor

        // An L along the two edges rather than the whole square
        containmentMask: QtObject {
          function contains(point: point): bool {
            var dx = grip.atLeft ? point.x : grip.hitSize - point.x
            var dy = grip.atTop ? point.y : grip.hitSize - point.y
            return dx >= 0 && dy >= 0 && dx <= grip.hitSize && dy <= grip.hitSize
              && Math.min(dx, dy) < grip.hitBand
          }
        }

        property real startX: 0
        property real startY: 0
        property real startWidth: 0
        property real startHeight: 0
        property point startScene: Qt.point(0, 0)

        onPressed: function(mouse) {
          startX = grips.target.x
          startY = grips.target.y
          startWidth = grips.card.width
          startHeight = grips.card.height
          // Scene coordinates: the card itself moves while a left or top corner drags
          startScene = mapToItem(null, mouse.x, mouse.y)
          grips.resizing = true
        }

        onPositionChanged: function(mouse) {
          if (!pressed) return
          var c = grips.card
          var p = mapToItem(null, mouse.x, mouse.y)
          // The opposite edge stays put, and the card stays 10px inside the screen
          var maxW = Math.min(c.maxWidth, grip.atLeft ? startX + startWidth - 10 : c.screenWidth - 10 - startX)
          var maxH = Math.min(c.maxHeight, grip.atTop ? startY + startHeight - 10 : c.screenHeight - 10 - startY)
          var w = startWidth + (p.x - startScene.x) * (grip.atLeft ? -1 : 1)
          var h = startHeight + (p.y - startScene.y) * (grip.atTop ? -1 : 1)
          w = Math.max(c.minWidth, Math.min(maxW, w))
          h = Math.max(c.minHeight, Math.min(maxH, h))
          c.width = w
          c.height = h
          if (grip.atLeft) grips.target.x = startX + startWidth - w
          if (grip.atTop) grips.target.y = startY + startHeight - h
        }

        function finish() {
          if (!grips.resizing) return
          var c = grips.card
          var w = Math.max(c.minWidth, Math.min(c.maxWidth, grips.snap(c.width)))
          var h = Math.max(c.minHeight, Math.min(c.maxHeight, grips.snap(c.height)))
          c.width = w
          c.height = h
          if (grip.atLeft) grips.target.x = startX + startWidth - w
          if (grip.atTop) grips.target.y = startY + startHeight - h
          grips.resizing = false
          grips.resized()
        }

        onReleased: finish()
        onCanceled: finish()
      }
    }
  }
}
