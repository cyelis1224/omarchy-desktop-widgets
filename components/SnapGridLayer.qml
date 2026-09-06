import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: gridRoot

  property bool active: false
  property color gridColor: Color.accent
  property int minorGridSize: 20
  property int majorGridSize: 100

  // 🎯 Active Drag & Spotlight Tracking
  property real highlightCenterX: -1
  property real highlightCenterY: -1
  property real highlightWidth: 0
  property real highlightHeight: 0
  readonly property bool hasHighlight: highlightCenterX >= 0 && highlightCenterY >= 0

  anchors.fill: parent
  opacity: active ? 1.0 : 0.0
  visible: opacity > 0

  Behavior on opacity {
    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
  }

  // ---------------------------------------------------------------------------
  // 📐 Base Subtle Snap Grid Canvas (Cached Texture)
  // ---------------------------------------------------------------------------
  Canvas {
    id: gridCanvas
    anchors.fill: parent
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative
    antialiasing: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
      target: Color
      function onAccentChanged() {
        gridCanvas.requestPaint()
      }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width
      var h = height
      if (w <= 0 || h <= 0) return

      var c = gridRoot.gridColor
      var minorDotColor = Qt.rgba(c.r, c.g, c.b, 0.22)
      var majorCrossColor = Qt.rgba(c.r, c.g, c.b, 0.65)
      var majorLineColor = Qt.rgba(c.r, c.g, c.b, 0.06)

      // 1. Major grid hairline guidelines (100px)
      ctx.beginPath()
      ctx.lineWidth = 1
      ctx.strokeStyle = majorLineColor
      for (var lx = gridRoot.majorGridSize; lx < w; lx += gridRoot.majorGridSize) {
        ctx.moveTo(lx + 0.5, 0)
        ctx.lineTo(lx + 0.5, h)
      }
      for (var ly = gridRoot.majorGridSize; ly < h; ly += gridRoot.majorGridSize) {
        ctx.moveTo(0, ly + 0.5)
        ctx.lineTo(w, ly + 0.5)
      }
      ctx.stroke()

      // 2. Minor snap dots (20px)
      ctx.fillStyle = minorDotColor
      var minorStep = gridRoot.minorGridSize
      var majorStep = gridRoot.majorGridSize
      for (var gx = minorStep; gx < w; gx += minorStep) {
        var isMajorX = (gx % majorStep === 0)
        for (var gy = minorStep; gy < h; gy += minorStep) {
          var isMajorY = (gy % majorStep === 0)
          if (!isMajorX || !isMajorY) {
            ctx.beginPath()
            ctx.arc(gx, gy, 1.2, 0, 2 * Math.PI)
            ctx.fill()
          }
        }
      }

      // 3. Precision major crosshairs (+) every 100px
      ctx.beginPath()
      ctx.lineWidth = 1.5
      ctx.strokeStyle = majorCrossColor
      var arm = 5
      for (var mx = majorStep; mx < w; mx += majorStep) {
        for (var my = majorStep; my < h; my += majorStep) {
          ctx.moveTo(mx - arm, my)
          ctx.lineTo(mx + arm, my)
          ctx.moveTo(mx, my - arm)
          ctx.lineTo(mx, my + arm)
        }
      }
      ctx.stroke()
    }
  }

  // ---------------------------------------------------------------------------
  // 🌟 Vivid Drag Spotlight & Alignment Laser Guidelines
  // ---------------------------------------------------------------------------
  Canvas {
    id: spotlightCanvas
    anchors.fill: parent
    visible: gridRoot.hasHighlight
    antialiasing: true

    Connections {
      target: gridRoot
      function onHighlightCenterXChanged() { spotlightCanvas.requestPaint() }
      function onHighlightCenterYChanged() { spotlightCanvas.requestPaint() }
      function onHighlightWidthChanged() { spotlightCanvas.requestPaint() }
      function onHighlightHeightChanged() { spotlightCanvas.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (!gridRoot.hasHighlight) return

      var cx = gridRoot.highlightCenterX
      var cy = gridRoot.highlightCenterY
      var hw = gridRoot.highlightWidth / 2
      var hh = gridRoot.highlightHeight / 2
      var left = cx - hw
      var right = cx + hw
      var top = cy - hh
      var bottom = cy + hh

      var c = gridRoot.gridColor
      var radius = 320

      // 1. Radial Spotlight Glow Gradient
      var radGrad = ctx.createRadialGradient(cx, cy, 40, cx, cy, radius)
      radGrad.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.18))
      radGrad.addColorStop(0.5, Qt.rgba(c.r, c.g, c.b, 0.08))
      radGrad.addColorStop(1.0, "transparent")
      ctx.fillStyle = radGrad
      ctx.beginPath()
      ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
      ctx.fill()

      // 2. Alignment Laser Guide Lines from Widget Edges
      ctx.beginPath()
      ctx.lineWidth = 1
      ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.35)
      ctx.setLineDash([4, 4])

      // Horizontal edge guides
      ctx.moveTo(0, Math.round(top) + 0.5)
      ctx.lineTo(width, Math.round(top) + 0.5)
      ctx.moveTo(0, Math.round(bottom) + 0.5)
      ctx.lineTo(width, Math.round(bottom) + 0.5)

      // Vertical edge guides
      ctx.moveTo(Math.round(left) + 0.5, 0)
      ctx.lineTo(Math.round(left) + 0.5, height)
      ctx.moveTo(Math.round(right) + 0.5, 0)
      ctx.lineTo(Math.round(right) + 0.5, height)
      ctx.stroke()
      ctx.setLineDash([])

      // 3. Vivid High-Intensity Dots in the Spotlight Zone
      var minX = Math.max(gridRoot.minorGridSize, Math.floor((cx - radius) / gridRoot.minorGridSize) * gridRoot.minorGridSize)
      var maxX = Math.min(width, Math.ceil((cx + radius) / gridRoot.minorGridSize) * gridRoot.minorGridSize)
      var minY = Math.max(gridRoot.minorGridSize, Math.floor((cy - radius) / gridRoot.minorGridSize) * gridRoot.minorGridSize)
      var maxY = Math.min(height, Math.ceil((cy + radius) / gridRoot.minorGridSize) * gridRoot.minorGridSize)

      for (var x = minX; x <= maxX; x += gridRoot.minorGridSize) {
        for (var y = minY; y <= maxY; y += gridRoot.minorGridSize) {
          var dist = Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
          if (dist <= radius) {
            var factor = Math.max(0, 1.0 - (dist / radius))
            var isMajor = (x % gridRoot.majorGridSize === 0) && (y % gridRoot.majorGridSize === 0)

            if (isMajor) {
              // Glowing Major Crosshair
              ctx.beginPath()
              ctx.lineWidth = 2.0
              ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.65 + factor * 0.35)
              var arm = 6
              ctx.moveTo(x - arm, y)
              ctx.lineTo(x + arm, y)
              ctx.moveTo(x, y - arm)
              ctx.lineTo(x, y + arm)
              ctx.stroke()
            } else {
              // Glowing Minor Dot
              ctx.beginPath()
              ctx.arc(x, y, 1.2 + factor * 1.2, 0, 2 * Math.PI)
              ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.30 + factor * 0.65)
              ctx.fill()
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🏷️ Blueprint HUD Indicator (Bottom Right)
  // ---------------------------------------------------------------------------
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: Style.space(20)
    implicitWidth: hudRow.implicitWidth + Style.space(20)
    implicitHeight: 26
    radius: 13
    color: Qt.rgba(14/255, 14/255, 20/255, 0.85)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
    border.width: 1

    RowLayout {
      id: hudRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        text: "\uf00a"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.accent
      }

      Text {
        text: "SNAP GRID: " + gridRoot.minorGridSize + "px"
        font.family: Style.font.family
        font.pixelSize: 10
        font.weight: Font.DemiBold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.85)
      }
    }
  }
}
