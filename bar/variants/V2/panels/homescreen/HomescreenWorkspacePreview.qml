import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland
import "../../modules"

Item {
    id: wsPreviewRoot
    anchors.fill: parent
    focus: true

    property var root: null
    property var panel: null
    property var dashboardContent: null

    signal closeRequested()

    // ── Theme & Font references ──
    readonly property var theme: root || (dashboardContent ? dashboardContent.root : null)
    readonly property string fontFam: (theme && theme.barFont) ? theme.barFont : "Genova"
    readonly property color sealColor: (theme && theme.seal) ? theme.seal : "#22d3ee"
    readonly property color inkColor: (theme && theme.ink) ? theme.ink : "#ffffff"
    readonly property color sumiColor: (theme && theme.sumi) ? theme.sumi : "#9ca3af"
    readonly property color paperColor: (theme && theme.paper) ? theme.paper : "#12131a"
    readonly property color fillIdleColor: (theme && theme.fillIdle) ? theme.fillIdle : Qt.rgba(1, 1, 1, 0.08)
    readonly property color fillHoverColor: (theme && theme.fillHover) ? theme.fillHover : Qt.rgba(1, 1, 1, 0.14)

    property var clientsData: []
    property int targetWorkspaceId: (theme && theme.workspaceTargetId && theme.workspaceTargetId > 0)
        ? theme.workspaceTargetId
        : ((Hyprland && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace.id : 1)

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            refreshClients()
        }
    }

    Component.onCompleted: {
        forceActiveFocus()
        refreshClients()
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text)
                    if (Array.isArray(parsed)) {
                        wsPreviewRoot.clientsData = parsed
                    }
                } catch(e) {}
            }
        }
    }

    function refreshClients() {
        if (!clientsProc.running) {
            clientsProc.running = true
        }
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onFocusedWorkspaceChanged() {
            if ((!theme || !theme.workspaceTargetId || theme.workspaceTargetId <= 0) && Hyprland && Hyprland.focusedWorkspace) {
                wsPreviewRoot.targetWorkspaceId = Hyprland.focusedWorkspace.id
            }
            refreshClients()
        }
        function onWorkspacesChanged() {
            refreshClients()
        }
    }

    Connections {
        target: wsPreviewRoot.theme ? wsPreviewRoot.theme : null
        ignoreUnknownSignals: true
        function onWorkspaceTargetIdChanged() {
            if (wsPreviewRoot.theme && wsPreviewRoot.theme.workspaceTargetId > 0) {
                wsPreviewRoot.targetWorkspaceId = wsPreviewRoot.theme.workspaceTargetId
            }
        }
    }

    // Monitor resolution calculations
    readonly property real monWidth: (Hyprland && Hyprland.focusedMonitor && Hyprland.focusedMonitor.width > 0)
        ? Hyprland.focusedMonitor.width : 1920
    readonly property real monHeight: (Hyprland && Hyprland.focusedMonitor && Hyprland.focusedMonitor.height > 0)
        ? Hyprland.focusedMonitor.height : 1080
    readonly property real monScale: (Hyprland && Hyprland.focusedMonitor && Hyprland.focusedMonitor.scale > 0)
        ? Hyprland.focusedMonitor.scale : 1.0

    readonly property real logicalWidth: Math.round(monWidth / monScale)
    readonly property real logicalHeight: Math.round(monHeight / monScale)

    // Build list of active workspaces
    readonly property var workspaceList: {
        if (theme && theme.getSortedWorkspacesList) {
            return theme.getSortedWorkspacesList()
        }
        let occupied = {}
        if (clientsData && clientsData.length > 0) {
            for (let i = 0; i < clientsData.length; i++) {
                let ws = clientsData[i].workspace
                if (ws && ws.id > 0) occupied[ws.id] = true
            }
        }
        let allIds = {}
        if (Hyprland && Hyprland.workspaces && Hyprland.workspaces.values) {
            let hw = Hyprland.workspaces.values
            for (let j = 0; j < hw.length; j++) {
                if (hw[j].id > 0) allIds[hw[j].id] = true
            }
        }
        if (Hyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) {
            allIds[Hyprland.focusedWorkspace.id] = true
        }

        let arr = Object.keys(allIds).map(Number).sort((a, b) => a - b)
        if (arr.length === 0) arr = [1]

        let hasEmpty = false
        for (let k = 0; k < arr.length; k++) {
            if (!occupied[arr[k]]) {
                hasEmpty = true
                break
            }
        }

        if (!hasEmpty) {
            let nextEmpty = 1
            while (allIds[nextEmpty]) nextEmpty++
            arr.push(nextEmpty)
            arr.sort((a, b) => a - b)
        }

        return arr
    }

    function getClientsForWorkspace(wsId) {
        if (!clientsData || clientsData.length === 0) return []
        let res = []
        for (let i = 0; i < clientsData.length; i++) {
            let c = clientsData[i]
            if (c.workspace && c.workspace.id === wsId && !c.hidden) {
                res.push(c)
            }
        }
        return res
    }

    function resolveAppIcon(cls, initCls) {
        let name = (cls || initCls || "").toLowerCase()
        if (name === "") return ""
        let fallback = "application-x-executable"
        if (name.includes("zen")) return Quickshell.iconPath("zen-browser", "web-browser")
        if (name.includes("chrome") || name.includes("brave")) return Quickshell.iconPath("google-chrome", "web-browser")
        if (name.includes("firefox")) return Quickshell.iconPath("firefox", "web-browser")
        if (name.includes("kitty") || name.includes("terminal") || name.includes("alacritty")) return Quickshell.iconPath("terminal", "utilities-terminal")
        if (name.includes("code") || name.includes("vsc")) return Quickshell.iconPath("code", "text-editor")
        if (name.includes("spotify")) return Quickshell.iconPath("spotify", "audio-player")
        if (name.includes("discord")) return Quickshell.iconPath("discord", "chat")
        if (name.includes("blender")) return Quickshell.iconPath("blender", fallback)
        if (name.includes("obsidian")) return Quickshell.iconPath("obsidian", "text-editor")
        if (name.includes("nautilus") || name.includes("thunar") || name.includes("files")) return Quickshell.iconPath("system-file-manager", "folder")
        if (name.includes("godot")) return Quickshell.iconPath("godot", fallback)

        let p = Quickshell.iconPath(name, fallback)
        return p || ""
    }

    function nextWorkspace() {
        if (theme && theme.switchWorkspace) {
            theme.switchWorkspace("next")
            return
        }
        let list = workspaceList
        let curIdx = list.indexOf(targetWorkspaceId)
        let nextIdx = (curIdx + 1) % list.length
        targetWorkspaceId = list[nextIdx]
        if (theme && theme.gotoWorkspace) theme.gotoWorkspace(targetWorkspaceId)
    }

    function prevWorkspace() {
        if (theme && theme.switchWorkspace) {
            theme.switchWorkspace("prev")
            return
        }
        let list = workspaceList
        let curIdx = list.indexOf(targetWorkspaceId)
        let prevIdx = (curIdx - 1 + list.length) % list.length
        targetWorkspaceId = list[prevIdx]
        if (theme && theme.gotoWorkspace) theme.gotoWorkspace(targetWorkspaceId)
    }

    function switchAndClose(wsId) {
        if (theme) {
            if (theme.gotoWorkspace) theme.gotoWorkspace(wsId)
            if (theme.finishWorkspaceSwitch) theme.finishWorkspaceSwitch()
            else {
                theme.dashboardExpanded = false
                theme.dashboardDetail = ""
            }
        }
        closeRequested()
    }

    function selectAndClose() {
        switchAndClose(targetWorkspaceId)
    }

    function close() {
        if (theme && theme.finishWorkspaceSwitch) {
            theme.finishWorkspaceSwitch()
        } else if (theme) {
            theme.dashboardExpanded = false
            theme.dashboardDetail = ""
        }
        closeRequested()
    }

    // Keyboard navigation
    Keys.onTabPressed: (event) => { nextWorkspace(); event.accepted = true }
    Keys.onBacktabPressed: (event) => { prevWorkspace(); event.accepted = true }
    Keys.onRightPressed: (event) => { nextWorkspace(); event.accepted = true }
    Keys.onLeftPressed: (event) => { prevWorkspace(); event.accepted = true }
    Keys.onReturnPressed: (event) => { selectAndClose(); event.accepted = true }
    Keys.onEnterPressed: (event) => { selectAndClose(); event.accepted = true }
    Keys.onSpacePressed: (event) => { selectAndClose(); event.accepted = true }
    Keys.onEscapePressed: (event) => { close(); event.accepted = true }

    // ── TOP HEADER (Minimal, clean, no clutter) ──
    Item {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            IconText {
                text: "view_carousel"
                color: wsPreviewRoot.sealColor
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Workspaces"
                color: wsPreviewRoot.inkColor
                font.family: wsPreviewRoot.fontFam
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Tab to cycle • Esc to close"
            color: wsPreviewRoot.sumiColor
            font.family: wsPreviewRoot.fontFam
            font.pixelSize: 10
            opacity: 0.7
        }
    }

    // ── WORKSPACES ROW (Fills full width of dashboard, no outer bg, no gradients, no borders) ──
    Item {
        id: cardsContainer
        anchors.top: headerBar.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        readonly property int cardCount: Math.max(1, wsPreviewRoot.workspaceList.length)
        readonly property real cardSpacing: 10
        readonly property real computedCardWidth: Math.floor((width - (cardSpacing * (cardCount - 1))) / cardCount)

        Row {
            anchors.fill: parent
            spacing: cardsContainer.cardSpacing

            Repeater {
                model: wsPreviewRoot.workspaceList

                delegate: Item {
                    id: cardDelegate
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property bool isTarget: wsPreviewRoot.targetWorkspaceId === wsId
                    readonly property bool isCurrentWs: (Hyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId)
                    readonly property var clients: wsPreviewRoot.getClientsForWorkspace(wsId)
                    readonly property bool hasClients: clients && clients.length > 0
                    readonly property string primaryAppName: {
                        if (!hasClients) return "Empty"
                        let first = clients[0].class || clients[0].initialClass || "Window"
                        return first.charAt(0).toUpperCase() + first.slice(1)
                    }

                    width: cardsContainer.computedCardWidth
                    height: parent.height

                    // ── Card Surface: Clean, flat, borderless ──
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        border.width: 0
                        color: isTarget
                            ? Qt.rgba(wsPreviewRoot.sealColor.r, wsPreviewRoot.sealColor.g, wsPreviewRoot.sealColor.b, 0.20)
                            : (cardMa.containsMouse ? wsPreviewRoot.fillHoverColor : wsPreviewRoot.fillIdleColor)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // Header: Workspace number + app name
                            Row {
                                width: parent.width
                                height: 22
                                spacing: 8

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    border.width: 0
                                    color: isTarget ? wsPreviewRoot.sealColor : Qt.rgba(wsPreviewRoot.inkColor.r, wsPreviewRoot.inkColor.g, wsPreviewRoot.inkColor.b, 0.12)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: String(wsId)
                                        color: isTarget ? wsPreviewRoot.paperColor : wsPreviewRoot.inkColor
                                        font.family: wsPreviewRoot.fontFam
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    text: primaryAppName
                                    color: wsPreviewRoot.inkColor
                                    font.family: wsPreviewRoot.fontFam
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width - 30 - (countText.visible ? countText.implicitWidth + 6 : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    id: countText
                                    visible: hasClients && clients.length > 1
                                    text: "+" + (clients.length - 1)
                                    color: wsPreviewRoot.sumiColor
                                    font.family: wsPreviewRoot.fontFam
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Viewport: Clean, flat desktop preview (no border)
                            Rectangle {
                                id: miniViewport
                                width: parent.width
                                height: parent.height - 22 - 20 - 16
                                radius: 10
                                clip: true
                                border.width: 0
                                color: Qt.rgba(0, 0, 0, 0.22)

                                // Window rectangles
                                Repeater {
                                    model: clients

                                    delegate: Rectangle {
                                        required property var modelData

                                        readonly property real rx: Math.max(3, Math.round(((modelData.at && modelData.at[0] !== undefined ? modelData.at[0] : 0) / wsPreviewRoot.logicalWidth) * miniViewport.width))
                                        readonly property real ry: Math.max(3, Math.round(((modelData.at && modelData.at[1] !== undefined ? modelData.at[1] : 0) / wsPreviewRoot.logicalHeight) * miniViewport.height))
                                        readonly property real rw: Math.max(16, Math.min(miniViewport.width - rx - 3, Math.round(((modelData.size && modelData.size[0] !== undefined ? modelData.size[0] : 100) / wsPreviewRoot.logicalWidth) * miniViewport.width)))
                                        readonly property real rh: Math.max(14, Math.min(miniViewport.height - ry - 3, Math.round(((modelData.size && modelData.size[1] !== undefined ? modelData.size[1] : 100) / wsPreviewRoot.logicalHeight) * miniViewport.height)))

                                        x: rx
                                        y: ry
                                        width: rw
                                        height: rh
                                        radius: 4
                                        border.width: 0

                                        readonly property bool isWinFocused: modelData.focusHistoryID === 0
                                        color: isWinFocused
                                            ? Qt.rgba(wsPreviewRoot.sealColor.r, wsPreviewRoot.sealColor.g, wsPreviewRoot.sealColor.b, 0.40)
                                            : Qt.rgba(wsPreviewRoot.inkColor.r, wsPreviewRoot.inkColor.g, wsPreviewRoot.inkColor.b, 0.14)

                                        Image {
                                            id: winIconImg
                                            anchors.centerIn: parent
                                            width: Math.min(parent.width - 4, 14)
                                            height: Math.min(parent.height - 4, 14)
                                            fillMode: Image.PreserveAspectFit
                                            sourceSize.width: 14
                                            sourceSize.height: 14
                                            visible: width >= 10 && height >= 10 && source !== ""
                                            source: wsPreviewRoot.resolveAppIcon(modelData.class, modelData.initialClass)
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: (!winIconImg.visible || winIconImg.status === Image.Error) && parent.width >= 12
                                            text: {
                                                let s = modelData.class || modelData.title || ""
                                                return s.length > 0 ? s.charAt(0).toUpperCase() : ""
                                            }
                                            color: isWinFocused ? wsPreviewRoot.sealColor : wsPreviewRoot.inkColor
                                            font.family: wsPreviewRoot.fontFam
                                            font.pixelSize: 9
                                            font.bold: true
                                            opacity: 0.85
                                        }
                                    }
                                }

                                // Empty state
                                Text {
                                    anchors.centerIn: parent
                                    visible: !hasClients
                                    text: "Empty"
                                    color: wsPreviewRoot.sumiColor
                                    font.family: wsPreviewRoot.fontFam
                                    font.pixelSize: 11
                                    opacity: 0.55
                                }
                            }

                            // Footer: Minimal indicator or apps
                            Item {
                                width: parent.width
                                height: 20

                                Text {
                                    visible: isTarget
                                    anchors.centerIn: parent
                                    text: isCurrentWs ? "Active" : "Switch to"
                                    color: wsPreviewRoot.sealColor
                                    font.family: wsPreviewRoot.fontFam
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                Row {
                                    visible: !isTarget && hasClients
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Repeater {
                                        model: clients.slice(0, 4)

                                        delegate: Image {
                                            required property var modelData
                                            width: 14
                                            height: 14
                                            fillMode: Image.PreserveAspectFit
                                            sourceSize.width: 14
                                            sourceSize.height: 14
                                            source: wsPreviewRoot.resolveAppIcon(modelData.class, modelData.initialClass)
                                            opacity: 0.7
                                        }
                                    }
                                }

                                Text {
                                    visible: !isTarget && !hasClients
                                    anchors.centerIn: parent
                                    text: "Available"
                                    color: wsPreviewRoot.sumiColor
                                    font.family: wsPreviewRoot.fontFam
                                    font.pixelSize: 10
                                    opacity: 0.6
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wsPreviewRoot.switchAndClose(wsId)
                        }
                    }
                }
            }
        }
    }
}
