import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: notifSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property string viewMode: "active" // "active" or "history"
    property bool isDnd: false
    property var activeList: []
    property var historyList: []

    readonly property var currentList: viewMode === "active" ? activeList : historyList
    readonly property int unreadCount: activeList.length

    // Polling process for notifications
    Process {
        id: notifStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/get_notifications.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    notifSection.isDnd = (d.dnd === "on")
                    notifSection.activeList = d.active || []
                    notifSection.historyList = d.history || []
                    if (notifSection.root) {
                        notifSection.root.notifCount = notifSection.activeList.length
                    }
                } catch(e) {}
            }
        }
    }

    // Action process (dismiss, clear, dnd)
    Process {
        id: notifActionProc
        stdout: StdioCollector {
            onStreamFinished: {
                notifStatusProc.running = false
                notifStatusProc.running = true
            }
        }
    }

    function poll() {
        notifStatusProc.running = false
        notifStatusProc.running = true
    }

    function doToggleDnd() {
        notifActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/get_notifications.py", "toggle_dnd"]
        notifActionProc.running = false
        notifActionProc.running = true
    }

    function doClearAll() {
        if (viewMode === "active") {
            notifActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/get_notifications.py", "clear_all"]
        } else {
            notifActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/get_notifications.py", "clear_history"]
        }
        notifActionProc.running = false
        notifActionProc.running = true
    }

    function doDismissOne(filePath) {
        if (!filePath) return
        notifActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/get_notifications.py", "dismiss", filePath]
        notifActionProc.running = false
        notifActionProc.running = true
    }

    function doInvoke(notif) {
        if (!notif) return
        let nid = notif.id || 0
        Quickshell.execDetached(["quickshell", "-p", "/usr/share/omarchy/shell", "ipc", "call", "notifications", "invoke", String(nid)])
        if (notif.filePath) {
            doDismissOne(notif.filePath)
        }
    }

    function formatTimeAgo(ts) {
        if (!ts) return ""
        let now = Date.now()
        let diffMs = Math.max(0, now - Number(ts))
        let diffSec = Math.floor(diffMs / 1000)
        if (diffSec < 60) return "Just Now"
        let diffMin = Math.floor(diffSec / 60)
        if (diffMin < 60) return diffMin + "m Ago"
        let diffHours = Math.floor(diffMin / 60)
        if (diffHours < 24) return diffHours + "h Ago"
        let diffDays = Math.floor(diffHours / 24)
        return diffDays + "d Ago"
    }

    function formatTitleCase(str) {
        if (!str) return ""
        return String(str).replace(/\w\S*/g, function(txt) {
            return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
        })
    }

    function formatSentenceCase(str) {
        if (!str) return ""
        let s = String(str).trim()
        if (s.length === 0) return ""
        if (s.length > 1 && s === s.toUpperCase()) {
            s = s.toLowerCase()
        }
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function formatNotificationBody(str) {
        if (!str) return ""
        let s = String(str).replace(/<a\b[^>]*>(.*?)<\/a>/gi, "$1")
                           .replace(/<br\s*\/?>/gi, " ")
                           .replace(/<[^>]*>/g, "")
                           .trim()
        if (s.length === 0) return ""
        if (s.length > 1 && s === s.toUpperCase()) {
            s = s.toLowerCase()
        }
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    Timer {
        interval: 3000
        repeat: true
        running: notifSection.visible
        onTriggered: notifSection.poll()
    }

    onVisibleChanged: {
        if (visible) notifSection.poll()
    }

    // Connections to root notifications events
    Connections {
        target: notifSection.root
        ignoreUnknownSignals: true
        function onNotifPeekTickChanged() { notifSection.poll() }
        function onNotifPeekDismissTickChanged() { notifSection.poll() }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Matches Calendar Widget Design) ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: NOTIFICATION CONTROL & STATUS WIDGET ────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Top Bar
            Item {
                id: leftTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26

                // Tab switcher [ Active | History ]
                PillTabs {
                    id: tabPill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root
                    model: [ { id: "active", label: "Active" }, { id: "history", label: "History" } ]
                    current: notifSection.viewMode
                    onActivated: (id) => notifSection.viewMode = id
                }

                // DND Status Pill Badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    width: dndBadgeText.implicitWidth + 16
                    radius: 11
                    color: notifSection.isDnd ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    Text {
                        id: dndBadgeText
                        anchors.centerIn: parent
                        text: notifSection.isDnd ? "DND On" : "DND Off"
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: notifSection.isDnd ? root.paper : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                    }
                }
            }

            // Central Status & Controls Area
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 6
                width: parent.width - 32
                spacing: 12

                // Bell Icon Circle
                Rectangle {
                    width: 58
                    height: 58
                    radius: 29
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: notifSection.unreadCount > 0 ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    border.width: 0

                    IconText {
                        anchors.centerIn: parent
                        text: notifSection.isDnd ? "\uE7F6" : "\uE7F4"
                        font.pixelSize: 26
                        color: notifSection.unreadCount > 0 ? root.seal : root.ink
                    }
                }

                // Title & Subtitle
                Column {
                    width: parent.width
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Notifications"
                        font.family: root.barFont
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: root.ink
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: notifSection.unreadCount > 0
                            ? (notifSection.unreadCount + (notifSection.unreadCount === 1 ? " Active Notification" : " Active Notifications"))
                            : (notifSection.isDnd ? "Do Not Disturb Enabled" : "All Caught Up")
                        font.family: root.barFont
                        font.pixelSize: 11
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                    }
                }

                // Quick Action Buttons
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    topPadding: 4

                    // DND Toggle Button
                    Rectangle {
                        width: Math.max(120, dndBtnRow.implicitWidth + 24)
                        height: 32
                        radius: 16
                        color: dndBtnMa.containsMouse ? root.fillHover : (notifSection.isDnd ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08))
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: dndBtnRow
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: notifSection.isDnd ? "\uE7F6" : "\uE7F4"
                                font.pixelSize: 14
                                color: notifSection.isDnd ? root.paper : root.ink
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: notifSection.isDnd ? "Do Not Disturb On" : "Do Not Disturb"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: notifSection.isDnd ? root.paper : root.ink
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: dndBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notifSection.doToggleDnd()
                        }
                    }

                    // Clear All Button
                    Rectangle {
                        width: 100
                        height: 32
                        radius: 16
                        border.width: 0
                        enabled: notifSection.currentList.length > 0
                        opacity: enabled ? 1.0 : 0.4
                        color: clearBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "delete_sweep"
                                font.pixelSize: 15
                                color: root.ink
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Clear All"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: root.ink
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: clearBtnMa
                            anchors.fill: parent
                            hoverEnabled: parent.enabled
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: notifSection.doClearAll()
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: NOTIFICATION LIST (Scrollable Material You Cards) ──
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Header Bar
            Item {
                id: listHeader
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: notifSection.viewMode === "active" ? "Active Notifications" : "Notification History"
                    font.family: root.barFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.ink
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: notifSection.currentList.length + " Total"
                    font.family: root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                }
            }

            // Scrollable Notifications List
            ListView {
                id: notifListView
                anchors.top: listHeader.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds

                model: notifSection.currentList

                delegate: Rectangle {
                    id: notifItemCard
                    width: notifListView.width
                    height: notifCardRow.implicitHeight + 16
                    radius: 14
                    color: notifCardMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: notifCardRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        spacing: 10

                        // App Icon / Glyph Badge
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                            border.width: 0

                            Image {
                                anchors.fill: parent
                                anchors.margins: 4
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                visible: !!modelData.appIcon && (modelData.appIcon.startsWith("file://") || modelData.appIcon.startsWith("/"))
                                source: (modelData.appIcon && (modelData.appIcon.startsWith("file://") || modelData.appIcon.startsWith("/"))) ? modelData.appIcon : ""
                            }

                            IconText {
                                anchors.centerIn: parent
                                visible: !modelData.appIcon || (!modelData.appIcon.startsWith("file://") && !modelData.appIcon.startsWith("/"))
                                text: {
                                    let app = String(modelData.app || "").toLowerCase()
                                    if (app.indexOf("kitty") >= 0 || app.indexOf("term") >= 0) return "terminal"
                                    if (app.indexOf("chrom") >= 0 || app.indexOf("browser") >= 0) return "public"
                                    if (app.indexOf("shot") >= 0 || app.indexOf("omarchy") >= 0) return "screenshot"
                                    return "notifications"
                                }
                                font.pixelSize: 15
                                color: root.seal
                            }
                        }

                        // Text Column (App + Summary + Body)
                        Column {
                            width: parent.width - 32 - 28 - parent.spacing * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: notifSection.formatTitleCase(modelData.app || "Notification")
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.seal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "·"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                                }

                                Text {
                                    text: notifSection.formatTimeAgo(modelData.timestamp)
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                                }
                            }

                            Text {
                                width: parent.width
                                text: notifSection.formatTitleCase(modelData.summary || "")
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.ink
                                elide: Text.ElideRight
                                visible: (modelData.summary || "") !== ""
                            }

                            Text {
                                width: parent.width
                                text: notifSection.formatNotificationBody(modelData.body || "")
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                linkColor: root.seal
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                visible: (modelData.body || "") !== ""
                            }
                        }

                        // Dismiss button ('×')
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: dismissMa.containsMouse ? root.fillHover : "transparent"
                            border.width: 0

                            IconText {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 14
                                color: dismissMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                            }

                            SpringPress {}
                            MouseArea {
                                id: dismissMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notifSection.doDismissOne(modelData.filePath)
                                }
                            }
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: notifCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            notifSection.doInvoke(modelData)
                        }
                    }
                }
            }

            // Empty State
            Column {
                anchors.centerIn: parent
                visible: notifSection.currentList.length === 0
                spacing: 8

                IconText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "mark_email_read"
                    font.pixelSize: 34
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.6)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: notifSection.viewMode === "active" ? "No Active Notifications" : "No Notification History"
                    font.family: root.barFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: root.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "You're all caught up"
                    font.family: root.barFont
                    font.pixelSize: 10
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                }
            }
        }
    }
}
