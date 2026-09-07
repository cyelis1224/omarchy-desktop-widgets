import QtQuick

QtObject {
  id: registry

  readonly property var builtins: [
    {
      id: "clock",
      name: "Hero Clock & Weather",
      category: "Glance",
      icon: "\uf017",
      badge: "Featured",
      description: "Centerpiece dynamic desktop clock with live weather status and date display.",
      componentUrl: Qt.resolvedUrl("HeroClockWidget.qml")
    },
    {
      id: "gallery",
      name: "3D Photo Deck Stack",
      category: "Glance",
      icon: "\uf03e",
      badge: "Animated",
      description: "Layered photo deck cycling through wallpapers, camera roll, and custom folders.",
      componentUrl: Qt.resolvedUrl("PhotoGalleryWidget.qml")
    },
    {
      id: "network",
      name: "Live Network Traffic",
      category: "System",
      icon: "\uf0ec",
      badge: "Real-time",
      description: "Real-time upload and download bandwidth sparkline area charts and connection metrics.",
      componentUrl: Qt.resolvedUrl("NetworkTrafficWidget.qml")
    },
    {
      id: "media",
      name: "MPRIS Media Player",
      category: "Media",
      icon: "\uf001",
      badge: "Visualizer",
      description: "Album artwork, track marquee, player controls, and dynamic 24-bar audio frequency spectrum.",
      componentUrl: Qt.resolvedUrl("MediaPlayerWidget.qml")
    },
    {
      id: "system",
      name: "System Resources",
      category: "System",
      icon: "\uf2db",
      badge: "Hardware",
      description: "Live system RAM usage monitor and multi-disk mount storage capacity indicators.",
      componentUrl: Qt.resolvedUrl("SystemResourcesWidget.qml")
    },
    {
      id: "git_activity",
      name: "Git Activity Radar",
      category: "Dev",
      icon: "\uf1d3",
      badge: "84-Day Radar",
      description: "84-day contribution pulse heatmap, commit history, branch tracker, and uncommitted diff status.",
      componentUrl: Qt.resolvedUrl("git-activity/GitActivityWidget.qml")
    },
    {
      id: "hardware_telemetry",
      name: "Hardware Telemetry",
      category: "System",
      icon: "\uf2db",
      badge: "Sensors",
      description: "Real-time CPU and GPU utilization, clock frequencies, thermals, and VRAM monitoring.",
      componentUrl: Qt.resolvedUrl("hardware-telemetry/HardwareTelemetryWidget.qml")
    },
    {
      id: "pomodoro",
      name: "Flow Pomodoro Timer",
      category: "Productivity",
      icon: "\uf252",
      badge: "Focus",
      description: "Flow-state countdown timer with circular progress ring, focus cycles, and audio alerts.",
      componentUrl: Qt.resolvedUrl("pomodoro/PomodoroWidget.qml")
    },
    {
      id: "quick_notes",
      name: "Quick Notes & Todos",
      category: "Productivity",
      icon: "\uf249",
      badge: "Scratchpad",
      description: "Markdown scratchpad and tagged Kanban todo deck with instant local state persistence.",
      componentUrl: Qt.resolvedUrl("quick-notes/QuickNotesWidget.qml")
    }
  ]

  property var customWidgets: []

  readonly property var allWidgets: {
    var list = [].concat(builtins)
    for (var i = 0; i < customWidgets.length; i++) {
      var c = customWidgets[i]
      list.push({
        id: c.id,
        name: c.name || "Custom Widget",
        category: "Custom",
        icon: "\uf12e",
        badge: "User QML",
        description: c.path || "Imported custom desktop widget component.",
        componentUrl: (c.path.startsWith("/") || c.path.startsWith("file://")) ? ("file://" + c.path.replace("file://", "")) : Qt.resolvedUrl(c.path)
      })
    }
    return list
  }

  function getWidget(id) {
    for (var i = 0; i < allWidgets.length; i++) {
      if (allWidgets[i].id === id) return allWidgets[i]
    }
    return null
  }
}
