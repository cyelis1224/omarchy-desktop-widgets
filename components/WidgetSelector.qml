import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

Item {
  id: selectorRoot

  property var rootRef: null
  property var registry: null
  property string targetMonitorName: ""
  property string selectedCategory: "ALL"
  property string searchQuery: ""

  anchors.fill: parent
  z: 500
  visible: opacity > 0
  opacity: (rootRef && rootRef.selectorOpen) ? 1.0 : 0.0

  Behavior on opacity {
    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
  }

  // Backdrop Dimmer (click to close)
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.65)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: if (rootRef) rootRef.selectorOpen = false
    }
  }

  // Sliding Bottom Drawer Container
  Rectangle {
    id: drawerSurface
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: (rootRef && rootRef.selectorOpen) ? Style.space(24) : -height
    width: Math.min(parent.width - Style.space(48), 920)
    height: Math.min(parent.height - Style.space(120), 480)
    radius: 24
    color: Util.alpha(Color.menu.background, 0.95)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
    border.width: 1.5

    Behavior on anchors.bottomMargin {
      NumberAnimation { duration: 320; easing.type: Easing.OutBack }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.95)
      shadowBlur: 1.0
      shadowVerticalOffset: 8
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(20)
      spacing: Style.space(16)

      // -----------------------------------------------------------------------
      // 🏷️ Top Header Bar
      // -----------------------------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(12)

        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf009"
            font.family: Style.font.family
            font.pixelSize: 16
            color: Color.accent
          }
        }

        ColumnLayout {
          spacing: 0
          Text {
            text: selectorRoot.targetMonitorName ? ("Widget Marketplace (" + selectorRoot.targetMonitorName + ")") : "Widget Marketplace & Selector"
            font.family: Style.font.family
            font.pixelSize: 16
            font.weight: Font.Bold
            color: Color.foreground
          }
          Text {
            text: "Toggle or drag widgets directly onto your desktop"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
          }
        }

        Item { Layout.fillWidth: true }

        // ➕ Import Custom QML Widget Button
        Rectangle {
          implicitWidth: importRow.implicitWidth + 20
          implicitHeight: 32
          radius: 16
          color: importMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Util.alpha(Color.foreground, 0.08)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
          border.width: 1

          RowLayout {
            id: importRow
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: "\uf093"
              font.family: Style.font.family
              font.pixelSize: 12
              color: Color.accent
            }
            Text {
              text: "Import QML Widget..."
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Color.foreground
            }
          }

          MouseArea {
            id: importMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (rootRef && rootRef.importCustomWidget) {
                rootRef.importCustomWidget()
              }
            }
          }
        }

        // Close Button
        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: closeDrawerMouse.containsMouse ? Util.alpha(Color.foreground, 0.22) : Util.alpha(Color.foreground, 0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 13
            color: Color.foreground
          }

          MouseArea {
            id: closeDrawerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (rootRef) rootRef.selectorOpen = false
          }
        }
      }

      // -----------------------------------------------------------------------
      // 🔍 Search Bar (Placed above category buttons)
      // -----------------------------------------------------------------------
      Rectangle {
        Layout.fillWidth: true
        height: 36
        radius: 18
        color: Util.alpha(Color.foreground, 0.08)
        border.color: searchInput.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 12
          spacing: 8

          Text {
            text: "\uf002"
            font.family: Style.font.family
            font.pixelSize: 13
            color: searchInput.activeFocus ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }

          TextInput {
            id: searchInput
            Layout.fillWidth: true
            font.family: Style.font.family
            font.pixelSize: 12
            color: Color.foreground
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true
            onTextChanged: selectorRoot.searchQuery = text.trim().toLowerCase()

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              text: "Search all widgets (e.g. coin tracker, clock, system, notes)..."
              font.family: Style.font.family
              font.pixelSize: 12
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
              visible: !searchInput.text && !searchInput.activeFocus
            }
          }

          Text {
            visible: searchInput.text.length > 0
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: searchInput.text = ""
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // 🏷️ Category Filter Bar
      // -----------------------------------------------------------------------
      Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        contentWidth: catRow.implicitWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        RowLayout {
          id: catRow
          spacing: Style.space(8)

          Repeater {
            model: [
              { label: "All Widgets", cat: "ALL", icon: "\uf009" },
              { label: "Finance", cat: "Finance", icon: "\uf51e" },
              { label: "Glance", cat: "Glance", icon: "\uf017" },
              { label: "Productivity", cat: "Productivity", icon: "\uf249" },
              { label: "System", cat: "System", icon: "\uf2db" },
              { label: "Dev", cat: "Dev", icon: "\uf1d3" },
              { label: "Media", cat: "Media", icon: "\uf001" },
              { label: "Custom", cat: "Custom", icon: "\uf12e" }
            ]

            Rectangle {
              required property var modelData
              implicitWidth: catTabRow.implicitWidth + 24
              implicitHeight: 30
              radius: 15
              readonly property bool isSelected: selectorRoot.selectedCategory === modelData.cat
              // Selected wins over hover: the label is Color.background, so it needs the solid accent under it
              color: isSelected ? Color.accent : (catMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Util.alpha(Color.foreground, 0.08))
              border.color: isSelected ? Util.alpha(Color.foreground, 0.3) : Util.alpha(Color.foreground, 0.1)
              border.width: 1

              RowLayout {
                id: catTabRow
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text {
                  text: modelData.icon
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: isSelected ? Color.background : Color.accent
                }
                Text {
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.weight: isSelected ? Font.Bold : Font.Normal
                  color: isSelected ? Color.background : Color.foreground
                }
              }

              MouseArea {
                id: catMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: selectorRoot.selectedCategory = modelData.cat
              }
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      // 📦 Widget Cards Grid
      // -----------------------------------------------------------------------
      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: widgetFlow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
          id: widgetFlow
          width: parent.width
          spacing: Style.space(12)

          Repeater {
            model: {
              if (!selectorRoot.registry) return []
              var all = selectorRoot.registry.allWidgets
              var filtered = []
              var q = selectorRoot.searchQuery
              for (var i = 0; i < all.length; i++) {
                var item = all[i]
                if (selectorRoot.selectedCategory !== "ALL" && item.category !== selectorRoot.selectedCategory) {
                  continue
                }
                if (q !== "") {
                  var name = (item.name || "").toLowerCase()
                  var desc = (item.description || "").toLowerCase()
                  var cat = (item.category || "").toLowerCase()
                  var id = (item.id || "").toLowerCase()
                  var isMatch = name.indexOf(q) !== -1 || desc.indexOf(q) !== -1 || cat.indexOf(q) !== -1 || id.indexOf(q) !== -1
                  if (id === "coin_tracker" && (q.indexOf("btc") !== -1 || q.indexOf("crypto") !== -1 || q.indexOf("bitcoin") !== -1 || q.indexOf("eth") !== -1 || q.indexOf("coin") !== -1)) {
                    isMatch = true
                  }
                  if (!isMatch) continue
                }
                filtered.push(item)
              }
              return filtered
            }

            Rectangle {
              id: widgetCardItem
              required property var modelData
              width: (widgetFlow.width - Style.space(12)) / 2
              implicitHeight: 120
              radius: 16
              color: Util.alpha(Color.foreground, cardHoverArea.containsMouse ? 0.08 : 0.04)
              border.color: isAdded ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : Util.alpha(Color.foreground, 0.1)
              border.width: 1

              readonly property bool isAdded: {
                if (rootRef && typeof rootRef.isWidgetActiveOnMonitor === "function") {
                  return rootRef.isWidgetActiveOnMonitor(modelData.id, selectorRoot.targetMonitorName)
                }
                return (rootRef && rootRef.enabledWidgets && rootRef.enabledWidgets.indexOf(modelData.id) !== -1)
              }

              RowLayout {
                anchors.fill: parent
                anchors.margins: Style.space(14)
                spacing: Style.space(12)

                // Left Icon Box
                Rectangle {
                  Layout.alignment: Qt.AlignTop
                  width: 44
                  height: 44
                  radius: 12
                  color: isAdded ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : Util.alpha(Color.foreground, 0.08)
                  border.color: isAdded ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : Util.alpha(Color.foreground, 0.12)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: Style.font.family
                    font.pixelSize: 20
                    color: isAdded ? Color.accent : Color.foreground
                  }
                }

                // Middle Info
                ColumnLayout {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  spacing: Style.space(4)

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    Text {
                      Layout.fillWidth: true
                      text: modelData.name
                      font.family: Style.font.family
                      font.pixelSize: 13
                      font.weight: Font.Bold
                      color: Color.foreground
                      elide: Text.ElideRight
                    }

                    Rectangle {
                      visible: modelData.badge !== undefined
                      implicitWidth: badgeText.implicitWidth + 10
                      implicitHeight: 18
                      radius: 9
                      color: isAdded ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Util.alpha(Color.foreground, 0.1)

                      Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: modelData.badge || ""
                        font.family: Style.font.family
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: isAdded ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
                      }
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.description
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }

                  Item { Layout.fillHeight: true }

                  // Action Button
                  RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    Rectangle {
                      implicitWidth: actionBtnText.implicitWidth + 20
                      implicitHeight: 26
                      radius: 13
                      color: actionMouse.containsMouse ? (isAdded ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.lighter(Color.accent, 1.2)) : (isAdded ? Util.alpha(Color.foreground, 0.1) : Color.accent)
                      border.color: isAdded ? (actionMouse.containsMouse ? Color.urgent : Util.alpha(Color.foreground, 0.2)) : "transparent"
                      border.width: 1

                      RowLayout {
                        id: actionBtnText
                        anchors.centerIn: parent
                        spacing: Style.space(4)

                        Text {
                          text: isAdded ? (actionMouse.containsMouse ? "\uf00d" : "\uf00c") : "\uf067"
                          font.family: Style.font.family
                          font.pixelSize: 10
                          color: isAdded ? (actionMouse.containsMouse ? Color.urgent : Color.accent) : Color.background
                        }
                        Text {
                          text: isAdded ? (actionMouse.containsMouse ? "Remove" : "On Desktop") : "Add to Desktop"
                          font.family: Style.font.family
                          font.pixelSize: 11
                          font.weight: Font.Bold
                          color: isAdded ? (actionMouse.containsMouse ? Color.urgent : Color.foreground) : Color.background
                        }
                      }

                      MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (rootRef && rootRef.toggleWidgetEnabled) {
                            rootRef.toggleWidgetEnabled(modelData.id, !isAdded, selectorRoot.targetMonitorName)
                          }
                        }
                      }
                    }
                  }
                }
              }

              MouseArea {
                id: cardHoverArea
                anchors.fill: parent
                hoverEnabled: true
                z: -1
              }
            }
          }
        }
      }
    }
  }
}
