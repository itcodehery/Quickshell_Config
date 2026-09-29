import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    property string noteToDelete: ""
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

    function updateCurrentNoteTitle(titleText) {
        if (editingId === "") return;
        var arr = Array.from(notesPanel.notesData);
        for (var i=0; i<arr.length; i++) {
            if (arr[i].id === editingId) {
                if (arr[i].title === titleText) return;
                arr[i].title = titleText;
                arr[i].timestamp = Date.now();
                break;
            }
        }
        notesPanel.notesData = arr;
        saveTimer.restart();
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
            title: "",
            text: "",
            color: root.paper,
            timestamp: Date.now()
        });
        notesPanel.notesData = arr;
        saveNotesToDisk();
        
        editingId = newId;
        editingColor = root.paper;
        titleField.text = "";
        textArea.text = "";
        titleField.forceActiveFocus();
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
        Qt.tint(root.paper, Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.15)),
        Qt.tint(root.paper, Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.15)),
        Qt.tint(root.paper, Qt.rgba(root.color04.r, root.color04.g, root.color04.b, 0.15)),
        Qt.tint(root.paper, Qt.rgba(root.color03.r, root.color03.g, root.color03.b, 0.15)),
        Qt.tint(root.paper, Qt.rgba(root.color05.r, root.color05.g, root.color05.b, 0.15))
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

                Row {
                    spacing: 8
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    IconText {
                        text: ""
                        color: root.accent
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    UiText {
                        text: "Notes"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
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

            ListView {
                width: parent.width
                height: parent.height - 32
                clip: true
                spacing: 4
                model: notesPanel.notesData

                delegate: Item {
                    width: ListView.view.width
                    height: 110
                    
                    Rectangle {
                        id: noteBg
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        radius: 4
                        color: modelData.color ? modelData.color : root.paper
                        border.color: noteCardMa.containsMouse ? root.seal : Qt.rgba(0,0,0,0.1)
                        border.width: 1
                        
                        property real rot: ((index * 37) % 7) - 3
                        rotation: rot * 0.4
                        
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.3)
                            shadowBlur: 0.8
                            shadowHorizontalOffset: 2
                            shadowVerticalOffset: 4
                        }
                        
                        // Washi Tape
                        Rectangle {
                            width: 40; height: 12
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                            border.color: Qt.rgba(0,0,0,0.05)
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: -6
                            rotation: ((index * 17) % 11) - 5
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            anchors.rightMargin: 32
                            anchors.topMargin: 16 // Space for tape
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
                                text: modelData.title || "Untitled Note"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            UiText {
                                width: parent.width
                                height: parent.height - 18 - 28
                                text: modelData.text || ""
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.8)
                                font.family: root.barFont
                                font.pixelSize: 12
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
                                var clickedId = modelData.id
                                var clickedColor = modelData.color || root.paper
                                var clickedTitle = modelData.title || ""
                                var clickedText = modelData.text || ""
                                
                                titleField.text = clickedTitle
                                textArea.text = clickedText
                                notesPanel.editingId = clickedId
                                notesPanel.editingColor = clickedColor
                            }
                        }

                        Rectangle {
                            width: 20; height: 20
                            radius: 10
                            color: delCardMa.containsMouse ? root.red : "transparent"
                            anchors.top: parent.top; anchors.topMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 8
                            visible: noteCardMa.containsMouse || delCardMa.containsMouse
                            IconText { anchors.centerIn: parent; text: ""; color: delCardMa.containsMouse ? root.barBg : root.sumi; font.pixelSize: 10 }
                            MouseArea {
                                id: delCardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notesPanel.noteToDelete = modelData.id
                            }
                        }
                    }
                }

                UiText {
                    visible: parent.count === 0
                    anchors.centerIn: parent
                    text: "No notes yet.
Click 'New' to add one!"
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
                        onClicked: notesPanel.noteToDelete = notesPanel.editingId
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
                    contentHeight: editCol.implicitHeight
                    clip: true
                    
                    Column {
                        id: editCol
                        width: parent.width
                        spacing: 4
                        TextField {
                            id: titleField
                            width: parent.width
                            text: ""
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            background: null
                            placeholderText: "Title"
                            placeholderTextColor: root.sumi
                            onTextChanged: {
                                if (notesPanel.editingId !== "") {
                                    updateCurrentNoteTitle(text)
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.sep
                        }
                        TextArea {
                            id: textArea
                            width: parent.width
                            text: ""
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 13
                            wrapMode: TextEdit.Wrap
                            background: null
                            placeholderText: "Note body..."
                            placeholderTextColor: root.sumi
                            
                            onTextChanged: {
                                if (notesPanel.editingId !== "") {
                                    updateCurrentNote(text)
                                }
                            }
                        }
                    }
                    
                    ScrollBar.vertical: ScrollBar {
                        width: 8
                        policy: editCol.implicitHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }
                }
            }
        }

        // CONFIRMATION OVERLAY
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            radius: root.panelRadius
            visible: notesPanel.noteToDelete !== ""
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent // block clicks to things underneath
            }

            Rectangle {
                width: 260
                height: 120
                anchors.centerIn: parent
                color: root.barBg
                radius: 8
                border.color: root.sep
                border.width: 1
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0,0,0,0.5)
                    shadowBlur: 1.0
                    shadowVerticalOffset: 4
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 20

                    UiText {
                        text: "Delete this note?"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        width: 240
                    }

                    Row {
                        spacing: 16
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 80; height: 32
                            radius: 6
                            color: cancelMa.containsMouse ? root.fillHover : "transparent"
                            border.color: root.sep
                            border.width: 1
                            UiText { text: "Cancel"; color: root.ink; font.family: root.barFont; font.pixelSize: 13; anchors.centerIn: parent }
                            MouseArea {
                                id: cancelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notesPanel.noteToDelete = ""
                            }
                        }

                        Rectangle {
                            width: 80; height: 32
                            radius: 6
                            color: confirmMa.containsMouse ? Qt.darker(root.red, 1.2) : root.red
                            UiText { text: "Delete"; color: root.barBg; font.family: root.barFont; font.pixelSize: 13; font.weight: Font.Bold; anchors.centerIn: parent }
                            MouseArea {
                                id: confirmMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    deleteNote(notesPanel.noteToDelete)
                                    notesPanel.noteToDelete = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
