import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: lockscreenSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    // Config state
    property string clockStyle: "stacked"
    property bool blurBackground: true
    property int blurRadius: 32
    property real darkenOverlay: 0.45
    property bool showMedia: true
    property bool showBattery: true
    property bool showDate: true

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/lock/config.json"

    FileView {
        id: cfgFile
        path: lockscreenSection.configPath
        printErrors: false
        onLoaded: {
            try {
                var raw = String(cfgFile.text() || "").trim()
                if (raw) {
                    var c = JSON.parse(raw)
                    if (c.clockStyle !== undefined) lockscreenSection.clockStyle = c.clockStyle
                    if (c.blurBackground !== undefined) lockscreenSection.blurBackground = c.blurBackground
                    if (c.blurRadius !== undefined) lockscreenSection.blurRadius = c.blurRadius
                    if (c.darkenOverlay !== undefined) lockscreenSection.darkenOverlay = c.darkenOverlay
                    if (c.showMedia !== undefined) lockscreenSection.showMedia = c.showMedia
                    if (c.showBattery !== undefined) lockscreenSection.showBattery = c.showBattery
                    if (c.showDate !== undefined) lockscreenSection.showDate = c.showDate
                }
            } catch (e) {
                console.log("Error parsing lock config:", e)
            }
        }
    }

    FontLoader {
        id: biggerFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Unknown Vendor/OpenType/Bigger/Bigger_Display.otf"
    }

    function saveConfig() {
        var obj = {
            "clockStyle": clockStyle,
            "blurBackground": blurBackground,
            "blurRadius": blurRadius,
            "darkenOverlay": darkenOverlay,
            "showMedia": showMedia,
            "showBattery": showBattery,
            "showDate": showDate
        }
        var str = JSON.stringify(obj, null, 2)
        Quickshell.execDetached(["python3", "-c", "import sys, json; open('" + configPath + "', 'w').write(sys.argv[1])", str])
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ── TOP HEADER ROW: TITLE PILL · CLOSE BUTTON ────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36

        // Left Title Pill
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: 16
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
            width: titleRow.implicitWidth + 24

            Row {
                id: titleRow
                anchors.centerIn: parent
                spacing: 8

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock"
                    font.pixelSize: 16
                    color: root.seal
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Lock Screen Settings"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        // Close Button
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: closeMa.containsMouse ? root.fillHover : root.fillIdle
            Behavior on color { ColorAnimation { duration: 140 } }

            IconText {
                anchors.centerIn: parent
                text: "close"
                color: root.ink
                font.pixelSize: 16
            }

            SpringPress {}
            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: lockscreenSection.closeRequested()
            }
        }
    }

    // ── TWO-COLUMN DASHBOARD LAYOUT ──
    Row {
        id: columnsRow
        anchors.top: headerBar.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: LOCK ACTIONS & QUICK CONFIG ─────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: leftContentCol.implicitHeight + 10
                clip: true

                Column {
                    id: leftContentCol
                    width: parent.width
                    spacing: 12

                    // Primary Lock Now Action Pill Button
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 26
                        color: lockNowMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            spacing: 12

                            IconText {
                                text: "lock"
                                font.pixelSize: 22
                                color: root.paper
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: "Lock Screen Now"
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.paper
                                }
                                Text {
                                    text: "Super + Shift + L"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: root.paper
                                    opacity: 0.8
                                }
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: lockNowMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root) root.dashboardExpanded = false
                                lockscreenSection.closeRequested()
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/bin/qs-lock"])
                            }
                        }
                    }

                    // Section: Clock Style Pills
                    Column {
                        width: parent.width
                        spacing: 6

                        Text {
                            text: "Clock Typography"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.ink
                            opacity: 0.75
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            // Stacked Pill Option
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 40
                                radius: 20
                                color: lockscreenSection.clockStyle === "stacked"
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                    : (stackedMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06))
                                border.color: lockscreenSection.clockStyle === "stacked" ? root.seal : "transparent"
                                border.width: 1.5

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    IconText {
                                        text: "view_agenda"
                                        font.pixelSize: 16
                                        color: lockscreenSection.clockStyle === "stacked" ? root.seal : root.ink
                                    }
                                    Text {
                                        text: "Stacked"
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: lockscreenSection.clockStyle === "stacked" ? root.seal : root.ink
                                    }
                                }

                                MouseArea {
                                    id: stackedMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lockscreenSection.clockStyle = "stacked"
                                        lockscreenSection.saveConfig()
                                    }
                                }
                            }

                            // Inline Pill Option
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 40
                                radius: 20
                                color: lockscreenSection.clockStyle === "inline"
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                    : (inlineMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06))
                                border.color: lockscreenSection.clockStyle === "inline" ? root.seal : "transparent"
                                border.width: 1.5

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    IconText {
                                        text: "schedule"
                                        font.pixelSize: 16
                                        color: lockscreenSection.clockStyle === "inline" ? root.seal : root.ink
                                    }
                                    Text {
                                        text: "Digital Cards"
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: lockscreenSection.clockStyle === "inline" ? root.seal : root.ink
                                    }
                                }

                                MouseArea {
                                    id: inlineMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lockscreenSection.clockStyle = "inline"
                                        lockscreenSection.saveConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Section: Dynamic Greeting Info Pill
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 24
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10

                            IconText {
                                text: "waving_hand"
                                font.pixelSize: 18
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: "Time of Day Greeting"
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: root.ink
                                }
                                Text {
                                    text: "Displays 'Good Morning/Evening, Hery'"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: root.ink
                                    opacity: 0.65
                                }
                            }
                        }
                    }

                    // Section: Dim Overlay Pills
                    Column {
                        width: parent.width
                        spacing: 6

                        Text {
                            text: "Background Fade Transition"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.ink
                            opacity: 0.75
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: [
                                    { label: "Pitch Black", val: 1.0 },
                                    { label: "Deep Charcoal", val: 0.85 },
                                    { label: "Dim Tint", val: 0.60 }
                                ]
                                delegate: Rectangle {
                                    width: (leftContentCol.width - 16) / 3
                                    height: 36
                                    radius: 18
                                    color: Math.abs(lockscreenSection.darkenOverlay - modelData.val) < 0.05
                                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                    border.color: Math.abs(lockscreenSection.darkenOverlay - modelData.val) < 0.05 ? root.seal : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: Math.abs(lockscreenSection.darkenOverlay - modelData.val) < 0.05 ? root.seal : root.ink
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            lockscreenSection.darkenOverlay = modelData.val
                                            lockscreenSection.saveConfig()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: INDICATORS & ANIMATION PREVIEW ─────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: rightContentCol.implicitHeight + 10
                clip: true

                Column {
                    id: rightContentCol
                    width: parent.width
                    spacing: 12

                    Text {
                        text: "Lockscreen Cards & Widgets"
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.ink
                        opacity: 0.75
                    }

                    // Toggle: Curved Calendar Ribbon Widget
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 24
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10

                            IconText {
                                text: "calendar_month"
                                font.pixelSize: 18
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Curved Calendar Widget"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38; height: 22; radius: 11
                            color: lockscreenSection.showDate ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.20)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: lockscreenSection.showDate ? (parent.width - width - 2) : 2
                                color: "#ffffff"
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    lockscreenSection.showDate = !lockscreenSection.showDate
                                    lockscreenSection.saveConfig()
                                }
                            }
                        }
                    }

                    // Toggle: Battery & Power Status
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 24
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10

                            IconText {
                                text: "battery_charging_full"
                                font.pixelSize: 18
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Battery & Charging State"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38; height: 22; radius: 11
                            color: lockscreenSection.showBattery ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.20)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: lockscreenSection.showBattery ? (parent.width - width - 2) : 2
                                color: "#ffffff"
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    lockscreenSection.showBattery = !lockscreenSection.showBattery
                                    lockscreenSection.saveConfig()
                                }
                            }
                        }
                    }

                    // Preview Card
                    Rectangle {
                        width: parent.width
                        height: 124
                        radius: 20
                        color: "#0a0a0c"
                        border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)
                        border.width: 1
                        clip: true

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "Good Morning, Hery"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.ink
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                spacing: 10
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Mini Clock Pill
                                Rectangle {
                                    width: lockscreenSection.clockStyle === "stacked" ? 70 : 90
                                    height: 54
                                    radius: 12
                                    color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.8)
                                    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                                    border.width: 1

                                    // Stacked View
                                    Column {
                                        visible: lockscreenSection.clockStyle === "stacked"
                                        anchors.centerIn: parent
                                        spacing: -5
                                        Text {
                                            text: "12"
                                            font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                            color: root.ink
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "31"
                                            font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                            color: root.ink
                                            opacity: 0.45
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    // Inline View
                                    Column {
                                        visible: lockscreenSection.clockStyle !== "stacked"
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            text: "12:31"
                                            font.family: root.barFont
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
                                            color: root.ink
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Clock"
                                            font.family: root.barFont
                                            font.pixelSize: 8
                                            color: root.seal
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                // Mini Calendar Pill
                                Rectangle {
                                    visible: lockscreenSection.showDate
                                    width: 86
                                    height: 54
                                    radius: 12
                                    color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.8)
                                    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                                    border.width: 1

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            text: "Oct 25"
                                            font.family: root.barFont
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: root.ink
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "Curved Ribbon"
                                            font.family: root.barFont
                                            font.pixelSize: 8
                                            color: root.seal
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
