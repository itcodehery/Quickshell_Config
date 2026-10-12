import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: searchBar
    required property var root

    property bool isOpen: false
    property string engine: "ddg" // "ddg" | "claude"
    readonly property real contentWidth: 280
    readonly property real contentHeight: 32

    signal focusLostOrClosed()
    signal searchSubmitted()

    // Smoothly expands width, pushing anything to its right in a Row
    implicitWidth: isOpen ? (contentWidth + 12) : 0
    implicitHeight: contentHeight
    clip: true
    visible: implicitWidth > 0.1
    opacity: implicitWidth > 1 ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
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
        sparkleAnim.restart()
        Quickshell.execDetached(["pw-play", Quickshell.env("HOME") + "/.config/quickshell/bar/pop.wav"])
    }

    function open() {
        isOpen = true
        sparkleAnim.restart()
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
        width: searchBar.contentWidth
        height: searchBar.contentHeight
        radius: 16
        color: root.fillIdle
        border.width: textInput.activeFocus ? 1.5 : 1
        border.color: textInput.activeFocus ? (engine === "ddg" ? "#DE5833" : "#D97757") : root.islandBorder

        Behavior on border.color { ColorAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 180 } }

        // Cute highlight shine (matching SystemPet shine spot)
        Rectangle {
            x: 12; y: 3
            width: 22; height: 3
            radius: 1.5
            color: root.paper
            opacity: 0.35
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            // ── Cute Engine Toggle Switch (DuckDuckGo vs Claude) ────
            Rectangle {
                id: togglePill
                anchors.verticalCenter: parent.verticalCenter
                width: 58
                height: 24
                radius: 12
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                // Sliding indicator bubble
                Rectangle {
                    id: slidingIndicator
                    y: 2
                    width: 26
                    height: 20
                    radius: 10
                    x: searchBar.engine === "ddg" ? 2 : 30
                    color: searchBar.engine === "ddg" ? "#DE5833" : "#D97757"

                    Behavior on x {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.3
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    // Tiny shine on sliding indicator
                    Rectangle {
                        x: 4; y: 2
                        width: 7; height: 2
                        radius: 1
                        color: "white"
                        opacity: 0.45
                    }
                }

                // DuckDuckGo button (Left)
                Item {
                    id: ddgBtn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 29

                    Image {
                        id: ddgIcon
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        fillMode: Image.PreserveAspectFit
                        source: Quickshell.env("HOME") + "/.config/quickshell/bar/duckduckgo.svg"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: searchBar.engine === "ddg" ? "#FFFFFF" : root.ink
                        }
                        scale: ddgMa.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
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
                    width: 29

                    Image {
                        id: claudeIcon
                        anchors.centerIn: parent
                        width: 13
                        height: 13
                        fillMode: Image.PreserveAspectFit
                        source: Quickshell.env("HOME") + "/.config/quickshell/bar/claude.svg"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: searchBar.engine === "claude" ? "#FFFFFF" : root.ink
                        }
                        scale: claudeMa.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
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
                width: parent.width - togglePill.width - goBtn.width - 18
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
                    color: root.ink
                    selectionColor: searchBar.engine === "ddg" ? "#DE5833" : "#D97757"
                    selectedTextColor: "white"
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
                        text: searchBar.engine === "ddg" ? "🦆 Search DuckDuckGo..." : "✻ Ask Claude..."
                        font.family: root.barFont
                        font.pixelSize: 11
                        color: root.ink
                        opacity: 0.45
                        visible: textInput.text === ""
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // ── Cute Search / Send Button ──────────────────────────
            Rectangle {
                id: goBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: goMa.containsMouse
                    ? (searchBar.engine === "ddg" ? "#DE5833" : "#D97757")
                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                scale: goMa.pressed ? 0.88 : (goMa.containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: textInput.text.trim() === "" ? "search" : "arrow_forward"
                    font.pixelSize: 12
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

        // Cute sparkle badge on engine switch
        Text {
            id: sparkleText
            text: "✦"
            color: searchBar.engine === "ddg" ? "#DE5833" : "#D97757"
            font.pixelSize: 12
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.topMargin: -4
            opacity: 0
            scale: 0.5

            SequentialAnimation {
                id: sparkleAnim
                ParallelAnimation {
                    NumberAnimation { target: sparkleText; property: "opacity"; to: 1.0; duration: 120 }
                    NumberAnimation { target: sparkleText; property: "scale"; to: 1.4; duration: 150; easing.type: Easing.OutBack }
                }
                ParallelAnimation {
                    NumberAnimation { target: sparkleText; property: "opacity"; to: 0.0; duration: 250 }
                    NumberAnimation { target: sparkleText; property: "scale"; to: 0.6; duration: 250 }
                }
            }
        }
    }
}
