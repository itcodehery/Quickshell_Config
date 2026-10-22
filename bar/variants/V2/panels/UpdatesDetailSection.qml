import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: updatesSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property string activeTab: (root && root.activeUpdateTab) ? root.activeUpdateTab : "packages"
    property string searchQuery: ""
    property bool refreshing: (root && root.archRefreshTick > 0) ? false : false

    readonly property var rawUpdates: (root && root.archUpdates) ? root.archUpdates : []

    readonly property var filteredUpdates: {
        var q = searchQuery.trim().toLowerCase()
        if (!q) return rawUpdates
        var res = []
        for (var i = 0; i < rawUpdates.length; i++) {
            var item = rawUpdates[i]
            var name = (item.name || "").toLowerCase()
            var repo = (item.repo || item.source || "").toLowerCase()
            if (name.indexOf(q) !== -1 || repo.indexOf(q) !== -1) {
                res.push(item)
            }
        }
        return res
    }

    readonly property int totalCount: rawUpdates.length
    readonly property int systemCount: {
        var n = 0
        for (var i = 0; i < rawUpdates.length; i++) {
            if (rawUpdates[i].source === "system" || rawUpdates[i].source !== "aur") n++
        }
        return n
    }
    readonly property int aurCount: {
        var n = 0
        for (var i = 0; i < rawUpdates.length; i++) {
            if (rawUpdates[i].source === "aur") n++
        }
        return n
    }

    readonly property int themeOutdated: (root && root.themeUpdOutdated) ? root.themeUpdOutdated : 0
    readonly property int shellBehind: (root && root.shellUpdateBehind) ? root.shellUpdateBehind : 0

    property string omarchyVersionStr: ""
    Process {
        id: verProc
        running: updatesSection.visible
        command: ["bash", "-c", "omarchy-version 2>/dev/null || cat /etc/omarchy-version 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                updatesSection.omarchyVersionStr = this.text.trim()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ── TOP HEADER ROW: TITLE · TABS · ACTION BUTTONS · CLOSE ────────────────
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
            width: titleRow.implicitWidth + 20

            Row {
                id: titleRow
                anchors.centerIn: parent
                spacing: 8

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "system_update"
                    font.pixelSize: 16
                    color: root.seal
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Software Updates"
                    font.family: root.barFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.ink
                }
            }
        }

        // Center: Segmented Tab Switcher [ Packages | Themes | Shell ]
        Rectangle {
            anchors.centerIn: parent
            height: 32
            radius: 16
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
            width: tabSwitcherRow.implicitWidth + 8

            Row {
                id: tabSwitcherRow
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [
                        { id: "packages", label: "Packages", badge: updatesSection.totalCount, icon: "package_2" },
                        { id: "themes",   label: "Themes",   badge: updatesSection.themeOutdated, icon: "palette" },
                        { id: "shell",    label: "Shell",    badge: updatesSection.shellBehind, icon: "terminal" }
                    ]

                    delegate: Rectangle {
                        id: tabItem
                        required property var modelData
                        readonly property bool isCur: updatesSection.activeTab === modelData.id
                        height: 26
                        width: Math.max(76, tabBtnRow.implicitWidth + 16)
                        radius: 13
                        color: isCur ? root.seal : (tabHov.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            id: tabBtnRow
                            anchors.centerIn: parent
                            spacing: 5

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabItem.modelData.icon
                                font.pixelSize: 12
                                color: tabItem.isCur ? root.paper : root.ink
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabItem.modelData.label
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: tabItem.isCur ? Font.Bold : Font.Medium
                                color: tabItem.isCur ? root.paper : root.ink
                            }

                            // Badge count pill
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: tabItem.modelData.badge > 0
                                height: 16
                                width: Math.max(16, badgeNum.implicitWidth + 8)
                                radius: 8
                                color: tabItem.isCur ? Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.28) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)

                                Text {
                                    id: badgeNum
                                    anchors.centerIn: parent
                                    text: String(tabItem.modelData.badge)
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: tabItem.isCur ? root.paper : root.seal
                                }
                            }
                        }

                        HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                updatesSection.activeTab = tabItem.modelData.id
                                if (updatesSection.root) updatesSection.root.activeUpdateTab = tabItem.modelData.id
                            }
                        }
                    }
                }
            }
        }

        // Right Actions: Refresh & Close Button
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Refresh Scan
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: refHov.hovered ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                IconText {
                    id: refIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    font.pixelSize: 16
                    color: refHov.hovered ? root.seal : root.ink

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                        running: updatesSection.refreshing
                    }
                }

                HoverHandler { id: refHov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        updatesSection.refreshing = true
                        if (updatesSection.root) updatesSection.root.archRefreshTick++
                        verProc.running = false
                        verProc.running = true
                        refreshResetTimer.restart()
                    }
                }
            }

            Timer {
                id: refreshResetTimer
                interval: 1500
                onTriggered: updatesSection.refreshing = false
            }

            // Close Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: closeHov.hovered ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                Behavior on color { ColorAnimation { duration: 120 } }

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 16
                    color: closeHov.hovered ? root.seal : root.ink
                }

                HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: updatesSection.closeRequested()
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ── TWO-COLUMN CONTENT AREA ──────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    Row {
        id: contentColumns
        anchors.top: headerBar.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: SYSTEM STATUS & QUICK ACTIONS ───────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftCard
            width: Math.max(260, Math.round(contentColumns.width * 0.35))
            height: contentColumns.height
            radius: 20
            color: root.fillIdle
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Status Hero Card
                Rectangle {
                    width: parent.width
                    height: 106
                    radius: 16
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width - 24

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8

                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                color: updatesSection.totalCount > 0
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                    : Qt.rgba(74/255, 222/255, 128/255, 0.18)

                                IconText {
                                    anchors.centerIn: parent
                                    text: updatesSection.totalCount > 0 ? "system_update" : "check_circle"
                                    font.pixelSize: 18
                                    color: updatesSection.totalCount > 0 ? root.seal : "#4ADE80"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: updatesSection.totalCount > 0
                                        ? (updatesSection.totalCount + " Updates Available")
                                        : "System Up to Date"
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.ink
                                }

                                Text {
                                    text: updatesSection.omarchyVersionStr !== ""
                                        ? ("Omarchy " + (updatesSection.omarchyVersionStr.startsWith("v") ? updatesSection.omarchyVersionStr : ("v" + updatesSection.omarchyVersionStr)))
                                        : "Arch Linux Rolling"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.60)
                                }
                            }
                        }

                        // Summary stat pills
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Rectangle {
                                height: 20
                                width: sysRow.implicitWidth + 12
                                radius: 10
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
                                Row {
                                    id: sysRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "Repo:"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                                    }
                                    Text {
                                        text: String(updatesSection.systemCount)
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: root.ink
                                    }
                                }
                            }

                            Rectangle {
                                height: 20
                                width: aurRow.implicitWidth + 12
                                radius: 10
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
                                Row {
                                    id: aurRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "AUR:"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                                    }
                                    Text {
                                        text: String(updatesSection.aurCount)
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: root.ink
                                    }
                                }
                            }
                        }
                    }
                }

                // Action Buttons
                Column {
                    width: parent.width
                    spacing: 8

                    // Primary Update Button
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 12
                        color: btnUpdHov.hovered ? Qt.lighter(root.seal, 1.1) : root.seal
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "download_for_offline"
                                font.pixelSize: 15
                                color: root.paper
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: updatesSection.totalCount > 0 ? "Update All Packages" : "Upgrade System"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.paper
                            }
                        }

                        HoverHandler { id: btnUpdHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-update"])
                            }
                        }
                    }

                    // Check Updates Button
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 12
                        color: btnCheckHov.hovered
                            ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)
                            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "sync"
                                font.pixelSize: 14
                                color: root.ink
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Check for Updates"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.ink
                            }
                        }

                        HoverHandler { id: btnCheckHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                updatesSection.refreshing = true
                                if (updatesSection.root) updatesSection.root.archRefreshTick++
                                refreshResetTimer.restart()
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: PACKAGES / THEMES / SHELL LIST & SEARCH ────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightCard
            width: contentColumns.width - leftCard.width - contentColumns.spacing
            height: contentColumns.height
            radius: 20
            color: root.fillIdle
            clip: true

            // ── TAB 1: PACKAGES VIEW ──
            Item {
                anchors.fill: parent
                visible: updatesSection.activeTab === "packages"

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Search input & counter row
                    Item {
                        width: parent.width
                        height: 30

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 30
                            radius: 15
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "search"
                                    font.pixelSize: 14
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.50)
                                }

                                TextInput {
                                    id: searchInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 44
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    color: root.ink
                                    clip: true
                                    text: updatesSection.searchQuery
                                    onTextChanged: updatesSection.searchQuery = text

                                    Text {
                                        anchors.fill: parent
                                        visible: !searchInput.text && !searchInput.activeFocus
                                        text: "Filter packages..."
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.40)
                                    }
                                }

                                IconText {
                                    visible: searchInput.text.length > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "close"
                                    font.pixelSize: 12
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.50)

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            updatesSection.searchQuery = ""
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Packages List Header
                    Item {
                        width: parent.width
                        height: 18

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6

                            Text {
                                width: Math.floor(parent.width * 0.45)
                                text: "PACKAGE (" + updatesSection.filteredUpdates.length + ")"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                            }

                            Text {
                                width: Math.floor(parent.width * 0.27)
                                text: "CURRENT"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                            }

                            Text {
                                width: Math.floor(parent.width * 0.28)
                                text: "NEW VERSION"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                            }
                        }
                    }

                    // Package Items Scrollable Area
                    Item {
                        width: parent.width
                        height: parent.height - 30 - 18 - 16

                        Flickable {
                            id: pkgFlick
                            anchors.fill: parent
                            contentHeight: pkgCol.implicitHeight
                            clip: true

                            Column {
                                id: pkgCol
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: updatesSection.filteredUpdates

                                    delegate: Rectangle {
                                        id: pkgRow
                                        required property var modelData
                                        width: pkgCol.width
                                        height: 28
                                        radius: 8
                                        color: pkgRowHov.hovered
                                            ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.03)

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter

                                            // Package Name & source chip
                                            Row {
                                                width: Math.floor(parent.width * 0.45)
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Rectangle {
                                                    height: 14
                                                    width: srcTxt.implicitWidth + 8
                                                    radius: 4
                                                    color: pkgRow.modelData.source === "aur"
                                                        ? Qt.rgba(147/255, 51/255, 234/255, 0.20)
                                                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Text {
                                                        id: srcTxt
                                                        anchors.centerIn: parent
                                                        text: (pkgRow.modelData.repo || pkgRow.modelData.source || "repo").toUpperCase()
                                                        font.family: root.barFont
                                                        font.pixelSize: 8
                                                        font.weight: Font.Bold
                                                        color: pkgRow.modelData.source === "aur" ? "#a855f7" : root.seal
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: pkgRow.modelData.name || ""
                                                    font.family: root.barFont
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: root.ink
                                                    elide: Text.ElideRight
                                                    width: parent.width - 55
                                                }
                                            }

                                            // Current Version
                                            Text {
                                                width: Math.floor(parent.width * 0.27)
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: pkgRow.modelData.oldVersion || pkgRow.modelData.installed || "—"
                                                font.family: root.barFont
                                                font.pixelSize: 10
                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                                                elide: Text.ElideRight
                                            }

                                            // New Version
                                            Row {
                                                width: Math.floor(parent.width * 0.28)
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                IconText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "arrow_forward"
                                                    font.pixelSize: 10
                                                    color: root.seal
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: pkgRow.modelData.newVersion || pkgRow.modelData.version || "—"
                                                    font.family: root.barFont
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: root.seal
                                                    elide: Text.ElideRight
                                                    width: parent.width - 16
                                                }
                                            }
                                        }

                                        HoverHandler { id: pkgRowHov }
                                    }
                                }
                            }
                        }

                        // Empty State if no updates or no search matches
                        Item {
                            anchors.fill: parent
                            visible: updatesSection.filteredUpdates.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                IconText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: updatesSection.totalCount === 0 ? "verified" : "search_off"
                                    font.pixelSize: 32
                                    color: updatesSection.totalCount === 0 ? "#4ADE80" : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: updatesSection.totalCount === 0
                                        ? "All packages are up to date"
                                        : "No packages match your search filter"
                                    font.family: root.barFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: root.ink
                                }
                            }
                        }
                    }
                }
            }

            // ── TAB 2: THEMES VIEW ──
            Item {
                anchors.fill: parent
                visible: updatesSection.activeTab === "themes"

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Row {
                        width: parent.width
                        Item { width: 1; height: 1 }

                        Rectangle {
                            anchors.right: parent.right
                            height: 28
                            radius: 14
                            color: themeUpdBtnHov.hovered ? Qt.lighter(root.seal, 1.1) : root.seal
                            width: themeUpdRow.implicitWidth + 18

                            Row {
                                id: themeUpdRow
                                anchors.centerIn: parent
                                spacing: 5
                                IconText {
                                    text: "palette"
                                    font.pixelSize: 12
                                    color: root.paper
                                }
                                Text {
                                    text: "Check & Update Themes"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.paper
                                }
                            }

                            HoverHandler { id: themeUpdBtnHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-theme-update"])
                                }
                            }
                        }
                    }

                    // Themes status / list
                    Item {
                        width: parent.width
                        height: parent.height - 40

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: updatesSection.themeOutdated > 0 ? "palette" : "check_circle"
                                font.pixelSize: 32
                                color: updatesSection.themeOutdated > 0 ? root.seal : "#4ADE80"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: updatesSection.themeOutdated > 0
                                    ? (updatesSection.themeOutdated + " theme updates available")
                                    : "All installed themes are up to date"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: root.ink
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Omarchy themes track remote Git repositories"
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.50)
                            }
                        }
                    }
                }
            }

            // ── TAB 3: SHELL VIEW ──
            Item {
                anchors.fill: parent
                visible: updatesSection.activeTab === "shell"

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48
                        height: 48
                        radius: 24
                        color: updatesSection.shellBehind > 0
                            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                            : Qt.rgba(74/255, 222/255, 128/255, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: "\uE900"
                            font.family: "omarchy"
                            font.pixelSize: 22
                            color: updatesSection.shellBehind > 0 ? root.seal : "#4ADE80"
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: updatesSection.shellBehind > 0
                            ? ("Omarchy Shell update available (" + updatesSection.shellBehind + " commits behind)")
                            : "Omarchy Shell is up to date"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: root.ink
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: updatesSection.omarchyVersionStr !== ""
                            ? ("Current version: " + (updatesSection.omarchyVersionStr.startsWith("v") ? updatesSection.omarchyVersionStr : ("v" + updatesSection.omarchyVersionStr)))
                            : "Omarchy v4.x"
                        font.family: root.barFont
                        font.pixelSize: 11
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.60)
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 32
                        radius: 16
                        color: shellBtnHov.hovered ? Qt.lighter(root.seal, 1.1) : root.seal
                        width: shellBtnRow.implicitWidth + 24

                        Row {
                            id: shellBtnRow
                            anchors.centerIn: parent
                            spacing: 6
                            IconText {
                                text: "sync"
                                font.pixelSize: 14
                                color: root.paper
                            }
                            Text {
                                text: updatesSection.shellBehind > 0 ? "Upgrade Omarchy Shell" : "Check Omarchy Updates"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.paper
                            }
                        }

                        HoverHandler { id: shellBtnHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-update"])
                            }
                        }
                    }
                }
            }
        }
    }
}
