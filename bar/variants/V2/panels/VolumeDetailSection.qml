import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../modules"

Item {
    id: volSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    AudioData { id: audio }
    readonly property int volume: audio.volume
    readonly property bool muted: audio.muted

    property bool micMuted: false
    property real micLevel: 0
    property bool notifyMicStateAfterRefresh: false
    property bool micStateRefreshPending: false
    readonly property real micNoiseFloorDb: -55
    readonly property bool micMeterAvailable: micPeakLoader.status === Loader.Ready && micPeakLoader.item !== null
    readonly property real micPeakValue: micMeterAvailable ? micPeakLoader.item.peak : 0

    Loader {
        id: micPeakLoader
        active: volSection.visible
        source: "MicrophonePeakMonitor.qml"
        onLoaded: {
            item.panelOpen = Qt.binding(function() { return volSection.visible })
            item.muted = Qt.binding(function() { return volSection.micMuted })
        }
    }

    function peakToMeter(peak) {
        if (!isFinite(peak) || peak <= 0) return 0
        var amplitude = peak * peak * peak
        var db = 20 * Math.log(amplitude) / Math.LN10
        if (db <= micNoiseFloorDb) return 0
        return Math.max(0, Math.min(1, (db - micNoiseFloorDb) / -micNoiseFloorDb))
    }

    Timer {
        interval: 45
        repeat: true
        running: volSection.visible && volSection.micMeterAvailable
        onTriggered: {
            var sample = volSection.micMuted ? 0 : volSection.peakToMeter(volSection.micPeakValue)
            volSection.micLevel = sample >= volSection.micLevel
                ? sample : Math.max(sample, volSection.micLevel * 0.78)
        }
        onRunningChanged: if (!running) volSection.micLevel = 0
    }

    // Per-app mixer and output sink devices
    property var apps: []
    property var sinks: []
    property string defaultSink: ""
    readonly property string defaultSinkDesc: {
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].name === defaultSink) return sinks[i].desc
        }
        return audio.sink && audio.sink.description ? audio.sink.description : "Default Output"
    }

    property string _appsRaw: ""
    property string _sinksRaw: ""

    readonly property string outputMuteCommand:
        "(command -v omarchy-swayosd-client >/dev/null 2>&1 && omarchy-swayosd-client --output-volume mute-toggle) || " +
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle || " +
        "pamixer -t"

    readonly property string micMuteCommand:
        "if command -v omarchy-audio-input-mute >/dev/null 2>&1; then " +
        "omarchy-audio-input-mute; " +
        "else wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle || pamixer --default-source -t; fi"

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function run(cmd, refreshAfter) {
        actProc.running = false
        actProc.refreshAfterExit = refreshAfter === true
        actProc.command = ["bash", "-c", cmd]
        actProc.running = true
    }

    function parseMicMuteState(text) {
        var match = String(text || "").trim().match(/^Mute:\s*(yes|no)$/i)
        if (!match) return -1
        return match[1].toLowerCase() === "yes" ? 1 : 0
    }

    function refreshMicState(notifyAfter) {
        if (notifyAfter === true) notifyMicStateAfterRefresh = true
        if (micData.running) {
            micStateRefreshPending = true
            return
        }
        micData.running = true
    }

    function setDefaultSink(dev) {
        if (!dev || !dev.name) return
        var sinkName = volSection.shq(dev.name)
        var nodeId = (dev.index !== undefined && dev.index !== null) ? String(dev.index).replace(/[^0-9]/g, "") : ""
        var cmd = ""
        if (nodeId.length > 0)
            cmd += "timeout 2 wpctl set-default " + nodeId + " 2>/dev/null || true\n"
        cmd += "timeout 2 pactl set-default-sink " + sinkName + " 2>/dev/null || true\n"
        cmd += "timeout 2 pactl list short sink-inputs 2>/dev/null | awk '{ print $1 }' | while read -r input; do\n"
        cmd += "  [ -n \"$input\" ] && timeout 2 pactl move-sink-input \"$input\" " + sinkName + " 2>/dev/null || true\n"
        cmd += "done"
        volSection.defaultSink = dev.name
        volSection.run(cmd, true)
    }

    function refreshAll() {
        audio.refresh()
        appsProc.running = false; appsProc.running = true
        sinksProc.running = false; sinksProc.running = true
        defSinkProc.running = false; defSinkProc.running = true
        volSection.refreshMicState(false)
    }

    onVisibleChanged: {
        if (visible) volSection.refreshAll()
    }

    // Background processes
    Process {
        id: muteRunner
        command: ["bash", "-c", volSection.outputMuteCommand]
        onExited: (code) => { audio.refresh() }
    }

    Process {
        id: micMuteRunner
        command: ["bash", "-c", volSection.micMuteCommand]
        onExited: (code) => { volSection.refreshMicState(code === 0) }
    }

    Process {
        id: actProc
        property bool refreshAfterExit: false
        command: []
        onExited: {
            if (refreshAfterExit) {
                refreshAfterExit = false
                volSection.refreshAll()
            }
        }
    }

    Process {
        id: micData
        command: ["env", "LC_ALL=C", "pactl", "get-source-mute", "@DEFAULT_SOURCE@"]
        running: false
        stdout: StdioCollector { id: micDataOut }
        onExited: (code) => {
            var state = volSection.parseMicMuteState(micDataOut.text)
            var rerun = volSection.micStateRefreshPending
            volSection.micStateRefreshPending = false
            if (rerun) {
                Qt.callLater(function() { volSection.refreshMicState(false) })
                return
            }
            if (code === 0 && state >= 0) {
                volSection.micMuted = (state === 1)
            }
        }
    }

    Process {
        id: appsProc
        command: ["bash", "-c", "pactl -f json list sink-inputs 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "[]")
                if (raw === volSection._appsRaw) return
                volSection._appsRaw = raw
                var out = []
                try {
                    var j = JSON.parse(raw)
                    for (var i = 0; i < j.length; i++) {
                        var s = j[i], p = s.properties || {}
                        var nm = p["application.name"] || p["media.name"] || p["application.process.binary"] || "App"
                        var vk = Object.keys(s.volume || {})
                        var vp = vk.length ? String(s.volume[vk[0]].value_percent) : "0%"
                        out.push({ idx: s.index, name: nm, vol: (parseInt(vp.replace("%", "")) || 0), muted: !!s.mute })
                    }
                } catch (e) {}
                volSection.apps = out
            }
        }
    }

    Process {
        id: sinksProc
        command: ["bash", "-c", "pactl -f json list sinks 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "[]")
                if (raw === volSection._sinksRaw) return
                volSection._sinksRaw = raw
                var out = []
                try {
                    var j = JSON.parse(raw)
                    for (var i = 0; i < j.length; i++) {
                        var d = j[i].description
                        if (!d || d === "(null)") {
                            var p = j[i].properties || {}
                            d = p["device.description"] || p["alsa.card_name"] || j[i].name
                        }
                        out.push({ index: j[i].index, name: j[i].name, desc: d })
                    }
                } catch (e) {}
                volSection.sinks = out
            }
        }
    }

    Process {
        id: defSinkProc
        command: ["bash", "-c", "pactl get-default-sink 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { volSection.defaultSink = this.text.trim() }
        }
    }

    Timer {
        interval: 2000; repeat: true
        running: volSection.visible
        onTriggered: {
            appsProc.running = false; appsProc.running = true
            defSinkProc.running = false; defSinkProc.running = true
        }
    }

    // ================= MAIN LAYOUT =================
    Column {
        anchors.fill: parent
        spacing: 10

        // ================= HEADER BAR =================
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: root.seal
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        text: volSection.muted ? "volume_off" : "volume_up"
                        color: root.paper
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "AUDIO & SOUND"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }

                    Row {
                        spacing: 6
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: volSection.muted ? "#f87171" : "#4ade80"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (volSection.muted ? "Output Muted" : (volSection.volume + "% Master Output")) +
                                  " • " + volSection.defaultSinkDesc
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, volSection.width - 250)
                        }
                    }
                }
            }

            // Top action buttons
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Refresh Button Pill
                Rectangle {
                    width: 82
                    height: 28
                    radius: 14
                    color: volRefMa.containsMouse ? root.fillHover : root.fillIdle
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        IconText {
                            text: "refresh"
                            color: root.ink
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Refresh"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: volRefMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: volSection.refreshAll()
                    }
                }
            }
        }

        // ================= DUAL CARD CONTENT =================
        Row {
            width: parent.width
            height: parent.height - 46
            spacing: 12

            // ---------------- CARD 1: OUTPUT & INPUT DEVICES (44%) ----------------
            Rectangle {
                id: card1
                width: Math.round((parent.width - 12) * 0.44)
                height: parent.height
                radius: 20
                color: root.fillIdle
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
                    contentWidth: width
                    contentHeight: leftContentCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: leftContentCol
                        width: parent.width
                        spacing: 12

                        // --- 1. Master Output Section ---
                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                text: "MASTER OUTPUT"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: volSection.muted ? "Muted" : (volSection.volume + "%")
                                color: volSection.muted ? root.color01 : root.seal
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Master Volume Slider Track
                        Rectangle {
                            id: masterSliderTrack
                            width: parent.width
                            height: 40
                            radius: 20
                            color: root.fillIdle
                            clip: true

                            property int localVal: volSection.volume
                            property bool dragging: false

                            Item {
                                id: masterFillItem
                                property real val: masterSliderTrack.dragging ? masterSliderTrack.localVal : volSection.volume
                                property real gap: val > 85 ? 23 * (100 - val) / 15 : 23
                                property real barOpacity: val > 85 ? (100 - val) / 15 : 1

                                width: Math.max(parent.height, parent.width * (val / 100))
                                height: parent.height
                                Behavior on width {
                                    enabled: !masterSliderTrack.dragging
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                }

                                // The actual fill
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(parent.height, parent.width - masterFillItem.gap)
                                    radius: 10 + (10 * (1 - masterFillItem.barOpacity))
                                    color: volSection.muted ? root.fillHover : root.seal

                                    // fully rounded on the left
                                    Rectangle {
                                        width: parent.height
                                        height: parent.height
                                        radius: height / 2
                                        color: volSection.muted ? root.fillHover : root.seal
                                        anchors.left: parent.left
                                    }
                                }

                                // The vertical bar with "padding"
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 23 // 10px gap + 3px line + 10px gap
                                    height: parent.height
                                    color: "transparent"
                                    opacity: masterFillItem.barOpacity

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 3
                                        height: parent.height - 16
                                        radius: 1.5
                                        color: volSection.muted ? root.fillHover : root.seal
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: volSection.muted ? "volume_off" : (masterFillItem.val > 50 ? "volume_up" : (masterFillItem.val > 0 ? "volume_down" : "volume_mute"))
                                    color: volSection.muted ? root.ink : root.paper
                                    font.pixelSize: 18
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Math.round(masterFillItem.val) + "%"
                                    color: volSection.muted ? root.ink : (masterFillItem.width > 70 ? root.paper : root.ink)
                                    font.pixelSize: 13
                                    font.family: root.barFont
                                    font.weight: Font.DemiBold
                                    opacity: masterSliderTrack.dragging ? 1 : (masterFillItem.width > 70 ? 1 : 0)
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function updateVal(mouse) {
                                    let v = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                    masterSliderTrack.localVal = v
                                }
                                onPressed: (mouse) => {
                                    masterSliderTrack.dragging = true
                                    updateVal(mouse)
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) updateVal(mouse)
                                }
                                onReleased: (mouse) => {
                                    masterSliderTrack.dragging = false
                                    updateVal(mouse)
                                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", masterSliderTrack.localVal + "%"])
                                }
                            }
                        }

                        // Mute Master Volume Pill Button
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 16
                            color: volSection.muted ? root.seal : (masterMuteMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.05))
                            border.width: 1
                            border.color: volSection.muted ? root.seal : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                IconText {
                                    text: volSection.muted ? "volume_off" : "volume_up"
                                    color: volSection.muted ? root.paper : root.ink
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: volSection.muted ? "Unmute Volume" : "Mute Volume"
                                    color: volSection.muted ? root.paper : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: masterMuteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!muteRunner.running) muteRunner.running = true
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // --- 2. Output Device Switcher ---
                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                text: "OUTPUT DEVICES"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: volSection.sinks.length + " available"
                                color: root.ink
                                opacity: 0.5
                                font.family: root.barFont
                                font.pixelSize: 10
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: volSection.sinks
                                delegate: Rectangle {
                                    id: devItem
                                    required property var modelData
                                    readonly property bool isSelected: modelData.name === volSection.defaultSink
                                    readonly property bool isHovered: devMa.containsMouse

                                    width: parent.width
                                    height: 34
                                    radius: 12
                                    color: isSelected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16) : (isHovered ? root.fillHover : Qt.rgba(1, 1, 1, 0.04))
                                    border.width: isSelected ? 1.5 : 1
                                    border.color: isSelected ? root.seal : Qt.rgba(1, 1, 1, 0.06)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        // Radio indicator dot
                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: devItem.isSelected ? root.seal : Qt.rgba(1, 1, 1, 0.25)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        IconText {
                                            text: {
                                                let d = (devItem.modelData.desc || "").toLowerCase()
                                                if (d.indexOf("headphone") >= 0 || d.indexOf("headset") >= 0) return "headphones"
                                                if (d.indexOf("hdmi") >= 0 || d.indexOf("display") >= 0) return "tv"
                                                if (d.indexOf("blue") >= 0) return "bluetooth"
                                                return "speaker"
                                            }
                                            color: devItem.isSelected ? root.seal : root.ink
                                            font.pixelSize: 15
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: devItem.modelData.desc
                                            color: devItem.isSelected ? root.seal : root.ink
                                            font.family: root.barFont
                                            font.pixelSize: 11
                                            font.weight: devItem.isSelected ? Font.Bold : Font.Normal
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 60
                                        }
                                    }

                                    MouseArea {
                                        id: devMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: volSection.setDefaultSink(devItem.modelData)
                                    }
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // --- 3. Microphone & Input Section ---
                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                text: "MICROPHONE INPUT"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: volSection.micMuted ? "Muted" : "Active"
                                color: volSection.micMuted ? "#f87171" : "#4ade80"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Live VU / Peak Level Meter
                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 5
                            color: root.fillIdle
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(0, Math.min(parent.width, parent.width * (volSection.micMuted ? 0 : volSection.micLevel)))
                                radius: 5
                                color: volSection.micMuted ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : root.seal
                                Behavior on width { NumberAnimation { duration: 80 } }
                            }
                        }

                        // Mic Mute Toggle Pill Button
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 16
                            color: volSection.micMuted ? root.seal : (micMuteMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.05))
                            border.width: 1
                            border.color: volSection.micMuted ? root.seal : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                IconText {
                                    text: volSection.micMuted ? "mic_off" : "mic"
                                    color: volSection.micMuted ? root.paper : root.ink
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: volSection.micMuted ? "Unmute Microphone" : "Mute Microphone"
                                    color: volSection.micMuted ? root.paper : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: micMuteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!micMuteRunner.running) micMuteRunner.running = true
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- CARD 2: PER-APP AUDIO MIXER (56%) ----------------
            Rectangle {
                id: card2
                width: parent.width - 12 - card1.width
                height: parent.height
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Header row
                    Item {
                        width: parent.width
                        height: 18

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            IconText {
                                text: "tune"
                                color: root.seal
                                font.pixelSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "APPLICATION AUDIO MIXER"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: volSection.apps.length > 0 ? (volSection.apps.length + " active") : "Idle"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // App Streams List (Flickable)
                    Flickable {
                        id: appsFlick
                        width: parent.width
                        height: parent.height - 45
                        contentWidth: width
                        contentHeight: Math.max(height, appItemsCol.implicitHeight)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Column {
                            id: appItemsCol
                            width: parent.width
                            spacing: 8
                            visible: volSection.apps.length > 0

                            Repeater {
                                model: volSection.apps
                                delegate: Rectangle {
                                    id: appCard
                                    required property var modelData
                                    property int localAppVol: modelData.vol
                                    property bool dragging: false

                                    width: parent.width
                                    height: 72
                                    radius: 14
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.06)

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        // Top Row: Icon + Name (left) & % + Mute Toggle (right)
                                        Item {
                                            width: parent.width
                                            height: 22

                                            Row {
                                                anchors.left: parent.left
                                                anchors.right: appControlsRow.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                IconText {
                                                    text: appCard.modelData.muted ? "volume_off" : "graphic_eq"
                                                    color: appCard.modelData.muted ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4) : root.seal
                                                    font.pixelSize: 16
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: appCard.modelData.name
                                                    color: appCard.modelData.muted ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45) : root.ink
                                                    font.family: root.barFont
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                    width: parent.width - 24
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Row {
                                                id: appControlsRow
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                Text {
                                                    text: (appCard.dragging ? appCard.localAppVol : appCard.modelData.vol) + "%"
                                                    color: appCard.modelData.muted ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4) : root.seal
                                                    font.family: root.barFont
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Rectangle {
                                                    id: appMuteBtn
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: appCard.modelData.muted ? root.seal : (appMuteMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.08))

                                                    IconText {
                                                        anchors.centerIn: parent
                                                        text: appCard.modelData.muted ? "volume_off" : "volume_up"
                                                        color: appCard.modelData.muted ? root.paper : root.ink
                                                        font.pixelSize: 12
                                                    }

                                                    MouseArea {
                                                        id: appMuteMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            volSection.run("pactl set-sink-input-mute " + appCard.modelData.idx + " toggle")
                                                            Qt.callLater(function() { volSection.refreshAll() })
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Bottom Row: Draggable Volume Slider Track with vertical bar UI
                                        Rectangle {
                                            id: appTrackRect
                                            width: parent.width
                                            height: 26
                                            radius: 13
                                            color: root.fillIdle
                                            clip: true

                                            Item {
                                                id: appFillItem
                                                property real val: appCard.dragging ? appCard.localAppVol : appCard.modelData.vol
                                                property real gap: val > 85 ? 18 * (100 - val) / 15 : 18
                                                property real barOpacity: val > 85 ? (100 - val) / 15 : 1

                                                width: Math.max(parent.height, parent.width * (val / 100))
                                                height: parent.height
                                                Behavior on width {
                                                    enabled: !appCard.dragging
                                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                                }

                                                // The actual fill
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: Math.max(parent.height, parent.width - appFillItem.gap)
                                                    radius: 7 + (6 * (1 - appFillItem.barOpacity))
                                                    color: appCard.modelData.muted ? root.fillHover : root.seal

                                                    // fully rounded on the left
                                                    Rectangle {
                                                        width: parent.height
                                                        height: parent.height
                                                        radius: height / 2
                                                        color: appCard.modelData.muted ? root.fillHover : root.seal
                                                        anchors.left: parent.left
                                                    }
                                                }

                                                // The vertical bar with "padding"
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 18 // 8px gap + 2.5px line + 8px gap
                                                    height: parent.height
                                                    color: "transparent"
                                                    opacity: appFillItem.barOpacity

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 2.5
                                                        height: parent.height - 10
                                                        radius: 1.25
                                                        color: appCard.modelData.muted ? root.fillHover : root.seal
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                function updateAppVal(mouse) {
                                                    let v = Math.max(0, Math.min(100, Math.round((mouse.x / appTrackRect.width) * 100)))
                                                    appCard.localAppVol = v
                                                }
                                                onPressed: (mouse) => {
                                                    appCard.dragging = true
                                                    updateAppVal(mouse)
                                                }
                                                onPositionChanged: (mouse) => {
                                                    if (pressed) updateAppVal(mouse)
                                                }
                                                onReleased: (mouse) => {
                                                    appCard.dragging = false
                                                    updateAppVal(mouse)
                                                    volSection.run("pactl set-sink-input-volume " + appCard.modelData.idx + " " + appCard.localAppVol + "%")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Empty State if no apps are playing audio
                        Item {
                            anchors.fill: parent
                            visible: volSection.apps.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                IconText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "music_off"
                                    color: root.ink
                                    opacity: 0.25
                                    font.pixelSize: 36
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No Active Audio Streams"
                                    color: root.ink
                                    opacity: 0.7
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Applications playing sound will appear here."
                                    color: root.ink
                                    opacity: 0.4
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
