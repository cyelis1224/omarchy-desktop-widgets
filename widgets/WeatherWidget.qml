import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetCard {
  id: weatherWidgetRoot

  widgetId: "weather"
  title: "Weather"
  icon: "\uf185"
  showHeader: false

  defaultX: 400
  defaultY: 140

  width: 340
  height: 250
  minWidth: 280
  minHeight: 190
  maxWidth: 550
  maxHeight: 400

  // 🌡️ Preference settings
  property bool useCelsius: false

  function applySavedSettings() {
    var c = getSetting("useCelsius", undefined)
    if (c !== undefined) {
      useCelsius = Boolean(c)
    }
  }

  onSettingsLoaded: applySavedSettings()
  Component.onCompleted: {
    applySavedSettings()
    fetchWeather()
  }

  function toggleUnits() {
    useCelsius = !useCelsius
    saveSetting("useCelsius", useCelsius)
  }

  // 🛰️ Data properties
  property string locationName: "Weather"
  property string tempF: "--"
  property string tempC: "--"
  property string feelsLikeF: "--"
  property string feelsLikeC: "--"
  property string humidity: "--"
  property string windF: "--"
  property string windC: "--"
  property string conditionDesc: "Loading..."
  property string weatherIcon: "\uf0c2"
  property bool isNight: false
  property var forecastList: []
  property bool isLoading: false

  readonly property string weatherScriptPath: {
    var u = Qt.resolvedUrl("../get-weather.sh").toString()
    return decodeURIComponent(u.replace(/^file:\/\//, ""))
  }

  function fetchWeather() {
    if (weatherProc.running) return
    isLoading = true
    weatherProc.running = true
  }

  Process {
    id: weatherProc
    command: [weatherWidgetRoot.weatherScriptPath]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str) return
        try {
          var data = JSON.parse(str)
          if (data.status === "ok") {
            weatherWidgetRoot.locationName = data.location || "Local Weather"
            weatherWidgetRoot.tempF = data.temp || "--"
            weatherWidgetRoot.tempC = data.tempC || "--"
            weatherWidgetRoot.feelsLikeF = data.feelsLike || "--"
            weatherWidgetRoot.feelsLikeC = data.feelsLikeC || "--"
            weatherWidgetRoot.humidity = data.humidity || "--"
            weatherWidgetRoot.windF = data.wind || "--"
            weatherWidgetRoot.windC = data.windKmph || "--"
            weatherWidgetRoot.conditionDesc = data.desc || "Clear"
            weatherWidgetRoot.weatherIcon = data.icon || "\uf0c2"
            weatherWidgetRoot.isNight = Boolean(data.isNight)
            weatherWidgetRoot.forecastList = Array.isArray(data.forecast) ? data.forecast : []
          }
        } catch (e) {
          console.warn("[WeatherWidget] Parse error:", e)
        }
        weatherWidgetRoot.isLoading = false
      }
    }
    onExited: {
      weatherWidgetRoot.isLoading = false
    }
  }

  // Auto-refresh every 15 minutes
  Timer {
    interval: 900000 // 15 min
    running: true
    repeat: true
    onTriggered: weatherWidgetRoot.fetchWeather()
  }

  // Dynamic icon color based on conditions
  readonly property color conditionColor: {
    var d = conditionDesc.toLowerCase()
    if (d.indexOf("sun") !== -1 || d.indexOf("clear") !== -1) return "#F59E0B"
    if (d.indexOf("rain") !== -1 || d.indexOf("drizzle") !== -1 || d.indexOf("shower") !== -1) return "#60A5FA"
    if (d.indexOf("snow") !== -1 || d.indexOf("ice") !== -1 || d.indexOf("blizzard") !== -1) return "#E0F2FE"
    if (d.indexOf("thunder") !== -1 || d.indexOf("storm") !== -1) return "#A78BFA"
    if (d.indexOf("fog") !== -1 || d.indexOf("mist") !== -1) return "#94A3B8"
    return "#CBD5E1"
  }

  // ---------------------------------------------------------------------------
  // 🎛️ Custom Context Menu Items
  // ---------------------------------------------------------------------------
  customMenuContent: Component {
    ColumnLayout {
      width: parent ? parent.width : 280
      spacing: Style.space(4)

      // Unit switch option
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: unitOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf2c9"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: weatherWidgetRoot.useCelsius ? "Switch to Fahrenheit (°F)" : "Switch to Celsius (°C)"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: unitOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            weatherWidgetRoot.contextMenuOpen = false
            weatherWidgetRoot.toggleUnits()
          }
        }
      }

      // Refresh option
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: refreshOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)

          Text {
            text: "\uf021"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.accent
          }

          Text {
            Layout.fillWidth: true
            text: "Refresh Weather Now"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: refreshOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            weatherWidgetRoot.contextMenuOpen = false
            weatherWidgetRoot.fetchWeather()
          }
        }
      }

      // Open wttr.in in browser
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: browserOptMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : "transparent"

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
            text: "Open Full Forecast in Browser"
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }

        MouseArea {
          id: browserOptMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            weatherWidgetRoot.contextMenuOpen = false
            Quickshell.execDetached(["xdg-open", "https://wttr.in"])
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ☀️ Main Widget Content
  // ---------------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    spacing: Style.space(10)

    // Top Header: Location + Refresh + Units Pill
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "\uf3c5"
        font.family: Style.font.family
        font.pixelSize: 13
        color: Color.accent
      }

      Text {
        Layout.fillWidth: true
        text: weatherWidgetRoot.locationName
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Color.foreground
        elide: Text.ElideRight
      }

      // Refresh Button
      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: refreshHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Text {
          id: refreshGlyph
          anchors.centerIn: parent
          text: "\uf021"
          font.family: Style.font.family
          font.pixelSize: 11
          color: weatherWidgetRoot.isLoading ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.7)

          RotationAnimation on rotation {
            running: weatherWidgetRoot.isLoading
            from: 0
            to: 360
            loops: Animation.Infinite
            duration: 900
          }
        }

        MouseArea {
          id: refreshHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: weatherWidgetRoot.fetchWeather()
        }
      }

      // Unit Toggle Pill (°F / °C)
      Rectangle {
        width: 48
        height: 24
        radius: 12
        color: unitHover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 2

          Text {
            text: "°F"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: !weatherWidgetRoot.useCelsius ? Font.Bold : Font.Normal
            color: !weatherWidgetRoot.useCelsius ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }

          Text {
            text: "/"
            font.family: Style.font.family
            font.pixelSize: 9
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
          }

          Text {
            text: "°C"
            font.family: Style.font.family
            font.pixelSize: 10
            font.weight: weatherWidgetRoot.useCelsius ? Font.Bold : Font.Normal
            color: weatherWidgetRoot.useCelsius ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.4)
          }
        }

        MouseArea {
          id: unitHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: weatherWidgetRoot.toggleUnits()
        }
      }
    }

    // Hero Section: Big Icon + Temperature & Condition
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(16)

      // Large Weather Glyph
      Item {
        Layout.preferredWidth: 54
        Layout.preferredHeight: 54

        Text {
          anchors.centerIn: parent
          text: weatherWidgetRoot.weatherIcon
          font.family: Style.font.family
          font.pixelSize: 38
          color: weatherWidgetRoot.conditionColor

          Behavior on color {
            ColorAnimation { duration: 300 }
          }
        }
      }

      // Temperature & Condition text
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Item {
          implicitWidth: tempText.implicitWidth
          implicitHeight: tempText.implicitHeight

          Text {
            id: tempText
            anchors.fill: parent
            text: weatherWidgetRoot.useCelsius ? weatherWidgetRoot.tempC : weatherWidgetRoot.tempF
            font.family: Style.font.family
            font.pixelSize: 30
            font.weight: Font.Bold
            color: Color.foreground
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: weatherWidgetRoot.toggleUnits()
          }
        }

        Text {
          Layout.fillWidth: true
          text: weatherWidgetRoot.conditionDesc
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.DemiBold
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.9)
          elide: Text.ElideRight
        }
      }
    }

    // Metrics Bar: Feels Like / Humidity / Wind
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      // Feels like
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "\uf2c9"
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.accent
          }
          Text {
            text: weatherWidgetRoot.useCelsius ? weatherWidgetRoot.feelsLikeC : weatherWidgetRoot.feelsLikeF
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
      }

      // Humidity
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "\uf043"
            font.family: Style.font.family
            font.pixelSize: 10
            color: "#60A5FA"
          }
          Text {
            text: weatherWidgetRoot.humidity
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
      }

      // Wind
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "\uf72e"
            font.family: Style.font.family
            font.pixelSize: 10
            color: "#94A3B8"
          }
          Text {
            text: weatherWidgetRoot.useCelsius ? weatherWidgetRoot.windC : weatherWidgetRoot.windF
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.foreground
          }
        }
      }
    }

    // 3-Day Forecast Strip
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(6)
      visible: weatherWidgetRoot.forecastList && weatherWidgetRoot.forecastList.length > 0

      Repeater {
        model: weatherWidgetRoot.forecastList

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 10
          color: Qt.rgba(1, 1, 1, 0.04)
          border.color: Qt.rgba(1, 1, 1, 0.06)
          border.width: 1

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(4)
            spacing: 2

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: modelData.day || "--"
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.DemiBold
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.6)
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: modelData.icon || "\uf0c2"
              font.family: Style.font.family
              font.pixelSize: 14
              color: Color.accent
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: weatherWidgetRoot.useCelsius ? (modelData.maxC + "/" + modelData.minC) : (modelData.maxF + "/" + modelData.minF)
              font.family: Style.font.family
              font.pixelSize: 10
              font.weight: Font.DemiBold
              color: Color.foreground
            }
          }
        }
      }
    }
  }
}
