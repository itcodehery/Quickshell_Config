import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQml.Models
import "../modules"

Item {
    id: dashboardContent
    anchors.fill: parent
    property var root
    property var panel

    AudioData { id: audioData }

    property int currentBrightness: 50
    Process {
        running: true
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }
    Timer {
        interval: 3000; repeat: true; running: panel.expanded
        onTriggered: { briUpdater.running = false; briUpdater.running = true }
    }
    Process {
        id: briUpdater
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }

    property string currentWifiName: "Wi-Fi"
    property string currentBtName: "Bluetooth"

    Timer {
        interval: 3000; repeat: true; running: panel.expanded; triggeredOnStart: true
        onTriggered: {
            wifiUpdater.running = false; wifiUpdater.running = true
            btUpdater.running = false; btUpdater.running = true
        }
    }
    
    Process {
        id: wifiUpdater
        command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = this.text.trim()
                dashboardContent.currentWifiName = s === "" ? "Wi-Fi" : s
            }
        }
    }
    
    Process {
        id: btUpdater
        command: ["bash", "-c", "bluetoothctl devices Connected | head -n1 | cut -d ' ' -f 3-"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = this.text.trim()
                dashboardContent.currentBtName = s === "" ? "Bluetooth" : s
            }
        }
    }

    MprisSelect { id: mprisSel }
    MprisArtwork { id: mprisArt; player: mprisSel.player; root: dashboardContent.root }
    
    property string curTitle: mprisSel.player ? (mprisSel.player.trackTitle || "") : ""
    property string curArtist: mprisSel.player ? (mprisSel.player.trackArtist || "") : ""
    property string curArtUrl: mprisArt.source
    
    onCurTitleChanged: { if (root && curTitle !== "") root.lastMediaTitle = curTitle }
    onCurArtistChanged: { if (root && curArtist !== "") root.lastMediaArtist = curArtist }
    onCurArtUrlChanged: { if (root && curArtUrl !== "") root.lastMediaArtUrl = curArtUrl }
    
    onRootChanged: {
        if (root) {
            if (mprisSel.player && mprisSel.player.trackTitle) {
                root.lastMediaTitle = mprisSel.player.trackTitle || ""
                root.lastMediaArtist = mprisSel.player.trackArtist || ""
            }
            if (mprisArt.source) root.lastMediaArtUrl = mprisArt.source
        }
    }

    Row {
        anchors.fill: parent
        spacing: 16

        // LEFT COLUMN (40%): Sliders, Tiles & Media Player
        Column {
            width: parent.width * 0.4 - 8
            height: parent.height
            spacing: 16

            // --- SLIDERS ---
            Column {
                width: parent.width
                spacing: 12
                
                // Brightness Slider
                Rectangle {
                    id: briSlider
                    width: parent.width
                    height: 40
                    radius: 20
                    color: root.fillIdle
                    
                    property bool sliding: false
                    property int localValue: dashboardContent.currentBrightness
                    
                    Rectangle {
                        width: Math.max(parent.height, parent.width * ((briSlider.sliding ? briSlider.localValue : dashboardContent.currentBrightness) / 100))
                        height: parent.height
                        radius: 20
                        color: root.seal
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        spacing: 12
                        IconText { text: "light_mode"; color: (briSlider.sliding ? briSlider.localValue : dashboardContent.currentBrightness) > 20 ? root.paper : root.ink; font.pixelSize: 18 }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onPressed: { briSlider.sliding = true }
                        onPositionChanged: (mouse) => {
                            if (pressed) briSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                        }
                        onReleased: (mouse) => {
                            briSlider.sliding = false
                            let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                            dashboardContent.currentBrightness = pct
                            Quickshell.execDetached(["bash", "-c", "brightnessctl set " + pct + "%"])
                        }
                    }
                }

                // Audio Slider
                Rectangle {
                    id: audSlider
                    width: parent.width
                    height: 40
                    radius: 20
                    color: root.fillIdle
                    
                    property bool sliding: false
                    property int localValue: audioData.volume
                    
                    Rectangle {
                        width: Math.max(parent.height, parent.width * ((audSlider.sliding ? audSlider.localValue : audioData.volume) / 100))
                        height: parent.height
                        radius: 20
                        color: audioData.muted ? root.fillHover : root.seal
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        spacing: 12
                        IconText { text: audioData.muted ? "volume_off" : "volume_up"; color: ((audSlider.sliding ? audSlider.localValue : audioData.volume) > 20 && !audioData.muted) ? root.paper : root.ink; font.pixelSize: 18 }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onPressed: { audSlider.sliding = true }
                        onPositionChanged: (mouse) => {
                            if (pressed) audSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                        }
                        onReleased: (mouse) => {
                            audSlider.sliding = false
                            let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%"])
                        }
                    }
                }
            }

            // --- MATERIAL YOU TILES ---
            ListView {
                id: tilesPager
                width: parent.width
                height: 132
                clip: true
                snapMode: ListView.SnapToItem
                orientation: ListView.Vertical
                boundsBehavior: Flickable.StopAtBounds
                spacing: 24
                
                WheelHandler {
                    onWheel: (event) => {
                        if (event.angleDelta.y > 0) {
                            tilesPager.flick(0, 2000)
                        } else if (event.angleDelta.y < 0) {
                            tilesPager.flick(0, -2000)
                        }
                    }
                }
                
                model: ObjectModel {
                    // --- PAGE 1 ---
                    Grid {
                        width: tilesPager.width
                        height: tilesPager.height
                        columns: 2
                        spacing: 12

                        // Wi-Fi Tile
                        Rectangle {
                            id: wifiTile
                            property bool connected: dashboardContent.currentWifiName !== "Wi-Fi"
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: connected ? root.seal : root.fillIdle
                            scale: wifiMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                
                                IconText { text: "wifi"; color: wifiTile.connected ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Wi-Fi"; color: wifiTile.connected ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: dashboardContent.currentWifiName; color: wifiTile.connected ? root.paper : root.ink; opacity: wifiTile.connected ? 0.8 : 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: wifiTile.width - 64; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: wifiMa
                                anchors.fill: parent
                                onClicked: root.networkVisible = !root.networkVisible
                            }
                        }

                        // Bluetooth Tile
                        Rectangle {
                            id: btTile
                            property bool connected: dashboardContent.currentBtName !== "Bluetooth"
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: connected ? root.seal : root.fillIdle
                            scale: btMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                
                                IconText { text: "bluetooth"; color: btTile.connected ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Bluetooth"; color: btTile.connected ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: dashboardContent.currentBtName; color: btTile.connected ? root.paper : root.ink; opacity: btTile.connected ? 0.8 : 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: btTile.width - 64; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: btMa
                                anchors.fill: parent
                                onClicked: root.bluetoothVisible = !root.bluetoothVisible
                            }
                        }

                        // CPU Tile
                        Rectangle {
                            id: cpuTile
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: root.fillIdle
                            scale: cpuMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                
                                IconText { text: "memory"; color: root.ink; font.pixelSize: 20 }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "CPU"; color: root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold }
                                    Text { text: root.systemCpuPercent + "%"; color: root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: 60 }
                                }
                            }
                            MouseArea {
                                id: cpuMa
                                anchors.fill: parent
                                onClicked: root.cpuVisible = !root.cpuVisible
                            }
                        }

                        // Memory Tile
                        Rectangle {
                            id: memTile
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: root.fillIdle
                            scale: memMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                
                                IconText { text: "dns"; color: root.ink; font.pixelSize: 20 }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Memory"; color: root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold }
                                    Text { text: root.systemMemUsedGiB.toFixed(1) + "/" + root.systemMemTotalGiB.toFixed(0) + "G"; color: root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: 60 }
                                }
                            }
                            MouseArea {
                                id: memMa
                                anchors.fill: parent
                                onClicked: root.memVisible = !root.memVisible
                            }
                        }
                    }

                    // --- PAGE 2 ---
                    Grid {
                        width: tilesPager.width
                        height: tilesPager.height
                        columns: 2
                        spacing: 12

                        // DND Tile
                        Rectangle {
                            id: dndTile
                            property bool active: root.notifSilenced
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color04 : root.fillIdle
                            scale: dndMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: dndTile.active ? "notifications_off" : "notifications_active"; color: dndTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "DND"; color: dndTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: dndTile.active ? "Silenced" : "Alerts On"; color: dndTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: dndMa
                                anchors.fill: parent
                                onClicked: {
                                    Quickshell.execDetached(["quickshell", "-p", "/usr/share/omarchy/shell", "ipc", "call", "notifications", "toggleDnd"])
                                    root.notifSilenced = !root.notifSilenced
                                }
                            }
                        }

                        // Eye Comfort Tile
                        Rectangle {
                            id: nightTile
                            property bool active: false
                            
                            Process {
                                running: true
                                command: ["bash", "-c", "pgrep -x hyprsunset > /dev/null && echo 'on' || echo 'off'"]
                                stdout: StdioCollector {
                                    onStreamFinished: nightTile.active = (this.text.trim() === "on")
                                }
                            }

                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color01 : root.fillIdle
                            scale: nightMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: "nightlight_round"; color: nightTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Night Light"; color: nightTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: nightTile.active ? "Warm" : "Off"; color: nightTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: nightMa
                                anchors.fill: parent
                                onClicked: {
                                    if (nightTile.active) {
                                        Quickshell.execDetached(["killall", "hyprsunset"])
                                        nightTile.active = false
                                    } else {
                                        Quickshell.execDetached(["hyprsunset", "-t", "4000"])
                                        nightTile.active = true
                                    }
                                }
                            }
                        }

                        // Power Mode Tile
                        Rectangle {
                            id: powerTile
                            property bool active: false
                            
                            Process {
                                running: true
                                command: ["powerprofilesctl", "get"]
                                stdout: StdioCollector {
                                    onStreamFinished: powerTile.active = (this.text.trim() === "performance")
                                }
                            }

                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color02 : root.fillIdle
                            scale: powerMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: "bolt"; color: powerTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Power"; color: powerTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: powerTile.active ? "Performance" : "Balanced"; color: powerTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: powerMa
                                anchors.fill: parent
                                onClicked: {
                                    let newMode = powerTile.active ? "balanced" : "performance"
                                    Quickshell.execDetached(["powerprofilesctl", "set", newMode])
                                    powerTile.active = !powerTile.active
                                }
                            }
                        }

                        // Caffeine Tile
                        Rectangle {
                            id: coffeeTile
                            property bool active: false
                            
                            Process {
                                running: true
                                command: ["bash", "-c", "pgrep -f 'why=caffeine' > /dev/null && echo 'on' || echo 'off'"]
                                stdout: StdioCollector {
                                    onStreamFinished: coffeeTile.active = (this.text.trim() === "on")
                                }
                            }

                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color03 : root.fillIdle
                            scale: coffeeMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: "local_cafe"; color: coffeeTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Caffeine"; color: coffeeTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: coffeeTile.active ? "Awake" : "Sleepy"; color: coffeeTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: coffeeMa
                                anchors.fill: parent
                                onClicked: {
                                    if (coffeeTile.active) {
                                        Quickshell.execDetached(["pkill", "-f", "why=caffeine"])
                                        coffeeTile.active = false
                                    } else {
                                        Quickshell.execDetached(["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=caffeine", "sleep", "infinity"])
                                        coffeeTile.active = true
                                    }
                                }
                            }
                        }
                    }

                    // --- PAGE 3 ---
                    Item {
                        width: tilesPager.width
                        height: tilesPager.height
                        
                        // Big Pill (Temp)
                        Rectangle {
                            id: tempTile
                            x: 0
                            y: 0
                            width: (tilesPager.width - 12) / 2
                            height: 132
                            radius: 30
                            
                            property int currentTemp: 45
                            
                            color: {
                                if (currentTemp < 50) return Qt.rgba(0.2, 0.6, 0.8, 0.4) // Cool blue
                                if (currentTemp < 75) return Qt.rgba(0.9, 0.7, 0.2, 0.4) // Warm yellow/orange
                                return Qt.rgba(0.9, 0.2, 0.2, 0.4) // Hot red
                            }
                            Behavior on color { ColorAnimation { duration: 500 } }
                            
                            Process {
                                running: true
                                command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let t = parseInt(this.text.trim())
                                        if (!isNaN(t)) {
                                            tempTile.currentTemp = Math.round(t / 1000)
                                        }
                                    }
                                }
                            }
                            
                            Timer {
                                interval: 3000; repeat: true; running: true
                                onTriggered: {
                                    Quickshell.execDetached(["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp > /tmp/qt_temp"])
                                }
                            }
                            
                            // Better: Let's use a Process that is re-run by a Timer
                            Process {
                                id: tempUpdater
                                command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let t = parseInt(this.text.trim())
                                        if (!isNaN(t)) {
                                            tempTile.currentTemp = Math.round(t / 1000)
                                        }
                                    }
                                }
                            }
                            
                            Timer {
                                interval: 2000; repeat: true; running: true
                                onTriggered: { tempUpdater.running = false; tempUpdater.running = true }
                            }
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 16
                                IconText { 
                                    text: "thermostat"
                                    color: root.ink
                                    font.pixelSize: 42
                                    anchors.horizontalCenter: parent.horizontalCenter 
                                }
                                Text { 
                                    text: tempTile.currentTemp + "°C"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 24
                                    font.weight: Font.Bold
                                    anchors.horizontalCenter: parent.horizontalCenter 
                                }
                            }
                        }
                        
                        // Two small pills
                        Column {
                            x: (tilesPager.width + 12) / 2
                            y: 0
                            width: (tilesPager.width - 12) / 2
                            height: 132
                            spacing: 12
                            
                            // Extra 1
                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: 30
                                color: root.fillIdle
                                
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12
                                    
                                    IconText { text: "speed"; color: root.ink; font.pixelSize: 20 }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "CPU Clock"; color: root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold }
                                        Text { text: "3.4 GHz"; color: root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: 60 }
                                    }
                                }
                            }
                            
                            // Extra 2
                            Rectangle {
                                id: storageTile
                                width: parent.width
                                height: 60
                                radius: 30
                                color: root.fillIdle
                                scale: storageMa.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                
                                Process {
                                    running: true
                                    command: ["bash", "-c", "df -h / | awk 'NR==2{print $4}'"]
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            storageVal.text = this.text.trim() + " Free"
                                        }
                                    }
                                }
                                
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12
                                    
                                    IconText { text: "storage"; color: root.ink; font.pixelSize: 20 }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "Disk Space"; color: root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold }
                                        Text { id: storageVal; text: "Loading..."; color: root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: 60 }
                                    }
                                }
                                
                                MouseArea {
                                    id: storageMa
                                    anchors.fill: parent
                                    onClicked: {
                                        Quickshell.execDetached(["xdg-open", "/"])
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- MEDIA PLAYER ---
            Rectangle {
                width: parent.width
                height: 80
                radius: 30
                color: (mprisArt.dominantColor && String(mprisArt.dominantColor) !== "#00000000" && String(mprisArt.dominantColor) !== "transparent") 
                    ? Qt.rgba(mprisArt.dominantColor.r, mprisArt.dominantColor.g, mprisArt.dominantColor.b, 0.2) 
                    : root.fillIdle
                
                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    // Album Art
                    ClippingRectangle {
                        width: 56; height: 56; radius: 20
                        color: "transparent"
                        Image {
                            anchors.fill: parent
                            source: root.lastMediaArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        IconText {
                            anchors.centerIn: parent
                            text: "music_note"
                            color: root.ink
                            opacity: 0.3
                            font.pixelSize: 24
                            visible: parent.children[0].status !== Image.Ready
                        }
                    }
                    
                    // Info
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 56 - 12 - 12 - 100 // Space for controls
                        Text {
                            text: root.lastMediaTitle || "No media"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: root.lastMediaArtist || "Unknown"
                                color: root.ink
                                opacity: 0.7
                                font.family: root.barFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width - (lastPlayedLbl.visible ? lastPlayedLbl.width + 6 : 0))
                            }
                            Rectangle {
                                id: lastPlayedLbl
                                visible: dashboardContent.curTitle === "" && root.lastMediaTitle !== ""
                                width: lblTxt.implicitWidth + 8
                                height: 14
                                radius: 4
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: lblTxt
                                    anchors.centerIn: parent
                                    text: "LAST PLAYED"
                                    color: root.ink
                                    opacity: 0.8
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                    
                    // Controls
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        IconText {
                            text: "skip_previous"
                            color: root.ink; font.pixelSize: 24
                            MouseArea { anchors.fill: parent; onClicked: if (mprisSel.player) mprisSel.player.previous() }
                        }
                        IconText {
                            text: mprisSel.playing ? "pause" : "play_arrow"
                            color: root.ink; font.pixelSize: 28
                            MouseArea { anchors.fill: parent; onClicked: if (mprisSel.player) mprisSel.player.togglePlaying() }
                        }
                        IconText {
                            text: "skip_next"
                            color: root.ink; font.pixelSize: 24
                            MouseArea { anchors.fill: parent; onClicked: if (mprisSel.player) mprisSel.player.next() }
                        }
                    }
                }
            }
        }

        // RIGHT COLUMN (60%): Process Monitor
        Rectangle {
            width: parent.width * 0.6 - 8
            height: parent.height
            radius: 20
            color: root.fillIdle
            clip: true
            
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text {
                    text: "PROCESS MONITOR"
                    color: root.ink
                    opacity: 0.5
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                
                ListView {
                    width: parent.width
                    height: parent.height - 20
                    model: procModel
                    clip: true
                    spacing: 8
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 48
                        radius: 12
                        color: killHover.containsMouse ? Qt.rgba(1, 0, 0, 0.1) : root.fillHover
                        clip: true
                        
                        // Bar chart background
                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width * (Math.min(100, parseInt(model.cpu)) / 100)
                            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.4)
                            radius: 12
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        }

                        // The close button
                        Rectangle {
                            id: killBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: killRow.width + 16
                            height: 32; radius: 16
                            color: killHover.containsMouse ? "#ff4444" : "transparent"
                            
                            Row {
                                id: killRow
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "close"
                                    color: killHover.containsMouse ? "white" : root.ink
                                    font.pixelSize: 16
                                    opacity: killHover.containsMouse ? 1.0 : 0.6
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Stop"
                                    color: killHover.containsMouse ? "white" : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    opacity: killHover.containsMouse ? 1.0 : 0.6
                                }
                            }
                            Process {
                                id: killProc
                                command: ["kill", "-9", model.pid]
                                running: false
                            }
                            MouseArea {
                                id: killHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { killProc.running = false; killProc.running = true }
                            }
                        }
                        
                        // Text info
                        Column {
                            anchors.left: parent.left
                            anchors.right: killBtn.left
                            anchors.leftMargin: 16
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    text: model.name
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, parent.width - 55)
                                }
                                Text {
                                    text: "•"
                                    color: root.ink
                                    opacity: 0.6
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: model.cpu
                                    color: root.ink
                                    opacity: 0.8
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }
                            Text {
                                text: "PID: " + model.pid
                                color: root.ink
                                opacity: 0.6
                                font.family: root.barFont
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
            
            ListModel { id: procModel }
            
            Process {
                id: procUpdater
                running: panel.expanded
                command: ["bash", "-c", "ps -eo pid,pcpu,comm --sort=-pcpu | head -n 10 | tail -n 9"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        var lines = this.text.split("\n")
                        procModel.clear()
                        for (var i = 0; i < lines.length; i++) {
                            var line = lines[i].trim()
                            if (line === "") continue
                            var parts = line.split(/\s+/)
                            if (parts.length >= 3) {
                                procModel.append({
                                    pid: parts[0],
                                    cpu: Math.round(parseFloat(parts[1])) + "%",
                                    name: parts.slice(2).join(" ")
                                })
                            }
                        }
                    }
                }
            }
            Timer {
                interval: 3000; repeat: true; running: panel.expanded
                onTriggered: { procUpdater.running = false; procUpdater.running = true }
            }
        }
    }
}
