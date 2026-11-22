import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import "../../modules"
import "../../motion"

// --- CIRCULAR WATCH CHRONOMETER FACE (Omarchy theme-aware, cardless) ---
Item {
    id: timeDateWidget
    required property var dashboardContent
    required property var root
    required property var mprisSel
    required property var biggerFont

    readonly property bool isClockVisible: true
    readonly property bool isMediaPlaying: Boolean(dashboardContent && dashboardContent.isMediaPlaying)

    // Jarvis M3 boot-up progress drivers (1.0 = settled)
    property real pillProgress: 1.0
    property real pillTextProgress: 1.0
    property real dateProgress: 1.0
    property real dayPctProgress: 1.0
    property real ticksProgress: 1.0

    property var vizLevels: []
    readonly property int vizBars: 60

    Component.onCompleted: {
        var init = []
        for (var i = 0; i < vizBars; i++) init.push(0.0)
        vizLevels = init
    }

    Process {
        id: clockCavaProc
        running: timeDateWidget.visible && Boolean(root && root.dashboardExpanded) && timeDateWidget.isMediaPlaying
        command: ["bash", "-c",
            "command -v cava >/dev/null 2>&1 || exit 0; " +
            "exec cava -p <(printf '%s\\n' " +
            "'[general]' 'bars = 60' 'framerate = 60' 'autosens = 1' 'sleep_timer = 0' " +
            "'[input]' 'method = pipewire' 'source = auto' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'[smoothing]' 'monstercat = 1' 'waves = 0' 'noise_reduction = 25')"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!timeDateWidget.isMediaPlaying) return
                var parts = line.split(";")
                var out = []
                for (var i = 0; i < timeDateWidget.vizBars; i++) {
                    var val = parseInt(parts[i])
                    out.push(isNaN(val) ? 0.0 : Math.min(1.0, val / 100.0))
                }
                timeDateWidget.vizLevels = out
            }
        }
    }

    opacity: 1.0
    scale: 1.0
    visible: true
    z: 5

    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#a3e635"
    readonly property color color01Col: (root && root.color01) ? root.color01 : "#f59e0b"
    readonly property color color03Col: (root && root.color03) ? root.color03 : "#10b981"
    readonly property color borderCol: (root && root.cardBorderColor) ? root.cardBorderColor : Qt.rgba(1, 1, 1, 0.14)
    readonly property bool isLight: (root && root.isLightMode) ? true : false

    property date currentTime: new Date()
    Timer {
        interval: 1000
        running: timeDateWidget.visible && root && root.dashboardExpanded
        repeat: true
        onTriggered: timeDateWidget.currentTime = new Date()
    }

    readonly property string timeHours: {
        var h = currentTime.getHours()
        if (root && root.clock12h) {
            h = h % 12
            if (h === 0) h = 12
        }
        return h < 10 ? "0" + h : "" + h
    }
    readonly property string timeMinutes: {
        var m = currentTime.getMinutes()
        return m < 10 ? "0" + m : "" + m
    }
    readonly property int timeSeconds: currentTime.getSeconds()
    readonly property real dayProgress: (currentTime.getHours() * 60 + currentTime.getMinutes()) / 1440.0
    readonly property real batteryPct: (root && typeof root.batteryPercent === "number") ? Math.max(0, Math.min(100, root.batteryPercent)) : 100
    readonly property int cpuTempVal: dashboardContent.cpuTemp
    readonly property int notifCount: (root && root.unreadNotifCount) ? root.unreadNotifCount : 0

    // Circular Watch Dial (borderless)
    Rectangle {
        id: watchDial
        width: Math.min(parent.width, parent.height)
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: Qt.rgba(paperCol.r, paperCol.g, paperCol.b, isLight ? 0.85 : 0.72)
        border.width: 0

        // Perimeter Ticks (act as audio visualizer bars when media is playing) + Sweeping Seconds Arc
        Canvas {
            id: dialCanvas
            anchors.fill: parent
            anchors.margins: -16
            readonly property int curSec: timeDateWidget.timeSeconds
            readonly property color sCol: timeDateWidget.sealCol
            readonly property color iCol: timeDateWidget.inkCol
            readonly property var vizLevels: timeDateWidget.vizLevels
            readonly property bool vizActive: timeDateWidget.isMediaPlaying
            readonly property real ticksProg: timeDateWidget.ticksProgress
            onCurSecChanged: requestPaint()
            onSColChanged: requestPaint()
            onIColChanged: requestPaint()
            onVizLevelsChanged: if (vizActive) requestPaint()
            onVizActiveChanged: requestPaint()
            onTicksProgChanged: requestPaint()
            onPaint: {
                if (width <= 40 || height <= 40 || watchDial.width <= 20) return
                var ctx = getContext("2d")
                ctx.reset()
                if (ticksProg <= 0.005) return
                var cx = width / 2
                var cy = height / 2
                var outerR = (watchDial.width / 2) - 8
                var lv = vizLevels || []

                // 60 watch ticks (fade in clockwise one by one on boot, track passed seconds, and pulse outward when playing)
                for (var i = 0; i < 60; i++) {
                    var tickT = Math.max(0.0, Math.min(1.0, (ticksProg * 62.0 - i) / 3.0))
                    if (tickT <= 0.01) continue

                    var angle = (i / 60.0) * Math.PI * 2 - Math.PI / 2
                    var isMajor = (i % 5 === 0)
                    var isPassed = (i <= curSec)
                    var isCurrent = (i === curSec)
                    var amp = (vizActive && i < lv.length) ? lv[i] : 0.0
                    var r1 = outerR - (isMajor ? 9 : 4)
                    var r2 = outerR + (vizActive ? (amp * 18) : 0)
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(angle) * r1, cy + Math.sin(angle) * r1)
                    ctx.lineTo(cx + Math.cos(angle) * r2, cy + Math.sin(angle) * r2)

                    if (isCurrent) {
                        ctx.strokeStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, 1.0 * tickT)
                    } else if (isPassed) {
                        var passedAlpha = vizActive ? Math.min(1.0, 0.72 + amp * 0.28) : (isMajor ? 0.90 : 0.72)
                        ctx.strokeStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, passedAlpha * tickT)
                    } else if (vizActive && amp > 0.06) {
                        var blend = Math.min(1.0, amp * 1.15)
                        ctx.strokeStyle = Qt.rgba(
                            iCol.r * (1 - blend) + sCol.r * blend,
                            iCol.g * (1 - blend) + sCol.g * blend,
                            iCol.b * (1 - blend) + sCol.b * blend,
                            (0.28 + blend * 0.50) * tickT
                        )
                    } else {
                        ctx.strokeStyle = isMajor
                            ? Qt.rgba(iCol.r, iCol.g, iCol.b, 0.34 * tickT)
                            : Qt.rgba(iCol.r, iCol.g, iCol.b, 0.14 * tickT)
                    }

                    var baseW = vizActive ? (isMajor ? 2.4 : 1.7) : (isMajor ? 1.8 : 1.1)
                    ctx.lineWidth = isCurrent ? (baseW + 1.2) : (isPassed ? (baseW + 0.7) : baseW)
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }

        // Top Complication: Date
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(watchDial.height * 0.13) - (1.0 - timeDateWidget.dateProgress) * 6
            opacity: timeDateWidget.dateProgress
            text: Qt.formatDate(timeDateWidget.currentTime, "ddd · MMM d").toUpperCase()
            color: Qt.rgba(inkCol.r, inkCol.g, inkCol.b, 0.65)
            font.family: "Google Sans"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        // Central 10:10 Time Pill (borderless, Bigger font)
        Rectangle {
            id: timePill
            anchors.centerIn: parent
            width: Math.round(watchDial.width * 0.60)
            height: Math.round(watchDial.width * 0.25)
            radius: height / 2
            color: Qt.rgba(sealCol.r, sealCol.g, sealCol.b, isLight ? 0.18 : 0.14)
            border.width: 0
            scale: 0.55 + 0.45 * timeDateWidget.pillProgress
            opacity: Math.max(0.0, Math.min(1.0, timeDateWidget.pillProgress * 1.4))

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 3 + (1.0 - timeDateWidget.pillTextProgress) * 6
                verticalAlignment: Text.AlignVCenter
                text: timeDateWidget.timeHours + ":" + timeDateWidget.timeMinutes
                color: isLight ? inkCol : sealCol
                opacity: timeDateWidget.pillTextProgress
                scale: 0.85 + 0.15 * timeDateWidget.pillTextProgress
                font.family: (biggerFont && biggerFont.status === FontLoader.Ready) ? biggerFont.name : "Google Sans"
                font.pixelSize: Math.max(34, Math.round(watchDial.width * 0.17))
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }

        // Bottom Complication: Live Day Progress %
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(watchDial.height * 0.12) - (1.0 - timeDateWidget.dayPctProgress) * 6
            opacity: timeDateWidget.dayPctProgress
            text: Math.round(timeDateWidget.dayProgress * 100) + "% OF DAY"
            color: Qt.rgba(inkCol.r, inkCol.g, inkCol.b, 0.50)
            font.family: "Google Sans"
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 1.4
        }
    }
}
