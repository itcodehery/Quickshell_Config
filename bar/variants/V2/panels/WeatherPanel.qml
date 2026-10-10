import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: wxPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-weather"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string location: ""
    property string humidity: ""
    property string wind: ""
    property var    forecastDays: []
    property bool   refreshing: false

    function refresh() {
        if (wxData.running) return
        refreshing = true
        wxData.running = true
    }

    function tConv(c) {
        var n = parseFloat(c); if (isNaN(n)) return c
        return root.weatherImperial ? String(Math.round(n * 9 / 5 + 32)) : String(Math.round(n))
    }
    function wConv(kmh) {
        var n = parseFloat(kmh); if (isNaN(n)) return kmh
        return root.weatherImperial ? (Math.round(n * 0.621371) + " mph") : (kmh + " km/h")
    }
    function glyphForCode(code) {
        var n = parseInt(code) || 0
        if (n === 113) return "light_mode"
        if (n === 116) return "partly_cloudy_day"
        if (n === 119 || n === 122) return "cloud"
        if (n === 143 || n === 248 || n === 260) return "foggy"
        if (n === 176 || n === 263 || n === 266 || n === 293 || n === 296 || n === 353) return "rainy"
        if (n === 179 || n === 227 || n === 230 || n === 323 || n === 326 || n === 368) return "ac_unit"
        if (n === 182 || n === 185 || n === 281 || n === 284 || n === 311 || n === 314 || n === 317 || n === 320 || n === 350 || n === 362 || n === 365 || n === 374 || n === 377) return "weather_mix"
        if (n === 200 || n === 386 || n === 389 || n === 392 || n === 395) return "thunderstorm"
        if (n === 299 || n === 302 || n === 305 || n === 308 || n === 356 || n === 359) return "water_drop"
        if (n === 329 || n === 332 || n === 335 || n === 338 || n === 371) return "snowing"
        return "cloud"
    }
    function dayLabel(dateStr, index) {
        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        var d = new Date(dateStr + "T00:00:00")
        if (isNaN(d.getTime())) return dateStr
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()]
    }
    function dayRange(day) {
        var unit = root.weatherImperial ? "°F" : "°C"
        return tConv(day.min) + "°/" + tConv(day.max) + unit
    }
    function chanceOfRain(day) {
        var hourly = day && day.hourly ? day.hourly : []
        var maxRain = 0
        for (var i = 0; i < hourly.length; i++) {
            var rain = parseFloat(hourly[i].chanceofrain)
            if (!isNaN(rain) && rain > maxRain) maxRain = rain
        }
        return maxRain
    }
    function forecastCode(day) {
        var hourly = day && day.hourly ? day.hourly : []
        var noon = hourly.length > 4 ? hourly[4] : (hourly.length > 0 ? hourly[0] : null)
        return noon ? (noon.weatherCode || "") : ""
    }
    function parseReport(raw) {
        var d = JSON.parse(raw)
        var current = d.current_condition && d.current_condition[0] ? d.current_condition[0] : null
        var area = d.nearest_area && d.nearest_area[0] ? d.nearest_area[0] : null
        if (!current) return false

        wxPanel.temp = current.temp_C || ""
        wxPanel.feels = current.FeelsLikeC || ""
        wxPanel.desc = current.weatherDesc && current.weatherDesc[0] ? current.weatherDesc[0].value || "" : ""
        wxPanel.humidity = current.humidity || ""
        wxPanel.wind = current.windspeedKmph || ""
        wxPanel.location = area && area.areaName && area.areaName[0] ? area.areaName[0].value || "" : ""

        var days = []
        var reportDays = d.weather || []
        for (var i = 0; i < reportDays.length && i < 3; i++) {
            var day = reportDays[i]
            days.push({
                date: day.date || "",
                min: day.mintempC || "",
                max: day.maxtempC || "",
                code: forecastCode(day),
                desc: "",
                rain: chanceOfRain(day)
            })
        }
        wxPanel.forecastDays = days
        return true
    }

    property real reveal: root.weatherVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.weatherVisible ? 160 : 120
            easing.type: root.weatherVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.weatherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.weatherVisible = false }

    // ── Android-shade surface tokens ──────────────────────────────────────────
    readonly property int   cardRadius: 18
    readonly property int   cardPad: 12
    readonly property color cardBg:    root.fillIdle
    readonly property color chipBg:    Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
    readonly property color chipHover: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)

    // ── rounded section card ──
    component Card: Rectangle {
        id: _card
        default property alias content: _cardBody.data
        property string title: ""
        property string trailing: ""
        width: parent ? parent.width : 0
        implicitHeight: _cardHead.height + (_cardHead.visible ? 8 : 0) + _cardBody.implicitHeight + wxPanel.cardPad * 2
        height: implicitHeight
        radius: wxPanel.cardRadius
        color: wxPanel.cardBg

        Item {
            id: _cardHead
            visible: _card.title !== ""
            x: wxPanel.cardPad + 2
            y: wxPanel.cardPad
            width: _card.width - wxPanel.cardPad * 2 - 4
            height: visible ? 16 : 0
            UiText {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: _card.title
                color: root.sumiHi; font.family: root.barFont
                font.pixelSize: 11; font.weight: Font.Medium
            }
            UiText {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: _card.trailing
                visible: text !== ""
                color: root.sumi; font.family: root.barFont; font.pixelSize: 10
            }
        }
        Column {
            id: _cardBody
            x: wxPanel.cardPad
            y: wxPanel.cardPad + _cardHead.height + (_cardHead.visible ? 8 : 0)
            width: _card.width - wxPanel.cardPad * 2
            spacing: 6
        }
    }

    // ── system spec tile: tinted icon squircle + vendor chip, label, short value ──
    component InfoTile: Rectangle {
        id: _it
        property string icon
        property string label
        property string value
        property string chip: ""
        height: 88
        radius: 16
        color: wxPanel.chipBg

        Rectangle {
            id: _itIcon
            x: 10; y: 10
            width: 30; height: 30; radius: 11
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, root.fillActiveAlpha)
            IconText {
                anchors.centerIn: parent
                text: _it.icon
                color: root.seal
                font.pixelSize: 17
            }
        }
        Rectangle {
            visible: _it.chip !== ""
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: _itIcon.verticalCenter
            width: Math.min(_itChip.implicitWidth + 14, _it.width - _itIcon.width - 30)
            height: 20; radius: 10
            color: wxPanel.chipBg
            UiText {
                id: _itChip
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 14)
                elide: Text.ElideRight
                text: _it.chip
                color: root.sumiHi; font.family: root.barFont
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 0.3
            }
        }
        Column {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.bottom: parent.bottom; anchors.bottomMargin: 11
            spacing: 1
            UiText {
                text: _it.label
                color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10
            }
            UiText {
                width: parent.width
                text: _it.value !== "" ? _it.value : "—"
                elide: Text.ElideRight
                color: root.ink; font.family: root.barFont
                font.pixelSize: 13; font.weight: Font.DemiBold
            }
        }
    }

    // ── tile for list of forecast ──
    component ForecastTile: Rectangle {
        id: _ft
        property string icon
        property string dayLabel
        property string range
        property string rain
        height: 48
        radius: 16
        color: wxPanel.chipBg

        Row {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            IconText {
                anchors.verticalCenter: parent.verticalCenter
                text: _ft.icon
                color: root.seal
                font.pixelSize: 19
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _ft.dayLabel
                color: root.ink; font.family: root.barFont; font.pixelSize: 12
                width: 70
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _ft.range
                color: root.sumiHi; font.family: root.barFont; font.pixelSize: 11
            }
            Item {
                width: Math.max(0, parent.width - 19 - 12 - 70 - 12 - implicitWidth - 40)
                height: 1
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _ft.rain !== "" ? _ft.rain + "%" : ""
                color: root.seal; font.family: root.barFont; font.pixelSize: 11
                visible: _ft.rain !== "" && _ft.rain !== "0"
            }
        }
    }

    Rectangle {
        id: cardMain
        width: 396
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: wxPanel.root
            ownerActive: wxPanel.root.weatherVisible
            targetX: wxPanel.root.weatherBarX
            reveal: wxPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.weatherBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - wxPanel.reveal)
            : (barBottom + gap) - 2 * (1 - wxPanel.reveal)
        opacity: wxPanel.reveal
        focus: root.weatherVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.weatherVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header: ──
            Item {
                width: parent.width
                height: 44

                Rectangle {
                    id: logoChip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 15
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, root.fillActiveAlpha)
                    IconText {
                        anchors.centerIn: parent
                        text: wxPanel.refreshing ? "sync" : "cloud"
                        color: root.seal
                        font.pixelSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: wxPanel.refresh()
                    }
                }
                Column {
                    anchors.left: logoChip.right; anchors.leftMargin: 10
                    anchors.right: closeBtn.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    UiText {
                        width: parent.width
                        text: "Weather"
                        elide: Text.ElideRight
                        color: root.ink; font.family: root.barFont
                        font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    UiText {
                        width: parent.width
                        text: wxPanel.location !== "" ? wxPanel.location : "—"
                        elide: Text.ElideRight
                        color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10
                    }
                }
                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15
                    color: closeMa.containsMouse ? wxPanel.chipHover : wxPanel.cardBg
                    Behavior on color { ColorAnimation { duration: 120 } }
                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        color: closeMa.containsMouse ? root.seal : root.ink
                        font.pixelSize: 16
                    }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.weatherVisible = false }
                }
            }

            // ── Weather info grid ──
            Card {
                Grid {
                    id: specGrid
                    width: parent.width
                    columns: 2
                    spacing: 6
                    readonly property real tileW: root.evenW((width - spacing) / 2)
                    InfoTile { width: specGrid.tileW; icon: "device_thermostat"; label: "Temperature"; value: wxPanel.temp !== "" ? wxPanel.tConv(wxPanel.temp) + "°" + (root.weatherImperial ? "F" : "C") : "—"; chip: wxPanel.desc }
                    InfoTile { width: specGrid.tileW; icon: "water_drop"; label: "Humidity"; value: wxPanel.humidity !== "" ? wxPanel.humidity + "%" : "—" }
                    InfoTile { width: specGrid.tileW; icon: "air"; label: "Wind"; value: wxPanel.wind !== "" ? wxPanel.wConv(wxPanel.wind) : "—" }
                    InfoTile { width: specGrid.tileW; icon: "explore"; label: "Feels like"; value: wxPanel.feels !== "" ? wxPanel.tConv(wxPanel.feels) + "°" + (root.weatherImperial ? "F" : "C") : "—" }
                }
            }

            // ── 3-DAY FORECAST ──
            Card {
                title: "3-Day Forecast"
                visible: wxPanel.forecastDays.length > 0
                Column {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: wxPanel.forecastDays
                        delegate: ForecastTile {
                            width: parent.width
                            required property var modelData
                            required property int index
                            dayLabel: wxPanel.dayLabel(modelData.date || "", index)
                            icon: wxPanel.glyphForCode(modelData.code)
                            range: wxPanel.dayRange(modelData)
                            rain: modelData.rain !== undefined ? Math.round(modelData.rain) : ""
                        }
                    }
                }
            }
        }
    }

    Process {
        id: wxData
        command: ["curl", "-fs", "--max-time", "5", "https://wttr.in?format=j1"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var txt = String(this.text || "").trim()
                if (txt === "") return
                try {
                    wxPanel.parseReport(txt)
                } catch (e) {
                    // Keep the last valid panel data on transient weather failures.
                }
            }
        }
        onExited: wxPanel.refreshing = false
    }

    onVisibleChanged: { if (visible && wxPanel.temp === "") wxPanel.refresh() }
}
