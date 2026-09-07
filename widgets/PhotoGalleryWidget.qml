import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: galleryWidgetRoot

  property string widgetId: "gallery"
  property var rootRef: null
  property real defaultX: Style.space(24)
  property real defaultY: Style.space(64)
  readonly property real screenWidth: (rootRef && rootRef.screenWidth > 0) ? rootRef.screenWidth : 1920
  readonly property real screenHeight: (rootRef && rootRef.screenHeight > 0) ? rootRef.screenHeight : 1080

  property real defaultWidth: 360
  property real defaultHeight: 228
  property real minWidth: 260
  property real minHeight: 180
  property real maxWidth: Math.min(1200, screenWidth - 40)
  property real maxHeight: Math.min(900, screenHeight - 80)
  property bool resizable: true
  readonly property bool isResizing: (resizeCornerArea && resizeCornerArea.isResizingNow) || (resizeRightArea && resizeRightArea.isResizingNow) || (resizeBottomArea && resizeBottomArea.isResizingNow)

  width: 360
  height: 228

  property var loaderItem: null
  readonly property var targetItem: loaderItem ? loaderItem : galleryWidgetRoot

  readonly property bool isDragging: galleryGripArea.drag.active || (galleryFullDragArea && galleryFullDragArea.drag.active)
  scale: isDragging ? 1.02 : 1.0

  Behavior on scale {
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
  }

  // ---------------------------------------------------------------------------
  // 🖼️ Photo Gallery Stack State & Auto-Cycler
  // ---------------------------------------------------------------------------
  property string photoFolder: "ALL"
  property var photoList: []
  property int photoIndex: 0
  readonly property var currentPhotoObj: (photoList && photoList.length > 0) ? photoList[photoIndex % photoList.length] : null
  readonly property string currentPhotoPath: currentPhotoObj ? currentPhotoObj.path : ""
  readonly property string currentPhotoRawPath: currentPhotoObj ? currentPhotoObj.raw_path : ""
  readonly property string currentPhotoTitle: currentPhotoObj ? currentPhotoObj.title : "Photo Gallery"
  property bool folderMenuOpen: false

  // Multi-layer photo stack sources
  property var layer3PhotoObj: (photoList && photoList.length > 3) ? photoList[(photoIndex + 1) % photoList.length] : null
  readonly property string layer3PhotoPath: layer3PhotoObj ? layer3PhotoObj.path : ""

  property var layer2PhotoObj: (photoList && photoList.length > 1) ? photoList[(photoIndex + 2) % photoList.length] : null
  readonly property string layer2PhotoPath: layer2PhotoObj ? layer2PhotoObj.path : ""

  property var layer1PhotoObj: (photoList && photoList.length > 2) ? photoList[(photoIndex + 3) % photoList.length] : null
  readonly property string layer1PhotoPath: layer1PhotoObj ? layer1PhotoObj.path : ""

  readonly property bool isHovered: cardHoverHandler.hovered && !folderMenuOpen
  readonly property bool isGif: (currentPhotoPath !== "" && currentPhotoPath.toLowerCase().indexOf(".gif") !== -1) || (currentPhotoRawPath !== "" && currentPhotoRawPath.toLowerCase().indexOf(".gif") !== -1)

  function nextPhoto() {
    if (photoList && photoList.length > 0) {
      photoIndex = (photoIndex + 1) % photoList.length
    }
  }

  function prevPhoto() {
    if (photoList && photoList.length > 0) {
      photoIndex = (photoIndex - 1 + photoList.length) % photoList.length
    }
  }

  function shufflePhoto() {
    if (photoList && photoList.length > 1) {
      var rand = Math.floor(Math.random() * photoList.length)
      if (rand === photoIndex) rand = (rand + 1) % photoList.length
      photoIndex = rand
    }
  }

  readonly property string photosScriptPath: {
    var u = Qt.resolvedUrl("../get-photos.sh").toString()
    if (u.indexOf("file://") === 0) return u.substring(7)
    return "/home/dagyr/.config/omarchy/plugins/dagyr.desktop-widgets/get-photos.sh"
  }

  function selectFolder(folderPath) {
    galleryWidgetRoot.folderMenuOpen = false
    photosProc.command = [galleryWidgetRoot.photosScriptPath, folderPath]
    if (!photosProc.running) photosProc.running = true
  }

  function openCurrentPhoto() {
    if (galleryWidgetRoot.currentPhotoRawPath !== "") {
      Quickshell.execDetached(["xdg-open", galleryWidgetRoot.currentPhotoRawPath])
    }
  }

  property var tempPhotoList: []

  Process {
    id: photosProc
    command: [galleryWidgetRoot.photosScriptPath]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.type === "init") {
            if (data.folder) galleryWidgetRoot.photoFolder = data.folder
            galleryWidgetRoot.tempPhotoList = []
          } else if (data.type === "photo") {
            galleryWidgetRoot.tempPhotoList.push(data)
            if (galleryWidgetRoot.tempPhotoList.length === 1) {
              galleryWidgetRoot.photoList = [data]
              galleryWidgetRoot.photoIndex = 0
            }
          } else if (data.type === "done") {
            galleryWidgetRoot.photoList = galleryWidgetRoot.tempPhotoList.slice()
          } else if (Array.isArray(data.images)) {
            if (data.folder) galleryWidgetRoot.photoFolder = data.folder
            galleryWidgetRoot.photoList = data.images
            galleryWidgetRoot.photoIndex = 0
          }
        } catch (e) {}
      }
    }
  }

  // Auto-cycle photo timer & interval preference
  property int cycleIntervalMs: 18000
  property bool autoCycleEnabled: true

  function applySavedSettings() {
    if (!rootRef || !rootRef.widgetSettings) return
    var s = rootRef.widgetSettings[widgetId]
    if (!s) return
    if (s.autoCycleEnabled !== undefined) autoCycleEnabled = s.autoCycleEnabled
    if (s.cycleIntervalMs !== undefined) cycleIntervalMs = s.cycleIntervalMs
  }

  signal settingsLoaded()

  Connections {
    target: rootRef || null
    function onWidgetSettingsChanged() {
      galleryWidgetRoot.applySavedSettings()
    }
  }

  function saveSetting(key, val) {
    if (rootRef && rootRef.saveWidgetSetting) {
      rootRef.saveWidgetSetting(galleryWidgetRoot.widgetId, key, val)
    }
  }

  onSettingsLoaded: applySavedSettings()
  onRootRefChanged: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function shufflePhotos() {
    if (!photoList || photoList.length <= 1) return
    var arr = photoList.slice()
    for (var i = arr.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1))
      var temp = arr[i]
      arr[i] = arr[j]
      arr[j] = temp
    }
    photoList = arr
    photoIndex = 0
  }

  function openPicturesFolder() {
    var target = galleryWidgetRoot.photoFolder
    if (!target || target === "ALL" || target === "pick_dialog") target = "/home/dagyr/Pictures"
    if (target.indexOf("~") === 0) target = target.replace("~", "/home/dagyr")
    Quickshell.execDetached(["xdg-open", target])
  }

  // Auto-cycle photo timer
  Timer {
    interval: galleryWidgetRoot.cycleIntervalMs
    running: galleryWidgetRoot.autoCycleEnabled && !galleryWidgetRoot.folderMenuOpen && galleryWidgetRoot.photoList && galleryWidgetRoot.photoList.length > 1
    repeat: true
    onTriggered: galleryWidgetRoot.nextPhoto()
  }

  // ---------------------------------------------------------------------------
  // 🎴 3D Layered Photo Deck (Real photos at varied angles)
  // ---------------------------------------------------------------------------

  // 🎴 Stack Layer 1 (Deepest Deck Photo, tilted +6.2 degrees)
  Item {
    id: stackCard1
    width: photoCardMain.width * 0.95
    height: photoCardMain.height * 0.95
    transformOrigin: Item.Center
    visible: galleryWidgetRoot.photoList && galleryWidgetRoot.photoList.length > 2

    readonly property real targetRot: isHovered ? 7.6 : 5.8
    readonly property real targetX: isHovered ? 12 : 8
    readonly property real targetY: isHovered ? 8 : 5
    rotation: targetRot
    x: (galleryWidgetRoot.width - width) / 2 + targetX
    y: (galleryWidgetRoot.height - height) / 2 + targetY

    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // Drop shadow caster
    Rectangle {
      anchors.fill: parent
      radius: 16
      color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowBlur: 0.6
        shadowVerticalOffset: 4
      }
    }

    // Photo Content to mask
    Item {
      id: card1Src
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Image {
        anchors.fill: parent
        source: galleryWidgetRoot.layer1PhotoPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }

      // Dark depth shadow overlay (simulating upper cards blocking light)
      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.36
      }

      // Razor-thin glossy paper edge
      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.color: Qt.rgba(255, 255, 255, 0.18)
        border.width: 1
      }
    }

    // Mask shape with rounded corners
    Item {
      id: card1Mask
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "black"
      }
    }

    // Masked Photo Output
    MultiEffect {
      anchors.fill: parent
      source: card1Src
      maskEnabled: true
      maskSource: card1Mask
    }
  }

  // 🎴 Stack Layer 2 (Middle Deck Photo, tilted -5.2 degrees)
  Item {
    id: stackCard2
    width: photoCardMain.width * 0.97
    height: photoCardMain.height * 0.97
    transformOrigin: Item.Center
    visible: galleryWidgetRoot.photoList && galleryWidgetRoot.photoList.length > 1

    readonly property real targetRot: isHovered ? -6.8 : -5.0
    readonly property real targetX: isHovered ? -11 : -7
    readonly property real targetY: isHovered ? 6 : 4
    rotation: targetRot
    x: (galleryWidgetRoot.width - width) / 2 + targetX
    y: (galleryWidgetRoot.height - height) / 2 + targetY

    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // Drop shadow caster
    Rectangle {
      anchors.fill: parent
      radius: 16
      color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.65)
        shadowBlur: 0.65
        shadowVerticalOffset: 5
      }
    }

    // Photo Content to mask
    Item {
      id: card2Src
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Image {
        anchors.fill: parent
        source: galleryWidgetRoot.layer2PhotoPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }

      // Slightly lighter depth shadow
      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.22
      }

      // Razor-thin glossy paper edge
      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.color: Qt.rgba(255, 255, 255, 0.18)
        border.width: 1
      }
    }

    // Mask shape with rounded corners
    Item {
      id: card2Mask
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "black"
      }
    }

    // Masked Photo Output
    MultiEffect {
      anchors.fill: parent
      source: card2Src
      maskEnabled: true
      maskSource: card2Mask
    }
  }

  // 🎴 Stack Layer 3 (Under-top Deck Photo, tilted +3.0 degrees)
  Item {
    id: stackCard3
    width: photoCardMain.width * 0.985
    height: photoCardMain.height * 0.985
    transformOrigin: Item.Center
    visible: galleryWidgetRoot.photoList && galleryWidgetRoot.photoList.length > 3

    readonly property real targetRot: isHovered ? 4.0 : 2.8
    readonly property real targetX: isHovered ? 6 : 4
    readonly property real targetY: isHovered ? 4 : 2
    rotation: targetRot
    x: (galleryWidgetRoot.width - width) / 2 + targetX
    y: (galleryWidgetRoot.height - height) / 2 + targetY

    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // Drop shadow caster
    Rectangle {
      anchors.fill: parent
      radius: 16
      color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.7)
        shadowBlur: 0.7
        shadowVerticalOffset: 5
      }
    }

    // Photo Content to mask
    Item {
      id: card3Src
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Image {
        anchors.fill: parent
        source: galleryWidgetRoot.layer3PhotoPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }

      // Subtle depth shadow
      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.12
      }

      // Razor-thin glossy paper edge
      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.color: Qt.rgba(255, 255, 255, 0.2)
        border.width: 1
      }
    }

    // Mask shape with rounded corners
    Item {
      id: card3Mask
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "black"
      }
    }

    // Masked Photo Output
    MultiEffect {
      anchors.fill: parent
      source: card3Src
      maskEnabled: true
      maskSource: card3Mask
    }
  }

  // Drop shadow caster for main photo card (separated from photoCardMain to prevent nested FBO layer caching)
  Rectangle {
    anchors.fill: photoCardMain
    radius: 16
    color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.85)
      shadowBlur: 0.85
      shadowVerticalOffset: 6
    }
  }

  // 🎴 Front Active Photo Card (Full bleed, borderless)
  Rectangle {
    id: photoCardMain
    anchors.centerIn: parent
    width: parent.width - 24
    height: parent.height - 18
    radius: 16
    color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
    border.color: (galleryGripArea.drag.active || galleryFullDragArea.drag.active || (rootRef && rootRef.layoutEditMode)) ? Color.accent : "transparent"
    border.width: (galleryGripArea.drag.active || galleryFullDragArea.drag.active || (rootRef && rootRef.layoutEditMode)) ? 2 : 0

    // Mask shape with rounded corners
    Item {
      id: mainCardMask
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: 16
        color: "black"
      }
    }

    // 🖼️ Static Image (Direct item with dedicated mask)
    Image {
      id: galleryImg
      visible: !galleryWidgetRoot.isGif
      anchors.fill: parent
      source: !galleryWidgetRoot.isGif ? galleryWidgetRoot.currentPhotoPath : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
      opacity: status === Image.Ready ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
      }

      property real imgScale: 1.0
      scale: imgScale
      onSourceChanged: {
        imgScale = 1.05
        scaleBounceAnim.restart()
      }

      NumberAnimation {
        id: scaleBounceAnim
        target: galleryImg
        property: "imgScale"
        to: 1.0
        duration: 650
        easing.type: Easing.OutCubic
      }

      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mainCardMask
      }
    }

    // 🎞️ Animated GIF Player (Direct item with dedicated mask to guarantee SceneGraph damage propagation and continuous playback)
    AnimatedImage {
      id: galleryGif
      visible: galleryWidgetRoot.isGif
      anchors.fill: parent
      source: galleryWidgetRoot.isGif ? galleryWidgetRoot.currentPhotoPath : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: false
      smooth: true
      playing: galleryWidgetRoot.isGif
      paused: false
      cache: false
      opacity: status === AnimatedImage.Ready ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
      }


      onSourceChanged: {
        playing = true
        paused = false
      }

      onStatusChanged: {
        if (status === AnimatedImage.Ready) {
          playing = true
          paused = false
        }
      }

      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mainCardMask
      }
    }

    // Placeholder if no photo
    ColumnLayout {
      anchors.centerIn: parent
      z: 10
      visible: (!galleryWidgetRoot.isGif && galleryImg.status !== Image.Ready) || (galleryWidgetRoot.isGif && galleryGif.status !== AnimatedImage.Ready)
      spacing: Style.space(6)

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "\uf03e"
        font.family: Style.font.family
        font.pixelSize: 28
        color: Color.accent
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: galleryWidgetRoot.photoList && galleryWidgetRoot.photoList.length > 0 ? "Loading photo..." : "Drop photos in ~/.config/omarchy/plugins/dagyr.desktop-widgets/photos/"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
      }
    }

    // Ultra-subtle paper edge highlight
    Rectangle {
      anchors.fill: parent
      radius: 16
      color: "transparent"
      border.color: Qt.rgba(255, 255, 255, 0.16)
      border.width: 1
      z: 25
    }

    // Top Vignette / Header Overlay
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 48
      radius: 16
      z: 50
      opacity: (galleryWidgetRoot.isHovered || (rootRef && rootRef.layoutEditMode) || galleryWidgetRoot.folderMenuOpen) ? 1.0 : 0.0
      Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.72) }
        GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.25) }
        GradientStop { position: 1.0; color: "transparent" }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        anchors.topMargin: Style.space(6)
        spacing: Style.space(8)

        Text {
          text: "\uf03e"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.accent
        }

        Text {
          Layout.fillWidth: true
          text: galleryWidgetRoot.currentPhotoTitle
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.DemiBold
          color: Color.foreground
          elide: Text.ElideRight
          style: Text.Outline
          styleColor: Qt.rgba(0, 0, 0, 0.85)
        }

        // Close / Hide Button (when in edit mode)
        Rectangle {
          visible: rootRef && rootRef.layoutEditMode
          width: 22
          height: 22
          radius: 11
          color: closePhotoMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.12)
          border.color: closePhotoMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.6)
          border.width: 1
          z: 120

          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.urgent
          }

          MouseArea {
            id: closePhotoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (rootRef && rootRef.toggleWidgetEnabled) {
                rootRef.toggleWidgetEnabled(galleryWidgetRoot.widgetId, false)
              }
            }
          }
        }

        // Drag Grip Button (when in edit mode)
        Rectangle {
          visible: rootRef && rootRef.layoutEditMode
          width: 22
          height: 22
          radius: 11
          color: galleryGripArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.12)
          border.color: galleryGripArea.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
          border.width: 1
          z: 120

          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "\uf0b2"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.accent
          }

          MouseArea {
            id: galleryGripArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            drag.target: galleryWidgetRoot.targetItem
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 10
            drag.maximumX: Math.max(10, galleryWidgetRoot.screenWidth - galleryWidgetRoot.width - 10)
            drag.minimumY: 10
            drag.maximumY: Math.max(10, galleryWidgetRoot.screenHeight - galleryWidgetRoot.height - 10)

            onReleased: function() {
              var maxX = Math.max(10, galleryWidgetRoot.screenWidth - galleryWidgetRoot.width - 10)
              var maxY = Math.max(10, galleryWidgetRoot.screenHeight - galleryWidgetRoot.height - 10)
              var snappedX = Math.round(galleryWidgetRoot.targetItem.x / 20) * 20
              var snappedY = Math.round(galleryWidgetRoot.targetItem.y / 20) * 20
              snappedX = Math.max(10, Math.min(maxX, snappedX))
              snappedY = Math.max(10, Math.min(maxY, snappedY))
              galleryWidgetRoot.targetItem.x = snappedX
              galleryWidgetRoot.targetItem.y = snappedY
              if (rootRef && rootRef.saveWidgetPos) {
                rootRef.saveWidgetPos(galleryWidgetRoot.widgetId, snappedX, snappedY, Math.round(galleryWidgetRoot.width / 20) * 20, Math.round(galleryWidgetRoot.height / 20) * 20)
              }
            }
          }
        }

        // Index Badge Pill
        Rectangle {
          visible: galleryWidgetRoot.photoList && galleryWidgetRoot.photoList.length > 0
          radius: 8
          color: Qt.rgba(0, 0, 0, 0.6)
          border.color: Qt.rgba(255, 255, 255, 0.15)
          border.width: 1
          implicitWidth: badgeText.implicitWidth + 12
          implicitHeight: 18

          Text {
            id: badgeText
            anchors.centerIn: parent
            text: (galleryWidgetRoot.photoIndex + 1) + " / " + (galleryWidgetRoot.photoList ? galleryWidgetRoot.photoList.length : 1)
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Color.foreground
          }
        }
      }
    }

    // Bottom Hover Controls Bar
    Rectangle {
      id: bottomControls
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 44
      radius: 16
      z: 50
      opacity: galleryWidgetRoot.isHovered ? 1.0 : 0.0
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.35) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
      }

      Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
      }

      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(14)

        // Prev Photo Button
        Rectangle {
          width: 28
          height: 28
          radius: 14
          color: prevPhotoMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.65)
          border.color: Qt.rgba(255, 255, 255, 0.25)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf053"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.foreground
          }

          MouseArea {
            id: prevPhotoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: galleryWidgetRoot.prevPhoto()
          }
        }

        // Shuffle Button
        Rectangle {
          width: 28
          height: 28
          radius: 14
          color: shuffleMouse.containsMouse ? Color.accent : Qt.rgba(0, 0, 0, 0.65)
          border.color: Qt.rgba(255, 255, 255, 0.25)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf074"
            font.family: Style.font.family
            font.pixelSize: 10
            color: shuffleMouse.containsMouse ? Color.background : Color.foreground
          }

          MouseArea {
            id: shuffleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: galleryWidgetRoot.shufflePhoto()
          }
        }

        // Next Photo Button
        Rectangle {
          width: 28
          height: 28
          radius: 14
          color: nextPhotoMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.65)
          border.color: Qt.rgba(255, 255, 255, 0.25)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf054"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.foreground
          }

          MouseArea {
            id: nextPhotoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: galleryWidgetRoot.nextPhoto()
          }
        }
      }
    }

    // Card Hover Handler for fan-out and controls animation without intercepting child mouse/hover events
    HoverHandler {
      id: cardHoverHandler
    }

    // Interactive Click Area (Left-click to cycle, right-click for folder menu)
    MouseArea {
      id: photoHoverArea
      anchors.fill: parent
      z: 20
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: galleryWidgetRoot.folderMenuOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
      visible: !(rootRef && rootRef.layoutEditMode)

      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          galleryWidgetRoot.folderMenuOpen = !galleryWidgetRoot.folderMenuOpen
        } else if (mouse.button === Qt.LeftButton) {
          if (galleryWidgetRoot.folderMenuOpen) {
            galleryWidgetRoot.folderMenuOpen = false
            return
          }
          if (mouse.x > parent.width * 0.5) {
            galleryWidgetRoot.nextPhoto()
          } else {
            galleryWidgetRoot.prevPhoto()
          }
        }
      }
    }
  }

  // Full body drag when in Edit Mode
  MouseArea {
    id: galleryFullDragArea
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.top: parent.top
    anchors.topMargin: 58
    z: 100
    visible: rootRef && rootRef.layoutEditMode
    cursorShape: Qt.SizeAllCursor
    drag.target: galleryWidgetRoot.targetItem
    drag.axis: Drag.XAndYAxis
    drag.minimumX: 10
    drag.maximumX: Math.max(10, galleryWidgetRoot.screenWidth - galleryWidgetRoot.width - 10)
    drag.minimumY: 10
    drag.maximumY: Math.max(10, galleryWidgetRoot.screenHeight - galleryWidgetRoot.height - 10)

    onPressed: function(mouse) {
      if (mouse.y <= 48 && mouse.x >= width - 64) {
        mouse.accepted = false
        return
      }
    }

    onReleased: function() {
      var maxX = Math.max(10, galleryWidgetRoot.screenWidth - galleryWidgetRoot.width - 10)
      var maxY = Math.max(10, galleryWidgetRoot.screenHeight - galleryWidgetRoot.height - 10)
      var snappedX = Math.round(galleryWidgetRoot.targetItem.x / 20) * 20
      var snappedY = Math.round(galleryWidgetRoot.targetItem.y / 20) * 20
      snappedX = Math.max(10, Math.min(maxX, snappedX))
      snappedY = Math.max(10, Math.min(maxY, snappedY))
      galleryWidgetRoot.targetItem.x = snappedX
      galleryWidgetRoot.targetItem.y = snappedY
      if (rootRef && rootRef.saveWidgetPos) {
        rootRef.saveWidgetPos(galleryWidgetRoot.widgetId, snappedX, snappedY, Math.round(galleryWidgetRoot.width / 20) * 20, Math.round(galleryWidgetRoot.height / 20) * 20)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📐 Interactive Resizing Handles & Live Dimensions Pill
  // ---------------------------------------------------------------------------

  // Visual Grip Icon in Bottom-Right Corner
  Rectangle {
    id: cornerResizeVisual
    visible: rootRef && rootRef.layoutEditMode && galleryWidgetRoot.resizable
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 6
    width: 18
    height: 18
    radius: 4
    z: 115
    color: (resizeCornerArea.containsMouse || resizeCornerArea.isResizingNow) ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : Qt.rgba(1, 1, 1, 0.08)
    border.color: (resizeCornerArea.containsMouse || resizeCornerArea.isResizingNow) ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
    border.width: 1

    Text {
      anchors.centerIn: parent
      text: "\uf424"
      font.family: Style.font.family
      font.pixelSize: 10
      color: Color.accent
    }
  }

  // Interactive Bottom-Right Corner Resize Area (Width & Height)
  MouseArea {
    id: resizeCornerArea
    width: 24
    height: 24
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    z: 125
    visible: rootRef && rootRef.layoutEditMode && galleryWidgetRoot.resizable
    cursorShape: Qt.SizeFDiagCursor
    hoverEnabled: true

    property real startScreenX: 0
    property real startScreenY: 0
    property real startWidth: 0
    property real startHeight: 0
    property bool isResizingNow: false

    onPressed: function(mouse) {
      var p = mapToItem(galleryWidgetRoot.parent, mouse.x, mouse.y)
      startScreenX = p.x
      startScreenY = p.y
      startWidth = galleryWidgetRoot.width
      startHeight = galleryWidgetRoot.height
      isResizingNow = true
    }

    onPositionChanged: function(mouse) {
      if (isResizingNow) {
        var cur = mapToItem(galleryWidgetRoot.parent, mouse.x, mouse.y)
        var newW = Math.max(galleryWidgetRoot.minWidth, Math.min(galleryWidgetRoot.maxWidth, startWidth + (cur.x - startScreenX)))
        var newH = Math.max(galleryWidgetRoot.minHeight, Math.min(galleryWidgetRoot.maxHeight, startHeight + (cur.y - startScreenY)))
        galleryWidgetRoot.width = newW
        galleryWidgetRoot.height = newH
      }
    }

    onReleased: function() {
      if (isResizingNow) {
        isResizingNow = false
        var snappedW = Math.round(galleryWidgetRoot.width / 20) * 20
        var snappedH = Math.round(galleryWidgetRoot.height / 20) * 20
        snappedW = Math.max(galleryWidgetRoot.minWidth, Math.min(galleryWidgetRoot.maxWidth, snappedW))
        snappedH = Math.max(galleryWidgetRoot.minHeight, Math.min(galleryWidgetRoot.maxHeight, snappedH))
        galleryWidgetRoot.width = snappedW
        galleryWidgetRoot.height = snappedH
        if (rootRef && rootRef.saveWidgetPos) {
          rootRef.saveWidgetPos(galleryWidgetRoot.widgetId, galleryWidgetRoot.targetItem.x, galleryWidgetRoot.targetItem.y, snappedW, snappedH)
        }
      }
    }
  }

  // Interactive Right Edge Resize Area (Width only)
  MouseArea {
    id: resizeRightArea
    width: 10
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
    z: 120
    visible: rootRef && rootRef.layoutEditMode && galleryWidgetRoot.resizable
    cursorShape: Qt.SizeHorCursor
    hoverEnabled: true

    property real startScreenX: 0
    property real startWidth: 0
    property bool isResizingNow: false

    onPressed: function(mouse) {
      var p = mapToItem(galleryWidgetRoot.parent, mouse.x, mouse.y)
      startScreenX = p.x
      startWidth = galleryWidgetRoot.width
      isResizingNow = true
    }

    onPositionChanged: function(mouse) {
      if (isResizingNow) {
        var cur = mapToItem(galleryWidgetRoot.parent, mouse.x, mouse.y)
        var newW = Math.max(galleryWidgetRoot.minWidth, Math.min(galleryWidgetRoot.maxWidth, startWidth + (cur.x - startScreenX)))
        galleryWidgetRoot.width = newW
      }
    }

    onReleased: function() {
      if (isResizingNow) {
        isResizingNow = false
        var snappedW = Math.round(galleryWidgetRoot.width / 20) * 20
        snappedW = Math.max(galleryWidgetRoot.minWidth, Math.min(galleryWidgetRoot.maxWidth, snappedW))
        galleryWidgetRoot.width = snappedW
        if (rootRef && rootRef.saveWidgetPos) {
          rootRef.saveWidgetPos(galleryWidgetRoot.widgetId, galleryWidgetRoot.targetItem.x, galleryWidgetRoot.targetItem.y, snappedW, Math.round(galleryWidgetRoot.height / 20) * 20)
        }
      }
    }
  }

  // Interactive Bottom Edge Resize Area (Height only)
  MouseArea {
    id: resizeBottomArea
    height: 10
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.rightMargin: 24
    z: 120
    visible: rootRef && rootRef.layoutEditMode && galleryWidgetRoot.resizable
    cursorShape: Qt.SizeVerCursor
    hoverEnabled: true

    property real startScreenY: 0
    property real startHeight: 0
    property bool isResizingNow: false

    onPressed: function(mouse) {
      var p = mapToItem(galleryWidgetRoot.parent, mouse.x, mouse.y)
      startScreenY = p.y
      startHeight = galleryWidgetRoot.height
      isResizingNow = true
    }

    onPositionChanged: function(mouse) {
      if (isResizingNow) {
        var cur = mapToItem(galleryWidgetRoot.parent, mouse.x, mouse.y)
        var newH = Math.max(galleryWidgetRoot.minHeight, Math.min(galleryWidgetRoot.maxHeight, startHeight + (cur.y - startScreenY)))
        galleryWidgetRoot.height = newH
      }
    }

    onReleased: function() {
      if (isResizingNow) {
        isResizingNow = false
        var snappedH = Math.round(galleryWidgetRoot.height / 20) * 20
        snappedH = Math.max(galleryWidgetRoot.minHeight, Math.min(galleryWidgetRoot.maxHeight, snappedH))
        galleryWidgetRoot.height = snappedH
        if (rootRef && rootRef.saveWidgetPos) {
          rootRef.saveWidgetPos(galleryWidgetRoot.widgetId, galleryWidgetRoot.targetItem.x, galleryWidgetRoot.targetItem.y, Math.round(galleryWidgetRoot.width / 20) * 20, snappedH)
        }
      }
    }
  }

  // Floating Real-Time Dimensions Pill Badge
  Rectangle {
    id: resizeDimPill
    visible: galleryWidgetRoot.isResizing
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.bottomMargin: 28
    anchors.rightMargin: 10
    z: 150
    implicitWidth: dimPillText.implicitWidth + Style.space(16)
    implicitHeight: 22
    radius: 11
    color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
    border.color: Color.accent
    border.width: 1

    Text {
      id: dimPillText
      anchors.centerIn: parent
      text: Math.round(galleryWidgetRoot.width) + " × " + Math.round(galleryWidgetRoot.height) + " px"
      font.family: Style.font.family
      font.pixelSize: 10
      font.weight: Font.Bold
      color: Color.accent
    }
  }

  // ---------------------------------------------------------------------------
  // 📂 Floating Right-Click Context Menu (reparented to desktop canvas)
  // ---------------------------------------------------------------------------

  // Close menu when widget starts being dragged
  onIsDraggingChanged: {
    if (isDragging && folderMenuOpen) {
      folderMenuOpen = false
    }
  }

  // Click-outside dismissal backdrop (full-screen transparent overlay)
  MouseArea {
    id: menuDismissBackdrop
    parent: galleryWidgetRoot.loaderItem ? galleryWidgetRoot.loaderItem.parent : galleryWidgetRoot
    anchors.fill: parent
    z: 999
    visible: galleryWidgetRoot.folderMenuOpen
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: galleryWidgetRoot.folderMenuOpen = false
  }

  // Floating context menu - reparented to widgetContainer canvas
  Rectangle {
    id: folderMenuOverlay
    parent: galleryWidgetRoot.loaderItem ? galleryWidgetRoot.loaderItem.parent : galleryWidgetRoot
    z: 1000

    // Position relative to the widget's location on the canvas
    readonly property var widgetTarget: galleryWidgetRoot.loaderItem ? galleryWidgetRoot.loaderItem : galleryWidgetRoot
    readonly property real menuWidth: 320
    readonly property real menuHeight: menuLayout.implicitHeight + 20

    // Clamp to screen edges
    x: Math.max(10, Math.min(widgetTarget.x, galleryWidgetRoot.screenWidth - menuWidth - 10))
    y: {
      var desiredY = widgetTarget.y + 36
      // If menu would overflow bottom, position above the widget instead
      if (desiredY + menuHeight > galleryWidgetRoot.screenHeight - 10) {
        desiredY = widgetTarget.y + galleryWidgetRoot.height - menuHeight - 36
      }
      return Math.max(10, Math.min(desiredY, galleryWidgetRoot.screenHeight - menuHeight - 10))
    }
    width: menuWidth
    height: menuHeight

    radius: 14
    color: Qt.rgba(14/255, 14/255, 20/255, 0.96)
    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
    border.width: 1.5

    opacity: galleryWidgetRoot.folderMenuOpen ? 1.0 : 0.0
    scale: galleryWidgetRoot.folderMenuOpen ? 1.0 : 0.94
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
      id: menuLayout
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(3)

      // Menu Header
      RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Style.space(4)

        Text {
          text: "\uf07b"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.accent
        }

        Text {
          text: "Gallery Options"
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.Bold
          color: Color.foreground
        }

        Item { Layout.fillWidth: true }

        // Close button
        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: closeMenuMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.foreground
          }

          MouseArea {
            id: closeMenuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: galleryWidgetRoot.folderMenuOpen = false
          }
        }
      }

      // Slideshow Autoplay Speed Selector
      Text {
        text: "AUTOPLAY SPEED"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: [
            { label: "10s", ms: 10000, active: true },
            { label: "18s", ms: 18000, active: true },
            { label: "45s", ms: 45000, active: true },
            { label: "Pause", ms: 0, active: false }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 24
            radius: 6
            readonly property bool isSelected: modelData.active ? (galleryWidgetRoot.autoCycleEnabled && galleryWidgetRoot.cycleIntervalMs === modelData.ms) : (!galleryWidgetRoot.autoCycleEnabled)
            color: spdMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.06))
            border.color: isSelected ? Color.accent : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isSelected ? Font.Bold : Font.Normal
              color: isSelected ? Color.accent : Color.foreground
            }

            MouseArea {
              id: spdMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.active) {
                  galleryWidgetRoot.autoCycleEnabled = true
                  galleryWidgetRoot.cycleIntervalMs = modelData.ms
                } else {
                  galleryWidgetRoot.autoCycleEnabled = false
                }
                galleryWidgetRoot.saveSetting("autoCycleEnabled", galleryWidgetRoot.autoCycleEnabled)
                galleryWidgetRoot.saveSetting("cycleIntervalMs", galleryWidgetRoot.cycleIntervalMs)
                galleryWidgetRoot.contextMenuOpen = false
              }
            }
          }
        }
      }

      // Actions Section Header
      Text {
        text: "ACTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 3
      }

      // 🖼️ Open Current Photo Action
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 26
        radius: 6
        color: openPhotoMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf08e"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Open Current Photo"
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Color.foreground
            elide: Text.ElideRight
          }

          Text {
            text: "\uf054"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
        }

        MouseArea {
          id: openPhotoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            galleryWidgetRoot.folderMenuOpen = false
            galleryWidgetRoot.openCurrentPhoto()
          }
        }
      }

      // 🎲 Shuffle Photos Action
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 26
        radius: 6
        color: shufPhotoMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf074"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Shuffle Deck Order"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: shufPhotoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            galleryWidgetRoot.shufflePhotos()
          }
        }
      }

      // 📁 Open Pictures Folder Action
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 26
        radius: 6
        color: openFldrMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf07c"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Open Folder in File Manager"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: openFldrMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            galleryWidgetRoot.folderMenuOpen = false
            galleryWidgetRoot.openPicturesFolder()
          }
        }
      }

      // Divider Line
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        Layout.topMargin: 3
        Layout.bottomMargin: 3
      }

      Text {
        text: "PHOTO SOURCES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
      }

      // Options List
      Repeater {
        model: [
          { label: "All Sources (Auto)", icon: "\uf005", value: "ALL" },
          { label: "Dedicated Gallery", icon: "\uf03e", value: "~/.config/omarchy/plugins/dagyr.desktop-widgets/photos" },
          { label: "Wallpapers", icon: "\uf03e", value: "~/Wallpapers" },
          { label: "Pictures", icon: "\uf030", value: "~/Pictures" },
          { label: "Theme Backgrounds", icon: "\uf53f", value: "~/.config/omarchy/backgrounds" },
          { label: "Choose Custom Folder...", icon: "\uf07c", value: "pick_dialog" },
          { label: (rootRef && rootRef.layoutEditMode) ? "Lock Layout" : "Unlock Layout", icon: (rootRef && rootRef.layoutEditMode) ? "\uf023" : "\uf0b2", value: "TOGGLE_EDIT_MODE" },
          { label: "Open Widget Selector (+)", icon: "\uf067", value: "OPEN_SELECTOR" },
          { label: "Reset Widgets Layout", icon: "\uf0e2", value: "RESET_LAYOUT" }
        ]

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: 26
          radius: 6
          readonly property bool isActionBtn: modelData.value === "RESET_LAYOUT" || modelData.value === "TOGGLE_EDIT_MODE" || modelData.value === "OPEN_SELECTOR"
          readonly property bool isSelected: !isActionBtn && (galleryWidgetRoot.photoFolder === modelData.value || (modelData.value === "pick_dialog" && galleryWidgetRoot.photoFolder !== "ALL" && !galleryWidgetRoot.photoFolder.startsWith("~/.config") && !galleryWidgetRoot.photoFolder.startsWith("~/Wallpapers") && !galleryWidgetRoot.photoFolder.startsWith("~/Pictures")))
          color: optMouse.containsMouse ? (modelData.value === "RESET_LAYOUT" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)) : (isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Item {
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              Layout.alignment: Qt.AlignVCenter

              Text {
                anchors.centerIn: parent
                text: modelData.icon
                font.family: Style.font.family
                font.pixelSize: 11
                color: modelData.value === "RESET_LAYOUT" ? (optMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)) : (isSelected || isActionBtn ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7))
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: (isSelected || isActionBtn) ? Font.Bold : Font.Normal
              color: modelData.value === "RESET_LAYOUT" ? (optMouse.containsMouse ? Color.urgent : Color.foreground) : (isSelected || isActionBtn ? Color.accent : Color.foreground)
              elide: Text.ElideRight
            }

            Text {
              visible: isSelected
              text: "\uf00c"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.accent
            }
          }

          MouseArea {
            id: optMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              galleryWidgetRoot.folderMenuOpen = false
              if (modelData.value === "TOGGLE_EDIT_MODE") {
                if (rootRef) rootRef.layoutEditMode = !rootRef.layoutEditMode
              } else if (modelData.value === "OPEN_SELECTOR") {
                if (rootRef) rootRef.selectorOpen = true
              } else if (modelData.value === "RESET_LAYOUT") {
                if (rootRef) rootRef.resetWidgetPositions()
              } else {
                galleryWidgetRoot.selectFolder(modelData.value)
              }
            }
          }
        }
      }
    }
  }
}
