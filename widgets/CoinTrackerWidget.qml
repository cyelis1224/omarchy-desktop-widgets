import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

WidgetCard {
  id: btcWidgetRoot

  widgetId: "coin_tracker"
  title: coinName + " Tracker"
  icon: coinIcon
  showHeader: false

  defaultX: 400
  defaultY: 140

  width: 350
  height: 245
  minWidth: 290
  minHeight: 200
  maxWidth: 580
  maxHeight: 420

  // ---------------------------------------------------------------------------
  // ⚙️ Persistent Settings
  // ---------------------------------------------------------------------------
  property string currency: "USD"
  property bool fillSparkline: true
  property bool showRangeBar: true
  property int refreshInterval: 60000 // 60s default
  property bool autoCycle: false
  menuWidth: 295

  // List of tracked coins: [{ id: "BTC", name: "Bitcoin", symbol: "BTC", icon: "\uf15a", url: "https://www.coinbase.com/price/bitcoin" }]
  property var trackedCoins: [
    { id: "BTC", name: "Bitcoin", symbol: "BTC", icon: "\uf15a", url: "https://www.coinbase.com/price/bitcoin" }
  ]
  property int currentCoinIndex: 0

  readonly property var currentCoin: {
    if (trackedCoins && trackedCoins.length > 0) {
      var idx = Math.max(0, Math.min(trackedCoins.length - 1, currentCoinIndex))
      return trackedCoins[idx]
    }
    return { id: "BTC", name: "Bitcoin", symbol: "BTC", icon: "\uf15a", url: "https://www.coinbase.com/price/bitcoin" }
  }

  readonly property string currentCoinParam: {
    if (currentCoin && currentCoin.url && currentCoin.url.indexOf("coinbase.com/price/") !== -1) {
      return currentCoin.url
    }
    return currentCoin && currentCoin.id ? currentCoin.id : "BTC"
  }

  function getSettingWithFallback(key, defaultVal) {
    var v = getSetting(key, undefined)
    if (v !== undefined) return v
    if (rootRef && rootRef.widgetSettings && rootRef.widgetSettings["btc_tracker"]) {
      var legacyVal = rootRef.widgetSettings["btc_tracker"][key]
      if (legacyVal !== undefined) return legacyVal
    }
    return defaultVal
  }

  function applySavedSettings() {
    var cur = getSettingWithFallback("currency", undefined)
    if (cur !== undefined && typeof cur === "string") {
      currency = cur.toUpperCase()
    }
    var fill = getSettingWithFallback("fillSparkline", undefined)
    if (fill !== undefined) {
      fillSparkline = Boolean(fill)
    }
    var range = getSettingWithFallback("showRangeBar", undefined)
    if (range !== undefined) {
      showRangeBar = Boolean(range)
    }
    var interval = getSettingWithFallback("refreshInterval", undefined)
    if (interval !== undefined && Number(interval) >= 15000) {
      refreshInterval = Number(interval)
    }
    var ac = getSettingWithFallback("autoCycle", undefined)
    if (ac !== undefined) {
      autoCycle = Boolean(ac)
    }
    var tc = getSettingWithFallback("trackedCoins", undefined)
    if (Array.isArray(tc) && tc.length > 0) {
      trackedCoins = tc
    }
    var cIdx = getSettingWithFallback("currentCoinIndex", undefined)
    if (cIdx !== undefined && Number(cIdx) >= 0 && Number(cIdx) < trackedCoins.length) {
      currentCoinIndex = Number(cIdx)
    }
  }

  onSettingsLoaded: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    fetchCrypto()
  }

  onIsAddingTrackerChanged: {
    if (rootRef && "keyboardFocusRequested" in rootRef) {
      rootRef.keyboardFocusRequested = isAddingTracker
    }
    if (isAddingTracker) {
      Qt.callLater(function() {
        if (typeof trackerInput !== "undefined" && trackerInput) {
          trackerInput.forceActiveFocus()
        }
      })
    }
  }

  onTrackingPopoutOpenChanged: {
    if (!trackingPopoutOpen) {
      isAddingTracker = false
      if (rootRef && "keyboardFocusRequested" in rootRef) {
        rootRef.keyboardFocusRequested = false
      }
    }
  }

  onContextMenuOpenChanged: {
    if (!contextMenuOpen) {
      trackingPopoutOpen = false
      isAddingTracker = false
      addInputText = ""
      if (rootRef && "keyboardFocusRequested" in rootRef) {
        rootRef.keyboardFocusRequested = false
      }
    }
  }

  function setCurrency(cur) {
    if (currency === cur) return
    currency = cur
    saveSetting("currency", cur)
    fetchCrypto()
  }

  function toggleCurrency() {
    var list = ["USD", "EUR", "GBP"]
    var idx = list.indexOf(currency)
    var next = list[(idx + 1) % list.length]
    setCurrency(next)
  }

  function setRefreshInterval(ms) {
    refreshInterval = ms
    saveSetting("refreshInterval", ms)
  }

  function toggleFillSparkline() {
    fillSparkline = !fillSparkline
    saveSetting("fillSparkline", fillSparkline)
    sparklineCanvas.requestPaint()
  }

  function toggleShowRangeBar() {
    showRangeBar = !showRangeBar
    saveSetting("showRangeBar", showRangeBar)
  }

  function toggleAutoCycle() {
    autoCycle = !autoCycle
    saveSetting("autoCycle", autoCycle)
  }

  // ---------------------------------------------------------------------------
  // 🪙 Tracked Coins List Management
  // ---------------------------------------------------------------------------
  property bool trackingPopoutOpen: false
  property bool isAddingTracker: false
  property string addInputText: ""

  function nextCoin() {
    if (!trackedCoins || trackedCoins.length <= 1) return
    currentCoinIndex = (currentCoinIndex + 1) % trackedCoins.length
    saveSetting("currentCoinIndex", currentCoinIndex)
    fetchCrypto()
  }

  function prevCoin() {
    if (!trackedCoins || trackedCoins.length <= 1) return
    currentCoinIndex = (currentCoinIndex - 1 + trackedCoins.length) % trackedCoins.length
    saveSetting("currentCoinIndex", currentCoinIndex)
    fetchCrypto()
  }

  function selectCoinIndex(idx) {
    if (idx >= 0 && idx < trackedCoins.length) {
      currentCoinIndex = idx
      saveSetting("currentCoinIndex", idx)
      fetchCrypto()
    }
  }

  function addTrackedCoin(inputStr) {
    var s = String(inputStr).trim()
    if (!s) return

    var slug = s
    var url = ""
    if (s.indexOf("coinbase.com/price/") !== -1) {
      url = s.indexOf("http") === 0 ? s : ("https://" + s)
      var p = s.split("coinbase.com/price/")[1].split("/")[0].split("?")[0].trim().toLowerCase()
      if (p) slug = p
    } else if (s.indexOf("http") === 0) {
      url = s
      slug = s.split("/").pop().split("?")[0].trim().toLowerCase()
    } else {
      slug = s.toLowerCase()
      url = "https://www.coinbase.com/price/" + slug
    }

    var sym = slug.toUpperCase()
    var name = slug.charAt(0).toUpperCase() + slug.slice(1).replace(/-/g, " ")

    // Check if already in list
    for (var i = 0; i < trackedCoins.length; i++) {
      var c = trackedCoins[i]
      if (c.id.toUpperCase() === sym || (c.slug && c.slug.toLowerCase() === slug)) {
        selectCoinIndex(i)
        isAddingTracker = false
        addInputText = ""
        return
      }
    }

    var icon = "\uf12e"
    if (slug === "bitcoin" || sym === "BTC") icon = "\uf15a"
    else if (slug === "ethereum" || sym === "ETH") icon = "\uf42e"
    else if (slug === "dogecoin" || sym === "DOGE") icon = "\uf1b0"

    var newEntry = {
      id: sym,
      name: name,
      symbol: sym,
      slug: slug,
      icon: icon,
      url: url
    }

    var list = trackedCoins.slice()
    list.push(newEntry)
    trackedCoins = list
    saveSetting("trackedCoins", list)
    currentCoinIndex = list.length - 1
    saveSetting("currentCoinIndex", currentCoinIndex)
    isAddingTracker = false
    addInputText = ""
    fetchCrypto()
  }

  function removeTrackedCoin(idx) {
    if (!trackedCoins || idx < 0 || idx >= trackedCoins.length) return
    var list = trackedCoins.slice()
    list.splice(idx, 1)
    if (list.length === 0) {
      list = [{ id: "BTC", name: "Bitcoin", symbol: "BTC", icon: "\uf15a", url: "https://www.coinbase.com/price/bitcoin" }]
    }
    trackedCoins = list
    saveSetting("trackedCoins", list)
    if (currentCoinIndex >= list.length) {
      currentCoinIndex = list.length - 1
    }
    saveSetting("currentCoinIndex", currentCoinIndex)
    fetchCrypto()
  }

  // ---------------------------------------------------------------------------
  // 📊 Live Crypto Data State
  // ---------------------------------------------------------------------------
  property string coinName: currentCoin.name || "Bitcoin"
  property string coinSymbol: currentCoin.symbol || "BTC"
  property string coinIcon: currentCoin.icon || "\uf15a"
  property string coinUrl: currentCoin.url || "https://www.coinbase.com/price/bitcoin"

  property real price: 0
  property string priceFormatted: "--"
  property string currencySymbol: "$"
  property real open24h: 0
  property real change24h: 0
  property real change24hPercent: 0
  property string changeFormatted: "--"
  property string changePctFormatted: "--"
  property bool isPositive: true
  property real high24h: 0
  property string highFormatted: "--"
  property real low24h: 0
  property string lowFormatted: "--"
  property real rangePercent: 50
  property string volumeCrypto: "--"
  property var sparkline: []
  property real sparklineMin: 0
  property real sparklineMax: 0
  property string lastUpdated: "--"
  property bool isLoading: false
  property bool isStale: false
  property string errorMessage: ""

  // Hover inspection on sparkline
  property int hoverIndex: -1
  property real hoverPrice: 0
  property string hoverTimeOffset: ""

  readonly property color bullishColor: "#10B981"
  readonly property color bearishColor: "#EF4444"
  readonly property color trendColor: isPositive ? bullishColor : bearishColor

  readonly property color coinBrandColor: {
    var s = coinSymbol.toUpperCase()
    if (s === "BTC") return "#F7931A"
    if (s === "ETH") return "#627EEA"
    if (s === "SOL") return "#14F195"
    if (s === "DOGE") return "#C2A633"
    if (s === "ADA") return "#0033AD"
    if (s === "AVAX") return "#E84142"
    if (s === "LINK") return "#375BD2"
    if (s === "XRP") return "#23292F"
    return Commons.Color.accent
  }

  readonly property string cryptoScriptPath: {
    var u = Qt.resolvedUrl("../get-crypto").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function fetchCrypto() {
    if (cryptoProc.running) return
    isLoading = true
    cryptoProc.command = [btcWidgetRoot.cryptoScriptPath, btcWidgetRoot.currentCoinParam, btcWidgetRoot.currency]
    cryptoProc.running = true
  }

  Process {
    id: cryptoProc
    command: [btcWidgetRoot.cryptoScriptPath, btcWidgetRoot.currentCoinParam, btcWidgetRoot.currency]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok") {
            btcWidgetRoot.coinName = data.coin_name || btcWidgetRoot.currentCoin.name
            btcWidgetRoot.coinSymbol = data.coin_symbol || btcWidgetRoot.currentCoin.symbol
            if (data.coin_icon) btcWidgetRoot.coinIcon = data.coin_icon
            if (data.coin_url) btcWidgetRoot.coinUrl = data.coin_url
            btcWidgetRoot.price = data.price || 0
            btcWidgetRoot.priceFormatted = data.price_formatted || "--"
            btcWidgetRoot.currencySymbol = data.currency_symbol || "$"
            btcWidgetRoot.open24h = data.open_24h || 0
            btcWidgetRoot.change24h = data.change_24h || 0
            btcWidgetRoot.change24hPercent = data.change_24h_percent || 0
            btcWidgetRoot.changeFormatted = data.change_formatted || "--"
            btcWidgetRoot.changePctFormatted = data.change_pct_formatted || "--"
            btcWidgetRoot.isPositive = data.is_positive !== undefined ? Boolean(data.is_positive) : true
            btcWidgetRoot.high24h = data.high_24h || 0
            btcWidgetRoot.highFormatted = data.high_formatted || "--"
            btcWidgetRoot.low24h = data.low_24h || 0
            btcWidgetRoot.lowFormatted = data.low_formatted || "--"
            btcWidgetRoot.rangePercent = data.range_percent !== undefined ? data.range_percent : 50
            btcWidgetRoot.volumeCrypto = data.volume_crypto || "--"
            btcWidgetRoot.sparkline = Array.isArray(data.sparkline) ? data.sparkline : []
            btcWidgetRoot.sparklineMin = data.sparkline_min || 0
            btcWidgetRoot.sparklineMax = data.sparkline_max || 0
            btcWidgetRoot.lastUpdated = data.last_updated || ""
            btcWidgetRoot.isStale = Boolean(data.is_stale)
            btcWidgetRoot.errorMessage = ""
          } else {
            btcWidgetRoot.errorMessage = data.message || "Failed to fetch crypto feed"
          }
        } catch (e) {
          console.warn("[CryptoTrackerWidget] Parse error:", e)
        }
        btcWidgetRoot.isLoading = false
        sparklineCanvas.requestPaint()
      }
    }
    onExited: {
      btcWidgetRoot.isLoading = false
      sparklineCanvas.requestPaint()
    }
  }

  // Periodic Auto-refresh Timer for active coin
  Timer {
    interval: btcWidgetRoot.refreshInterval
    running: true
    repeat: true
    onTriggered: btcWidgetRoot.fetchCrypto()
  }

  // Auto-Cycle Timer: switches coin every (refreshInterval / trackedCoins.length)
  Timer {
    id: autoCycleTimer
    interval: {
      var count = btcWidgetRoot.trackedCoins ? Math.max(1, btcWidgetRoot.trackedCoins.length) : 1
      return Math.max(4000, Math.round(btcWidgetRoot.refreshInterval / count))
    }
    running: btcWidgetRoot.autoCycle && btcWidgetRoot.trackedCoins && btcWidgetRoot.trackedCoins.length > 1
    repeat: true
    onTriggered: {
      btcWidgetRoot.nextCoin()
    }
  }

  Process {
    id: pasteProc
    command: ["wl-paste", "-n"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (str) {
          btcWidgetRoot.addInputText = str
          if (typeof trackerInput !== "undefined" && trackerInput) {
            trackerInput.text = str
            trackerInput.forceActiveFocus()
          }
        }
      }
    }
  }

  function pasteClipboard() {
    if (!pasteProc.running) {
      pasteProc.running = true
    }
  }

  // ---------------------------------------------------------------------------
  // 🎛️ Custom Context Menu (Right-click)
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 280
      spacing: Style.space(4)

      // Section: Manage Tracked Cryptos Submenu Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 6
        color: (trackTriggerMouse.containsMouse || btcWidgetRoot.trackingPopoutOpen)
          ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
          : Qt.rgba(1, 1, 1, 0.04)
        border.color: btcWidgetRoot.trackingPopoutOpen
          ? Commons.Color.accent
          : (trackTriggerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf06e" // eye icon
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Tracking (" + (btcWidgetRoot.trackedCoins ? btcWidgetRoot.trackedCoins.length : 0) + " coins)..."
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Commons.Color.foreground
          }

          Text {
            text: "\uf054" // chevron right
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
          }
        }

        MouseArea {
          id: trackTriggerMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            btcWidgetRoot.trackingPopoutOpen = !btcWidgetRoot.trackingPopoutOpen
          }
        }
      }

      // Checkbox: Auto-Cycle Tracked Coins
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 6
        color: autoCycleMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: btcWidgetRoot.autoCycle ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: btcWidgetRoot.autoCycle ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: "Auto-Cycle Tracked Coins"
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Commons.Color.foreground
            }

            Text {
              Layout.fillWidth: true
              text: {
                var count = btcWidgetRoot.trackedCoins ? Math.max(1, btcWidgetRoot.trackedCoins.length) : 1
                var sec = Math.round(btcWidgetRoot.refreshInterval / count / 1000)
                return "Switch coin every " + sec + "s (cycle / " + count + ")"
              }
              font.family: Style.font.family
              font.pixelSize: 9
              color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
            }
          }
        }

        MouseArea {
          id: autoCycleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.toggleAutoCycle()
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
        Layout.topMargin: 2
        Layout.bottomMargin: 2
      }

      // Section Title: Currency
      Text {
        text: "DISPLAY CURRENCY"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
      }

      // Currency Choice Pill Bar
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Repeater {
          model: [
            { id: "USD", symbol: "$", label: "USD ($)" },
            { id: "EUR", symbol: "€", label: "EUR (€)" },
            { id: "GBP", symbol: "£", label: "GBP (£)" }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isSelected: btcWidgetRoot.currency === modelData.id
            color: isSelected
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
              : (curMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
            border.color: isSelected
              ? Commons.Color.accent
              : (curMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isSelected ? Font.Bold : Font.Normal
              color: isSelected ? Commons.Color.accent : Commons.Color.foreground
            }

            MouseArea {
              id: curMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                btcWidgetRoot.setCurrency(modelData.id)
                btcWidgetRoot.contextMenuOpen = false
              }
            }
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
        Layout.topMargin: 2
        Layout.bottomMargin: 2
      }

      // Section Title: Refresh Frequency
      Text {
        text: "UPDATE FREQUENCY"
        font.family: Style.font.family
        font.pixelSize: 9
        font.weight: Font.Bold
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
        Layout.leftMargin: 4
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Repeater {
          model: [
            { ms: 30000, label: "30s" },
            { ms: 60000, label: "1m" },
            { ms: 300000, label: "5m" }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            readonly property bool isSelected: btcWidgetRoot.refreshInterval === modelData.ms
            color: isSelected
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
              : (freqMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
            border.color: isSelected ? Commons.Color.accent : "transparent"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: isSelected ? Font.Bold : Font.Normal
              color: isSelected ? Commons.Color.accent : Commons.Color.foreground
            }

            MouseArea {
              id: freqMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                btcWidgetRoot.setRefreshInterval(modelData.ms)
                btcWidgetRoot.contextMenuOpen = false
              }
            }
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
        Layout.topMargin: 2
        Layout.bottomMargin: 2
      }

      // Toggle Sparkline Fill Option
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: fillMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: btcWidgetRoot.fillSparkline ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: btcWidgetRoot.fillSparkline ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }

          Text {
            Layout.fillWidth: true
            text: "Sparkline Area Gradient Fill"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: fillMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.toggleFillSparkline()
        }
      }

      // Toggle Range Bar Option
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: rangeMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: btcWidgetRoot.showRangeBar ? "\uf14a" : "\uf0c8"
            font.family: Style.font.family
            font.pixelSize: 12
            color: btcWidgetRoot.showRangeBar ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
          }

          Text {
            Layout.fillWidth: true
            text: "24h High/Low Range Gauge"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: rangeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.toggleShowRangeBar()
        }
      }

      // Refresh Now Button
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf021"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Refresh " + btcWidgetRoot.coinName + " Now"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: refMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            btcWidgetRoot.contextMenuOpen = false
            btcWidgetRoot.fetchCrypto()
          }
        }
      }

      // Open in Browser
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: webMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            text: "\uf08e"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Open " + btcWidgetRoot.coinName + " on Coinbase"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Commons.Color.foreground
          }
        }

        MouseArea {
          id: webMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            btcWidgetRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-open", btcWidgetRoot.coinUrl || "https://www.coinbase.com/price/bitcoin"])
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🖧 Floating Tracked Cryptos Popout Submenu (reparented to desktop canvas)
  // ---------------------------------------------------------------------------
  Rectangle {
    id: trackingPopout
    parent: btcWidgetRoot.contextMenuCanvasParent
    z: 1015

    readonly property real popoutWidth: 290
    readonly property real headerHeight: 38
    readonly property real addSectionHeight: btcWidgetRoot.isAddingTracker ? 84 : 36
    readonly property real itemHeight: 36
    readonly property real listHeight: Math.min(240, Math.max(1, btcWidgetRoot.trackedCoins ? btcWidgetRoot.trackedCoins.length : 1) * itemHeight + 8)
    readonly property real popoutHeight: headerHeight + addSectionHeight + listHeight + 14

    x: {
      var rightX = btcWidgetRoot.contextMenuX + btcWidgetRoot.contextMenuWidth + 8
      if (rightX + popoutWidth + 10 <= btcWidgetRoot.screenWidth) {
        return rightX
      } else {
        return Math.max(10, btcWidgetRoot.contextMenuX - popoutWidth - 8)
      }
    }
    y: Math.max(10, Math.min(btcWidgetRoot.contextMenuY, btcWidgetRoot.screenHeight - popoutHeight - 10))
    width: popoutWidth
    height: popoutHeight

    radius: 14
    color: Qt.rgba(14/255, 14/255, 20/255, 0.98)
    border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
    border.width: 1.5

    opacity: (btcWidgetRoot.contextMenuOpen && btcWidgetRoot.trackingPopoutOpen) ? 1.0 : 0.0
    scale: (btcWidgetRoot.contextMenuOpen && btcWidgetRoot.trackingPopoutOpen) ? 1.0 : 0.94
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
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
      anchors.fill: parent
      anchors.margins: Style.space(8)
      spacing: Style.space(4)

      // Popout Header
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 2
        spacing: Style.space(6)

        Text {
          text: "\uf06e"
          font.family: Style.font.family
          font.pixelSize: 11
          color: Commons.Color.accent
        }

        Text {
          text: "TRACKED COINS"
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.Bold
          color: Commons.Color.foreground
        }

        Rectangle {
          width: tpCountText.implicitWidth + 8
          height: 16
          radius: 8
          color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
          Text {
            id: tpCountText
            anchors.centerIn: parent
            text: btcWidgetRoot.trackedCoins ? btcWidgetRoot.trackedCoins.length : 0
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Commons.Color.accent
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          width: 20
          height: 20
          radius: 10
          color: closePopoutMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

          Text {
            anchors.centerIn: parent
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Commons.Color.foreground
          }

          MouseArea {
            id: closePopoutMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btcWidgetRoot.trackingPopoutOpen = false
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
        Layout.bottomMargin: 2
      }

      // "Add tracker..." Section at Top of the List
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        // Add tracker trigger button (when not typing)
        Rectangle {
          visible: !btcWidgetRoot.isAddingTracker
          Layout.fillWidth: true
          height: 32
          radius: 6
          color: addTriggerMouse.containsMouse
            ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
            : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12)
          border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
          border.width: 1

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: "\uf067" // fa-plus
              font.family: Style.font.family
              font.pixelSize: 10
              color: Commons.Color.accent
            }

            Text {
              text: "Add tracker..."
              font.family: Style.font.family
              font.pixelSize: 11
              font.weight: Font.Bold
              color: Commons.Color.accent
            }
          }

          MouseArea {
            id: addTriggerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              btcWidgetRoot.isAddingTracker = true
              trackerInput.forceActiveFocus()
            }
          }
        }

        // Active text input container (when adding)
        ColumnLayout {
          visible: btcWidgetRoot.isAddingTracker
          Layout.fillWidth: true
          spacing: 4

          Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.07)
            border.color: trackerInput.activeFocus ? Commons.Color.accent : Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            MouseArea {
              anchors.fill: parent
              z: -1
              cursorShape: Qt.IBeamCursor
              onClicked: trackerInput.forceActiveFocus()
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 6
              spacing: 6

              TextInput {
                id: trackerInput
                Layout.fillWidth: true
                font.family: Style.font.family
                font.pixelSize: 11
                color: Commons.Color.foreground
                clip: true
                selectByMouse: true
                focus: true
                activeFocusOnTab: true
                text: btcWidgetRoot.addInputText
                onTextChanged: btcWidgetRoot.addInputText = text
                onAccepted: {
                  if (text.trim()) {
                    btcWidgetRoot.addTrackedCoin(text.trim())
                    text = ""
                  }
                }

                Text {
                  anchors.fill: parent
                  text: "Coinbase URL or symbol (e.g. SOL)..."
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.35)
                  visible: !trackerInput.text && !trackerInput.activeFocus
                  verticalAlignment: Text.AlignVCenter
                }
              }

              // Paste from Clipboard Button
              Rectangle {
                width: 22
                height: 20
                radius: 4
                color: pasteBtnHover.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: "\uf0ea" // clipboard paste
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: Commons.Color.accent
                }

                MouseArea {
                  id: pasteBtnHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: btcWidgetRoot.pasteClipboard()
                }
              }

              // Clear button
              Text {
                visible: trackerInput.text !== ""
                text: "\uf00d"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    trackerInput.text = ""
                    trackerInput.forceActiveFocus()
                  }
                }
              }
            }
          }

          // Action row: Add & Cancel
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
              Layout.fillWidth: true
              height: 26
              radius: 5
              color: cancelAddMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)

              Text {
                anchors.centerIn: parent
                text: "Cancel"
                font.family: Style.font.family
                font.pixelSize: 10
                color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
              }

              MouseArea {
                id: cancelAddMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  btcWidgetRoot.isAddingTracker = false
                  btcWidgetRoot.addInputText = ""
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 26
              radius: 5
              color: confirmAddMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
              border.color: Commons.Color.accent
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "Add Coin"
                font.family: Style.font.family
                font.pixelSize: 10
                font.weight: Font.Bold
                color: confirmAddMouse.containsMouse ? "#FFFFFF" : Commons.Color.accent
              }

              MouseArea {
                id: confirmAddMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (trackerInput.text.trim()) {
                    btcWidgetRoot.addTrackedCoin(trackerInput.text.trim())
                    trackerInput.text = ""
                  }
                }
              }
            }
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
        Layout.topMargin: 2
        Layout.bottomMargin: 2
      }

      // Scrollable List of Tracked Cryptos
      Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: trackingPopout.listHeight
        contentWidth: width
        contentHeight: coinListLayout.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: coinListLayout
          width: parent.width
          spacing: 2

          Repeater {
            model: btcWidgetRoot.trackedCoins

            Rectangle {
              required property var modelData
              required property int index
              Layout.fillWidth: true
              implicitHeight: 34
              radius: 6
              readonly property bool isCurrent: btcWidgetRoot.currentCoinIndex === index
              color: isCurrent
                ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
                : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
              border.color: isCurrent
                ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
                : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(8)

                // Active dot or checkmark
                Text {
                  text: isCurrent ? "\uf058" : "\uf111"
                  font.family: Style.font.family
                  font.pixelSize: 10
                  color: isCurrent ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.25)
                }

                // Coin Symbol Badge
                Rectangle {
                  width: symText.implicitWidth + 8
                  height: 18
                  radius: 4
                  color: Qt.rgba(1, 1, 1, 0.08)

                  Text {
                    id: symText
                    anchors.centerIn: parent
                    text: modelData.symbol || modelData.id
                    font.family: Style.font.family
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: isCurrent ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.8)
                  }
                }

                // Coin Name
                Text {
                  Layout.fillWidth: true
                  text: modelData.name || modelData.id
                  font.family: Style.font.family
                  font.pixelSize: 11
                  font.weight: isCurrent ? Font.Bold : Font.Normal
                  color: isCurrent ? Commons.Color.foreground : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.85)
                  elide: Text.ElideRight
                }

                // Small Remove "X" Button
                Rectangle {
                  width: 20
                  height: 20
                  radius: 10
                  color: delMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35) : "transparent"
                  border.color: delMouse.containsMouse ? Commons.Color.urgent : "transparent"
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "\uf00d" // fa-times
                    font.family: Style.font.family
                    font.pixelSize: 9
                    color: delMouse.containsMouse ? Commons.Color.urgent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
                  }

                  MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      btcWidgetRoot.removeTrackedCoin(index)
                    }
                  }
                }
              }

              MouseArea {
                id: itemMouse
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.rightMargin: 24 // Leave space for delete button
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  btcWidgetRoot.selectCoinIndex(index)
                }
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🪙 Main Widget Layout & Content
  // ---------------------------------------------------------------------------
  ColumnLayout {
    id: mainCryptoLayout
    anchors.fill: parent
    anchors.margins: Style.space(14)
    spacing: Style.space(8)

    // 1. Top Header Row: Cycle Arrows, Icon, Title, Badge, Pulse, Currency Pill & Refresh
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      // Left Cycle Arrow
      Rectangle {
        width: 22
        height: 22
        radius: 11
        visible: btcWidgetRoot.trackedCoins && btcWidgetRoot.trackedCoins.length > 1
        color: prevHover.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
        border.color: prevHover.containsMouse ? Commons.Color.accent : Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf053" // fa-chevron-left
          font.family: Style.font.family
          font.pixelSize: 8
          color: prevHover.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
        }

        MouseArea {
          id: prevHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.prevCoin()
        }
      }

      // Coin Icon Circle
      Rectangle {
        width: 24
        height: 24
        radius: 12
        color: Qt.rgba(btcWidgetRoot.coinBrandColor.r, btcWidgetRoot.coinBrandColor.g, btcWidgetRoot.coinBrandColor.b, 0.20)
        border.color: Qt.rgba(btcWidgetRoot.coinBrandColor.r, btcWidgetRoot.coinBrandColor.g, btcWidgetRoot.coinBrandColor.b, 0.50)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: btcWidgetRoot.coinIcon
          font.family: Style.font.family
          font.pixelSize: 12
          color: btcWidgetRoot.coinBrandColor
        }
      }

      // Title & Coin Tag
      RowLayout {
        spacing: Style.space(6)

        Text {
          text: btcWidgetRoot.coinName
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.Bold
          color: Commons.Color.foreground
          elide: Text.ElideRight
          Layout.maximumWidth: 130
        }

        Rectangle {
          width: coinTagText.implicitWidth + 8
          height: 16
          radius: 4
          color: Qt.rgba(1, 1, 1, 0.08)

          Text {
            id: coinTagText
            anchors.centerIn: parent
            text: btcWidgetRoot.coinSymbol
            font.family: Style.font.family
            font.pixelSize: 9
            font.weight: Font.Bold
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
          }
        }
      }

      // Right Cycle Arrow
      Rectangle {
        width: 22
        height: 22
        radius: 11
        visible: btcWidgetRoot.trackedCoins && btcWidgetRoot.trackedCoins.length > 1
        color: nextHover.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
        border.color: nextHover.containsMouse ? Commons.Color.accent : Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf054" // fa-chevron-right
          font.family: Style.font.family
          font.pixelSize: 8
          color: nextHover.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
        }

        MouseArea {
          id: nextHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.nextCoin()
        }
      }

      // Live Pulse Dot
      Rectangle {
        width: 6
        height: 6
        radius: 3
        color: btcWidgetRoot.isStale ? "#F59E0B" : btcWidgetRoot.trendColor

        SequentialAnimation on opacity {
          // Pause while hidden: a running animation keeps the whole shell repainting every vsync.
          running: btcWidgetRoot.visible
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.3; duration: 1000; easing.type: Easing.InOutQuad }
          NumberAnimation { from: 0.3; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
        }
      }

      Item { Layout.fillWidth: true }

      // Currency Switcher Pill
      Rectangle {
        width: curPillText.implicitWidth + 14
        height: 22
        radius: 11
        color: curPillHover.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
        border.width: 1

        Text {
          id: curPillText
          anchors.centerIn: parent
          text: btcWidgetRoot.currency
          font.family: Style.font.family
          font.pixelSize: 10
          font.weight: Font.Bold
          color: Commons.Color.accent
        }

        MouseArea {
          id: curPillHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.toggleCurrency()
        }
      }

      // Manual Refresh Button
      Rectangle {
        width: 22
        height: 22
        radius: 11
        color: refHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "\uf021"
          font.family: Style.font.family
          font.pixelSize: 10
          color: btcWidgetRoot.isLoading ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.75)

          RotationAnimation on rotation {
            running: btcWidgetRoot.isLoading
            from: 0
            to: 360
            loops: Animation.Infinite
            duration: 850
          }
        }

        MouseArea {
          id: refHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: btcWidgetRoot.fetchCrypto()
        }
      }

      // Remove / Close Button (when in edit mode)
      Rectangle {
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: closeCoinMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: closeCoinMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (rootRef && rootRef.toggleWidgetEnabled) {
              rootRef.toggleWidgetEnabled(btcWidgetRoot.widgetId, false, btcWidgetRoot.monitorName)
            }
          }
        }
      }

      // Move Grip Button (when in edit mode)
      Rectangle {
        id: coinGripButton
        visible: rootRef && rootRef.layoutEditMode
        width: 22
        height: 22
        radius: 11
        color: coinGripArea.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
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
          id: coinGripArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeAllCursor
          drag.target: btcWidgetRoot.targetItem
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 10
          drag.maximumX: Math.max(10, btcWidgetRoot.screenWidth - btcWidgetRoot.width - 10)
          drag.minimumY: 10
          drag.maximumY: Math.max(10, btcWidgetRoot.screenHeight - btcWidgetRoot.height - 10)

          onPressed: btcWidgetRoot.customGripDragging = true
          onReleased: function() {
            btcWidgetRoot.customGripDragging = false
            var maxX = Math.max(10, btcWidgetRoot.screenWidth - btcWidgetRoot.width - 10)
            var maxY = Math.max(10, btcWidgetRoot.screenHeight - btcWidgetRoot.height - 10)
            var snappedX = btcWidgetRoot.snapVal(btcWidgetRoot.targetItem.x)
            var snappedY = btcWidgetRoot.snapVal(btcWidgetRoot.targetItem.y)
            snappedX = Math.max(10, Math.min(maxX, snappedX))
            snappedY = Math.max(10, Math.min(maxY, snappedY))
            btcWidgetRoot.targetItem.x = snappedX
            btcWidgetRoot.targetItem.y = snappedY
            if (rootRef && rootRef.saveWidgetPos) {
              rootRef.saveWidgetPos(btcWidgetRoot.widgetId, snappedX, snappedY, btcWidgetRoot.snapVal(btcWidgetRoot.width), btcWidgetRoot.snapVal(btcWidgetRoot.height), btcWidgetRoot.monitorName)
            }
          }
          onCanceled: btcWidgetRoot.customGripDragging = false
        }
      }
    }

    // 2. Hero Section: Big Price + 24h Change Pill
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      // Big Price Text
      Text {
        text: btcWidgetRoot.priceFormatted
        font.family: Style.font.family
        font.pixelSize: btcWidgetRoot.width < 320 ? 22 : 26
        font.weight: Font.Bold
        color: Commons.Color.foreground
      }

      Item { Layout.fillWidth: true }

      // 24h Change Badge Pill
      Rectangle {
        implicitWidth: changeRow.implicitWidth + Style.space(12)
        implicitHeight: 24
        radius: 6
        color: Qt.rgba(btcWidgetRoot.trendColor.r, btcWidgetRoot.trendColor.g, btcWidgetRoot.trendColor.b, 0.15)
        border.color: Qt.rgba(btcWidgetRoot.trendColor.r, btcWidgetRoot.trendColor.g, btcWidgetRoot.trendColor.b, 0.35)
        border.width: 1

        RowLayout {
          id: changeRow
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: btcWidgetRoot.isPositive ? "\uf0d8" : "\uf0d7"
            font.family: Style.font.family
            font.pixelSize: 10
            color: btcWidgetRoot.trendColor
          }

          Text {
            text: btcWidgetRoot.changePctFormatted
            font.family: Style.font.family
            font.pixelSize: 11
            font.weight: Font.Bold
            color: btcWidgetRoot.trendColor
          }
        }
      }
    }

    // 3. Interactive 24-Hour Sparkline Chart Card
    Rectangle {
      id: chartCard
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 65
      radius: 10
      color: Qt.rgba(1, 1, 1, 0.03)
      border.color: Qt.rgba(1, 1, 1, 0.07)
      border.width: 1
      clip: true

      // High / Low background markers
      RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        z: 2
        visible: !sparklineMouse.containsMouse && btcWidgetRoot.sparkline.length > 1

        Text {
          text: "24h High: " + btcWidgetRoot.highFormatted
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "24h Low: " + btcWidgetRoot.lowFormatted
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.4)
        }
      }

      // Sparkline Canvas
      Canvas {
        id: sparklineCanvas
        anchors.fill: parent
        anchors.margins: 4

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
          target: btcWidgetRoot
          function onSparklineChanged() { sparklineCanvas.requestPaint() }
          function onIsPositiveChanged() { sparklineCanvas.requestPaint() }
          function onFillSparklineChanged() { sparklineCanvas.requestPaint() }
        }

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var w = width
          var h = height
          if (w <= 0 || h <= 0) return

          var arr = btcWidgetRoot.sparkline
          var count = arr.length
          if (count < 2) return

          var minVal = arr[0]
          var maxVal = arr[0]
          for (var i = 0; i < count; i++) {
            if (arr[i] < minVal) minVal = arr[i]
            if (arr[i] > maxVal) maxVal = arr[i]
          }

          var span = maxVal - minVal
          if (span <= 0) span = 1

          var padTop = 16
          var padBottom = 12
          var usableH = Math.max(10, h - padTop - padBottom)
          var stepX = w / (count - 1)

          // 1. Subtle baseline grid line
          ctx.strokeStyle = "rgba(255, 255, 255, 0.05)"
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(0, h * 0.5)
          ctx.lineTo(w, h * 0.5)
          ctx.stroke()

          // Compute points
          var pts = []
          for (var idx = 0; idx < count; idx++) {
            var px = idx * stepX
            var py = padTop + (1.0 - (arr[idx] - minVal) / span) * usableH
            pts.push({ x: px, y: py })
          }

          // 2. Area Gradient Fill
          if (btcWidgetRoot.fillSparkline) {
            ctx.save()
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (var f = 1; f < count; f++) {
              ctx.lineTo(pts[f].x, pts[f].y)
            }
            ctx.lineTo(w, h)
            ctx.lineTo(0, h)
            ctx.closePath()

            var grad = ctx.createLinearGradient(0, padTop, 0, h)
            var gradColor = btcWidgetRoot.isPositive ? "16, 185, 129" : "239, 68, 68"
            grad.addColorStop(0.0, "rgba(" + gradColor + ", 0.28)")
            grad.addColorStop(0.8, "rgba(" + gradColor + ", 0.05)")
            grad.addColorStop(1.0, "rgba(" + gradColor + ", 0.00)")
            ctx.fillStyle = grad
            ctx.fill()
            ctx.restore()
          }

          // 3. Line Stroke
          ctx.save()
          ctx.beginPath()
          ctx.moveTo(pts[0].x, pts[0].y)
          for (var s = 1; s < count; s++) {
            var xc = (pts[s - 1].x + pts[s].x) / 2
            var yc = (pts[s - 1].y + pts[s].y) / 2
            ctx.quadraticCurveTo(pts[s - 1].x, pts[s - 1].y, xc, yc)
          }
          ctx.lineTo(pts[count - 1].x, pts[count - 1].y)

          ctx.strokeStyle = btcWidgetRoot.isPositive ? "#10B981" : "#EF4444"
          ctx.lineWidth = 2
          ctx.lineCap = "round"
          ctx.lineJoin = "round"
          ctx.stroke()
          ctx.restore()

          // 4. Draw Last Point Glowing Circle
          var lastPt = pts[count - 1]
          ctx.save()
          ctx.beginPath()
          ctx.arc(lastPt.x - 2, lastPt.y, 4, 0, Math.PI * 2)
          ctx.fillStyle = btcWidgetRoot.isPositive ? "#10B981" : "#EF4444"
          ctx.fill()
          ctx.beginPath()
          ctx.arc(lastPt.x - 2, lastPt.y, 7, 0, Math.PI * 2)
          ctx.strokeStyle = btcWidgetRoot.isPositive ? "rgba(16, 185, 129, 0.4)" : "rgba(239, 68, 68, 0.4)"
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.restore()
        }
      }

      // Interactive Hover Crosshair & Tooltip
      MouseArea {
        id: sparklineMouse
        anchors.fill: parent
        hoverEnabled: true

        onPositionChanged: function(mouse) {
          var count = btcWidgetRoot.sparkline.length
          if (count < 2) return
          var stepX = width / (count - 1)
          var idx = Math.round(mouse.x / stepX)
          idx = Math.max(0, Math.min(count - 1, idx))
          btcWidgetRoot.hoverIndex = idx
          btcWidgetRoot.hoverPrice = btcWidgetRoot.sparkline[idx]

          var hoursAgo = count - 1 - idx
          btcWidgetRoot.hoverTimeOffset = hoursAgo === 0 ? "Now" : ("-" + hoursAgo + "h")
        }

        onExited: {
          btcWidgetRoot.hoverIndex = -1
        }
      }

      // Hover Tooltip Badge
      Rectangle {
        id: hoverBadge
        visible: btcWidgetRoot.hoverIndex >= 0 && btcWidgetRoot.sparkline.length > 1
        z: 10
        width: hoverBadgeLayout.implicitWidth + 12
        height: 22
        radius: 6
        color: Qt.rgba(14/255, 14/255, 20/255, 0.95)
        border.color: btcWidgetRoot.trendColor
        border.width: 1

        readonly property real stepX: (parent.width - 8) / Math.max(1, btcWidgetRoot.sparkline.length - 1)
        readonly property real targetX: 4 + btcWidgetRoot.hoverIndex * stepX
        x: Math.max(6, Math.min(parent.width - width - 6, targetX - width / 2))
        y: 6

        RowLayout {
          id: hoverBadgeLayout
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: btcWidgetRoot.hoverTimeOffset
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.6)
          }

          Text {
            text: btcWidgetRoot.currencySymbol + Number(btcWidgetRoot.hoverPrice).toLocaleString(Qt.locale(), 'f', btcWidgetRoot.price < 1 ? 4 : 2)
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Commons.Color.foreground
          }
        }
      }
    }

    // 4. 24h High/Low Range Gauge
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3
      visible: btcWidgetRoot.showRangeBar

      RowLayout {
        Layout.fillWidth: true

        Text {
          text: "24h Range"
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.DemiBold
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
        }

        Item { Layout.fillWidth: true }

        Text {
          text: btcWidgetRoot.lowFormatted + " — " + btcWidgetRoot.highFormatted
          font.family: Style.font.family
          font.pixelSize: 9
          font.weight: Font.Bold
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.7)
        }
      }

      // Range Bar Track
      Rectangle {
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.08)

        // Filled Portion
        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Math.max(4, parent.width * (btcWidgetRoot.rangePercent / 100.0))
          radius: 2
          color: btcWidgetRoot.trendColor

          Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
          }
        }

        // Current Price Pin Indicator
        Rectangle {
          width: 8
          height: 8
          radius: 4
          anchors.verticalCenter: parent.verticalCenter
          x: Math.max(0, Math.min(parent.width - 8, parent.width * (btcWidgetRoot.rangePercent / 100.0) - 4))
          color: "#FFFFFF"
          border.color: btcWidgetRoot.trendColor
          border.width: 1.5

          Behavior on x {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
          }
        }
      }
    }

    // 5. Bottom Metrics Bar: Volume, 24h Delta, Updated Time
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      // 24h Volume Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: "\uf080"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Commons.Color.accent
          }

          Text {
            text: "Vol: " + btcWidgetRoot.volumeCrypto
            font.family: Style.font.family
            font.pixelSize: 10
            color: Commons.Color.foreground
            elide: Text.ElideRight
          }
        }
      }

      // 24h Change Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: "\uf201"
            font.family: Style.font.family
            font.pixelSize: 9
            color: btcWidgetRoot.trendColor
          }

          Text {
            text: (btcWidgetRoot.isPositive ? "+" : "") + btcWidgetRoot.currencySymbol + Math.abs(btcWidgetRoot.change24h).toLocaleString(Qt.locale(), 'f', btcWidgetRoot.price < 1 ? 4 : 0)
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: btcWidgetRoot.trendColor
          }
        }
      }

      // Last Updated Pill
      Rectangle {
        implicitWidth: updatedText.implicitWidth + 10
        implicitHeight: 24
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        Text {
          id: updatedText
          anchors.centerIn: parent
          text: btcWidgetRoot.lastUpdated ? btcWidgetRoot.lastUpdated : "--"
          font.family: Style.font.family
          font.pixelSize: 9
          color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.5)
        }
      }
    }
  }
}
