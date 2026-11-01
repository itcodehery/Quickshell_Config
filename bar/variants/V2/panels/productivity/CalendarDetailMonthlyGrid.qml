import QtQuick
import ".."
import "../../modules"
import "../../motion"

// 2B. MONTHLY GRID - EXPANDED TO FULL AVAILABLE HEIGHT (Header is in top bar)
Item {
    id: monthlyGridView

    required property var root
    required property var calSection

    visible: calSection.viewMode === "monthly"
    clip: true

    // Wheel scroll over month grid to step months
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                calSection.stepMonth(1);
            } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                calSection.stepMonth(-1);
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 4

        // Weekday letter headers
        Row {
            width: parent.width
            height: 14
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                delegate: Item {
                    width: parent.width / 7
                    height: 14
                    UiText {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: root.sumi
                        opacity: 0.7
                    }
                }
            }
        }

        // 42-day complete month grid (6 rows of 7 days)
        Grid {
            width: parent.width
            height: parent.height - 18
            columns: 7
            rowSpacing: 2
            columnSpacing: 1

            Repeater {
                model: calSection.monthGridData
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isSelectedCell: (modelData.year === calSection.selYear && modelData.month === calSection.selMonth && modelData.day === calSection.selDay)

                    width: Math.floor((monthlyGridView.width - 6) / 7)
                    height: Math.floor((parent.height - (5 * 2)) / 6)
                    radius: 5
                    color: isSelectedCell 
                        ? root.seal
                        : (mCellMa.containsMouse ? root.fillHover : "transparent")

                    UiText {
                        anchors.centerIn: parent
                        text: modelData.day
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: (modelData.isToday || isSelectedCell) ? Font.Bold : Font.Normal
                        color: isSelectedCell
                            ? root.paper
                            : (modelData.isCurrentMonth ? root.ink : root.sumi)
                        opacity: isSelectedCell ? 1.0 : (modelData.isCurrentMonth ? 1.0 : 0.35)
                    }

                    // Dot for days with notes
                    Rectangle {
                        visible: modelData.hasNotes
                        width: 3
                        height: 3
                        radius: 1.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        color: isSelectedCell ? root.paper : root.seal
                    }

                    SpringPress {}
                    MouseArea {
                        id: mCellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calSection.selYear = modelData.year;
                            calSection.selMonth = modelData.month;
                            calSection.selDay = modelData.day;
                        }
                    }
                }
            }
        }
    }
}
