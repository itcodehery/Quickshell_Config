import QtQuick
import ".."
import QtQuick.Controls
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── RIGHT COLUMN: COLOR PICKER, DESCRIPTION & QUICK FORMAT BAR ────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: editorCard
    required property var root
    required property var notesSection
    property alias editorTitleInput: editorTitleInput
    property alias editorBodyArea: editorBodyArea

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
                        notesSection.isInputFocused = (notesSection.searchInputItem && notesSection.searchInputItem.activeFocus) || (editorBodyArea && editorBodyArea.activeFocus) || false
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
                        notesSection.isInputFocused = (notesSection.searchInputItem && notesSection.searchInputItem.activeFocus) || (editorTitleInput && editorTitleInput.activeFocus) || false
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
