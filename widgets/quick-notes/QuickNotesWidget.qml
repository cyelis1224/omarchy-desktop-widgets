import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Ui

// Import base WidgetCard from the shared repository link or parent widgets directory
import "../../shared"
import ".."

WidgetCard {
  id: notesWidgetRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Placement Settings
  // ---------------------------------------------------------------------------
  widgetId: "quick_notes"
  title: "Scratchpad & Tasks"
  icon: "\uf044"
  showHeader: false // Custom integrated header for tabs & counters

  defaultX: Style.space(24)
  defaultY: 320

  width: 380
  height: 440
  minWidth: 320
  minHeight: 280

  // ---------------------------------------------------------------------------
  // 📂 Data State & Backend Process
  // ---------------------------------------------------------------------------
  property string currentTab: "TASKS" // "TASKS" | "SCRATCHPAD" | "COMMANDS"
  property var todosList: []
  property string scratchpadText: ""
  property var commandsList: []
  property string currentTag: "#todo"
  readonly property var availableTags: ["#todo", "#work", "#idea", "#bug"]
  property string statusMessage: "Synced to notes.md"
  property bool feedbackActive: false

  readonly property int pendingCount: {
    var count = 0
    for (var i = 0; i < todosList.length; i++) {
      if (!todosList[i].done) count++
    }
    return count
  }
  readonly property int completedCount: todosList.length - pendingCount
  readonly property string notesManagerPath: Qt.resolvedUrl("notes_manager.py").toString().replace(/^file:\/\//, "")

  Process {
    id: notesProc
    command: [notesWidgetRoot.notesManagerPath, "load"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var res = JSON.parse(String(line).trim())
          if (res.todos !== undefined) notesWidgetRoot.todosList = res.todos
          if (res.scratchpad !== undefined) {
            notesWidgetRoot.scratchpadText = res.scratchpad
            if (scratchpadEdit.text !== res.scratchpad && !scratchpadEdit.activeFocus) {
              scratchpadEdit.text = res.scratchpad
            }
          }
          if (res.commands !== undefined) notesWidgetRoot.commandsList = res.commands
        } catch (e) {}
      }
    }
  }

  function runAction(args) {
    var cmd = [notesWidgetRoot.notesManagerPath].concat(args)
    notesProc.running = false
    notesProc.command = cmd
    notesProc.running = true
  }

  function toggleTodo(id) {
    runAction(["toggle_todo", id.toString()])
  }

  function deleteTodo(id) {
    runAction(["delete_todo", id.toString()])
  }

  function addTodo(text, tag) {
    if (!text || text.trim() === "") return
    runAction(["add_todo", text.trim(), tag])
  }

  function clearCompleted() {
    runAction(["clear_completed"])
  }

  // Snippets state & management
  property bool snippetEditorOpen: false
  property int editingSnippetId: -1
  property string snippetEditorName: ""
  property string snippetEditorCmd: ""
  property string snippetEditorDesc: ""

  onCurrentTabChanged: {
    if (currentTab !== "COMMANDS") {
      closeSnippetEditor()
    }
  }

  onSnippetEditorOpenChanged: {
    if (snippetEditorOpen) {
      if (typeof snipNameInput !== "undefined" && snipNameInput) {
        snipNameInput.text = snippetEditorName
        snipNameInput.forceActiveFocus()
      }
      if (typeof snipCmdInput !== "undefined" && snipCmdInput) {
        snipCmdInput.text = snippetEditorCmd
      }
      if (typeof snipDescInput !== "undefined" && snipDescInput) {
        snipDescInput.text = snippetEditorDesc
      }
    }
  }

  function openNewSnippetEditor() {
    editingSnippetId = -1
    snippetEditorName = ""
    snippetEditorCmd = ""
    snippetEditorDesc = ""
    if (typeof snipNameInput !== "undefined" && snipNameInput) snipNameInput.text = ""
    if (typeof snipCmdInput !== "undefined" && snipCmdInput) snipCmdInput.text = ""
    if (typeof snipDescInput !== "undefined" && snipDescInput) snipDescInput.text = ""
    snippetEditorOpen = true
  }

  function openEditSnippetEditor(snippet) {
    editingSnippetId = snippet.id !== undefined ? snippet.id : -1
    snippetEditorName = snippet.name || ""
    snippetEditorCmd = snippet.cmd || ""
    snippetEditorDesc = snippet.desc || ""
    if (typeof snipNameInput !== "undefined" && snipNameInput) snipNameInput.text = snippetEditorName
    if (typeof snipCmdInput !== "undefined" && snipCmdInput) snipCmdInput.text = snippetEditorCmd
    if (typeof snipDescInput !== "undefined" && snipDescInput) snipDescInput.text = snippetEditorDesc
    snippetEditorOpen = true
  }

  function closeSnippetEditor() {
    snippetEditorOpen = false
    editingSnippetId = -1
    snippetEditorName = ""
    snippetEditorCmd = ""
    snippetEditorDesc = ""
  }

  function addSnippet(name, cmd, desc) {
    if (!name || !name.trim() || !cmd || !cmd.trim()) return
    runAction(["add_command", name.trim(), cmd.trim(), desc ? desc.trim() : ""])
  }

  function editSnippet(id, name, cmd, desc) {
    if (!name || !name.trim() || !cmd || !cmd.trim()) return
    runAction(["edit_command", id.toString(), name.trim(), cmd.trim(), desc ? desc.trim() : ""])
  }

  function deleteSnippet(id) {
    runAction(["delete_command", id.toString()])
  }

  Timer {
    id: saveDebounce
    interval: 800
    repeat: false
    onTriggered: {
      runAction(["save_scratchpad", scratchpadEdit.text])
      notesWidgetRoot.statusMessage = "✓ Saved to notes.md"
    }
  }

  customMenuContent: Component {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      Text {
        text: "QUICK NOTES & DECK ACTIONS"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        Layout.leftMargin: 4
        Layout.topMargin: 2
      }

      // Switch to Tasks Tab
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: tabTaskMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf0ae"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Switch to Tasks Tab"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
        MouseArea {
          id: tabTaskMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            notesWidgetRoot.currentTab = "TASKS"
            notesWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Switch to Scratchpad Tab
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: tabScratchMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf044"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Switch to Scratchpad"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
        MouseArea {
          id: tabScratchMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            notesWidgetRoot.currentTab = "SCRATCHPAD"
            notesWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Switch to Snippets Tab
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: tabCmdMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf120"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Switch to Snippets Tab"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
        MouseArea {
          id: tabCmdMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            notesWidgetRoot.currentTab = "COMMANDS"
            notesWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Add New Snippet
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: addSnipOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf067"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Add New Snippet"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
        MouseArea {
          id: addSnipOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            notesWidgetRoot.currentTab = "COMMANDS"
            notesWidgetRoot.openNewSnippetEditor()
            notesWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Clear Completed Tasks
      Rectangle {
        visible: notesWidgetRoot.completedCount > 0
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: clearOptMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf1f8"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.urgent
          }
          Text {
            Layout.fillWidth: true
            text: "Clear " + notesWidgetRoot.completedCount + " Completed Tasks"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.urgent
          }
        }
        MouseArea {
          id: clearOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            notesWidgetRoot.clearCompleted()
            notesWidgetRoot.contextMenuOpen = false
          }
        }
      }

      // Open notes.md in Text Editor
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: editMdMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf15c"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }
          Text {
            Layout.fillWidth: true
            text: "Open notes.md in Editor"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
        MouseArea {
          id: editMdMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["bash", "-c", "xdg-open \"$HOME/.local/state/omarchy/dagyr.desktop-widgets/notes.md\""])
            notesWidgetRoot.contextMenuOpen = false
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 Layout Body
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(10)

    // -------------------------------------------------------------------------
    // 🏷️ Top Header: Icon, Title, Badge & Grip/Close Slot
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Rectangle {
        width: 30
        height: 30
        radius: 15
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf044"
          font.family: Style.font.family
          font.pixelSize: 13
          color: Color.accent
        }
      }

      ColumnLayout {
        spacing: 0
        Text {
          text: "Quick Notes & Deck"
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Color.foreground
        }
        Text {
          text: notesWidgetRoot.pendingCount + " pending · " + notesWidgetRoot.completedCount + " done"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
        }
      }

      Item { Layout.fillWidth: true }

      // Close button when in layout edit mode
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
              rootRef.toggleWidgetEnabled(notesWidgetRoot.widgetId, false)
            }
          }
        }
      }

      // Drag Grip Button (Move Mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: customGripMouse.drag.active ? Color.accent : (customGripMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0b2"
          font.family: Style.font.family
          font.pixelSize: 10
          color: customGripMouse.drag.active ? Color.background : Color.accent
        }

        MouseArea {
          id: customGripMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: screenWidth - notesWidgetRoot.width - 10
          drag.minimumY: 10
          drag.maximumY: screenHeight - notesWidgetRoot.height - 10
          onPressed: notesWidgetRoot.customGripDragging = true
          onReleased: {
            notesWidgetRoot.customGripDragging = false
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(notesWidgetRoot.widgetId, Math.round(targetItem.x), Math.round(targetItem.y))
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 🗂️ Category Tab Pills
    // -------------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Repeater {
        model: [
          { key: "TASKS", label: "Tasks", icon: "\uf0ae" },
          { key: "SCRATCHPAD", label: "Scratchpad", icon: "\uf044" },
          { key: "COMMANDS", label: "Snippets", icon: "\uf120" }
        ]

        Rectangle {
          required property var modelData
          implicitWidth: tabRow.implicitWidth + 18
          implicitHeight: 26
          radius: 13
          readonly property bool isSelected: notesWidgetRoot.currentTab === modelData.key
          color: tabMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.08))

          RowLayout {
            id: tabRow
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text {
              text: modelData.icon
              font.family: Style.font.family
              font.pixelSize: 10
              color: isSelected ? Color.background : Color.accent
            }
            Text {
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: isSelected ? Font.Bold : Font.Normal
              color: isSelected ? Color.background : Color.foreground
            }
          }

          MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: notesWidgetRoot.currentTab = modelData.key
          }
        }
      }

      Item { Layout.fillWidth: true }
    }

    // -------------------------------------------------------------------------
    // 📋 TAB 1: Tasks / Todos
    // -------------------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: notesWidgetRoot.currentTab === "TASKS"
      spacing: Style.space(8)

      // Add Task Input Row
      Rectangle {
        Layout.fillWidth: true
        height: 34
        radius: 17
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: taskInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(6)
          spacing: Style.space(6)

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
              id: taskInput
              anchors.fill: parent
              verticalAlignment: TextInput.AlignVCenter
              font.family: Style.font.family
              font.pixelSize: 12
              color: Color.foreground
              clip: true
              selectByMouse: true
              cursorVisible: activeFocus

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Add new task... press Enter"
                font.family: Style.font.family
                font.pixelSize: 12
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
                visible: !taskInput.text && !taskInput.activeFocus
              }

              onAccepted: {
                notesWidgetRoot.addTodo(taskInput.text, notesWidgetRoot.currentTag)
                taskInput.text = ""
              }
            }
          }

          // Tag Pill Cycler
          Rectangle {
            implicitWidth: tagText.implicitWidth + 14
            implicitHeight: 22
            radius: 11
            color: notesWidgetRoot.currentTag === "#bug" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
            border.color: notesWidgetRoot.currentTag === "#bug" ? Color.urgent : Color.accent
            border.width: 1

            Text {
              id: tagText
              anchors.centerIn: parent
              text: notesWidgetRoot.currentTag
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.Bold
              color: notesWidgetRoot.currentTag === "#bug" ? Color.urgent : Color.accent
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var idx = notesWidgetRoot.availableTags.indexOf(notesWidgetRoot.currentTag)
                notesWidgetRoot.currentTag = notesWidgetRoot.availableTags[(idx + 1) % notesWidgetRoot.availableTags.length]
              }
            }
          }

          // Add Button
          Rectangle {
            width: 24
            height: 24
            radius: 12
            color: addBtnMouse.containsMouse ? Qt.lighter(Color.accent, 1.2) : Color.accent

            Text {
              anchors.centerIn: parent
              text: "\uf067"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Color.background
            }

            MouseArea {
              id: addBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                notesWidgetRoot.addTodo(taskInput.text, notesWidgetRoot.currentTag)
                taskInput.text = ""
              }
            }
          }
        }
      }

      // Tasks List
      ListView {
        id: todosListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.space(6)
        model: notesWidgetRoot.todosList

        delegate: Rectangle {
          required property var modelData
          width: todosListView.width
          height: 38
          radius: 10
          color: taskItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
          border.color: Qt.rgba(1, 1, 1, 0.07)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            // Custom Checkbox
            Rectangle {
              width: 18
              height: 18
              radius: 6
              color: modelData.done ? Color.accent : "transparent"
              border.color: modelData.done ? Color.accent : Qt.rgba(1, 1, 1, 0.35)
              border.width: 1.5

              Text {
                anchors.centerIn: parent
                visible: modelData.done
                text: "\uf00c"
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Color.background
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: notesWidgetRoot.toggleTodo(modelData.id)
              }
            }

            // Task Text
            Text {
              Layout.fillWidth: true
              text: modelData.text || ""
              font.family: Style.font.family
              font.pixelSize: 12
              font.strikeout: modelData.done
              color: modelData.done ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4) : Color.foreground
              elide: Text.ElideRight
            }

            // Tag Pill
            Rectangle {
              visible: modelData.tag !== undefined && modelData.tag !== ""
              implicitWidth: rowTagText.implicitWidth + 10
              implicitHeight: 18
              radius: 9
              color: {
                if (modelData.tag === "#bug") return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2)
                if (modelData.tag === "#work") return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                if (modelData.tag === "#idea") return Qt.rgba(1, 0.75, 0.2, 0.2)
                return Qt.rgba(1, 1, 1, 0.1)
              }

              Text {
                id: rowTagText
                anchors.centerIn: parent
                text: modelData.tag || ""
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: {
                  if (modelData.tag === "#bug") return Color.urgent
                  if (modelData.tag === "#work") return Color.accent
                  if (modelData.tag === "#idea") return Qt.rgba(1, 0.8, 0.25, 1.0)
                  return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
                }
              }
            }

            // Delete Button (visible on hover)
            Rectangle {
              width: 20
              height: 20
              radius: 10
              visible: taskItemMouse.containsMouse
              color: delMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : "transparent"

              Text {
                anchors.centerIn: parent
                text: "\uf1f8"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.urgent
              }

              MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notesWidgetRoot.deleteTodo(modelData.id)
              }
            }
          }

          MouseArea {
            id: taskItemMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
          }
        }
      }

      // Bottom Bar
      RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: 10

        Text {
          text: notesWidgetRoot.completedCount + " completed"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          visible: notesWidgetRoot.completedCount > 0
          implicitWidth: clearRow.implicitWidth + 20
          implicitHeight: 22
          radius: 11
          color: clearMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.08)
          border.color: clearMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3)
          border.width: 1

          RowLayout {
            id: clearRow
            anchors.centerIn: parent
            spacing: 5
            Text {
              text: "\uf1f8"
              font.family: Style.font.family
              font.pixelSize: 9
              color: Color.urgent
            }
            Text {
              id: clearText
              text: "Clear Done"
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.DemiBold
              color: Color.urgent
            }
          }

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: notesWidgetRoot.clearCompleted()
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 📝 TAB 2: Scratchpad
    // -------------------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: notesWidgetRoot.currentTab === "SCRATCHPAD"
      spacing: Style.space(8)

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: scratchpadEdit.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Flickable {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          contentWidth: width
          contentHeight: scratchpadEdit.implicitHeight
          clip: true

          TextEdit {
            id: scratchpadEdit
            width: parent.width
            font.family: Style.font.family
            font.pixelSize: 12
            color: Color.foreground
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            cursorVisible: activeFocus

            Text {
              anchors.fill: parent
              text: "Jot down anything here... auto-syncs to notes.md"
              font.family: Style.font.family
              font.pixelSize: 12
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
              visible: !scratchpadEdit.text && !scratchpadEdit.activeFocus
            }

            onTextChanged: {
              notesWidgetRoot.statusMessage = "Typing..."
              saveDebounce.restart()
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true

        Text {
          text: notesWidgetRoot.statusMessage
          font.family: Style.font.family
          font.pixelSize: 10
          color: Color.accent
        }

        Item { Layout.fillWidth: true }

        Text {
          text: scratchpadEdit.text.length + " chars"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
      }
    }

    // -------------------------------------------------------------------------
    // ⚡ TAB 3: Commands & Snippets
    // -------------------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: notesWidgetRoot.currentTab === "COMMANDS"
      spacing: Style.space(8)

      // 1. When NOT editing a snippet: show List and "+ New Snippet" button
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !notesWidgetRoot.snippetEditorOpen
        spacing: Style.space(8)

        // Header Row: Count & Add Button
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: "SAVED SNIPPETS"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
          }

          Rectangle {
            implicitWidth: countText.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
            border.width: 1

            Text {
              id: countText
              anchors.centerIn: parent
              text: notesWidgetRoot.commandsList.length.toString()
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Color.accent
            }
          }

          Item { Layout.fillWidth: true }

          // Add Snippet Button
          Rectangle {
            implicitWidth: addSnipRow.implicitWidth + 16
            implicitHeight: 24
            radius: 12
            color: addSnipMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
            border.color: Color.accent
            border.width: 1

            RowLayout {
              id: addSnipRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: "\uf067"
                font.family: Style.font.family
                font.pixelSize: 9
                color: addSnipMouse.containsMouse ? Color.background : Color.accent
              }
              Text {
                text: "New Snippet"
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: Font.Bold
                color: addSnipMouse.containsMouse ? Color.background : Color.accent
              }
            }

            MouseArea {
              id: addSnipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: notesWidgetRoot.openNewSnippetEditor()
            }
          }
        }

        // Snippets List & Scrollbar Container
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          // Empty state
          ColumnLayout {
            anchors.centerIn: parent
            visible: notesWidgetRoot.commandsList.length === 0
            spacing: Style.space(6)

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "\uf120"
              font.family: Style.font.family
              font.pixelSize: 28
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2)
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "No snippets saved yet"
              font.family: Style.font.family
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "Click '+ New Snippet' to add custom commands"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
            }
          }

          ListView {
            id: commandsListView
            anchors.fill: parent
            clip: true
            spacing: Style.space(6)
            model: notesWidgetRoot.commandsList

            delegate: Rectangle {
              required property var modelData
              width: commandsListView.width - (scrollTrack.visible ? 8 : 0)
              height: 52
              radius: 10
              color: cmdMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
              border.color: cmdMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)

                Rectangle {
                  width: 30
                  height: 30
                  radius: 8
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                  border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "\uf120"
                    font.family: Style.font.family
                    font.pixelSize: 11
                    color: Color.accent
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name || ""
                    font.family: Style.font.family
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Color.foreground
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    text: modelData.cmd || ""
                    font.family: "Monospace"
                    font.pixelSize: 10
                    color: Qt.lighter(Color.accent, 1.15)
                    elide: Text.ElideRight
                  }
                }

                // Actions: Run, Edit, Delete
                RowLayout {
                  spacing: 4

                  // Run Button
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: runBtnMouse.containsMouse ? Qt.lighter(Color.accent, 1.2) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                    border.color: Color.accent
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "\uf04b"
                      font.family: Style.font.family
                      font.pixelSize: 8
                      color: runBtnMouse.containsMouse ? Color.background : Color.accent
                    }

                    MouseArea {
                      id: runBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        Quickshell.execDetached(["bash", "-c", modelData.cmd])
                      }
                    }
                  }

                  // Edit Button
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: editBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: editBtnMouse.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "\uf044"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: editBtnMouse.containsMouse ? Color.accent : Color.foreground
                    }

                    MouseArea {
                      id: editBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: notesWidgetRoot.openEditSnippetEditor(modelData)
                    }
                  }

                  // Delete Button
                  Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: delBtnMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: delBtnMouse.containsMouse ? Color.urgent : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "\uf1f8"
                      font.family: Style.font.family
                      font.pixelSize: 10
                      color: Color.urgent
                    }

                    MouseArea {
                      id: delBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: notesWidgetRoot.deleteSnippet(modelData.id)
                    }
                  }
                }
              }

              MouseArea {
                id: cmdMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }
            }
          }

          // Sleek Custom Scrollbar
          Rectangle {
            id: scrollTrack
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.05)
            visible: commandsListView.contentHeight > commandsListView.height

            Rectangle {
              width: parent.width
              radius: 2
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
              height: Math.max(16, (commandsListView.height / Math.max(1, commandsListView.contentHeight)) * commandsListView.height)
              y: Math.max(0, Math.min(commandsListView.height - height, (commandsListView.contentY / Math.max(1, commandsListView.contentHeight - commandsListView.height)) * (commandsListView.height - height)))
            }
          }
        }
      }

      // 2. When EDITING or ADDING a snippet: dedicated full editor card
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: notesWidgetRoot.snippetEditorOpen
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(8)

          // Editor Header
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Rectangle {
              width: 24
              height: 24
              radius: 12
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: notesWidgetRoot.editingSnippetId > 0 ? "\uf044" : "\uf067"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.accent
              }
            }

            Text {
              text: notesWidgetRoot.editingSnippetId > 0 ? "Edit Snippet" : "New Snippet"
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
              color: closeEditMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

              Text {
                anchors.centerIn: parent
                text: "\uf00d"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)
              }

              MouseArea {
                id: closeEditMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notesWidgetRoot.closeSnippetEditor()
              }
            }
          }

          // Divider
          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
          }

          // Field 1: Snippet Name
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: "NAME / TITLE"
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }

            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 8
              color: Qt.rgba(1, 1, 1, 0.06)
              border.color: snipNameInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
              border.width: 1

              TextInput {
                id: snipNameInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.foreground
                clip: true
                selectByMouse: true
                onAccepted: snipCmdInput.forceActiveFocus()

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  text: "e.g. Restart Shell, Git Status..."
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
                  visible: !snipNameInput.text && !snipNameInput.activeFocus
                }
              }
            }
          }

          // Field 2: Shell Command
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: "SHELL COMMAND"
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }

            Rectangle {
              Layout.fillWidth: true
              height: 32
              radius: 8
              color: Qt.rgba(1, 1, 1, 0.06)
              border.color: snipCmdInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
              border.width: 1

              TextInput {
                id: snipCmdInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: "Monospace"
                font.pixelSize: 11
                color: Qt.lighter(Color.accent, 1.2)
                clip: true
                selectByMouse: true
                onAccepted: snipDescInput.forceActiveFocus()

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  text: "e.g. omarchy-restart-shell, fastfetch..."
                  font.family: "Monospace"
                  font.pixelSize: 11
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
                  visible: !snipCmdInput.text && !snipCmdInput.activeFocus
                }
              }
            }
          }

          // Field 3: Description (Optional)
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: "DESCRIPTION (OPTIONAL)"
              font.family: Style.font.family
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }

            Rectangle {
              Layout.fillWidth: true
              height: 30
              radius: 8
              color: Qt.rgba(1, 1, 1, 0.06)
              border.color: snipDescInput.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.12)
              border.width: 1

              TextInput {
                id: snipDescInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.foreground
                clip: true
                selectByMouse: true
                onAccepted: saveSnippetBtn.triggerSave()

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  text: "Brief description of command"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
                  visible: !snipDescInput.text && !snipDescInput.activeFocus
                }
              }
            }
          }

          // Spacer
          Item { Layout.fillHeight: true }

          // Action Buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            // Delete button (visible when editing existing snippet)
            Rectangle {
              visible: notesWidgetRoot.editingSnippetId > 0
              implicitWidth: delEditRow.implicitWidth + 16
              implicitHeight: 30
              radius: 15
              color: delEditBtnMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.12)
              border.color: Color.urgent
              border.width: 1

              RowLayout {
                id: delEditRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                  text: "\uf1f8"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.urgent
                }
                Text {
                  text: "Delete"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Color.urgent
                }
              }

              MouseArea {
                id: delEditBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  notesWidgetRoot.deleteSnippet(notesWidgetRoot.editingSnippetId)
                  notesWidgetRoot.closeSnippetEditor()
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Cancel Button
            Rectangle {
              implicitWidth: cancelText.implicitWidth + 18
              implicitHeight: 30
              radius: 15
              color: cancelBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
              border.color: Qt.rgba(1, 1, 1, 0.15)
              border.width: 1

              Text {
                id: cancelText
                anchors.centerIn: parent
                text: "Cancel"
                font.family: Style.font.family
                font.pixelSize: 11
                color: Color.foreground
              }

              MouseArea {
                id: cancelBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notesWidgetRoot.closeSnippetEditor()
              }
            }

            // Save Button
            Rectangle {
              id: saveSnippetBtn
              implicitWidth: saveRow.implicitWidth + 18
              implicitHeight: 30
              radius: 15
              readonly property bool canSave: snipNameInput.text.trim().length > 0 && snipCmdInput.text.trim().length > 0
              opacity: canSave ? 1.0 : 0.5
              color: canSave && saveBtnMouse.containsMouse ? Qt.lighter(Color.accent, 1.2) : Color.accent

              function triggerSave() {
                var name = snipNameInput.text.trim()
                var cmd = snipCmdInput.text.trim()
                var desc = snipDescInput.text.trim()
                if (!name || !cmd) return
                if (notesWidgetRoot.editingSnippetId > 0) {
                  notesWidgetRoot.editSnippet(notesWidgetRoot.editingSnippetId, name, cmd, desc)
                } else {
                  notesWidgetRoot.addSnippet(name, cmd, desc)
                }
                notesWidgetRoot.closeSnippetEditor()
              }

              RowLayout {
                id: saveRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                  text: "\uf00c"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Color.background
                }
                Text {
                  text: notesWidgetRoot.editingSnippetId > 0 ? "Save Changes" : "Create Snippet"
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: Font.Bold
                  color: Color.background
                }
              }

              MouseArea {
                id: saveBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: saveSnippetBtn.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: saveSnippetBtn.triggerSave()
              }
            }
          }
        }
      }
    }
  }
}
