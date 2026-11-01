import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// --- MATERIAL YOU TILES (Dynamic Pager with Resizable & Movable Tiles) ---
Item {
    id: tilesPagerContainer
    required property var dashboardContent
    required property var tilesModel
    required property var smoothScrollAnim

    property alias tilesPager: tilesPager

    Flickable {
        id: tilesPager
        anchors.fill: parent
        anchors.leftMargin: -3
        anchors.rightMargin: -3
        anchors.topMargin: -3
        anchors.bottomMargin: -3
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, dashboardContent.totalPageCount * dashboardContent.pageStride - 12 + 6)
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        Timer {
            id: snapTimer
            interval: 60
            onTriggered: {
                if (!smoothScrollAnim.running && dashboardContent.draggingTileId === "") {
                    let nearest = Math.max(0, Math.min(dashboardContent.totalPageCount - 1, Math.round(tilesPager.contentY / dashboardContent.pageStride)))
                    let targetY = nearest * dashboardContent.pageStride
                    if (Math.abs(tilesPager.contentY - targetY) > 1) {
                        dashboardContent.goToPage(nearest)
                    }
                }
            }
        }

        onContentYChanged: {
            if (!smoothScrollAnim.running) {
                snapTimer.restart()
            }
        }

        Timer {
            id: wheelResetTimer
            interval: 220
            onTriggered: pagerWheel.accumDelta = 0
        }

        WheelHandler {
            id: pagerWheel
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real accumDelta: 0

            onWheel: (event) => {
                wheelResetTimer.restart()
                pagerWheel.accumDelta += event.angleDelta.y
                if (pagerWheel.accumDelta >= 40) {
                    pagerWheel.accumDelta = 0
                    dashboardContent.pageUp()
                } else if (pagerWheel.accumDelta <= -40) {
                    pagerWheel.accumDelta = 0
                    dashboardContent.pageDown()
                }
            }
        }

        DragHandler {
            id: pagerDrag
            target: null
            acceptedDevices: PointerDevice.TouchScreen
            property real startY: 0
            onActiveChanged: {
                if (active) {
                    startY = centroid.position.y
                } else {
                    let diff = centroid.position.y - startY
                    if (diff < -24) dashboardContent.pageDown()
                    else if (diff > 24) dashboardContent.pageUp()
                }
            }
        }

        Item {
            id: tilesContent
            x: 3
            y: 3
            width: tilesPagerContainer.width
            height: tilesPager.contentHeight

            Repeater {
                model: tilesModel

                DashboardTile {
                    dashContent: dashboardContent
                    tileId: model.id
                    span: model.span
                    tileIndex: index
                    gridPage: model.gridPage
                    gridRow: model.gridRow
                    gridCol: model.gridCol

                    x: gridCol * (dashboardContent.tileUnitWidth + 10)
                    y: gridPage * dashboardContent.pageStride + (gridRow === 0 ? 0 : 66)
                    width: span === 2 ? dashboardContent.tileDoubleWidth : dashboardContent.tileUnitWidth

                    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on width {
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.35
                        }
                    }
                }
            }
        }
    } // end tilesPager
} // end tilesPagerContainer
