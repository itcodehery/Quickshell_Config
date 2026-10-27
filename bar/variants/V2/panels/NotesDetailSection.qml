import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: notesSection
    anchors.fill: parent
    focus: true

    required property var root
    property var panel: null

    signal closeRequested()

    property var notesData: []
    property string selectedId: ""
    property string searchQuery: ""
    property string editingTitle: ""
    property string editingText: ""
    property var editingColor: root ? root.paper : "#ffffff"
    property bool editingPinned: false
    property string sortMode: "recent" // "recent", "alpha", "oldest"
    property bool copiedNotice: false
    property bool isInputFocused: false

    function clearInputFocus() {
        if (searchInput && searchInput.activeFocus) searchInput.focus = false
        if (editorTitleInput && editorTitleInput.activeFocus) editorTitleInput.focus = false
        if (editorBodyArea && editorBodyArea.activeFocus) editorBodyArea.focus = false
        notesSection.forceActiveFocus()
        isInputFocused = false
    }

    function selectNextNote() {
        if (notesData.length === 0) return
        var list = filteredNotes
        if (list.length === 0) return
        var idx = list.findIndex(n => n.id === selectedId)
        if (idx === -1 || idx >= list.length - 1) {
            selectNote(list[0].id)
        } else {
            selectNote(list[idx + 1].id)
        }
    }

    function selectPrevNote() {
        if (notesData.length === 0) return
        var list = filteredNotes
        if (list.length === 0) return
        var idx = list.findIndex(n => n.id === selectedId)
        if (idx <= 0) {
            selectNote(list[list.length - 1].id)
        } else {
            selectNote(list[idx - 1].id)
        }
    }

    // Keyboard Shortcuts (Ctrl+N, Ctrl+D, Ctrl+P, Ctrl+F, Escape, Arrow navigation)
    Keys.onPressed: function(event) {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
            createNote()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
            duplicateNote()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
            togglePin()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            searchInput.forceActiveFocus()
            searchInput.selectAll()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (isInputFocused) {
                clearInputFocus()
                event.accepted = true
            } else {
                closeRequested()
                event.accepted = true
            }
        } else if (!isInputFocused && (event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
            selectPrevNote()
            event.accepted = true
        } else if (!isInputFocused && (event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
            selectNextNote()
            event.accepted = true
        }
    }

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: notesSection.copiedNotice = false
    }

    // ── Persistent Notes File (Shared with Control Center & Widgets) ──
    FileView {
        id: notesFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell_notes.json"
        watchChanges: true
        onLoaded: {
            if (saveTimer.running || writeProc.running) return
            try {
                let txt = notesFile.text().trim()
                notesSection.notesData = txt.length > 0 ? JSON.parse(txt) : []
            } catch(e) {
                notesSection.notesData = []
            }
            if (notesSection.selectedId === "" && notesSection.notesData.length > 0) {
                notesSection.selectNote(notesSection.notesData[0].id)
            }
        }
    }

    Process {
        id: writeProc
        property string jsonContent: "[]"
        command: ["python3", "-c", "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", Quickshell.env("HOME") + "/.local/state/quickshell_notes.json", jsonContent]
    }

    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: notesSection.saveNotesToDisk()
    }

    function saveNotesToDisk() {
        writeProc.jsonContent = JSON.stringify(notesSection.notesData)
        writeProc.running = false
        writeProc.running = true
    }

    // Palette custom colors for notes: vibrant swatches + tinted backgrounds
    readonly property var noteColorOptions: [
        { name: "Default",  swatch: root.sumiHi,  bg: root.paper },
        { name: "Coral",    swatch: root.color01, bg: Qt.tint(root.paper, Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.25)) },
        { name: "Sage",     swatch: root.color02, bg: Qt.tint(root.paper, Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.25)) },
        { name: "Amber",    swatch: root.color03, bg: Qt.tint(root.paper, Qt.rgba(root.color03.r, root.color03.g, root.color03.b, 0.25)) },
        { name: "Sky",      swatch: root.color04, bg: Qt.tint(root.paper, Qt.rgba(root.color04.r, root.color04.g, root.color04.b, 0.25)) },
        { name: "Lavender", swatch: root.color05, bg: Qt.tint(root.paper, Qt.rgba(root.color05.r, root.color05.g, root.color05.b, 0.25)) },
        { name: "Mint",     swatch: root.color06, bg: Qt.tint(root.paper, Qt.rgba(root.color06.r, root.color06.g, root.color06.b, 0.25)) },
        { name: "Espresso", swatch: Qt.darker(root.paper, 1.8), bg: Qt.darker(root.paper, 1.25) }
    ]

    function isColorSelected(colorCandidate) {
        if (!editingColor) return false
        try {
            var c1 = Qt.color(colorCandidate)
            var c2 = (typeof editingColor === "object" && editingColor.r !== undefined)
                ? Qt.rgba(editingColor.r, editingColor.g, editingColor.b, 1)
                : Qt.color(editingColor)
            return c1.toString() === c2.toString()
        } catch(e) {
            return false
        }
    }

    function selectNote(id) {
        selectedId = id
        for (var i = 0; i < notesData.length; i++) {
            if (notesData[i].id === id) {
                editingTitle = notesData[i].title || ""
                editingText = notesData[i].text || ""
                editingColor = notesData[i].color ? notesData[i].color : root.paper
                editingPinned = notesData[i].pinned === true
                return
            }
        }
        editingTitle = ""
        editingText = ""
        editingColor = root.paper
        editingPinned = false
    }

    function createNote() {
        var newId = Date.now().toString()
        var arr = Array.from(notesData)
        var newNote = {
            id: newId,
            title: "",
            text: "",
            color: root.paper,
            pinned: false,
            timestamp: Date.now()
        }
        arr.unshift(newNote)
        notesData = arr
        saveNotesToDisk()
        selectNote(newId)
    }

    function duplicateNote() {
        if (!selectedId) return
        var curNote = notesData.find(n => n.id === selectedId)
        if (!curNote) return
        var newId = Date.now().toString()
        var baseTitle = curNote.title ? curNote.title.trim() : "Untitled"
        var newNote = {
            id: newId,
            title: baseTitle + " (Copy)",
            text: curNote.text || "",
            color: curNote.color || root.paper,
            pinned: false,
            timestamp: Date.now()
        }
        var arr = Array.from(notesData)
        arr.unshift(newNote)
        notesData = arr
        saveNotesToDisk()
        selectNote(newId)
    }

    function togglePin(id) {
        var targetId = id || selectedId
        if (!targetId) return
        var arr = Array.from(notesData)
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].id === targetId) {
                arr[i].pinned = !arr[i].pinned
                if (arr[i].id === selectedId) {
                    editingPinned = arr[i].pinned
                }
                break
            }
        }
        notesData = arr
        saveNotesToDisk()
    }

    function deleteNote(id) {
        var arr = Array.from(notesData).filter(n => n.id !== id)
        notesData = arr
        saveNotesToDisk()
        if (selectedId === id) {
            if (notesData.length > 0) {
                selectNote(notesData[0].id)
            } else {
                selectedId = ""
                editingTitle = ""
                editingText = ""
                editingColor = root.paper
                editingPinned = false
            }
        }
    }

    function changeCurrentNoteColor(colorVal) {
        if (!selectedId) return
        editingColor = colorVal
        var arr = Array.from(notesData)
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].id === selectedId) {
                arr[i].color = colorVal
                break
            }
        }
        notesData = arr
        saveNotesToDisk()
    }

    function updateTitle(newTitle) {
        if (!selectedId) return
        editingTitle = newTitle
        // Mutate in-place so filteredNotes is not constantly recomputed and ListView delegates
        // are not reconstructed mid-typing (which would destroy activeFocus and drop keystrokes).
        for (var i = 0; i < notesData.length; i++) {
            if (notesData[i].id === selectedId) {
                notesData[i].title = newTitle
                break
            }
        }
        saveTimer.restart()
    }

    function commitTitle() {
        if (!selectedId) return
        var arr = Array.from(notesData)
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].id === selectedId) {
                if (arr[i].title === editingTitle) return
                arr[i].title = editingTitle
                arr[i].timestamp = Date.now()
                break
            }
        }
        notesData = arr
        saveNotesToDisk()
    }

    function updateBody(newText) {
        if (!selectedId) return
        editingText = newText
        for (var i = 0; i < notesData.length; i++) {
            if (notesData[i].id === selectedId) {
                notesData[i].text = newText
                break
            }
        }
        saveTimer.restart()
    }

    function commitBody() {
        if (!selectedId) return
        var arr = Array.from(notesData)
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].id === selectedId) {
                if (arr[i].text === editingText) return
                arr[i].text = editingText
                arr[i].timestamp = Date.now()
                break
            }
        }
        notesData = arr
        saveNotesToDisk()
    }

    function copyNoteToClipboard() {
        if (!selectedId) return
        var full = ""
        if (editingTitle && editingTitle.trim().length > 0) {
            full += "# " + editingTitle.trim() + "\n\n"
        }
        full += (editingText || "").trim()
        Quickshell.execDetached(["wl-copy", full])
        copiedNotice = true
        copiedTimer.restart()
    }

    function insertSnippet(snippet) {
        if (!selectedId) return
        var cursor = editorBodyArea.cursorPosition
        var old = editingText || ""
        var updated = old.slice(0, cursor) + snippet + old.slice(cursor)
        updateBody(updated)
        editorBodyArea.cursorPosition = cursor + snippet.length
        editorBodyArea.forceActiveFocus()
    }

    function cycleSortMode() {
        if (sortMode === "recent") sortMode = "alpha"
        else if (sortMode === "alpha") sortMode = "oldest"
        else sortMode = "recent"
    }

    function formatTime(ms) {
        if (!ms) return ""
        var d = new Date(ms)
        var now = new Date()
        var isToday = d.toDateString() === now.toDateString()
        var tStr = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        if (isToday) return "Today " + tStr
        var dateStr = (d.getMonth() + 1) + "/" + d.getDate()
        return dateStr + " " + tStr
    }

    readonly property int wordCount: {
        var str = (editingText || "").trim()
        if (str.length === 0) return 0
        return str.split(/\s+/).length
    }
    readonly property int charCount: (editingText || "").length

    readonly property string lastEditedTime: {
        if (!selectedId) return ""
        for (var i = 0; i < notesData.length; i++) {
            if (notesData[i].id === selectedId) {
                return notesSection.formatTime(notesData[i].timestamp)
            }
        }
        return ""
    }

    // Filter & Sort notes based on search query, pin status, and sort mode
    readonly property var filteredNotes: {
        var arr = Array.from(notesData)
        if (searchQuery && searchQuery.trim() !== "") {
            var q = searchQuery.trim().toLowerCase()
            arr = arr.filter(function(n) {
                var t = (n.title || "").toLowerCase()
                var b = (n.text || "").toLowerCase()
                return t.indexOf(q) !== -1 || b.indexOf(q) !== -1
            })
        }
        arr.sort(function(a, b) {
            var aPin = a.pinned === true ? 1 : 0
            var bPin = b.pinned === true ? 1 : 0
            if (aPin !== bPin) return bPin - aPin

            if (sortMode === "alpha") {
                var at = (a.title || "").toLowerCase()
                var bt = (b.title || "").toLowerCase()
                return at.localeCompare(bt)
            } else if (sortMode === "oldest") {
                return (a.timestamp || 0) - (b.timestamp || 0)
            } else {
                return (b.timestamp || 0) - (a.timestamp || 0)
            }
        })
        return arr
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ── TWO-COLUMN MASTER-DETAIL LAYOUT: LIST ON LEFT, FULL EDITOR ON RIGHT ──
    // ─────────────────────────────────────────────────────────────────────────
    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: SEARCH, SORT & NOTE TITLES ──────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Item {
            id: leftCol
            width: 290
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: 8

                // Top Toolbar: Search + New Note Button
                Row {
                    width: parent.width
                    height: 36
                    spacing: 8

                    // Search Pill
                    Rectangle {
                        width: parent.width - newBtn.width - parent.spacing
                        height: parent.height
                        radius: 18
                        color: root.fillIdle
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: root.seal

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "search"
                                font.pixelSize: 16
                                color: root.sumiHi
                            }

                            TextField {
                                id: searchInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24
                                background: null
                                placeholderText: "Search notes..."
                                placeholderTextColor: root.sumi
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        notesSection.isInputFocused = true
                                    } else {
                                        notesSection.isInputFocused = (editorBodyArea && editorBodyArea.activeFocus) || false
                                    }
                                }
                                onTextChanged: notesSection.searchQuery = text
                                Keys.onEscapePressed: {
                                    if (text.length > 0) {
                                        text = ""
                                    } else {
                                        focus = false
                                        notesSection.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    // + New Note Button
                    Rectangle {
                        id: newBtn
                        width: 84
                        height: parent.height
                        radius: 18
                        color: newBtnMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "add"
                                font.pixelSize: 16
                                color: root.paper
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            UiText {
                                text: "New"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: root.paper
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        TooltipMixin {
                            id: newTip
                            root: notesSection.root
                            owner: newBtn
                            text: "New Note (Ctrl+N)"
                        }

                        SpringPress {}
                        MouseArea {
                            id: newBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: newTip.show()
                            onExited: newTip.hide()
                            onClicked: {
                                newTip.hide()
                                notesSection.createNote()
                            }
                        }
                    }
                }

                // Subheader: Counter & Sort Chip
                Item {
                    width: parent.width
                    height: 20

                    UiText {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var total = notesSection.notesData.length
                            var shown = notesSection.filteredNotes.length
                            if (notesSection.searchQuery.trim().length > 0) {
                                return shown + " of " + total + " notes"
                            }
                            return total + (total === 1 ? " note" : " notes")
                        }
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: root.sumiHi
                    }

                    // Sort Chip Button
                    Rectangle {
                        id: sortChip
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        width: sortRow.width + 12
                        radius: 10
                        color: sortMa.containsMouse ? root.fillHover : "transparent"
                        border.width: 1
                        border.color: sortMa.containsMouse ? root.sep : Qt.rgba(255, 255, 255, 0.05)

                        Row {
                            id: sortRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "sort"
                                font.pixelSize: 12
                                color: root.sumiHi
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            UiText {
                                text: notesSection.sortMode === "recent" ? "Recent" : (notesSection.sortMode === "alpha" ? "A-Z" : "Oldest")
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        TooltipMixin {
                            id: sortTip
                            root: notesSection.root
                            owner: sortChip
                            text: "Sort: " + (notesSection.sortMode === "recent" ? "Recent" : (notesSection.sortMode === "alpha" ? "A-Z" : "Oldest"))
                        }

                        MouseArea {
                            id: sortMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: sortTip.show()
                            onExited: sortTip.hide()
                            onClicked: notesSection.cycleSortMode()
                        }
                    }
                }

                // Notes List: Showing Name / Only Title of Notes
                Item {
                    width: parent.width
                    height: parent.height - 36 - 20 - 16
                    clip: true

                    ListView {
                        id: notesList
                        anchors.fill: parent
                        spacing: 6
                        model: notesSection.filteredNotes
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: noteCardItem
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: notesSection.selectedId === modelData.id
                            readonly property bool isPinned: modelData.pinned === true

                            width: notesList.width
                            height: 38
                            radius: 10
                            color: modelData.color ? modelData.color : root.paper

                            border.width: isSelected ? 2 : 1
                            border.color: isSelected
                                ? root.seal
                                : (cardMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16) : Qt.rgba(0, 0, 0, 0.08))
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            scale: cardMa.containsMouse ? 1.01 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: isSelected
                                shadowColor: Qt.rgba(0, 0, 0, 0.16)
                                shadowBlur: 0.5
                                shadowVerticalOffset: 1
                            }

                            // Left Pin Indicator
                            IconText {
                                id: pinIcon
                                visible: noteCardItem.isPinned
                                text: "push_pin"
                                font.pixelSize: 11
                                color: root.seal
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Card Content: Only Note Title / Name
                            Item {
                                anchors.left: noteCardItem.isPinned ? pinIcon.right : parent.left
                                anchors.leftMargin: noteCardItem.isPinned ? 5 : 12
                                anchors.right: delCardBtn.visible ? delCardBtn.left : parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height

                                // Inline Editable Title when selected
                                TextField {
                                    id: activeTitleField
                                    visible: noteCardItem.isSelected
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: notesSection.editingTitle
                                    placeholderText: "Untitled Note"
                                    placeholderTextColor: root.sumi
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    background: null
                                    padding: 0
                                    selectByMouse: true
                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            notesSection.isInputFocused = true
                                        } else {
                                            notesSection.isInputFocused = (searchInput && searchInput.activeFocus) || (editorBodyArea && editorBodyArea.activeFocus) || false
                                        }
                                    }
                                    onTextChanged: {
                                        if (activeFocus) notesSection.updateTitle(text)
                                    }
                                    onEditingFinished: {
                                        notesSection.commitTitle()
                                    }
                                    onAccepted: {
                                        notesSection.commitTitle()
                                        focus = false
                                        notesSection.forceActiveFocus()
                                    }
                                    Keys.onEscapePressed: {
                                        focus = false
                                        notesSection.forceActiveFocus()
                                    }
                                }

                                Binding {
                                    target: activeTitleField
                                    property: "text"
                                    value: notesSection.editingTitle
                                    when: !activeTitleField.activeFocus
                                }

                                // Non-editable clean Title text when not selected
                                UiText {
                                    visible: !noteCardItem.isSelected
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.title && modelData.title.trim().length > 0 ? modelData.title : "Untitled Note"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                            }

                            // Delete Button on Card (visible on hover)
                            Rectangle {
                                id: delCardBtn
                                width: 22
                                height: 22
                                radius: 11
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: delMa.containsMouse ? root.color01 : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                visible: cardMa.containsMouse || delMa.containsMouse
                                z: 2

                                IconText {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.pixelSize: 12
                                    color: delMa.containsMouse ? root.paper : root.sumiHi
                                }

                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notesSection.deleteNote(noteCardItem.modelData.id)
                                }
                            }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !noteCardItem.isSelected
                                onClicked: {
                                    notesSection.commitTitle()
                                    notesSection.commitBody()
                                    notesSection.selectNote(noteCardItem.modelData.id)
                                }
                            }
                        }
                    }

                    // Empty List Notice
                    Item {
                        anchors.fill: parent
                        visible: notesSection.filteredNotes.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "note_add"
                                font.pixelSize: 32
                                color: root.sumi
                                opacity: 0.45
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: notesSection.notesData.length === 0 ? "No notes yet" : "No matching notes"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: root.sumi
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: COLOR PICKER, DESCRIPTION & QUICK FORMAT BAR ────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: editorCard
            width: parent.width - leftCol.width - parent.spacing
            height: parent.height
            radius: 18
            color: notesSection.selectedId !== "" ? (notesSection.editingColor || root.paper) : root.fillIdle
            Behavior on color { ColorAnimation { duration: 180 } }

            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.05)

            // When a note is active
            Item {
                anchors.fill: parent
                anchors.margins: 12
                visible: notesSection.selectedId !== ""

                // ── Top Bar: Compact Color Picker + Action Buttons (Pin, Copy, Duplicate, Delete) ──
                Item {
                    id: editorHeader
                    width: parent.width
                    height: 28
                    anchors.top: parent.top

                    // Redesigned Compact Color Picker Capsule
                    Rectangle {
                        id: colorPickerPill
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: swatchesRow.width + 12
                        radius: 13
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.06)

                        Row {
                            id: swatchesRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: notesSection.noteColorOptions

                                Item {
                                    id: swatchItem
                                    required property var modelData
                                    width: 18
                                    height: 20

                                    readonly property bool isSelected: notesSection.isColorSelected(modelData.bg)

                                    Rectangle {
                                        id: swatchDot
                                        anchors.centerIn: parent
                                        width: 13
                                        height: 13
                                        radius: 7
                                        color: swatchItem.modelData.swatch
                                        border.width: swatchItem.isSelected ? 2 : 1
                                        border.color: swatchItem.isSelected ? root.ink : Qt.rgba(0, 0, 0, 0.25)
                                        scale: swatchMa.containsMouse ? 1.25 : (swatchItem.isSelected ? 1.15 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                    }

                                    TooltipMixin {
                                        id: swatchTip
                                        root: notesSection.root
                                        owner: swatchItem
                                        text: swatchItem.modelData.name
                                    }

                                    MouseArea {
                                        id: swatchMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: swatchTip.show()
                                        onExited: swatchTip.hide()
                                        onClicked: {
                                            swatchTip.hide()
                                            notesSection.changeCurrentNoteColor(swatchItem.modelData.bg)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Actions Group on the Right (Pin, Copy, Duplicate, Delete)
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // 1. Toggle Pin Button
                        Rectangle {
                            id: pinBtn
                            width: 26
                            height: 26
                            radius: 13
                            color: notesSection.editingPinned
                                ? root.seal
                                : (pinMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "push_pin"
                                font.pixelSize: 14
                                color: notesSection.editingPinned ? root.paper : (pinMa.containsMouse ? root.ink : root.sumiHi)
                            }

                            TooltipMixin {
                                id: pinTip
                                root: notesSection.root
                                owner: pinBtn
                                text: notesSection.editingPinned ? "Unpin note (Ctrl+P)" : "Pin note to top (Ctrl+P)"
                            }

                            MouseArea {
                                id: pinMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: pinTip.show()
                                onExited: pinTip.hide()
                                onClicked: notesSection.togglePin()
                            }
                        }

                        // 2. Copy Note to Clipboard Button
                        Rectangle {
                            id: copyBtn
                            width: 26
                            height: 26
                            radius: 13
                            color: notesSection.copiedNotice
                                ? root.color02
                                : (copyMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }

                            IconText {
                                anchors.centerIn: parent
                                text: notesSection.copiedNotice ? "check" : "content_copy"
                                font.pixelSize: 14
                                color: notesSection.copiedNotice ? root.paper : (copyMa.containsMouse ? root.ink : root.sumiHi)
                            }

                            TooltipMixin {
                                id: copyTip
                                root: notesSection.root
                                owner: copyBtn
                                text: notesSection.copiedNotice ? "Copied!" : "Copy note to clipboard"
                            }

                            MouseArea {
                                id: copyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: copyTip.show()
                                onExited: copyTip.hide()
                                onClicked: notesSection.copyNoteToClipboard()
                            }
                        }

                        // 3. Duplicate Note Button
                        Rectangle {
                            id: dupBtn
                            width: 26
                            height: 26
                            radius: 13
                            color: dupMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "file_copy"
                                font.pixelSize: 14
                                color: dupMa.containsMouse ? root.ink : root.sumiHi
                            }

                            TooltipMixin {
                                id: dupTip
                                root: notesSection.root
                                owner: dupBtn
                                text: "Duplicate note (Ctrl+D)"
                            }

                            MouseArea {
                                id: dupMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: dupTip.show()
                                onExited: dupTip.hide()
                                onClicked: notesSection.duplicateNote()
                            }
                        }

                        // 4. Delete Note Button
                        Rectangle {
                            id: delBtn
                            width: 26
                            height: 26
                            radius: 13
                            color: delEditorMa.containsMouse ? root.color01 : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "delete"
                                font.pixelSize: 14
                                color: delEditorMa.containsMouse ? root.paper : root.sumiHi
                            }

                            TooltipMixin {
                                id: delTip
                                root: notesSection.root
                                owner: delBtn
                                text: "Delete note"
                            }

                            MouseArea {
                                id: delEditorMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: delTip.show()
                                onExited: delTip.hide()
                                onClicked: {
                                    delTip.hide()
                                    notesSection.deleteNote(notesSection.selectedId)
                                }
                            }
                        }
                    }
                }

                // ── Note Title in Editor (Headline) ──
                Item {
                    id: editorTitleRow
                    anchors.top: editorHeader.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 24

                    TextField {
                        id: editorTitleInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        text: notesSection.editingTitle
                        placeholderText: "Note Title..."
                        placeholderTextColor: root.sumi
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        background: null
                        padding: 0
                        selectByMouse: true
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                notesSection.isInputFocused = true
                            } else {
                                notesSection.isInputFocused = (searchInput && searchInput.activeFocus) || (editorBodyArea && editorBodyArea.activeFocus) || false
                            }
                        }
                        onTextChanged: {
                            if (activeFocus) notesSection.updateTitle(text)
                        }
                        onEditingFinished: {
                            notesSection.commitTitle()
                        }
                        onAccepted: {
                            notesSection.commitTitle()
                            editorBodyArea.forceActiveFocus()
                        }
                        Keys.onEscapePressed: {
                            focus = false
                            notesSection.forceActiveFocus()
                        }
                    }

                    Binding {
                        target: editorTitleInput
                        property: "text"
                        value: notesSection.editingTitle
                        when: !editorTitleInput.activeFocus
                    }
                }

                // ── Note Description Text Area ──
                Flickable {
                    id: editorFlick
                    anchors.top: editorTitleRow.bottom
                    anchors.topMargin: 4
                    anchors.bottom: editorFooter.top
                    anchors.bottomMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: editorBodyArea.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextArea.flickable: TextArea {
                        id: editorBodyArea
                        width: editorFlick.width
                        text: notesSection.editingText
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        wrapMode: Text.Wrap
                        background: null
                        placeholderText: "Write your note description here..."
                        placeholderTextColor: root.sumi
                        selectByMouse: true
                        padding: 0
                        topPadding: 2
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                notesSection.isInputFocused = true
                            } else {
                                notesSection.isInputFocused = (searchInput && searchInput.activeFocus) || (editorTitleInput && editorTitleInput.activeFocus) || false
                            }
                        }
                        onTextChanged: {
                            if (activeFocus) notesSection.updateBody(text)
                        }
                        onEditingFinished: {
                            notesSection.commitBody()
                        }
                        Keys.onEscapePressed: {
                            focus = false
                            notesSection.forceActiveFocus()
                        }
                    }

                    Binding {
                        target: editorBodyArea
                        property: "text"
                        value: notesSection.editingText
                        when: !editorBodyArea.activeFocus
                    }

                    ScrollBar.vertical: ScrollBar {
                        width: 4
                        policy: ScrollBar.AsNeeded
                    }
                }

                // ── Footer: Quick Markdown Inserts + Word/Char Count & Timestamp ──
                Item {
                    id: editorFooter
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 22

                    // Quick Format Inserts Bar
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Todo Checklist Item
                        Rectangle {
                            width: 24
                            height: 20
                            radius: 6
                            color: todoHov.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"
                            IconText {
                                anchors.centerIn: parent
                                text: "check_box"
                                font.pixelSize: 13
                                color: todoHov.containsMouse ? root.ink : root.sumiHi
                            }
                            TooltipMixin { root: notesSection.root; owner: parent; text: "Insert checklist [ ]" }
                            MouseArea { id: todoHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notesSection.insertSnippet("\n- [ ] ") }
                        }

                        // Bullet Item
                        Rectangle {
                            width: 24
                            height: 20
                            radius: 6
                            color: bulletHov.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"
                            IconText {
                                anchors.centerIn: parent
                                text: "format_list_bulleted"
                                font.pixelSize: 13
                                color: bulletHov.containsMouse ? root.ink : root.sumiHi
                            }
                            TooltipMixin { root: notesSection.root; owner: parent; text: "Insert bullet •" }
                            MouseArea { id: bulletHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notesSection.insertSnippet("\n• ") }
                        }

                        // Code Block
                        Rectangle {
                            width: 24
                            height: 20
                            radius: 6
                            color: codeHov.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"
                            IconText {
                                anchors.centerIn: parent
                                text: "code"
                                font.pixelSize: 13
                                color: codeHov.containsMouse ? root.ink : root.sumiHi
                            }
                            TooltipMixin { root: notesSection.root; owner: parent; text: "Insert code block" }
                            MouseArea { id: codeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notesSection.insertSnippet("\n```\n\n```\n") }
                        }

                        // Current Timestamp
                        Rectangle {
                            width: 24
                            height: 20
                            radius: 6
                            color: timeHov.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"
                            IconText {
                                anchors.centerIn: parent
                                text: "schedule"
                                font.pixelSize: 13
                                color: timeHov.containsMouse ? root.ink : root.sumiHi
                            }
                            TooltipMixin { root: notesSection.root; owner: parent; text: "Insert current timestamp" }
                            MouseArea {
                                id: timeHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var t = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                                    notesSection.insertSnippet("[" + t + "] ")
                                }
                            }
                        }
                    }

                    // Word Count, Char Count, and Last Edited Timestamp
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        UiText {
                            text: notesSection.wordCount + (notesSection.wordCount === 1 ? " word" : " words") + "  •  " + notesSection.charCount + " chars"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: root.sumiHi
                        }

                        UiText {
                            visible: notesSection.lastEditedTime !== ""
                            text: "•  " + notesSection.lastEditedTime
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: root.sumi
                        }
                    }
                }
            }

            // Empty state when no note selected
            Item {
                anchors.fill: parent
                visible: notesSection.selectedId === ""

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "description"
                        font.pixelSize: 42
                        color: root.sumi
                        opacity: 0.4
                    }

                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Select a note to view or edit"
                        font.family: root.barFont
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: root.sumi
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 120
                        height: 34
                        radius: 17
                        color: root.seal

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                text: "add"
                                font.pixelSize: 17
                                color: root.paper
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            UiText {
                                text: "Create Note"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: root.paper
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notesSection.createNote()
                        }
                    }
                }
            }
        }
    }
}
