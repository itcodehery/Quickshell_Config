import QtQuick
import QtQuick.Controls
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: notesPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-notes"

    property real targetX: 0
    property bool notesOpen: false
    
    property real reveal: notesOpen ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001

    WlrLayershell.keyboardFocus: notesOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: notesPanel.notesOpen = false
    }

    property var notesData: []
    property string editingId: ""
    property string editingColor: ""

    FileView {
        id: notesFile
        path: "/home/hery/.local/state/quickshell_notes.json"
        watchChanges: true
        onLoaded: {
            if (saveTimer.running || writeProc.running) return;
            try {
                let txt = notesFile.text().trim();
                notesPanel.notesData = txt.length > 0 ? JSON.parse(txt) : [];
            } catch(e) {
                notesPanel.notesData = [];
            }
        }
    }

    Process {
        id: writeProc
        property string jsonContent: "[]"
        command: ["python3", "-c", "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", "/home/hery/.local/state/quickshell_notes.json", jsonContent]
    }

    function saveNotesToDisk() {
        writeProc.jsonContent = JSON.stringify(notesPanel.notesData);
        writeProc.running = false;
        writeProc.running = true;
    }

    function updateCurrentNote(text) {
        if (editingId === "") return;
        var arr = Array.from(notesPanel.notesData);
        for (var i=0; i<arr.length; i++) {
            if (arr[i].id === editingId) {
                if (arr[i].text === text) return;
                arr[i].text = text;
                arr[i].timestamp = Date.now();
                break;
            }
        }
        notesPanel.notesData = arr;
        saveTimer.restart();
    }

    function changeCurrentNoteColor(colorVal) {
        if (editingId === "") return;
        editingColor = colorVal;
        var arr = Array.from(notesPanel.notesData);
        for (var i=0; i<arr.length; i++) {
            if (arr[i].id === editingId) {
                arr[i].color = colorVal;
                break;
            }
        }
        notesPanel.notesData = arr;
        saveNotesToDisk();
    }

    function createNote() {
        var newId = Date.now().toString();
        var arr = Array.from(notesPanel.notesData);
        arr.unshift({
            id: newId,
            text: "",
            color: root.paper,
            timestamp: Date.now()
        });
        notesPanel.notesData = arr;
        saveNotesToDisk();
        
        editingId = newId;
        editingColor = root.paper;
        textArea.text = "";
        textArea.forceActiveFocus();
    }

    function deleteNote(id) {
        var arr = Array.from(notesPanel.notesData);
        arr = arr.filter(n => n.id !== id);
        notesPanel.notesData = arr;
        saveNotesToDisk();
        if (editingId === id) {
            editingId = "";
        }
    }

    function formatTime(ms) {
        if (!ms) return "";
        var d = new Date(ms);
        var dateStr = (d.getMonth() + 1) + "/" + d.getDate() + "/" + d.getFullYear();
        var tStr = d.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        return dateStr + " " + tStr;
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: saveNotesToDisk()
    }

    readonly property var noteColors: [
        root.paper,
        "#4a2a2a", // red tinted
        "#2a4a35", // green tinted
        "#2a3b4a", // blue tinted
        "#4a452a", // yellow tinted
        "#422a4a"  // purple tinted
    ]

    Rectangle {
        id: panelCard
        width: 360
        height: 400
        
        x: Math.max(4, Math.min(notesPanel.targetX - width / 2, parent.width - width - 4))
        y: root.barPosition === "bottom"
            ? (parent.height - root.v2BarHeight - 6 - height) + 2 * (1 - notesPanel.reveal)
            : (root.v2BarHeight + 6) - 2 * (1 - notesPanel.reveal)

        color: root.barBg
        border.color: root.panelOuterBorderColor
        border.width: root.panelOuterBorderW
        radius: root.panelRadius
        opacity: notesPanel.reveal

        MouseArea {
            anchors.fill: parent
            // Eat clicks so they don't close the panel
        }

        PillShadow { theme: root }

        // MAIN LIST VIEW
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            visible: editingId === ""

            Item {
                width: parent.width
                height: 24

                UiText {
                    text: "Notes"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8
                    
                    Rectangle {
                        width: 65; height: 24
                        radius: root.panelButtonRadius
                        color: newNoteMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: root.sep
                        border.width: 1
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText { text: "\uE145"; color: root.ink; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            UiText { text: "New"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }
                        
                        MouseArea {
                            id: newNoteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: createNote()
                        }
                    }

                    Rectangle {
                        width: 24; height: 24
                        radius: root.panelButtonRadius
                        color: closeListMa.containsMouse ? root.fillHover : "transparent"
                        IconText { anchors.centerIn: parent; text: "\uE5CD"; color: root.ink; font.pixelSize: 12 }
                        MouseArea {
                            id: closeListMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notesPanel.notesOpen = false
                        }
                    }
                }
            }

            GridView {
                width: parent.width
                height: parent.height - 32
                cellWidth: width / 2
                cellHeight: 110
                clip: true
                model: notesPanel.notesData

                delegate: Item {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: modelData.color ? modelData.color : root.paper
                        border.color: noteCardMa.containsMouse ? root.seal : root.sep
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.rightMargin: 24 // Don't overlap the trash can!
                            spacing: 4

                            UiText {
                                text: formatTime(modelData.timestamp || 0)
                                color: root.sumiHi
                                font.family: root.barFont
                                font.pixelSize: 9
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            UiText {
                                width: parent.width
                                height: parent.height - 18
                                text: modelData.text || "Empty Note"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: noteCardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                notesPanel.editingId = modelData.id
                                notesPanel.editingColor = modelData.color || root.paper
                                textArea.text = modelData.text || ""
                            }
                        }

                        Rectangle {
                            width: 20; height: 20
                            radius: 10
                            color: delCardMa.containsMouse ? root.red : "transparent"
                            anchors.top: parent.top; anchors.topMargin: 4
                            anchors.right: parent.right; anchors.rightMargin: 4
                            visible: noteCardMa.containsMouse || delCardMa.containsMouse
                            IconText { anchors.centerIn: parent; text: "\uE872"; color: delCardMa.containsMouse ? root.barBg : root.sumi; font.pixelSize: 10 }
                            MouseArea {
                                id: delCardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: deleteNote(modelData.id)
                            }
                        }
                    }
                }

                UiText {
                    visible: parent.count === 0
                    anchors.centerIn: parent
                    text: "No notes yet.\nClick 'New' to add one!"
                    color: root.sumi
                    font.family: root.barFont
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // EDIT VIEW
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            visible: editingId !== ""

            Item {
                width: parent.width
                height: 24

                Rectangle {
                    width: 24; height: 24
                    radius: root.panelButtonRadius
                    color: backMa.containsMouse ? root.fillHover : "transparent"
                    anchors.left: parent.left
                    IconText { anchors.centerIn: parent; text: "\uE5CB"; color: root.ink; font.pixelSize: 14 }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            notesPanel.editingId = ""
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Repeater {
                        model: notesPanel.noteColors
                        Rectangle {
                            width: 16; height: 16
                            radius: 8
                            color: modelData
                            border.color: notesPanel.editingColor === modelData ? root.ink : root.sep
                            border.width: notesPanel.editingColor === modelData ? 2 : 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: changeCurrentNoteColor(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    width: 24; height: 24
                    radius: root.panelButtonRadius
                    color: delEditMa.containsMouse ? root.red : "transparent"
                    anchors.right: parent.right
                    IconText { anchors.centerIn: parent; text: "\uE872"; color: delEditMa.containsMouse ? root.barBg : root.sumi; font.pixelSize: 12 }
                    MouseArea {
                        id: delEditMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteNote(notesPanel.editingId)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: parent.height - 32
                color: notesPanel.editingColor !== "" ? notesPanel.editingColor : root.paper
                radius: root.panelRadius - 4
                border.color: root.sep
                border.width: 1

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: textArea.implicitHeight
                    clip: true
                    
                    TextArea.flickable: TextArea {
                        id: textArea
                        text: ""
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 13
                        wrapMode: TextEdit.Wrap
                        background: null
                        
                        onTextChanged: {
                            if (notesPanel.editingId !== "") {
                                updateCurrentNote(text)
                            }
                        }
                    }
                    
                    ScrollBar.vertical: ScrollBar {
                        width: 8
                        policy: textArea.implicitHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }
                }
            }
        }
    }
}
