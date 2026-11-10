import QtQuick
import ".."
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── RIGHT COLUMN: DATE NOTE & EVENT DETAILS ──────────────────────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: rightColContainer

    required property var root
    required property var calSection

    readonly property bool isInputFocused: noteTextInput.activeFocus

    radius: 20
    color: root.fillIdle
    border.width: root.isLightMode ? 1 : 0
    border.color: root.cardBorderColor
    clip: true

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // 1. Right Header: Selected Date Title + Today/Count Badges
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "event_note"
                    font.pixelSize: 15
                    color: root.seal
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: calSection.selectedDayFullLabel
                    font.family: root.barFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.ink
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // "TODAY" badge
                Rectangle {
                    height: 18
                    width: todayBadgeTxt.implicitWidth + 10
                    radius: 9
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                    border.width: 1
                    border.color: root.seal
                    visible: calSection.isSelectedToday

                    UiText {
                        id: todayBadgeTxt
                        anchors.centerIn: parent
                        text: "TODAY"
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: root.seal
                    }
                }

                // Notes count badge
                Rectangle {
                    height: 18
                    width: noteCountBadgeTxt.implicitWidth + 10
                    radius: 9
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    UiText {
                        id: noteCountBadgeTxt
                        anchors.centerIn: parent
                        text: calSection.currentDayNotes.length + (calSection.currentDayNotes.length === 1 ? " note" : " notes")
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: root.sumi
                    }
                }
            }
        }

        // 2. Add Note Input Box
        Rectangle {
            id: addNoteBox
            width: parent.width
            height: 28
            radius: 14
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
            border.width: noteTextInput.activeFocus ? 1 : 0
            border.color: root.seal

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 4
                spacing: 6

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "add"
                    font.pixelSize: 15
                    color: noteTextInput.activeFocus ? root.seal : root.sumi
                    opacity: 0.8
                }

                Item {
                    width: parent.width - 20 - 24
                    height: parent.height

                    TextInput {
                        id: noteTextInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        clip: true
                        selectByMouse: true

                        onAccepted: {
                            if (noteTextInput.text.trim() !== "") {
                                calSection.addNote(calSection.selectedKey, noteTextInput.text);
                                noteTextInput.text = "";
                            }
                        }

                        Keys.onEscapePressed: {
                            noteTextInput.text = "";
                            noteTextInput.focus = false;
                        }
                    }

                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Add note or reminder..."
                        font.family: root.barFont
                        font.pixelSize: 11
                        color: root.sumi
                        opacity: 0.55
                        visible: noteTextInput.text === "" && !noteTextInput.activeFocus
                    }
                }

                // Submit Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: noteTextInput.text.trim() !== "" ? root.seal : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "arrow_forward"
                        font.pixelSize: 13
                        color: noteTextInput.text.trim() !== "" ? root.paper : root.sumi
                        opacity: noteTextInput.text.trim() !== "" ? 1.0 : 0.4
                    }

                    SpringPress {}
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: noteTextInput.text.trim() !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (noteTextInput.text.trim() !== "") {
                                calSection.addNote(calSection.selectedKey, noteTextInput.text);
                                noteTextInput.text = "";
                            }
                        }
                    }
                }
            }
        }

        // 3. Scrollable List of Notes / Events for Selected Date
        Item {
            width: parent.width
            height: parent.height - 24 - 8 - 28 - 8
            clip: true

            ListView {
                id: notesListView
                anchors.fill: parent
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: calSection.currentDayNotes

                delegate: Rectangle {
                    id: noteDelegateItem
                    width: notesListView.width
                    height: 28
                    radius: 8
                    color: noteItemMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: noteItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // Custom Checkbox (Toggle Done)
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            border.width: 1
                            border.color: modelData.done ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                            color: modelData.done ? root.seal : "transparent"

                            UiText {
                                anchors.centerIn: parent
                                text: "✓"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.paper
                                visible: modelData.done
                            }

                            SpringPress {}
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calSection.toggleNote(calSection.selectedKey, modelData.id)
                            }
                        }

                        // Note Text (Strikethrough when done)
                        UiText {
                            text: modelData.text
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.strikeout: modelData.done
                            color: modelData.done ? root.sumi : root.ink
                            opacity: modelData.done ? 0.50 : 1.0
                            elide: Text.ElideRight
                            width: parent.width - 56
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Delete Button
                        IconText {
                            text: "close"
                            color: root.sumi
                            font.pixelSize: 13
                            opacity: delNoteMa.containsMouse ? 1.0 : 0.6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: noteItemMa.containsMouse

                            SpringPress {}
                            MouseArea {
                                id: delNoteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calSection.deleteNote(calSection.selectedKey, modelData.id)
                            }
                        }
                    }
                }
            }

            // Empty State when no notes for selected date
            Item {
                anchors.fill: parent
                visible: calSection.currentDayNotes.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "event_available"
                        font.pixelSize: 24
                        color: root.sumi
                        opacity: 0.35
                    }

                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No notes for " + calSection.monthsShort[calSection.selMonth] + " " + calSection.selDay
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.sumi
                        opacity: 0.65
                    }

                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Type above and press Enter to save"
                        font.family: root.barFont
                        font.pixelSize: 10
                        color: root.sumi
                        opacity: 0.40
                    }
                }
            }
        }
    }
}
