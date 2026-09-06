import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

Item {
  id: widgetCardRoot

  property string widgetId: ""
  property string title: ""
  property string icon: ""
  property bool showHeader: false
  property real defaultX: Style.space(24)
  property real defaultY: Style.space(64)
  property var rootRef: null
  readonly property real screenWidth: (rootRef && rootRef.screenWidth > 0) ? rootRef.screenWidth : 1920
  readonly property real screenHeight: (rootRef && rootRef.screenHeight > 0) ? rootRef.screenHeight : 1080

  property var loaderItem: null
  readonly property var targetItem: loaderItem ? loaderItem : widgetCardRoot

  property bool customGripDragging: false
  readonly property bool isDragging: gripArea.drag.active || (fullDragArea && fullDragArea.drag.active) || customGripDragging
  scale: isDragging ? 1.025 : 1.0

  Behavior on scale {
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
  }

  // Visual container
  Rectangle {
    id: cardSurface
    anchors.fill: parent
    radius: 18
    color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 0.85)
    border.color: (widgetCardRoot.isDragging || (rootRef && rootRef.layoutEditMode)) ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
    border.width: (widgetCardRoot.isDragging || (rootRef && rootRef.layoutEditMode)) ? 2 : 1

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, widgetCardRoot.isDragging ? 0.90 : 0.70)
      shadowBlur: widgetCardRoot.isDragging ? 0.95 : 0.65
      shadowVerticalOffset: widgetCardRoot.isDragging ? 8 : 4
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // Standard Optional Header Bar
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(12)
        Layout.leftMargin: Style.space(16)
        Layout.rightMargin: Style.space(16)
        Layout.bottomMargin: Style.space(4)
        visible: widgetCardRoot.showHeader
        spacing: Style.space(8)

        Text {
          visible: widgetCardRoot.icon !== ""
          text: widgetCardRoot.icon
          font.family: Style.font.family
          font.pixelSize: 14
          color: Color.accent
        }

        Text {
          visible: widgetCardRoot.title !== ""
          text: widgetCardRoot.title
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Color.foreground
        }

        Item { Layout.fillWidth: true }

        // Remove / Close Widget Button (when in edit mode)
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
                rootRef.toggleWidgetEnabled(widgetCardRoot.widgetId, false)
              }
            }
          }
        }

        // Dedicated Move Grip Handle
        Rectangle {
          id: gripButton
          visible: rootRef && rootRef.layoutEditMode
          width: 22
          height: 22
          radius: 11
          color: gripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
            id: gripArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            drag.target: widgetCardRoot.targetItem
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 10
            drag.maximumX: Math.max(10, widgetCardRoot.screenWidth - widgetCardRoot.width - 10)
            drag.minimumY: 10
            drag.maximumY: Math.max(10, widgetCardRoot.screenHeight - widgetCardRoot.height - 10)

            onReleased: function() {
              var maxX = Math.max(10, widgetCardRoot.screenWidth - widgetCardRoot.width - 10)
              var maxY = Math.max(10, widgetCardRoot.screenHeight - widgetCardRoot.height - 10)
              var snappedX = Math.round(widgetCardRoot.targetItem.x / 20) * 20
              var snappedY = Math.round(widgetCardRoot.targetItem.y / 20) * 20
              snappedX = Math.max(10, Math.min(maxX, snappedX))
              snappedY = Math.max(10, Math.min(maxY, snappedY))
              widgetCardRoot.targetItem.x = snappedX
              widgetCardRoot.targetItem.y = snappedY
              if (rootRef && rootRef.saveWidgetPos) {
                rootRef.saveWidgetPos(widgetCardRoot.widgetId, snappedX, snappedY)
              }
            }
          }
        }
      }

      // Content Slot
      Item {
        id: contentContainer
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
    }
  }

  // Full Body Drag Overlay (Active in Layout Move Mode)
  MouseArea {
    id: fullDragArea
    anchors.fill: parent
    z: 100
    visible: rootRef && rootRef.layoutEditMode
    cursorShape: Qt.SizeAllCursor
    drag.target: widgetCardRoot.targetItem
    drag.axis: Drag.XAndYAxis
    drag.minimumX: 10
    drag.maximumX: Math.max(10, widgetCardRoot.screenWidth - widgetCardRoot.width - 10)
    drag.minimumY: 10
    drag.maximumY: Math.max(10, widgetCardRoot.screenHeight - widgetCardRoot.height - 10)

    onReleased: function() {
      var maxX = Math.max(10, widgetCardRoot.screenWidth - widgetCardRoot.width - 10)
      var maxY = Math.max(10, widgetCardRoot.screenHeight - widgetCardRoot.height - 10)
      var snappedX = Math.round(widgetCardRoot.targetItem.x / 20) * 20
      var snappedY = Math.round(widgetCardRoot.targetItem.y / 20) * 20
      snappedX = Math.max(10, Math.min(maxX, snappedX))
      snappedY = Math.max(10, Math.min(maxY, snappedY))
      widgetCardRoot.targetItem.x = snappedX
      widgetCardRoot.targetItem.y = snappedY
      if (rootRef && rootRef.saveWidgetPos) {
        rootRef.saveWidgetPos(widgetCardRoot.widgetId, snappedX, snappedY)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📂 Standard Right-Click Context Menu
  // ---------------------------------------------------------------------------
  property bool contextMenuOpen: false

  // Right-click handler on the widget body (only when NOT in edit mode)
  MouseArea {
    anchors.fill: parent
    z: 50
    visible: !(rootRef && rootRef.layoutEditMode)
    acceptedButtons: Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        widgetCardRoot.contextMenuOpen = !widgetCardRoot.contextMenuOpen
      }
    }
  }

  // Close menu when widget starts being dragged
  onIsDraggingChanged: {
    if (isDragging && contextMenuOpen) {
      contextMenuOpen = false
    }
  }

  // Custom context menu content (provided by derived widgets)
  property Component customMenuContent: null
  property real menuWidth: 300

  // Geometry helpers for floating submenus/popouts
  readonly property real contextMenuX: wcContextMenu.x
  readonly property real contextMenuY: wcContextMenu.y
  readonly property real contextMenuWidth: wcContextMenu.width
  readonly property real contextMenuHeight: wcContextMenu.height
  readonly property var contextMenuCanvasParent: widgetCardRoot.loaderItem ? widgetCardRoot.loaderItem.parent : widgetCardRoot

  // ---------------------------------------------------------------------------
  // 💾 Widget Settings Persistence Helpers
  // ---------------------------------------------------------------------------
  signal settingsLoaded()

  Connections {
    target: rootRef || null
    function onWidgetSettingsChanged() {
      widgetCardRoot.settingsLoaded()
    }
  }

  function saveSetting(key, val) {
    if (rootRef && rootRef.saveWidgetSetting) {
      rootRef.saveWidgetSetting(widgetCardRoot.widgetId, key, val)
    }
  }

  function saveSettings(valMap) {
    if (rootRef && rootRef.saveWidgetSettings) {
      rootRef.saveWidgetSettings(widgetCardRoot.widgetId, valMap)
    }
  }

  function getSetting(key, defaultVal) {
    if (rootRef && rootRef.widgetSettings && rootRef.widgetSettings[widgetCardRoot.widgetId]) {
      var val = rootRef.widgetSettings[widgetCardRoot.widgetId][key]
      if (val !== undefined) return val
    }
    return defaultVal
  }



  // Click-outside dismissal backdrop
  MouseArea {
    id: wcMenuDismissBackdrop
    parent: widgetCardRoot.loaderItem ? widgetCardRoot.loaderItem.parent : widgetCardRoot
    anchors.fill: parent
    z: 999
    visible: widgetCardRoot.contextMenuOpen
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: widgetCardRoot.contextMenuOpen = false
  }

  // Floating context menu - reparented to widgetContainer canvas
  Rectangle {
    id: wcContextMenu
    parent: widgetCardRoot.loaderItem ? widgetCardRoot.loaderItem.parent : widgetCardRoot
    z: 1000

    readonly property var widgetTarget: widgetCardRoot.loaderItem ? widgetCardRoot.loaderItem : widgetCardRoot
    readonly property real menuWidth: widgetCardRoot.menuWidth
    readonly property real menuHeight: wcMenuLayout.implicitHeight + 20

    x: Math.max(10, Math.min(widgetTarget.x, widgetCardRoot.screenWidth - menuWidth - 10))
    y: {
      var desiredY = widgetTarget.y + 36
      if (desiredY + menuHeight > widgetCardRoot.screenHeight - 10) {
        desiredY = widgetTarget.y + widgetCardRoot.height - menuHeight - 36
      }
      return Math.max(10, Math.min(desiredY, widgetCardRoot.screenHeight - menuHeight - 10))
    }
    width: menuWidth
    height: menuHeight

    radius: 14
    color: Qt.rgba(14/255, 14/255, 20/255, 0.96)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
    border.width: 1.5

    opacity: widgetCardRoot.contextMenuOpen ? 1.0 : 0.0
    scale: widgetCardRoot.contextMenuOpen ? 1.0 : 0.94
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.85)
      shadowBlur: 0.85
      shadowVerticalOffset: 8
      shadowHorizontalOffset: 2
    }

    ColumnLayout {
      id: wcMenuLayout
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(3)

      // Menu Header
      RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Style.space(4)

        Text {
          text: "\uf085"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.accent
        }

        Text {
          text: widgetCardRoot.title !== "" ? (widgetCardRoot.title + " Options") : "Widget Options"
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.Bold
          color: Color.foreground
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: wcCloseMenuMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.foreground
          }

          MouseArea {
            id: wcCloseMenuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: widgetCardRoot.contextMenuOpen = false
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.bottomMargin: 3
      }

      // 🧩 Custom Widget Settings (Injected by derived widget)
      Loader {
        Layout.fillWidth: true
        active: widgetCardRoot.customMenuContent !== null
        sourceComponent: widgetCardRoot.customMenuContent
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.topMargin: 3
        Layout.bottomMargin: 3
        visible: widgetCardRoot.customMenuContent !== null
      }

      // Options List
      Repeater {
        model: [
          { label: (rootRef && rootRef.layoutEditMode) ? "Lock Widgets Layout" : "Unlock Widgets Layout (Move Mode)", icon: (rootRef && rootRef.layoutEditMode) ? "\uf023" : "\uf0b2", value: "TOGGLE_EDIT_MODE" },
          { label: "Open Widget Selector (+)", icon: "\uf067", value: "OPEN_SELECTOR" },
          { label: "Reset Widgets Layout", icon: "\uf0e2", value: "RESET_LAYOUT" }
        ]

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          color: wcOptMouse.containsMouse ? (modelData.value === "RESET_LAYOUT" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              text: modelData.icon
              font.family: Style.font.family
              font.pixelSize: 11
              color: modelData.value === "RESET_LAYOUT" ? (wcOptMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)) : Color.accent
            }

            Text {
              Layout.fillWidth: true
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: modelData.value === "RESET_LAYOUT" ? (wcOptMouse.containsMouse ? Color.urgent : Color.foreground) : Color.accent
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: wcOptMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              widgetCardRoot.contextMenuOpen = false
              if (modelData.value === "TOGGLE_EDIT_MODE") {
                if (rootRef) rootRef.layoutEditMode = !rootRef.layoutEditMode
              } else if (modelData.value === "OPEN_SELECTOR") {
                if (rootRef) rootRef.selectorOpen = true
              } else if (modelData.value === "RESET_LAYOUT") {
                if (rootRef) rootRef.resetWidgetPositions()
              }
            }
          }
        }
      }
    }
  }

  default property alias content: contentContainer.data
}
