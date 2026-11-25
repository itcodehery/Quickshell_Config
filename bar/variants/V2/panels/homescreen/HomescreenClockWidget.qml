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
            anchors.margins: -20
            readonly property int curSec: timeDateWidget.timeSeconds
            readonly property color sCol: timeDateWidget.sealCol
            readonly property color iCol: timeDateWidget.inkCol
            readonly property color c3Col: timeDateWidget.color03Col
            readonly property var vizLevels: timeDateWidget.vizLevels
            readonly property bool vizActive: timeDateWidget.isMediaPlaying
            readonly property string vizStyle: (timeDateWidget.root && timeDateWidget.root.clockVisualizerStyle) ? timeDateWidget.root.clockVisualizerStyle : "ticks"
            readonly property real ticksProg: timeDateWidget.ticksProgress
            onCurSecChanged: requestPaint()
            onSColChanged: requestPaint()
            onIColChanged: requestPaint()
            onC3ColChanged: requestPaint()
            onVizLevelsChanged: if (vizActive) requestPaint()
            onVizActiveChanged: requestPaint()
            onVizStyleChanged: requestPaint()
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
                var useTicksViz = vizActive && vizStyle === "ticks"

                // 60 watch ticks (only drawn when idle or using the "ticks" visualizer style)
                if (!vizActive || vizStyle === "ticks") {
                    for (var i = 0; i < 60; i++) {
                        var tickT = Math.max(0.0, Math.min(1.0, (ticksProg * 62.0 - i) / 3.0))
                        if (tickT <= 0.01) continue

                        var angle = (i / 60.0) * Math.PI * 2 - Math.PI / 2
                        var isMajor = (i % 5 === 0)
                        var isPassed = (i <= curSec)
                        var isCurrent = (i === curSec)
                        var amp = (useTicksViz && i < lv.length) ? lv[i] : 0.0
                        var r1 = outerR - (isMajor ? 9 : 4)
                        var r2 = outerR + (useTicksViz ? (amp * 18) : 0)
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(angle) * r1, cy + Math.sin(angle) * r1)
                        ctx.lineTo(cx + Math.cos(angle) * r2, cy + Math.sin(angle) * r2)

                        if (isCurrent) {
                            ctx.strokeStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, 1.0 * tickT)
                        } else if (isPassed) {
                            var passedAlpha = useTicksViz ? Math.min(1.0, 0.72 + amp * 0.28) : (isMajor ? 0.90 : 0.72)
                            ctx.strokeStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, passedAlpha * tickT)
                        } else if (useTicksViz && amp > 0.06) {
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

                        var baseW = useTicksViz ? (isMajor ? 2.4 : 1.7) : (isMajor ? 1.8 : 1.1)
                        ctx.lineWidth = isCurrent ? (baseW + 1.2) : (isPassed ? (baseW + 0.7) : baseW)
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }

                if (!vizActive || ticksProg < 0.95) return

                // Style 2: WAVEFORM — smooth closed spline audio ring around the dial
                if (vizStyle === "waveform") {
                    var pts = []
                    for (var w = 0; w < 60; w++) {
                        var wa = (w / 60.0) * Math.PI * 2 - Math.PI / 2
                        var wAmp = (w < lv.length) ? lv[w] : 0.0
                        var wr = outerR + 4 + wAmp * 16
                        pts.push({ x: cx + Math.cos(wa) * wr, y: cy + Math.sin(wa) * wr })
                    }
                    ctx.beginPath()
                    for (var p = 0; p < 60; p++) {
                        var p0 = pts[p]
                        var p1 = pts[(p + 1) % 60]
                        var mx = (p0.x + p1.x) / 2
                        var my = (p0.y + p1.y) / 2
                        if (p === 0) {
                            var pLast = pts[59]
                            ctx.moveTo((pLast.x + p0.x) / 2, (pLast.y + p0.y) / 2)
                        }
                        ctx.quadraticCurveTo(p0.x, p0.y, mx, my)
                    }
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, 0.08)
                    ctx.fill()
                    ctx.strokeStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, 0.88)
                    ctx.lineWidth = 2.2
                    ctx.stroke()
                }

                // Style 3: ORBIT — floating radial frequency beads orbiting the watch face
                else if (vizStyle === "orbit") {
                    for (var o = 0; o < 60; o += 2) {
                        var oa = (o / 60.0) * Math.PI * 2 - Math.PI / 2
                        var oAmp = (o < lv.length) ? lv[o] : 0.0
                        var orad = outerR + 5 + oAmp * 15
                        var dotR = 1.4 + oAmp * 2.6
                        ctx.beginPath()
                        ctx.arc(cx + Math.cos(oa) * orad, cy + Math.sin(oa) * orad, dotR, 0, Math.PI * 2)
                        ctx.fillStyle = oAmp > 0.35
                            ? Qt.rgba(sCol.r, sCol.g, sCol.b, 0.55 + oAmp * 0.45)
                            : Qt.rgba(iCol.r, iCol.g, iCol.b, 0.25 + oAmp * 0.55)
                        ctx.fill()
                    }
                }

                // Style 4: STARWEB / CONSTELLATION — reactive polygonal web with glowing star vertices & peak cross-chords
                else if (vizStyle === "constellation" || vizStyle === "aurora") {
                    var nNodes = 20
                    var nodes = []
                    for (var n = 0; n < nNodes; n++) {
                        var na = (n / nNodes) * Math.PI * 2 - Math.PI / 2
                        var bandIdx = Math.floor((n / nNodes) * Math.min(60, lv.length))
                        var nAmp = (bandIdx < lv.length) ? lv[bandIdx] : 0.0
                        var nr = outerR + 3 + nAmp * 16
                        nodes.push({
                            x: cx + Math.cos(na) * nr,
                            y: cy + Math.sin(na) * nr,
                            amp: nAmp
                        })
                    }

                    // Outer polygonal constellation perimeter
                    ctx.beginPath()
                    for (var j = 0; j < nNodes; j++) {
                        if (j === 0) ctx.moveTo(nodes[j].x, nodes[j].y)
                        else ctx.lineTo(nodes[j].x, nodes[j].y)
                    }
                    ctx.closePath()
                    ctx.strokeStyle = Qt.rgba(sCol.r, sCol.g, sCol.b, 0.55)
                    ctx.lineWidth = 1.4
                    ctx.stroke()

                    // Cross-chords connecting energetic nodes to their harmonic opposite/neighbor
                    for (var a = 0; a < nNodes; a++) {
                        if (nodes[a].amp < 0.22) continue
                        var b = (a + 3) % nNodes
                        ctx.beginPath()
                        ctx.moveTo(nodes[a].x, nodes[a].y)
                        ctx.lineTo(nodes[b].x, nodes[b].y)
                        ctx.strokeStyle = Qt.rgba(c3Col.r, c3Col.g, c3Col.b, Math.min(0.65, nodes[a].amp * 0.75))
                        ctx.lineWidth = 1.0
                        ctx.stroke()
                    }

                    // Glowing star vertices
                    for (var v = 0; v < nNodes; v++) {
                        var vAmp = nodes[v].amp
                        var vr = 1.4 + vAmp * 2.4
                        ctx.beginPath()
                        ctx.arc(nodes[v].x, nodes[v].y, vr, 0, Math.PI * 2)
                        ctx.fillStyle = vAmp > 0.35
                            ? Qt.rgba(sCol.r, sCol.g, sCol.b, 0.95)
                            : Qt.rgba(iCol.r, iCol.g, iCol.b, 0.35 + vAmp * 0.45)
                        ctx.fill()
                    }
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

        // Central 10:10 Time Pill (borderless, Bigger font, clickable -> opens calendar)
        Rectangle {
            id: timePill
            anchors.centerIn: parent
            width: Math.round(watchDial.width * 0.60)
            height: Math.round(watchDial.width * 0.25)
            radius: height / 2
            color: timePillMa.containsMouse
                ? Qt.rgba(sealCol.r, sealCol.g, sealCol.b, isLight ? 0.28 : 0.24)
                : Qt.rgba(sealCol.r, sealCol.g, sealCol.b, isLight ? 0.18 : 0.14)
            border.width: 0
            scale: (0.55 + 0.45 * timeDateWidget.pillProgress) * (timePillMa.pressed ? 0.95 : (timePillMa.containsMouse ? 1.03 : 1.0))
            opacity: Math.max(0.0, Math.min(1.0, timeDateWidget.pillProgress * 1.4))

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.005 } }

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

            MouseArea {
                id: timePillMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (timeDateWidget.dashboardContent) {
                        timeDateWidget.dashboardContent.activeDetailView = "calendar"
                    }
                }
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
