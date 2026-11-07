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
    },
    {
      id: "weather",
      name: "Weather Forecast",
      category: "Glance",
      icon: "\uf185",
      badge: "Live",
      description: "Current temperature, atmospheric conditions, and 3-day forecast with °F/°C switching.",
      componentUrl: Qt.resolvedUrl("WeatherWidget.qml")
    },
    {
      id: "app_launcher",
      name: "App Launcher Grid",
      category: "Productivity",
      icon: "\uf108",
      badge: "QuickLaunch",
      description: "Fast desktop application launcher with live search, category filters, and system icons.",
      componentUrl: Qt.resolvedUrl("AppLauncherWidget.qml")
    },
    {
      id: "folder_view",
      name: "Folder View Card",
      category: "Productivity",
      icon: "\uf07b",
      badge: "Transparent",
      description: "Transparent desktop portal for any directory with .desktop app launching and subfolder navigation.",
      componentUrl: Qt.resolvedUrl("FolderViewWidget.qml")
    },
    {
      id: "coin_tracker",
      name: "Coin Tracker",
      category: "Finance",
      icon: "\uf51e",
      badge: "Core",
      description: "Live cryptocurrency market tracker with multi-coin watchlist, auto-cycle, interactive sparklines, and fiat switcher.",
      componentUrl: Qt.resolvedUrl("CoinTrackerWidget.qml")
    },
    {
      id: "analog_clock",
      name: "Luxury & Bauhaus Analog Clock",
      category: "Glance",
      icon: "\uf017",
      badge: "Chronograph",
      description: "Precision timepiece with 60 FPS sweep, Swiss chronograph subdials, date complication, and multiple styles.",
      componentUrl: Qt.resolvedUrl("AnalogClockWidget.qml")
    },
    {
      id: "calendar",
      name: "Interactive Calendar & Agenda",
      category: "Productivity",
      icon: "\uf073",
      badge: "Planner",
      description: "Interactive monthly planner grid with day navigation and tagged daily agenda checklist.",
      componentUrl: Qt.resolvedUrl("CalendarWidget.qml")
    },
    {
      id: "rss_feed",
      name: "RSS Feed Radar",
      category: "Glance",
      icon: "\uf09e",
      badge: "Live Feeds",
      description: "News and article reader with customizable RSS/Atom feeds, channel tabs, and browser integration.",
      componentUrl: Qt.resolvedUrl("rss-feed/RssFeedWidget.qml")
    },
    {
      id: "agent_usage",
      name: "Agent Usage",
      category: "Dev",
      icon: "\uee0d",
      badge: "Multi-Account",
      description: "Claude Code and Codex rate limits, 7-day tokens, and top models for every account, including a second login of the same tool.",
      componentUrl: Qt.resolvedUrl("agent-usage/AgentUsageWidget.qml")
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
    var targetId = (id === "btc_tracker") ? "coin_tracker" : id
    for (var i = 0; i < allWidgets.length; i++) {
      if (allWidgets[i].id === targetId || allWidgets[i].id === id) return allWidgets[i]
    }
    return null
  }
}
