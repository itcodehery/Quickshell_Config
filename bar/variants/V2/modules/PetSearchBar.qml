import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: searchBar
    required property var root

    property bool isOpen: false
    property string engine: "ddg" // "ddg" | "claude"
    property real maxContentWidth: 220
    readonly property real contentHeight: 28

    signal focusLostOrClosed()
    signal searchSubmitted()

    // Smoothly expands width from 0 to maxContentWidth
    implicitWidth: isOpen ? Math.max(120, maxContentWidth) : 0
    implicitHeight: contentHeight
    clip: true
    visible: implicitWidth > 0.1
    opacity: implicitWidth > 1 ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function toggle() {
        if (isOpen) {
            close()
        } else {
            open()
        }
    }

    function toggleEngine() {
        engine = (engine === "ddg" ? "claude" : "ddg")
        Quickshell.execDetached(["pw-play", Quickshell.env("HOME") + "/.config/quickshell/bar/pop.wav"])
    }

    function open() {
        isOpen = true
        Qt.callLater(() => textInput.forceActiveFocus())
    }

    function close() {
        isOpen = false
        textInput.focus = false
        focusLostOrClosed()
    }

    function doSearch() {
        var query = textInput.text.trim()
        var url = ""
        if (engine === "ddg") {
            url = query === "" ? "https://duckduckgo.com" : "https://duckduckgo.com/?q=" + encodeURIComponent(query)
        } else {
            url = query === "" ? "https://claude.ai" : "https://claude.ai/new?q=" + encodeURIComponent(query)
        }

        if (query !== "") {
            Quickshell.execDetached(["wl-copy", query])
        }
        Quickshell.execDetached(["xdg-open", url])
        Quickshell.execDetached(["pw-play", Quickshell.env("HOME") + "/.config/quickshell/bar/pop.wav"])
        Quickshell.execDetached(["bash", "-c", "sleep 0.1 && hyprctl dispatch focuswindow class:zen"])

        textInput.text = ""
        searchSubmitted()
        close()
    }

    // Main search pill
    Rectangle {
        id: pillBody
        anchors.fill: parent
        radius: searchBar.contentHeight / 2
        color: textInput.activeFocus ? root.fillHover : (pillMa.containsMouse ? root.fillHover : root.fillIdle)
        border.width: textInput.activeFocus ? 1.5 : 1
        border.color: textInput.activeFocus
            ? (engine === "ddg" ? "#E35934" : "#D97757")
            : (pillMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22) : root.islandBorder)

        Behavior on border.color { ColorAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 180 } }

        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter

            // ── Engine Toggle Switch (DuckDuckGo vs Claude) ────
            Rectangle {
                id: togglePill
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 20
                radius: 10
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                // Sliding indicator bubble
                Rectangle {
                    id: slidingIndicator
                    y: 1.5
                    width: 22
                    height: 17
                    radius: 8.5
                    x: searchBar.engine === "ddg" ? 2 : 24
                    color: searchBar.engine === "ddg" ? "#E35934" : "#D97757"

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // DuckDuckGo button (Left)
                Item {
                    id: ddgBtn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 24

                    Image {
                        id: ddgIcon
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        fillMode: Image.PreserveAspectFit
                        source: Quickshell.env("HOME") + "/.config/quickshell/bar/duckduckgo.svg"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: searchBar.engine === "ddg" ? "#FFFFFF" : root.ink
                        }
                        opacity: searchBar.engine === "ddg" ? 1.0 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: ddgMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (searchBar.engine !== "ddg") {
                                searchBar.toggleEngine()
                            }
                            textInput.forceActiveFocus()
                        }
                    }
                }

                // Claude button (Right)
                Item {
                    id: claudeBtn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 24

                    Image {
                        id: claudeIcon
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        fillMode: Image.PreserveAspectFit
                        source: Quickshell.env("HOME") + "/.config/quickshell/bar/claude.svg"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: searchBar.engine === "claude" ? "#FFFFFF" : root.ink
                        }
                        opacity: searchBar.engine === "claude" ? 1.0 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: claudeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (searchBar.engine !== "claude") {
                                searchBar.toggleEngine()
                            }
                            textInput.forceActiveFocus()
                        }
                    }
                }
            }

            // ── Input Field Container ──────────────────────────────
            Item {
                id: inputContainer
                width: Math.max(60, parent.width - togglePill.width - goBtn.width - (clearBtn.width > 0 ? (clearBtn.width + parent.spacing) : 0) - (parent.spacing * 2) - 8)
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                TextInput {
                    id: textInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: root.ink
                    selectionColor: searchBar.engine === "ddg" ? "#E35934" : "#D97757"
                    selectedTextColor: "#FFFFFF"
                    selectByMouse: true
                    clip: true

                    Keys.onTabPressed: (event) => {
                        searchBar.toggleEngine()
                        event.accepted = true
                    }
                    Keys.onBacktabPressed: (event) => {
                        searchBar.toggleEngine()
                        event.accepted = true
                    }

                    Keys.onEscapePressed: (event) => {
                        searchBar.close()
                        event.accepted = true
                    }

                    onAccepted: searchBar.doSearch()

                    // Placeholder text
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: searchBar.engine === "ddg" ? "Search web..." : "Ask Claude..."
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.ink
                        opacity: 0.4
                        visible: textInput.text === ""
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // ── Clear Button (when text is present) ──
            Item {
                id: clearBtn
                width: textInput.text.length > 0 ? 16 : 0
                height: 20
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                Behavior on width { NumberAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 12
                    color: root.ink
                    opacity: clearMa.containsMouse ? 0.9 : 0.5
                }

                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        textInput.text = ""
                        textInput.forceActiveFocus()
                    }
                }
            }

            // ── Cute Search / Send Button ──────────────────────────
            Rectangle {
                id: goBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: goMa.containsMouse
                    ? (searchBar.engine === "ddg" ? "#E35934" : "#D97757")
                    : (textInput.text.trim() !== ""
                        ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)
                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06))

                scale: goMa.pressed ? 0.88 : (goMa.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: textInput.text.trim() === "" ? "search" : "arrow_forward"
                    font.pixelSize: 11
                    color: goMa.containsMouse ? "#FFFFFF" : root.ink
                    opacity: goMa.containsMouse ? 1.0 : 0.75
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: goMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchBar.doSearch()
                }
            }
        }
    }
}
