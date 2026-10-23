import "../motion"
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

    readonly property color engineColor: engine === "ddg" ? "#E35934" : "#D97757"
    readonly property color iconOnEngine: "#2B1710"

    // Main search pill (engine-coloured, like a chat composer)
    Rectangle {
        id: pillBody
        anchors.fill: parent
        radius: searchBar.contentHeight / 2
        color: searchBar.engineColor
        Behavior on color { ColorAnimation { duration: 180 } }

        // Engine icon buttons (DuckDuckGo, Claude) sitting directly on the pill
        Row {
            id: engineRow
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Item {
                id: ddgBtn
                width: 24
                height: searchBar.contentHeight

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.env("HOME") + "/.config/quickshell/bar/duckduckgo.svg"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: searchBar.iconOnEngine
                    }
                    opacity: searchBar.engine === "ddg" ? 1.0 : (ddgMa.containsMouse ? 0.7 : 0.45)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                SpringPress {}
                MouseArea {
                    id: ddgMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (searchBar.engine !== "ddg") searchBar.toggleEngine()
                        textInput.forceActiveFocus()
                    }
                }
            }

            Item {
                id: claudeBtn
                width: 24
                height: searchBar.contentHeight

                Image {
                    anchors.centerIn: parent
                    width: 13
                    height: 13
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.env("HOME") + "/.config/quickshell/bar/claude.svg"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: searchBar.iconOnEngine
                    }
                    opacity: searchBar.engine === "claude" ? 1.0 : (claudeMa.containsMouse ? 0.7 : 0.45)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                SpringPress {}
                MouseArea {
                    id: claudeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (searchBar.engine !== "claude") searchBar.toggleEngine()
                        textInput.forceActiveFocus()
                    }
                }
            }
        }

        // Light inner subsection holding the input, clear and go buttons
        Rectangle {
            id: innerSection
            anchors.left: engineRow.right
            anchors.leftMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            height: searchBar.contentHeight - 6
            radius: height / 2
            color: root.paper

            Row {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 3
                spacing: 5

                Item {
                    id: inputContainer
                    width: Math.max(40, parent.width - goBtn.width - (clearBtn.width > 0 ? clearBtn.width + parent.spacing : 0) - parent.spacing)
                    height: parent.height
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
                        selectionColor: searchBar.engineColor
                        selectedTextColor: "#FFFFFF"
                        selectByMouse: true
                        clip: true

                        Keys.onTabPressed: (event) => { searchBar.toggleEngine(); event.accepted = true }
                        Keys.onBacktabPressed: (event) => { searchBar.toggleEngine(); event.accepted = true }
                        Keys.onEscapePressed: (event) => { searchBar.close(); event.accepted = true }

                        onAccepted: searchBar.doSearch()

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
                        }
                    }
                }

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

                    SpringPress {}
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

                Item {
                    id: goBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20

                    IconText {
                        anchors.centerIn: parent
                        text: textInput.text.trim() === "" ? "search" : "arrow_forward"
                        font.pixelSize: 13
                        color: goMa.containsMouse ? searchBar.engineColor : root.ink
                        opacity: goMa.containsMouse ? 1.0 : 0.7
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    SpringPress {}
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
}
