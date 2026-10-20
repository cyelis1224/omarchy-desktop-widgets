import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

WidgetCard {
  id: calendarRoot

  // ---------------------------------------------------------------------------
  // 🏷️ Identity & Sizing
  // ---------------------------------------------------------------------------
  widgetId: "calendar"
  title: "Calendar & Agenda"
  icon: "\uf073"
  showHeader: false

  defaultX: 760
  defaultY: 480

  width: 340
  height: 480
  minWidth: 300
  minHeight: 380
  maxWidth: 520
  maxHeight: 650
  menuWidth: 290

  // ---------------------------------------------------------------------------
  // ⚙️ Preferences & State
  // ---------------------------------------------------------------------------
  property bool startOnMonday: true
  property var viewDate: new Date()
  property var selectedDate: new Date()
  property var eventsList: []

  // Sub Modal Form State & Editing State
  property bool showEventModal: false
  property string editingEventId: ""
  property string modalEventTitle: ""
  property string modalStartDate: ""
  property string modalEndDate: ""
  property bool modalAllDay: false
  property string modalStartTime: "09:00 AM"
  property string modalEndTime: "10:00 AM"
  property string modalCategory: "work" // "work" | "meeting" | "personal" | "deadline"

  readonly property bool hasInputFocus: (
    (typeof titleInput !== "undefined" && titleInput && titleInput.activeFocus) ||
    (typeof startInput !== "undefined" && startInput && startInput.activeFocus) ||
    (typeof endInput !== "undefined" && endInput && endInput.activeFocus) ||
    (typeof sTimeInput !== "undefined" && sTimeInput && sTimeInput.activeFocus) ||
    (typeof eTimeInput !== "undefined" && eTimeInput && eTimeInput.activeFocus)
  )

  onHasInputFocusChanged: {
    if (rootRef && "keyboardFocusRequested" in rootRef) {
      rootRef.keyboardFocusRequested = hasInputFocus || showEventModal
    }
  }

  onShowEventModalChanged: {
    if (rootRef && "keyboardFocusRequested" in rootRef) {
      rootRef.keyboardFocusRequested = showEventModal
    }
    if (showEventModal) {
      syncModalInputs()
      Qt.callLater(function() {
        if (typeof titleInput !== "undefined" && titleInput) {
          titleInput.forceActiveFocus()
          titleInput.selectAll()
        }
      })
    } else {
      editingEventId = ""
      if (rootRef && "keyboardFocusRequested" in rootRef) {
        rootRef.keyboardFocusRequested = false
      }
    }
  }

  Connections {
    target: (rootRef && "keyboardFocusRequested" in rootRef) ? rootRef : null
    ignoreUnknownSignals: true
    function onKeyboardFocusRequestedChanged() {
      if (rootRef && !rootRef.keyboardFocusRequested && calendarRoot.showEventModal) {
        calendarRoot.showEventModal = false
      }
    }
  }

  Component.onDestruction: {
    if (rootRef && "keyboardFocusRequested" in rootRef && rootRef.keyboardFocusRequested) {
      rootRef.keyboardFocusRequested = false
    }
  }

  function getCategoryColor(cat) {
    if (cat === "meeting") return Commons.Color.accent
    if (cat === "personal") return "#34d399" // Mint green
    if (cat === "deadline") return "#f87171" // Red
    return "#38bdf8" // Cyan for work
  }

  function applySavedSettings() {
    var som = getSetting("startOnMonday", undefined)
    if (som !== undefined) startOnMonday = Boolean(som)
    var ev = getSetting("events", undefined)
    if (Array.isArray(ev)) {
      eventsList = ev
    } else if (ev && typeof ev === "object") {
      // Migrate from old eventsMap format
      var migrated = []
      for (var k in ev) {
        if (Array.isArray(ev[k])) {
          for (var j = 0; j < ev[k].length; j++) {
            var oldItem = ev[k][j]
            migrated.push({
              id: oldItem.id || ("ev_" + Date.now() + "_" + Math.floor(Math.random() * 1000)),
              title: oldItem.text || oldItem.title || "Note",
              startDate: k,
              endDate: k,
              allDay: true,
              startTime: oldItem.time || "09:00 AM",
              endTime: "10:00 AM",
              category: "work",
              done: Boolean(oldItem.done)
            })
          }
        }
      }
      eventsList = migrated
    }
  }

  onSettingsLoaded: applySavedSettings()
  Component.onCompleted: applySavedSettings()

  function dateKey(d) {
    var y = d.getFullYear()
    var m = String(d.getMonth() + 1).padStart(2, '0')
    var day = String(d.getDate()).padStart(2, '0')
    return y + "-" + m + "-" + day
  }

  readonly property string selectedKey: dateKey(selectedDate)

  readonly property var selectedEvents: {
    var k = selectedKey
    if (!eventsList || !eventsList.length) return []
    return eventsList.filter(function(ev) {
      var s = ev.startDate || ev.date || ""
      var e = ev.endDate || ev.startDate || s
      return (s <= k && k <= e)
    })
  }

  function hasEventsOnDate(dateStr) {
    if (!eventsList || !eventsList.length) return false
    for (var i = 0; i < eventsList.length; i++) {
      var ev = eventsList[i]
      var s = ev.startDate || ev.date || ""
      var e = ev.endDate || ev.startDate || s
      if (s <= dateStr && dateStr <= e) return true
    }
    return false
  }

  function saveEvents() {
    saveSetting("events", eventsList)
  }

  function syncModalInputs() {
    if (typeof titleInput !== "undefined" && titleInput) titleInput.text = modalEventTitle
    if (typeof startInput !== "undefined" && startInput) startInput.text = modalStartDate
    if (typeof endInput !== "undefined" && endInput) endInput.text = modalEndDate
    if (typeof sTimeInput !== "undefined" && sTimeInput) sTimeInput.text = modalStartTime
    if (typeof eTimeInput !== "undefined" && eTimeInput) eTimeInput.text = modalEndTime
  }

  function openAddEventModal(presetDate) {
    editingEventId = ""
    var dStr = presetDate ? presetDate : selectedKey
    modalEventTitle = ""
    modalStartDate = dStr
    modalEndDate = dStr
    modalAllDay = false
    modalStartTime = "09:00 AM"
    modalEndTime = "10:00 AM"
    modalCategory = "work"
    syncModalInputs()
    showEventModal = true
  }

  function openEditEventModal(ev) {
    if (!ev) return
    editingEventId = ev.id || ""
    modalEventTitle = ev.title || ev.text || ""
    modalStartDate = ev.startDate || selectedKey
    modalEndDate = ev.endDate || modalStartDate
    modalAllDay = Boolean(ev.allDay)
    modalStartTime = ev.startTime || "09:00 AM"
    modalEndTime = ev.endTime || "10:00 AM"
    modalCategory = ev.category || "work"
    syncModalInputs()
    showEventModal = true
  }

  function createCalendarEvent(title, startDate, endDate, allDay, startTime, endTime, category) {
    saveCalendarEvent("", title, startDate, endDate, allDay, startTime, endTime, category)
  }

  function saveCalendarEvent(id, title, startDate, endDate, allDay, startTime, endTime, category) {
    var cleanTitle = (title ? String(title).trim() : "")
    if (!cleanTitle) cleanTitle = "Untitled Event"
    var s = (startDate ? String(startDate).trim() : "") || selectedKey
    var e = (endDate ? String(endDate).trim() : "") || s
    if (s > e) {
      var tmp = s; s = e; e = tmp;
    }
    var list = eventsList ? eventsList.slice() : []
    if (id) {
      var found = false
      for (var i = 0; i < list.length; i++) {
        if (list[i].id === id) {
          list[i].title = cleanTitle
          list[i].startDate = s
          list[i].endDate = e
          list[i].allDay = Boolean(allDay)
          list[i].startTime = startTime || "09:00 AM"
          list[i].endTime = endTime || "10:00 AM"
          list[i].category = category || "work"
          found = true
          break
        }
      }
      if (!found) {
        list.push({
          id: id,
          title: cleanTitle,
          startDate: s,
          endDate: e,
          allDay: Boolean(allDay),
          startTime: startTime || "09:00 AM",
          endTime: endTime || "10:00 AM",
          category: category || "work",
          done: false
        })
      }
    } else {
      list.push({
        id: "ev_" + Date.now() + "_" + Math.floor(Math.random() * 10000),
        title: cleanTitle,
        startDate: s,
        endDate: e,
        allDay: Boolean(allDay),
        startTime: startTime || "09:00 AM",
        endTime: endTime || "10:00 AM",
        category: category || "work",
        done: false
      })
    }
    eventsList = list
    saveEvents()
    showEventModal = false
    editingEventId = ""
  }

  function toggleEventDone(id) {
    var list = eventsList.slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        list[i].done = !list[i].done
        break
      }
    }
    eventsList = list
    saveEvents()
  }

  function deleteCalendarEvent(id) {
    eventsList = eventsList.filter(function(item) { return item.id !== id })
    saveEvents()
  }

  function prevMonth() {
    var d = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1)
    viewDate = d
  }

  function nextMonth() {
    var d = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1)
    viewDate = d
  }

  function goToday() {
    var t = new Date()
    viewDate = new Date(t.getFullYear(), t.getMonth(), 1)
    selectedDate = t
  }

  // ---------------------------------------------------------------------------
  // 📅 Calendar Days Grid Calculation
  // ---------------------------------------------------------------------------
  readonly property var calendarGrid: {
    var _dep = calendarRoot.eventsList.length
    var today = new Date()
    var todayStr = dateKey(today)
    var selStr = dateKey(selectedDate)

    var year = viewDate.getFullYear()
    var month = viewDate.getMonth()

    var firstDayOfMonth = new Date(year, month, 1)
    var firstDayWeek = firstDayOfMonth.getDay() // 0 = Sunday, 1 = Monday
    var offset = startOnMonday ? ((firstDayWeek + 6) % 7) : firstDayWeek

    var daysInCurrent = new Date(year, month + 1, 0).getDate()
    var daysInPrev = new Date(year, month, 0).getDate()

    var days = []

    // 1. Previous month trailing days
    for (var p = offset - 1; p >= 0; p--) {
      var pDay = daysInPrev - p
      var pDate = new Date(year, month - 1, pDay)
      var pKey = dateKey(pDate)
      days.push({
        dayNumber: pDay,
        isCurrentMonth: false,
        isToday: (pKey === todayStr),
        isSelected: (pKey === selStr),
        dateStr: pKey,
        hasEvents: calendarRoot.hasEventsOnDate(pKey)
      })
    }

    // 2. Current month days
    for (var c = 1; c <= daysInCurrent; c++) {
      var cDate = new Date(year, month, c)
      var cKey = dateKey(cDate)
      days.push({
        dayNumber: c,
        isCurrentMonth: true,
        isToday: (cKey === todayStr),
        isSelected: (cKey === selStr),
        dateStr: cKey,
        hasEvents: calendarRoot.hasEventsOnDate(cKey)
      })
    }

    // 3. Next month leading days (fill up to 35 or 42 slots)
    var totalCells = (days.length > 35) ? 42 : 35
    var nextCount = totalCells - days.length
    for (var n = 1; n <= nextCount; n++) {
      var nDate = new Date(year, month + 1, n)
      var nKey = dateKey(nDate)
      days.push({
        dayNumber: n,
        isCurrentMonth: false,
        isToday: (nKey === todayStr),
        isSelected: (nKey === selStr),
        dateStr: nKey,
        hasEvents: calendarRoot.hasEventsOnDate(nKey)
      })
    }

    return days
  }

  // ---------------------------------------------------------------------------
  // 🖥️ Content Layout
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    // Month Navigation Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "\uf073"
        font.family: Style.font.family
        font.pixelSize: 13
        color: Commons.Color.accent
      }

      Text {
        text: Qt.formatDate(calendarRoot.viewDate, "MMMM yyyy")
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Commons.Color.foreground
      }

      Item { Layout.fillWidth: true }

      // Today Button
      Rectangle {
        width: todayTxt.implicitWidth + 12
        height: 22
        radius: 4
        color: todayMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : calendarRoot.fgTint(0.08)

        Text {
          id: todayTxt
          anchors.centerIn: parent
          text: "Today"
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.DemiBold
          color: Commons.Color.accent
        }

        MouseArea {
          id: todayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: calendarRoot.goToday()
        }
      }

      // Prev Month Arrow
      Rectangle {
        width: 22
        height: 22
        radius: 4
        color: prevMouse.containsMouse ? calendarRoot.fgTint(0.15) : calendarRoot.fgTint(0.06)

        Text {
          anchors.centerIn: parent
          text: "\uf053"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Commons.Color.foreground
        }

        MouseArea {
          id: prevMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: calendarRoot.prevMonth()
        }
      }

      // Next Month Arrow
      Rectangle {
        width: 22
        height: 22
        radius: 4
        color: nextMouse.containsMouse ? calendarRoot.fgTint(0.15) : calendarRoot.fgTint(0.06)

        Text {
          anchors.centerIn: parent
          text: "\uf054"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Commons.Color.foreground
        }

        MouseArea {
          id: nextMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: calendarRoot.nextMonth()
        }
      }

      // Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: calCloseMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35) : calendarRoot.fgTint(0.08)
        border.color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf00d"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Commons.Color.urgent
        }

        MouseArea {
          id: calCloseMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(calendarRoot.widgetId, false, calendarRoot.monitorName)
            }
          }
        }
      }

      // Move Grip Handle (when in edit mode)
      Rectangle {
        id: calGripButton
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: calGripArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : calendarRoot.fgTint(0.08)
        border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf0b2"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Commons.Color.accent
        }

        MouseArea {
          id: calGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: calendarRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, calendarRoot.screenWidth - calendarRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, calendarRoot.screenHeight - calendarRoot.height - 10)

          onPressed: {
            calendarRoot.customGripDragging = true
          }

          onReleased: function() {
            calendarRoot.customGripDragging = false
            var maxX = Math.max(10, calendarRoot.screenWidth - calendarRoot.width - 10)
            var maxY = Math.max(10, calendarRoot.screenHeight - calendarRoot.height - 10)
            var snappedX = calendarRoot.snapVal(calendarRoot.targetItem.x)
            var snappedY = calendarRoot.snapVal(calendarRoot.targetItem.y)
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            calendarRoot.targetItem.x = snappedX
            calendarRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(calendarRoot.widgetId, snappedX, snappedY, calendarRoot.snapVal(calendarRoot.width), calendarRoot.snapVal(calendarRoot.height), calendarRoot.monitorName)
            }
          }
        }
      }
    }

    // Weekday Header Row (Mon..Sun or Sun..Sat)
    RowLayout {
      Layout.fillWidth: true
      spacing: 2

      Repeater {
        model: calendarRoot.startOnMonday ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

        Item {
          required property var modelData
          required property int index
          Layout.fillWidth: true
          height: 18

          Text {
            anchors.centerIn: parent
            text: modelData
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: (index >= 5 && calendarRoot.startOnMonday) || (index === 0 && !calendarRoot.startOnMonday) ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }
        }
      }
    }

    // Days Grid (7 columns x 5 or 6 rows)
    GridLayout {
      id: daysGrid
      Layout.fillWidth: true
      columns: 7
      rowSpacing: 3
      columnSpacing: 2

      Repeater {
        model: calendarRoot.calendarGrid

        Rectangle {
          id: dayCell
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 25
          radius: 6

          color: {
            if (modelData.isSelected) return Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.30)
            if (modelData.isToday) return Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15)
            if (cellMouse.containsMouse) return calendarRoot.fgTint(0.08)
            return "transparent"
          }

          border.width: modelData.isSelected ? 1.5 : (modelData.isToday ? 1 : 0)
          border.color: modelData.isSelected ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: String(modelData.dayNumber)
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: modelData.isToday ? Font.Bold : (modelData.isSelected ? Font.DemiBold : Font.Normal)
              color: {
                if (modelData.isSelected || modelData.isToday) return Commons.Color.accent
                if (!modelData.isCurrentMonth) return Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)
                return Commons.Color.foreground
              }
            }

            // Event Marker Dot
            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              width: 3.5
              height: 3.5
              radius: 1.75
              visible: modelData.hasEvents
              color: modelData.isSelected ? Commons.Color.foreground : Commons.Color.accent
            }
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var parts = modelData.dateStr.split('-')
              calendarRoot.selectedDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
            }
          }
        }
      }
    }

    // Divider line
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: calendarRoot.fgTint(0.08)
      Layout.topMargin: 2
      Layout.bottomMargin: 2
    }

    // Agenda Section Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "\uf022"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Commons.Color.accent
      }

      Text {
        Layout.fillWidth: true
        text: Qt.formatDate(calendarRoot.selectedDate, "ddd, MMM d") + " Agenda"
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Commons.Color.foreground
        elide: Text.ElideRight
      }

      Text {
        text: calendarRoot.selectedEvents.length + " items"
        font.family: Style.font.family
        font.pixelSize: 10
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
      }

      // Quick Add Plus Button
      Rectangle {
        width: 20
        height: 20
        radius: 4
        color: plusHeaderMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)

        Text {
          anchors.centerIn: parent
          text: "\uf067"
          font.family: Style.font.family
          font.pixelSize: 9
          color: plusHeaderMouse.containsMouse ? "#0a0a0f" : Commons.Color.accent
        }

        MouseArea {
          id: plusHeaderMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: calendarRoot.openAddEventModal()
        }
      }
    }

    // Agenda List
    ListView {
      id: agendaListView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: 5
      model: calendarRoot.selectedEvents

      delegate: Rectangle {
        id: eventRow
        required property var modelData
        width: agendaListView.width
        implicitHeight: eventCol.implicitHeight + 12
        radius: 6
        color: evMouse.containsMouse ? calendarRoot.fgTint(0.08) : calendarRoot.fgTint(0.04)
        border.width: 1
        border.color: modelData.done ? "transparent" : calendarRoot.fgTint(0.06)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 8

          // Left Category Accent Strip
          Rectangle {
            width: 3
            Layout.fillHeight: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            radius: 1.5
            color: calendarRoot.getCategoryColor(modelData.category)
          }

          // Checkbox (Done/Not Done)
          Rectangle {
            width: 15
            height: 15
            radius: 3
            color: modelData.done ? Commons.Color.accent : "transparent"
            border.width: 1
            border.color: modelData.done ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.35)

            Text {
              anchors.centerIn: parent
              visible: modelData.done
              text: "\uf00c"
              font.family: Style.font.family
              font.pixelSize: 9
              color: "#0a0a0f"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: calendarRoot.toggleEventDone(modelData.id)
            }
          }

          // Event Content (Title, Time/Range, Multi-day indicator)
          ColumnLayout {
            id: eventCol
            Layout.fillWidth: true
            spacing: 2

            Text {
              Layout.fillWidth: true
              text: modelData.title || modelData.text || "Event"
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              font.strikeout: modelData.done
              color: modelData.done ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4) : Commons.Color.foreground
              elide: Text.ElideRight
            }

            RowLayout {
              spacing: 6

              // Time or All Day Badge
              RowLayout {
                spacing: 3
                Text {
                  text: modelData.allDay ? "\uf073" : "\uf017"
                  font.family: Style.font.family
                  font.pixelSize: 8
                  color: calendarRoot.getCategoryColor(modelData.category)
                }
                Text {
                  text: modelData.allDay ? "All Day" : (modelData.startTime + (modelData.endTime ? (" - " + modelData.endTime) : ""))
                  font.family: Style.font.family
                  font.pixelSize: 9
                  color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
                }
              }

              // Multi-day indicator
              Text {
                visible: (modelData.startDate && modelData.endDate && modelData.startDate !== modelData.endDate)
                text: "• " + modelData.startDate + " → " + modelData.endDate
                font.family: Style.font.family
                font.pixelSize: 8
                color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
              }
            }
          }

          // Edit Button
          Rectangle {
            width: 20
            height: 20
            radius: 4
            color: editMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "\uf044"
              font.family: Style.font.family
              font.pixelSize: 10
              color: editMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
            }

            MouseArea {
              id: editMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: calendarRoot.openEditEventModal(modelData)
            }
          }

          // Delete Button
          Rectangle {
            width: 20
            height: 20
            radius: 4
            color: delMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.25) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "\uf1f8"
              font.family: Style.font.family
              font.pixelSize: 10
              color: delMouse.containsMouse ? Commons.Color.urgent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.3)
            }

            MouseArea {
              id: delMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: calendarRoot.deleteCalendarEvent(modelData.id)
            }
          }
        }

        MouseArea {
          id: evMouse
          anchors.fill: parent
          z: -1
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: calendarRoot.openEditEventModal(modelData)
        }
      }

      // Empty State
      Text {
        anchors.centerIn: parent
        visible: calendarRoot.selectedEvents.length === 0
        text: "No events scheduled for this day"
        font.family: Style.font.family
        font.pixelSize: 11
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.35)
      }
    }

    // Schedule Event Button
    Rectangle {
      Layout.fillWidth: true
      height: 30
      radius: 6
      color: schedBtnMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : calendarRoot.fgTint(0.05)
      border.width: 1
      border.color: schedBtnMouse.containsMouse ? Commons.Color.accent : calendarRoot.fgTint(0.08)

      RowLayout {
        anchors.centerIn: parent
        spacing: 6

        Text {
          text: "\uf067"
          font.family: Style.font.family
          font.pixelSize: 10
          color: Commons.Color.accent
        }

        Text {
          text: "Schedule Event on " + Qt.formatDate(calendarRoot.selectedDate, "MMM d") + "..."
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.DemiBold
          color: Commons.Color.foreground
        }
      }

      MouseArea {
        id: schedBtnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: calendarRoot.openAddEventModal()
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📋 In-Widget Event Creation Sub Modal
  // ---------------------------------------------------------------------------
  Rectangle {
    id: eventModalOverlay
    anchors.fill: parent
    z: 300
    visible: calendarRoot.showEventModal
    radius: 18
    color: Qt.rgba(Commons.Color.menu.background.r, Commons.Color.menu.background.g, Commons.Color.menu.background.b, 0.97)
    border.width: 1.5
    border.color: Commons.Color.accent

    MouseArea {
      anchors.fill: parent
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 8

      // Modal Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
          width: 26
          height: 26
          radius: 6
          color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)
          border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "\uf073"
            font.family: Style.font.family
            font.pixelSize: 12
            color: Commons.Color.accent
          }
        }

        ColumnLayout {
          spacing: 1
          Text {
            text: calendarRoot.editingEventId ? "Edit Event" : "Schedule New Event"
            font.family: Style.font.family
            font.pixelSize: 12
            font.weight: Font.Bold
            color: Commons.Color.foreground
          }
          Text {
            text: calendarRoot.editingEventId ? "Update your scheduled event details" : "Add to your personal calendar agenda"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }
        }

        Item { Layout.fillWidth: true }

        // Close Modal Button
        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: modalCloseMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35) : calendarRoot.fgTint(0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Commons.Color.urgent
          }

          MouseArea {
            id: modalCloseMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarRoot.showEventModal = false
          }
        }
      }

      // Event Title Input
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 3

        Text {
          text: "EVENT TITLE"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
        }

        Rectangle {
          Layout.fillWidth: true
          height: 30
          radius: 6
          color: calendarRoot.wellColor
          border.width: 1
          border.color: titleInput.activeFocus ? Commons.Color.accent : calendarRoot.fgTint(0.12)

          MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.IBeamCursor
            onClicked: {
              if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
              titleInput.forceActiveFocus()
            }
          }

          TextInput {
            id: titleInput
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
            selectByMouse: true
            activeFocusOnTab: true
            clip: true
            text: calendarRoot.modalEventTitle
            onTextChanged: calendarRoot.modalEventTitle = text
            onAccepted: saveBtnMouse.clicked(null)

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: !titleInput.text && !titleInput.activeFocus
              text: "e.g. Design Review, Flight, Doctor..."
              font.family: Style.font.family
              font.pixelSize: 11
              color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.35)
            }
          }
        }
      }

      // Date Range Fields
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 3

        Text {
          text: "DATE RANGE (YYYY-MM-DD)"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: calendarRoot.wellColor
            border.width: 1
            border.color: startInput.activeFocus ? Commons.Color.accent : calendarRoot.fgTint(0.12)

            MouseArea {
              anchors.fill: parent
              z: -1
              cursorShape: Qt.IBeamCursor
              onClicked: {
                if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
                startInput.forceActiveFocus()
              }
            }

            TextInput {
              id: startInput
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              verticalAlignment: TextInput.AlignVCenter
              font.family: Style.font.family
              font.pixelSize: 10
              color: Commons.Color.foreground
              selectByMouse: true
              activeFocusOnTab: true
              clip: true
              text: calendarRoot.modalStartDate
              onTextChanged: calendarRoot.modalStartDate = text
              onAccepted: saveBtnMouse.clicked(null)
            }
          }

          Text {
            text: "→"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: calendarRoot.wellColor
            border.width: 1
            border.color: endInput.activeFocus ? Commons.Color.accent : calendarRoot.fgTint(0.12)

            MouseArea {
              anchors.fill: parent
              z: -1
              cursorShape: Qt.IBeamCursor
              onClicked: {
                if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
                endInput.forceActiveFocus()
              }
            }

            TextInput {
              id: endInput
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              verticalAlignment: TextInput.AlignVCenter
              font.family: Style.font.family
              font.pixelSize: 10
              color: Commons.Color.foreground
              selectByMouse: true
              activeFocusOnTab: true
              clip: true
              text: calendarRoot.modalEndDate
              onTextChanged: calendarRoot.modalEndDate = text
              onAccepted: saveBtnMouse.clicked(null)
            }
          }
        }
      }

      // Time Range & All Day Toggle
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 3

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "TIME RANGE"
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }

          Item { Layout.fillWidth: true }

          // All Day Checkbox
          RowLayout {
            spacing: 5

            Rectangle {
              width: 14
              height: 14
              radius: 3
              color: calendarRoot.modalAllDay ? Commons.Color.accent : "transparent"
              border.width: 1
              border.color: calendarRoot.modalAllDay ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)

              Text {
                anchors.centerIn: parent
                visible: calendarRoot.modalAllDay
                text: "\uf00c"
                font.family: Style.font.family
                font.pixelSize: 9
                color: "#0a0a0f"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarRoot.modalAllDay = !calendarRoot.modalAllDay
              }
            }

            Text {
              text: "All Day Event"
              font.family: Style.font.family
              font.pixelSize: 10
              color: Commons.Color.foreground
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: !calendarRoot.modalAllDay

          Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: calendarRoot.wellColor
            border.width: 1
            border.color: sTimeInput.activeFocus ? Commons.Color.accent : calendarRoot.fgTint(0.12)

            MouseArea {
              anchors.fill: parent
              z: -1
              cursorShape: Qt.IBeamCursor
              onClicked: {
                if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
                sTimeInput.forceActiveFocus()
              }
            }

            TextInput {
              id: sTimeInput
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              verticalAlignment: TextInput.AlignVCenter
              font.family: Style.font.family
              font.pixelSize: 10
              color: Commons.Color.foreground
              selectByMouse: true
              activeFocusOnTab: true
              clip: true
              text: calendarRoot.modalStartTime
              onTextChanged: calendarRoot.modalStartTime = text
              onAccepted: saveBtnMouse.clicked(null)
            }
          }

          Text {
            text: "to"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }

          Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: calendarRoot.wellColor
            border.width: 1
            border.color: eTimeInput.activeFocus ? Commons.Color.accent : calendarRoot.fgTint(0.12)

            MouseArea {
              anchors.fill: parent
              z: -1
              cursorShape: Qt.IBeamCursor
              onClicked: {
                if (rootRef && "keyboardFocusRequested" in rootRef) rootRef.keyboardFocusRequested = true
                eTimeInput.forceActiveFocus()
              }
            }

            TextInput {
              id: eTimeInput
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              verticalAlignment: TextInput.AlignVCenter
              font.family: Style.font.family
              font.pixelSize: 10
              color: Commons.Color.foreground
              selectByMouse: true
              activeFocusOnTab: true
              clip: true
              text: calendarRoot.modalEndTime
              onTextChanged: calendarRoot.modalEndTime = text
              onAccepted: saveBtnMouse.clicked(null)
            }
          }
        }
      }

      // Category / Tag Picker
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 3

        Text {
          text: "CATEGORY"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: [
              { id: "work", label: "Work", color: "#38bdf8" },
              { id: "meeting", label: "Meeting", color: Commons.Color.accent },
              { id: "personal", label: "Personal", color: "#34d399" },
              { id: "deadline", label: "Deadline", color: "#f87171" }
            ]

            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              height: 24
              radius: 5
              readonly property bool isSelected: (calendarRoot.modalCategory === modelData.id)
              color: isSelected ? Qt.rgba(0.2, 0.6, 0.9, 0.25) : calendarRoot.fgTint(0.05)
              border.width: isSelected ? 1 : 0
              border.color: modelData.color

              Text {
                anchors.centerIn: parent
                text: modelData.label
                font.family: Style.font.family
                font.pixelSize: 9
                font.weight: isSelected ? Font.Bold : Font.Normal
                color: isSelected ? modelData.color : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarRoot.modalCategory = modelData.id
              }
            }
          }
        }
      }

      Item { Layout.fillHeight: true }

      // Action Buttons: Cancel and Create/Save
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
          Layout.fillWidth: true
          height: 30
          radius: 6
          color: cancelBtnMouse.containsMouse ? calendarRoot.fgTint(0.12) : calendarRoot.fgTint(0.06)

          Text {
            anchors.centerIn: parent
            text: "Cancel"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
          }

          MouseArea {
            id: cancelBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarRoot.showEventModal = false
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 30
          radius: 6
          color: saveBtnMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.9) : Commons.Color.accent

          RowLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
              text: "\uf00c"
              font.family: Style.font.family
              font.pixelSize: 10
              color: "#0a0a0f"
            }

            Text {
              text: calendarRoot.editingEventId ? "Save Changes" : "Create Event"
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: "#0a0a0f"
            }
          }

          MouseArea {
            id: saveBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var enteredTitle = (titleInput.text || calendarRoot.modalEventTitle || "").trim()
              if (!enteredTitle) {
                enteredTitle = "Untitled Event"
              }
              var sDate = (startInput.text || calendarRoot.modalStartDate || calendarRoot.selectedKey || "").trim()
              var eDate = (endInput.text || calendarRoot.modalEndDate || sDate || "").trim()
              var sTime = (sTimeInput.text || calendarRoot.modalStartTime || "09:00 AM").trim()
              var eTime = (eTimeInput.text || calendarRoot.modalEndTime || "10:00 AM").trim()

              calendarRoot.saveCalendarEvent(
                calendarRoot.editingEventId,
                enteredTitle,
                sDate,
                eDate,
                calendarRoot.modalAllDay,
                sTime,
                eTime,
                calendarRoot.modalCategory
              )
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ⚙️ Custom Context Menu Settings
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 260
      spacing: Style.space(6)

      Text {
        text: "CALENDAR PREFERENCES"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
        Layout.leftMargin: Style.space(8)
      }

      // First Day of Week Toggle
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: somMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf073"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Start Week on Monday"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }

          Text {
            text: calendarRoot.startOnMonday ? "\uf205" : "\uf204"
            font.family: Style.font.family
            font.pixelSize: 13
            color: calendarRoot.startOnMonday ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: somMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            calendarRoot.startOnMonday = !calendarRoot.startOnMonday
            calendarRoot.saveSetting("startOnMonday", calendarRoot.startOnMonday)
          }
        }
      }

      // Clear Current Day Events
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: clearDayMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.15) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf1f8"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.urgent
          }

          Text {
            Layout.fillWidth: true
            text: "Clear Today's Agenda"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: clearDayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            calendarRoot.contextMenuOpen = false
            var em = Object.assign({}, calendarRoot.eventsMap)
            delete em[calendarRoot.selectedKey]
            calendarRoot.eventsMap = em
            calendarRoot.saveEvents()
          }
        }
      }
    }
  }
}
