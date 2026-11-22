import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// --- MATERIAL 3 EXPRESSIVE DASHBOARD TILES (Spring-Driven Pager) ---
Item {
    id: tilesPagerContainer
    required property var dashboardContent
    required property var tilesModel
    required property var smoothScrollAnim

    property alias tilesPager: tilesPager

    readonly property var rootObj: dashboardContent ? dashboardContent.root : null
    readonly property color inkCol: (rootObj && rootObj.ink) ? rootObj.ink : "#ffffff"
    readonly property color sealCol: (rootObj && rootObj.seal) ? rootObj.seal : "#22d3ee"
    readonly property bool showPageDots: dashboardContent && dashboardContent.totalPageCount > 1

    Flickable {
        id: tilesPager
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: pageIndicatorCol.visible ? pageIndicatorCol.left : parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: pageIndicatorCol.visible ? 6 : 4
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, dashboardContent.totalPageCount * dashboardContent.pageStride - 12 + 16)
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        z: 1

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
            x: 2
            y: 2
            width: dashboardContent.gridInnerWidth
            height: tilesPager.contentHeight

            Repeater {
                model: tilesModel

                DashboardTile {
                    dashContent: dashboardContent
                    tileId: model.id
                    span: model.span
                    tileShape: model.shape || ""
                    tileIndex: index
                    gridPage: model.gridPage
                    gridRow: model.gridRow
                    gridCol: model.gridCol

                    x: gridCol * (dashboardContent.tileUnitWidth + 10)
                    y: gridPage * dashboardContent.pageStride + (gridRow === 0 ? 0 : 66)
                    width: (span === 1 || span === "1x1") ? dashboardContent.tileUnitWidth : dashboardContent.tileDoubleWidth
                    height: (span === 4 || span === "2x2") ? 122 : 56

                    Behavior on x { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.25 } }
                    Behavior on y { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.25 } }
                    Behavior on width { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.25 } }
                    Behavior on height { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.25 } }
                }
            }
        }
    } // end tilesPager

    // ── M3 Expressive Morphing Page Indicator (Borderless) ──
    Column {
        id: pageIndicatorCol
        visible: tilesPagerContainer.showPageDots
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        z: 2

        Repeater {
            model: dashboardContent ? dashboardContent.totalPageCount : 1
            delegate: Rectangle {
                required property int index
                readonly property bool isCurrent: dashboardContent && dashboardContent.targetPageIndex === index
                width: 5
                height: isCurrent ? 18 : 5
                radius: 2.5
                border.width: 0
                color: isCurrent
                    ? tilesPagerContainer.sealCol
                    : Qt.rgba(tilesPagerContainer.inkCol.r, tilesPagerContainer.inkCol.g, tilesPagerContainer.inkCol.b, dotMa.containsMouse ? 0.50 : 0.22)

                Behavior on height { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                Behavior on color { ColorAnimation { duration: 160 } }

                MouseArea {
                    id: dotMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (dashboardContent) dashboardContent.goToPage(parent.index)
                }
            }
        }
    }
} // end tilesPagerContainer
