import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

Item {
  id: prefsDialogRoot

  property var rootRef: null
  property bool isOpen: false
  property int activeTab: 0

  readonly property real curOpacity: (rootRef && rootRef.appearance && rootRef.appearance.bg_opacity !== undefined) ? rootRef.appearance.bg_opacity : 0.85
  readonly property int curRadius: (rootRef && rootRef.appearance && rootRef.appearance.corner_radius !== undefined) ? rootRef.appearance.corner_radius : 18
  readonly property bool curShadows: (rootRef && rootRef.appearance && rootRef.appearance.shadows_enabled !== undefined) ? rootRef.appearance.shadows_enabled : true
  readonly property bool curAnimations: (rootRef && rootRef.appearance && rootRef.appearance.animations_enabled !== undefined) ? rootRef.appearance.animations_enabled : true
  readonly property int curGridSnap: (rootRef && rootRef.appearance && rootRef.appearance.grid_snap !== undefined) ? rootRef.appearance.grid_snap : 20
  readonly property string curAutoHide: (rootRef && rootRef.appearance && rootRef.appearance.auto_hide_mode) ? rootRef.appearance.auto_hide_mode : "tiled"

  anchors.fill: parent
  z: 600
  visible: opacity > 0
  opacity: isOpen ? 1.0 : 0.0

  Behavior on opacity {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  // Backdrop Dimmer (click to close)
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.65)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: prefsDialogRoot.isOpen = false
    }
  }

  // Floating Center Modal Dialog
  Rectangle {
    id: dialogSurface
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(32), 640)
    height: Math.min(parent.height - Style.space(64), 540)
    radius: 22
    color: Qt.rgba(16/255, 16/255, 22/255, 0.96)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
    border.width: 1.5

    scale: prefsDialogRoot.isOpen ? 1.0 : 0.92
    Behavior on scale {
      NumberAnimation { duration: 240; easing.type: Easing.OutBack }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.90)
      shadowBlur: 1.0
      shadowVerticalOffset: 8
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(20)
      spacing: Style.space(14)

      // -----------------------------------------------------------------------
      // 🏷️ Header Bar
      // -----------------------------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(12)

        Rectangle {
          width: 38
          height: 38
          radius: 19
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf013"
            font.family: Style.font.family
            font.pixelSize: 16
            color: Color.accent
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "Widget Appearance & Preferences"
            font.family: Style.font.family
            font.pixelSize: 16
            font.weight: Font.Bold
            color: Color.foreground
          }

          Text {
            text: "Customize card acrylic blur, corner styling, grid snap & auto-hide"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            elide: Text.ElideRight
          }
        }

        // Close Button
        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: closeMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
          border.color: closeMouse.containsMouse ? Color.urgent : "transparent"
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 12
            color: closeMouse.containsMouse ? Color.urgent : Color.foreground
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: prefsDialogRoot.isOpen = false
          }
        }
      }

      // -----------------------------------------------------------------------
      // 📑 Tab Bar
      // -----------------------------------------------------------------------
      Rectangle {
        Layout.fillWidth: true
        height: 38
        radius: 10
        color: Qt.rgba(0, 0, 0, 0.40)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: 3
          spacing: 4

          // Tab 0: Appearance
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: prefsDialogRoot.activeTab === 0 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (tab0Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: prefsDialogRoot.activeTab === 0 ? Color.accent : "transparent"
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: "\uf53f"
                font.family: Style.font.family
                font.pixelSize: 12
                color: prefsDialogRoot.activeTab === 0 ? Color.accent : Color.foreground
              }
              Text {
                text: "Appearance"
                font.family: Style.font.family
                font.pixelSize: 12
                font.weight: prefsDialogRoot.activeTab === 0 ? Font.Bold : Font.Normal
                color: prefsDialogRoot.activeTab === 0 ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
              }
            }

            MouseArea {
              id: tab0Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: prefsDialogRoot.activeTab = 0
            }
          }

          // Tab 1: Grid & Snapping
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: prefsDialogRoot.activeTab === 1 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (tab1Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: prefsDialogRoot.activeTab === 1 ? Color.accent : "transparent"
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: "\uf00a"
                font.family: Style.font.family
                font.pixelSize: 12
                color: prefsDialogRoot.activeTab === 1 ? Color.accent : Color.foreground
              }
              Text {
                text: "Grid & Snap"
                font.family: Style.font.family
                font.pixelSize: 12
                font.weight: prefsDialogRoot.activeTab === 1 ? Font.Bold : Font.Normal
                color: prefsDialogRoot.activeTab === 1 ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
              }
            }

            MouseArea {
              id: tab1Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: prefsDialogRoot.activeTab = 1
            }
          }

          // Tab 2: Auto-Hide
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: prefsDialogRoot.activeTab === 2 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (tab2Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: prefsDialogRoot.activeTab === 2 ? Color.accent : "transparent"
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: "\uf06e"
                font.family: Style.font.family
                font.pixelSize: 12
                color: prefsDialogRoot.activeTab === 2 ? Color.accent : Color.foreground
              }
              Text {
                text: "Auto-Hide"
                font.family: Style.font.family
                font.pixelSize: 12
                font.weight: prefsDialogRoot.activeTab === 2 ? Font.Bold : Font.Normal
                color: prefsDialogRoot.activeTab === 2 ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
              }
            }

            MouseArea {
              id: tab2Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: prefsDialogRoot.activeTab = 2
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // 📦 Content Area
      // -----------------------------------------------------------------------
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // =====================================================================
        // TAB 0: APPEARANCE
        // =====================================================================
        ColumnLayout {
          anchors.fill: parent
          visible: prefsDialogRoot.activeTab === 0
          spacing: Style.space(12)

          // 1. Background Opacity & Acrylic
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: opacityCol.implicitHeight + 20
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.30)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            ColumnLayout {
              id: opacityCol
              anchors.fill: parent
              anchors.margins: 12
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "Card Background Transparency"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.weight: Font.DemiBold
                  color: Color.foreground
                }
                Item { Layout.fillWidth: true }
                Text {
                  text: Math.round(prefsDialogRoot.curOpacity * 100) + "%"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.weight: Font.Bold
                  color: Color.accent
                }
              }

              // Custom Slider Track
              Rectangle {
                id: opacityTrack
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                  height: parent.height
                  width: Math.max(8, Math.min(parent.width, Math.max(0, (prefsDialogRoot.curOpacity - 0.15) / 0.85) * parent.width))
                  radius: 4
                  color: Color.accent
                }

                Rectangle {
                  x: Math.max(0, Math.min(parent.width - width, (prefsDialogRoot.curOpacity - 0.15) / 0.85 * (parent.width - width)))
                  anchors.verticalCenter: parent.verticalCenter
                  width: 18
                  height: 18
                  radius: 9
                  color: Color.accent
                  border.color: "#ffffff"
                  border.width: 2

                  layer.enabled: true
                  layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.6)
                    shadowBlur: 0.5
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -10
                  cursorShape: Qt.PointingHandCursor
                  function setVal(mx) {
                    var frac = Math.max(0.0, Math.min(1.0, (mx - 10) / opacityTrack.width))
                    var op = 0.15 + frac * 0.85
                    op = Math.round(op * 100) / 100
                    if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("bg_opacity", op)
                  }
                  onPressed: function(mouse) { setVal(mouse.x) }
                  onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x) }
                }
              }

              // Quick Chips
              RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                  model: [
                    { label: "Glassy 30%", val: 0.30 },
                    { label: "Translucent 60%", val: 0.60 },
                    { label: "Standard 85%", val: 0.85 },
                    { label: "Solid 100%", val: 1.00 }
                  ]

                  Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 6
                    readonly property bool isSelected: Math.abs(prefsDialogRoot.curOpacity - modelData.val) < 0.05
                    color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28) : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.35))
                    border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
                    border.width: isSelected ? 1.5 : 1

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.weight: isSelected ? Font.Bold : Font.Normal
                      color: isSelected ? Color.accent : Color.foreground
                    }

                    MouseArea {
                      id: chipMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("bg_opacity", modelData.val)
                    }
                  }
                }
              }
            }
          }

          // 2. Corner Radius
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: radiusCol.implicitHeight + 20
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.30)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            ColumnLayout {
              id: radiusCol
              anchors.fill: parent
              anchors.margins: 12
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "Card Corner Curvature"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.weight: Font.DemiBold
                  color: Color.foreground
                }
                Item { Layout.fillWidth: true }
                Text {
                  text: prefsDialogRoot.curRadius + " px"
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.weight: Font.Bold
                  color: Color.accent
                }
              }

              Rectangle {
                id: radiusTrack
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                  height: parent.height
                  width: Math.max(8, Math.min(parent.width, prefsDialogRoot.curRadius / 32 * parent.width))
                  radius: 4
                  color: Color.accent
                }

                Rectangle {
                  x: Math.max(0, Math.min(parent.width - width, (prefsDialogRoot.curRadius / 32) * (parent.width - width)))
                  anchors.verticalCenter: parent.verticalCenter
                  width: 18
                  height: 18
                  radius: 9
                  color: Color.accent
                  border.color: "#ffffff"
                  border.width: 2

                  layer.enabled: true
                  layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.6)
                    shadowBlur: 0.5
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -10
                  cursorShape: Qt.PointingHandCursor
                  function setRad(mx) {
                    var frac = Math.max(0.0, Math.min(1.0, (mx - 10) / radiusTrack.width))
                    var rad = Math.round(frac * 32)
                    if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("corner_radius", rad)
                  }
                  onPressed: function(mouse) { setRad(mouse.x) }
                  onPositionChanged: function(mouse) { if (pressed) setRad(mouse.x) }
                }
              }

              // Corner Radius Chips
              RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                  model: [
                    { label: "Sharp (0px)", val: 0 },
                    { label: "Subtle (8px)", val: 8 },
                    { label: "Standard (18px)", val: 18 },
                    { label: "Rounded (28px)", val: 28 }
                  ]

                  Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 6
                    readonly property bool isSelected: prefsDialogRoot.curRadius === modelData.val
                    color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28) : (radMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.35))
                    border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
                    border.width: isSelected ? 1.5 : 1

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      font.family: Style.font.family
                      font.pixelSize: 10
                      font.weight: isSelected ? Font.Bold : Font.Normal
                      color: isSelected ? Color.accent : Color.foreground
                    }

                    MouseArea {
                      id: radMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("corner_radius", modelData.val)
                    }
                  }
                }
              }
            }
          }

          // 3. Toggles: Drop Shadows & Workspace Transitions
          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Drop Shadows Toggle
            Rectangle {
              Layout.fillWidth: true
              height: 48
              radius: 12
              color: Qt.rgba(0, 0, 0, 0.30)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    text: "Card Shadows"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Color.foreground
                  }
                  Text {
                    text: "Depth drop shadows"
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
                  }
                }

                Rectangle {
                  width: 40
                  height: 24
                  radius: 12
                  color: prefsDialogRoot.curShadows ? Color.accent : Qt.rgba(0, 0, 0, 0.45)
                  border.color: prefsDialogRoot.curShadows ? Color.accent : Qt.rgba(1, 1, 1, 0.20)
                  border.width: 1
                  Behavior on color { ColorAnimation { duration: 160 } }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: prefsDialogRoot.curShadows ? (parent.width - width - 3) : 3
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("shadows_enabled", !prefsDialogRoot.curShadows)
                  }
                }
              }
            }

            // Workspace Transitions Toggle
            Rectangle {
              Layout.fillWidth: true
              height: 48
              radius: 12
              color: Qt.rgba(0, 0, 0, 0.30)
              border.color: Qt.rgba(1, 1, 1, 0.08)
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    text: "Workspace Motion"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Color.foreground
                  }
                  Text {
                    text: "Slide & fade transitions"
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
                  }
                }

                Rectangle {
                  width: 40
                  height: 24
                  radius: 12
                  color: prefsDialogRoot.curAnimations ? Color.accent : Qt.rgba(0, 0, 0, 0.45)
                  border.color: prefsDialogRoot.curAnimations ? Color.accent : Qt.rgba(1, 1, 1, 0.20)
                  border.width: 1
                  Behavior on color { ColorAnimation { duration: 160 } }

                  Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: prefsDialogRoot.curAnimations ? (parent.width - width - 3) : 3
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("animations_enabled", !prefsDialogRoot.curAnimations)
                  }
                }
              }
            }
          }
        }

        // =====================================================================
        // TAB 1: GRID & SNAPPING
        // =====================================================================
        ColumnLayout {
          anchors.fill: parent
          visible: prefsDialogRoot.activeTab === 1
          spacing: Style.space(10)

          Text {
            text: "Select snapping precision when dragging and resizing widgets:"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
          }

          Repeater {
            model: [
              {
                title: "Standard 20px Snap",
                desc: "Balanced alignment recommended for clean, organized desktop grids.",
                snap: 20,
                icon: "\uf00a"
              },
              {
                title: "Fine 10px Snap",
                desc: "High density alignment allowing tighter packing between widgets.",
                snap: 10,
                icon: "\uf141"
              },
              {
                title: "Coarse 40px Snap",
                desc: "Bold modular blocks that align cleanly across larger displays.",
                snap: 40,
                icon: "\uf0c9"
              },
              {
                title: "Freeform (Pixel Perfect)",
                desc: "No snapping restriction; place widgets anywhere with 1-pixel precision.",
                snap: 0,
                icon: "\uf256"
              }
            ]

            Rectangle {
              Layout.fillWidth: true
              height: 54
              radius: 12
              readonly property bool isSelected: prefsDialogRoot.curGridSnap === modelData.snap
              color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (gridMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.28))
              border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.08)
              border.width: isSelected ? 1.5 : 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                  width: 32
                  height: 32
                  radius: 8
                  color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isSelected ? Color.accent : Color.foreground
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    Layout.fillWidth: true
                    text: modelData.title
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.desc
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
                    elide: Text.ElideRight
                  }
                }

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: isSelected ? Color.accent : "transparent"
                  border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.3)
                  border.width: 1.5

                  Text {
                    visible: isSelected
                    anchors.centerIn: parent
                    text: "\uf00c"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: "#ffffff"
                  }
                }
              }

              MouseArea {
                id: gridMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("grid_snap", modelData.snap)
              }
            }
          }
        }

        // =====================================================================
        // TAB 2: AUTO-HIDE BEHAVIOR
        // =====================================================================
        ColumnLayout {
          anchors.fill: parent
          visible: prefsDialogRoot.activeTab === 2
          spacing: Style.space(10)

          Text {
            text: "Choose how widgets respond to application windows on the desktop:"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
          }

          Repeater {
            model: [
              {
                idVal: "tiled",
                title: "Hide on Any Active Window (Default)",
                desc: "Widgets automatically hide whenever any app window is open on the workspace.",
                icon: "\uf2d0"
              },
              {
                idVal: "fullscreen",
                title: "Hide on Fullscreen Only",
                desc: "Widgets stay visible beneath tiled & floating windows, hiding only for fullscreen apps.",
                icon: "\uf065"
              },
              {
                idVal: "always",
                title: "Always Keep Visible",
                desc: "Widgets remain rendered on the desktop wallpaper canvas at all times.",
                icon: "\uf06e"
              },
              {
                idVal: "manual",
                title: "Manual Toggle Only",
                desc: "Widgets disregard window states and only show/hide when triggered via top bar or shortcut.",
                icon: "\uf011"
              }
            ]

            Rectangle {
              Layout.fillWidth: true
              height: 54
              radius: 12
              readonly property bool isSelected: prefsDialogRoot.curAutoHide === modelData.idVal
              color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (hideMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.28))
              border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.08)
              border.width: isSelected ? 1.5 : 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                  width: 32
                  height: 32
                  radius: 8
                  color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 14
                    color: isSelected ? Color.accent : Color.foreground
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    Layout.fillWidth: true
                    text: modelData.title
                    font.family: Style.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Color.foreground
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.desc
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
                    elide: Text.ElideRight
                  }
                }

                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: isSelected ? Color.accent : "transparent"
                  border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.3)
                  border.width: 1.5

                  Text {
                    visible: isSelected
                    anchors.centerIn: parent
                    text: "\uf00c"
                    font.family: Style.font.family
                    font.pixelSize: 10
                    color: "#ffffff"
                  }
                }
              }

              MouseArea {
                id: hideMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.updateAppearance) prefsDialogRoot.rootRef.updateAppearance("auto_hide_mode", modelData.idVal)
              }
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // 🏁 Footer Actions
      // -----------------------------------------------------------------------
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // Reset to Defaults Button
        Rectangle {
          implicitWidth: resetText.implicitWidth + 20
          height: 32
          radius: 8
          color: resetMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
          border.color: resetMouse.containsMouse ? Color.urgent : Qt.rgba(1, 1, 1, 0.1)
          border.width: 1

          RowLayout {
            id: resetText
            anchors.centerIn: parent
            spacing: 6
            Text {
              text: "\uf0e2"
              font.family: Style.font.family
              font.pixelSize: 11
              color: resetMouse.containsMouse ? Color.urgent : Color.foreground
            }
            Text {
              text: "Reset Defaults"
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: resetMouse.containsMouse ? Color.urgent : Color.foreground
            }
          }

          MouseArea {
            id: resetMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (prefsDialogRoot.rootRef && prefsDialogRoot.rootRef.setAppearanceAll) {
                prefsDialogRoot.rootRef.setAppearanceAll({
                  bg_opacity: 0.85,
                  corner_radius: 18,
                  grid_snap: 20,
                  auto_hide_mode: "tiled",
                  shadows_enabled: true,
                  animations_enabled: true
                })
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Done Button
        Rectangle {
          implicitWidth: doneText.implicitWidth + 28
          height: 32
          radius: 8
          color: doneMouse.containsMouse ? Qt.lighter(Color.accent, 1.15) : Color.accent

          Text {
            id: doneText
            anchors.centerIn: parent
            text: "Done"
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.Bold
            color: "#ffffff"
          }

          MouseArea {
            id: doneMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: prefsDialogRoot.isOpen = false
          }
        }
      }
    }
  }
}
