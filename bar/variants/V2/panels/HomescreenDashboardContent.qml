import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQml.Models
import "../modules"
import "../motion"

Item {
    id: dashboardContent
    anchors.fill: parent
    implicitHeight: 220
    focus: true

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            if (tilesModel.count === 0) initTiles()
            if (!root || !root.dashboardDetail) {
                activeDetailView = ""
                selectCategoryByIndex(0)
            }
        }
    }
    Component.onCompleted: {
        forceActiveFocus()
        initTiles()
        if (!root || !root.dashboardDetail) {
            activeDetailView = ""
            selectCategoryByIndex(0)
        }
        recalculateGridLayout()
    }

    SpringPress {}
    MouseArea {
        anchors.fill: parent
        // Prevent clicks anywhere on the dashboard background from closing the dashboard
        onClicked: {}
    }

    // ── Resizable & Movable Tiles State ──
    property bool editTilesMode: false
    property string selectedTileId: ""
    property string draggingTileId: ""
    property int dragTileSpan: 1
    property bool caffeineActive: false
    property int cpuTemp: 45
    readonly property color cpuTempColor: cpuTemp < 52 ? "#22d3ee" : (cpuTemp < 72 ? "#fbbf24" : "#f87171")

    readonly property var defaultTiles: [
        { id: "wifi", span: 2 },
        { id: "bluetooth", span: 2 },
        { id: "cpu", span: 2 },
        { id: "memory", span: 2 },
        { id: "notifications", span: 2 },
        { id: "screentime", span: 2 },
        { id: "nightlight", span: 1 },
        { id: "caffeine", span: 1 },
        { id: "battery", span: 1 },
        { id: "temperature", span: 1 },
        { id: "plugins", span: 2 },
        { id: "updates", span: 1 },
        { id: "lockscreen", span: 1 },
        { id: "pomodoro", span: 1 },
        { id: "quickshare", span: 1 },
        { id: "theme", span: 1 },
        { id: "wallpaper", span: 1 }
    ]

    readonly property real tileUnitWidth: Math.floor((leftCol.width - 30) / 4)
    readonly property real tileDoubleWidth: tileUnitWidth * 2 + 10
    readonly property real pageStride: 122 + 12
    property int totalPageCount: 1
    property bool showPomodoroPopup: false

    ListModel {
        id: tilesModel
        Component.onCompleted: dashboardContent.initTiles()
    }

    property string dropTargetTileId: ""

    function recalculateGridLayout() {
        let curPage = 0
        let curRow = 0
        let curCol = 0

        for (let i = 0; i < tilesModel.count; i++) {
            let item = tilesModel.get(i)
            let span = (item.span === 2) ? 2 : 1
            if (curCol + span > 4) {
                curRow++
                curCol = 0
            }
            if (curRow >= 2) {
                curPage++
                curRow = 0
            }

            tilesModel.setProperty(i, "gridPage", curPage)
            tilesModel.setProperty(i, "gridRow", curRow)
            tilesModel.setProperty(i, "gridCol", curCol)

            curCol += span
        }

        totalPageCount = Math.max(1, curPage + 1)
        if (tilesPager) {
            let maxScroll = Math.max(0, (totalPageCount - 1) * pageStride)
            if (tilesPager.contentY > maxScroll) {
                smoothScrollAnim.stop()
                smoothScrollAnim.to = maxScroll
                smoothScrollAnim.start()
            }
        }
    }

    function setTileSpan(id, newSpan) {
        for (let i = 0; i < tilesModel.count; i++) {
            if (tilesModel.get(i).id === id) {
                tilesModel.setProperty(i, "span", newSpan)
                break
            }
        }
        recalculateGridLayout()
        saveTilesLayout()
    }

    function toggleTileSpan(id) {
        let cur = getTileSpan(id)
        setTileSpan(id, cur === 2 ? 1 : 2)
    }

    function getTileSpan(id) {
        for (let i = 0; i < tilesModel.count; i++) {
            if (tilesModel.get(i).id === id) return tilesModel.get(i).span === 2 ? 2 : 1
        }
        return 1
    }

    function toggleEditMode(id) {
        if (!editTilesMode) {
            editTilesMode = true
            selectedTileId = id || (tilesModel.count > 0 ? tilesModel.get(0).id : "")
        } else {
            if (id && id !== selectedTileId) {
                selectedTileId = id
            } else {
                editTilesMode = false
                selectedTileId = ""
                dropTargetTileId = ""
                saveTilesLayout()
            }
        }
    }

    function moveSelectedTile(dir) {
        if (!selectedTileId) return
        let idx = -1
        for (let i = 0; i < tilesModel.count; i++) {
            if (tilesModel.get(i).id === selectedTileId) {
                idx = i
                break
            }
        }
        if (idx === -1) return
        let targetIdx = idx + dir
        if (targetIdx < 0 || targetIdx >= tilesModel.count) return

        tilesModel.move(idx, targetIdx, 1)
        recalculateGridLayout()
        saveTilesLayout()

        goToPage(getTilePageIndex(selectedTileId))
    }

    function startDraggingTile(id, globalX, globalY) {
        draggingTileId = id
        selectedTileId = id
        dropTargetTileId = ""
        dragTileSpan = getTileSpan(id)
        if (dragPreviewItem) {
            dragPreviewItem.currentMouseX = globalX
            dragPreviewItem.currentMouseY = globalY
        }
    }

    function updateDraggingTile(globalX, globalY) {
        if (draggingTileId === "") return
        if (dragPreviewItem) {
            dragPreviewItem.currentMouseX = globalX
            dragPreviewItem.currentMouseY = globalY
        }

        let pt = tilesPager.mapFromItem(dashboardContent, globalX, globalY)

        if (pt.y < 12 && !autoScrollTimer.running) {
            autoScrollTimer.dir = -1
            autoScrollTimer.restart()
            pageUp()
        } else if (pt.y > tilesPager.height - 12 && !autoScrollTimer.running) {
            autoScrollTimer.dir = 1
            autoScrollTimer.restart()
            pageDown()
        }

        let curPage = Math.max(0, Math.min(totalPageCount - 1, Math.round(tilesPager.contentY / pageStride)))
        let localY = pt.y + tilesPager.contentY
        let localX = pt.x

        let targetId = ""
        for (let i = 0; i < tilesModel.count; i++) {
            let t = tilesModel.get(i)
            if (t.gridPage !== curPage) continue
            let tX = t.gridCol * (tileUnitWidth + 10)
            let tY = t.gridPage * pageStride + (t.gridRow === 0 ? 0 : 66)
            let tW = t.span === 2 ? tileDoubleWidth : tileUnitWidth
            if (localX >= tX - 4 && localX <= tX + tW + 4 &&
                localY >= tY - 4 && localY <= tY + 56 + 4) {
                targetId = t.id
                break
            }
        }
        dropTargetTileId = targetId
    }

    function finishDraggingTile() {
        if (draggingTileId !== "" && dropTargetTileId !== "" && draggingTileId !== dropTargetTileId) {
            let fromIdx = -1
            let toIdx = -1
            for (let i = 0; i < tilesModel.count; i++) {
                if (tilesModel.get(i).id === draggingTileId) fromIdx = i
                if (tilesModel.get(i).id === dropTargetTileId) toIdx = i
            }
            if (fromIdx !== -1 && toIdx !== -1) {
                tilesModel.move(fromIdx, toIdx, 1)
                recalculateGridLayout()
            }
        }
        draggingTileId = ""
        dropTargetTileId = ""
        saveTilesLayout()
    }

    function getTilePageIndex(id) {
        if (!id) return 0
        for (let i = 0; i < tilesModel.count; i++) {
            if (tilesModel.get(i).id === id) {
                return tilesModel.get(i).gridPage
            }
        }
        return 0
    }

    function triggerTileAction(tileId) {
        switch (tileId) {
            case "wifi":
            case "bluetooth":
            case "cpu":
            case "memory":
            case "notifications":
            case "screentime":
            case "battery":
            case "plugins":
            case "updates":
            case "lockscreen":
            case "theme":
            case "wallpaper":
            case "notes":
            case "calendar":
                if (dashboardContent.activeDetailView === tileId) {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                } else {
                    dashboardContent.activeDetailView = tileId
                    if (root) root.dashboardDetail = tileId
                }
                break
            case "nightlight":
                dashboardContent.cycleNightMode()
                break
            case "caffeine":
                toggleCaffeine()
                break
            case "temperature":
                refreshCpuTemp()
                break
            case "pomodoro":
                dashboardContent.showPomodoroPopup = !dashboardContent.showPomodoroPopup
                break
            case "quickshare":
                Quickshell.execDetached(["localsend"])
                break
        }
    }

    function toggleCaffeine() {
        if (dashboardContent.caffeineActive) {
            Quickshell.execDetached(["pkill", "-f", "why=caffeine"])
            dashboardContent.caffeineActive = false
        } else {
            Quickshell.execDetached(["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=caffeine", "sleep", "infinity"])
            dashboardContent.caffeineActive = true
        }
    }

    function refreshCpuTemp() {
        tempUpdater.running = false
        tempUpdater.running = true
    }

    function initTiles() {
        if (tilesModel.count > 0) return
        try {
            let txt = tilesLayoutFile.text().trim()
            if (txt.length > 0) {
                let parsed = JSON.parse(txt)
                if (Array.isArray(parsed) && parsed.length > 0) {
                    loadCustomTiles(parsed)
                    return
                }
            }
        } catch(e) {}
        loadDefaultTiles()
    }

    function loadDefaultTiles() {
        tilesModel.clear()
        for (let i = 0; i < defaultTiles.length; i++) {
            tilesModel.append({
                id: defaultTiles[i].id,
                span: defaultTiles[i].span,
                gridPage: 0,
                gridRow: 0,
                gridCol: 0
            })
        }
        recalculateGridLayout()
    }

    function loadCustomTiles(savedList) {
        let knownIds = defaultTiles.map(t => t.id)
        let result = []
        let savedMap = {}
        for (let i = 0; i < savedList.length; i++) {
            let item = savedList[i]
            if (knownIds.indexOf(item.id) !== -1 && !savedMap[item.id]) {
                result.push({ id: item.id, span: item.span === 2 ? 2 : 1 })
                savedMap[item.id] = true
            }
        }
        for (let j = 0; j < defaultTiles.length; j++) {
            let dt = defaultTiles[j]
            if (!savedMap[dt.id]) {
                result.push({ id: dt.id, span: dt.span })
            }
        }
        tilesModel.clear()
        for (let k = 0; k < result.length; k++) {
            tilesModel.append({
                id: result[k].id,
                span: result[k].span,
                gridPage: 0,
                gridRow: 0,
                gridCol: 0
            })
        }
        recalculateGridLayout()
    }

    function saveTilesLayout() {
        let toSave = []
        for (let i = 0; i < tilesModel.count; i++) {
            let item = tilesModel.get(i)
            toSave.push({ id: item.id, span: item.span })
        }
        saveLayoutProc.jsonContent = JSON.stringify(toSave, null, 2)
        saveLayoutProc.running = true
    }

    function resetTilesLayout() {
        loadDefaultTiles()
        saveTilesLayout()
    }

    readonly property var detailOrder: ["", "wifi", "bluetooth", "cpu", "memory", "notifications", "screentime", "plugins", "updates", "notes", "battery", "calendar", "volume", "system", "theme", "wallpaper", "lockscreen"]

    function selectCategoryByIndex(idx) {
        if (idx < 0) idx = 0
        if (idx >= detailOrder.length) idx = detailOrder.length - 1
        let cat = detailOrder[idx]
        dashboardContent.activeDetailView = cat
        if (root) root.dashboardDetail = cat

        // Keep left-hand tilesPager in sync so active tile is visible
        goToPage(getTilePageIndex(cat))

        dashboardContent.forceActiveFocus()
    }

    function jumpNextCategory() {
        let curIdx = detailOrder.indexOf(dashboardContent.activeDetailView)
        let nextIdx = (curIdx + 1) % detailOrder.length
        selectCategoryByIndex(nextIdx)
    }

    function jumpPrevCategory() {
        let curIdx = detailOrder.indexOf(dashboardContent.activeDetailView)
        if (curIdx <= 0) curIdx = detailOrder.length
        let prevIdx = curIdx - 1
        selectCategoryByIndex(prevIdx)
    }

    function nextOption() {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(1)
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex + 1) % 4
            return
        }
        jumpNextCategory()
    }

    function prevOption() {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(-1)
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex - 1 + 4) % 4
            return
        }
        jumpPrevCategory()
    }

    Keys.onUpPressed: {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.setMode) {
                themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
            }
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex - 1 + 4) % 4
            return
        }
        if (dashboardContent.activeDetailView === "plugins") {
            if (pluginsDetailLoader.item) pluginsDetailLoader.item.focusedIndex = Math.max(0, pluginsDetailLoader.item.focusedIndex - 1)
            return
        }
        pageUp()
    }
    Keys.onDownPressed: {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.setMode) {
                themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
            }
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex + 1) % 4
            return
        }
        if (dashboardContent.activeDetailView === "plugins") {
            if (pluginsDetailLoader.item) pluginsDetailLoader.item.focusedIndex = pluginsDetailLoader.item.focusedIndex + 1
            return
        }
        pageDown()
    }
    Keys.onLeftPressed: {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        prevOption()
    }
    Keys.onRightPressed: {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        nextOption()
    }
    Keys.onPressed: (event) => {
        if (dashboardContent.editTilesMode) {
            if (event.key === Qt.Key_Escape) {
                dashboardContent.editTilesMode = false
                dashboardContent.saveTilesLayout()
                event.accepted = true
                return
            }
        }
        if (dashboardContent.activeDetailView === "system") {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_X) {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
                event.accepted = true
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex + 1) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex - 1 + 4) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (sysDetailLoader.item) sysDetailLoader.item.triggerOption(sysDetailLoader.item.focusedIndex)
                event.accepted = true
            }
            return
        }
        if (dashboardContent.activeDetailView === "plugins") {
            if (event.key === Qt.Key_Escape) {
                if (pluginsDetailLoader.item && pluginsDetailLoader.item.filterText.length > 0) {
                    pluginsDetailLoader.item.filterText = ""
                } else {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
                event.accepted = true
            } else if (event.key === Qt.Key_H) {
                if (event.modifiers & Qt.ShiftModifier) {
                    jumpPrevCategory()
                } else {
                    prevOption()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_L) {
                if (event.modifiers & Qt.ShiftModifier) {
                    jumpNextCategory()
                } else {
                    nextOption()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                if (pluginsDetailLoader.item) {
                    var count = pluginsDetailLoader.item.filteredCount || 1
                    pluginsDetailLoader.item.focusedIndex = (pluginsDetailLoader.item.focusedIndex + 1) % count
                }
                event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                if (pluginsDetailLoader.item) {
                    var count = pluginsDetailLoader.item.filteredCount || 1
                    pluginsDetailLoader.item.focusedIndex = (pluginsDetailLoader.item.focusedIndex - 1 + count) % count
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (pluginsDetailLoader.item) pluginsDetailLoader.item.triggerLaunch(pluginsDetailLoader.item.focusedIndex)
                event.accepted = true
            } else if (event.key === Qt.Key_P) {
                if (pluginsDetailLoader.item) pluginsDetailLoader.item.togglePinCurrent(pluginsDetailLoader.item.focusedIndex)
                event.accepted = true
            } else if (event.key === Qt.Key_Slash) {
                if (pluginsDetailLoader.item && pluginsDetailLoader.item.focusSearch) {
                    pluginsDetailLoader.item.focusSearch()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (pluginsDetailLoader.item && pluginsDetailLoader.item.filterText.length > 0) {
                    pluginsDetailLoader.item.filterText = pluginsDetailLoader.item.filterText.slice(0, -1)
                }
                event.accepted = true
            }
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (event.key === Qt.Key_Escape) {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (themeLoader.item && themeLoader.item.applySelected) themeLoader.item.applySelected()
                event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                if (themeLoader.item && themeLoader.item.setMode) {
                    themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                if (themeLoader.item && themeLoader.item.setMode) {
                    themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (themeLoader.item && themeLoader.item.filterText.length > 0) {
                    themeLoader.item.filterText = themeLoader.item.filterText.slice(0, -1)
                }
                event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                       && event.text.charCodeAt(0) !== 127
                       && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
                if (themeLoader.item) {
                    themeLoader.item.filterText += event.text
                }
                event.accepted = true
            }
            return
        }
        if (dashboardContent.activeDetailView === "notes") {
            if (notesDetailSection && notesDetailSection.isInputFocused) {
                if (event.key === Qt.Key_Escape) {
                    if (notesDetailSection.clearInputFocus) {
                        notesDetailSection.clearInputFocus()
                    }
                    event.accepted = true
                }
                return
            }
            if (event.key === Qt.Key_Escape) {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
                event.accepted = true
            }
            return
        }
        if ((calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (event.key === Qt.Key_K) {
            pageUp()
            event.accepted = true
        } else if (event.key === Qt.Key_J) {
            pageDown()
            event.accepted = true
        } else if (event.key === Qt.Key_H) {
            if (event.modifiers & Qt.ShiftModifier) {
                jumpPrevCategory()
            } else {
                prevOption()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            if (event.modifiers & Qt.ShiftModifier) {
                jumpNextCategory()
            } else {
                nextOption()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            if (panel && panel.searchOpen) {
                panel.toggleSearchEngine()
            } else if (event.modifiers & Qt.ShiftModifier) {
                jumpPrevCategory()
            } else {
                jumpNextCategory()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
            jumpPrevCategory()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (dashboardContent.activeDetailView !== "") {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else if (panel) {
                panel.expanded = false
            }
            event.accepted = true
        } else if (event.key === Qt.Key_S) {
            if (panel) {
                panel.toggleSearch()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_N) {
            if (mprisSel.player) mprisSel.player.next()
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            if (mprisSel.player) mprisSel.player.previous()
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            if (mprisSel.player) {
                mprisSel.player.togglePlaying()
                event.accepted = true
            } else if (dashboardContent.activeDetailView === "wifi" && wifiDetailSection) {
                wifiDetailSection.startSpeedTestWithSweep()
                event.accepted = true
            } else if (dashboardContent.activeDetailView === "bluetooth" && btDetailSection) {
                btDetailSection.doTogglePower()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_C) {
            if (calDetailSection && calDetailSection.isInputFocused) {
                return;
            }
            if (dashboardContent.activeDetailView === "calendar") {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else {
                dashboardContent.activeDetailView = "calendar"
                if (root) root.dashboardDetail = "calendar"
            }
            event.accepted = true
        } else if (event.key === Qt.Key_X) {
            if (calDetailSection && calDetailSection.isInputFocused) {
                return;
            }
            if (panel && panel.searchOpen) {
                return;
            }
            if (dashboardContent.activeDetailView === "system") {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else {
                dashboardContent.activeDetailView = "system"
                if (root) root.dashboardDetail = "system"
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (dashboardContent.activeDetailView === "wifi" && wifiDetailSection) {
                wifiDetailSection.startSpeedTestWithSweep()
                event.accepted = true
            } else if (dashboardContent.activeDetailView === "bluetooth" && btDetailSection) {
                btDetailSection.doTogglePower()
                event.accepted = true
            }
        }
    }
    
    property int targetPageIndex: 0

    NumberAnimation {
        id: smoothScrollAnim
        target: tilesPager
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic
        onFinished: {
            if (tilesPager) {
                tilesPager.contentY = targetPageIndex * pageStride
            }
        }
    }
    
    function pageUp() {
        let cur = smoothScrollAnim.running ? targetPageIndex : Math.round(tilesPager.contentY / pageStride)
        if (cur > 0) {
            goToPage(cur - 1)
        } else {
            goToPage(0)
        }
    }
    
    function pageDown() {
        let cur = smoothScrollAnim.running ? targetPageIndex : Math.round(tilesPager.contentY / pageStride)
        if (cur < totalPageCount - 1) {
            goToPage(cur + 1)
        } else {
            goToPage(totalPageCount - 1)
        }
    }

    function goToPage(idx) {
        if (!tilesPager) return
        if (idx < 0) idx = 0
        if (idx >= totalPageCount) idx = totalPageCount - 1
        targetPageIndex = idx
        smoothScrollAnim.stop()
        smoothScrollAnim.to = idx * pageStride
        smoothScrollAnim.start()
    }

    function snapToNearestPage() {
        if (!tilesPager || smoothScrollAnim.running || dashboardContent.draggingTileId !== "") return
        let nearest = Math.max(0, Math.min(totalPageCount - 1, Math.round(tilesPager.contentY / pageStride)))
        goToPage(nearest)
    }

    Timer {
        id: autoScrollTimer
        interval: 350
        property int dir: 0
        onTriggered: {
            if (dashboardContent.draggingTileId === "") return
            if (dir < 0) pageUp()
            else if (dir > 0) pageDown()
        }
    }

    FileView {
        id: tilesLayoutFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell_tiles_layout.json"
        watchChanges: false
        onLoaded: {
            try {
                let txt = tilesLayoutFile.text().trim()
                if (txt.length > 0) {
                    let parsed = JSON.parse(txt)
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        dashboardContent.loadCustomTiles(parsed)
                        return
                    }
                }
            } catch(e) {}
            dashboardContent.loadDefaultTiles()
        }
    }

    Process {
        id: saveLayoutProc
        property string jsonContent: "[]"
        command: ["python3", "-c", "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", Quickshell.env("HOME") + "/.local/state/quickshell_tiles_layout.json", jsonContent]
    }

    Process {
        id: caffeineCheckProc
        running: true
        command: ["bash", "-c", "pgrep -f 'why=caffeine' > /dev/null && echo 'on' || echo 'off'"]
        stdout: StdioCollector {
            onStreamFinished: dashboardContent.caffeineActive = (this.text.trim() === "on")
        }
    }

    Process {
        id: tempReader
        running: true
        command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = parseInt(this.text.trim())
                if (!isNaN(t)) dashboardContent.cpuTemp = Math.round(t / 1000)
            }
        }
    }

    Process {
        id: tempUpdater
        command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = parseInt(this.text.trim())
                if (!isNaN(t)) dashboardContent.cpuTemp = Math.round(t / 1000)
            }
        }
    }

    Timer {
        interval: 2500; repeat: true; running: panel ? panel.expanded : true
        onTriggered: { tempUpdater.running = false; tempUpdater.running = true }
    }

    property var root
    property var panel
    property string activeDetailView: root && root.dashboardDetail ? root.dashboardDetail : ""

    readonly property var wifiDetailSection: wifiDetailLoader.item
    readonly property var btDetailSection: btDetailLoader.item
    readonly property var cpuDetailSection: cpuDetailLoader.item
    readonly property var memDetailSection: memDetailLoader.item
    readonly property var batDetailSection: batDetailLoader.item
    readonly property var stDetailSection: stDetailLoader.item
    readonly property var volDetailSection: volDetailLoader.item
    readonly property var sysDetailSection: sysDetailLoader.item
    readonly property var calDetailSection: calDetailLoader.item
    readonly property var notifDetailSection: notifDetailLoader.item
    readonly property var updatesDetailSection: updatesDetailLoader.item
    readonly property var notesDetailSection: notesDetailLoader.item
    readonly property var pluginsDetailSection: pluginsDetailLoader.item

    Connections {
        target: dashboardContent.root
        ignoreUnknownSignals: true
        function onDashboardDetailChanged() {
            if (dashboardContent.root && dashboardContent.activeDetailView !== dashboardContent.root.dashboardDetail) {
                dashboardContent.activeDetailView = dashboardContent.root.dashboardDetail || ""
            }
        }
    }

    onActiveDetailViewChanged: {
        if (root && root.dashboardDetail !== activeDetailView) {
            root.dashboardDetail = activeDetailView
        }
        if (activeDetailView === "") {
            pageUp()
        }
    }

    AudioData { id: audioData }

    property int currentBrightness: 50
    Process {
        running: true
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }
    Timer {
        interval: 3000; repeat: true; running: panel.expanded
        onTriggered: { briUpdater.running = false; briUpdater.running = true }
    }
    Process {
        id: briUpdater
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }

    property string currentWifiName: "Wi-Fi"
    property string currentBtName: "Bluetooth"
    property bool btPowered: false

    property int nightMode: 0 // 0: Off, 1: Soft (4500K), 2: Intense (3000K)
    property real lastNightChange: 0

    function cycleNightMode() {
        let nextMode = (nightMode + 1) % 3
        setNightMode(nextMode)
    }

    function setNightMode(mode) {
        lastNightChange = Date.now()
        nightMode = mode
        if (mode === 0) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset"])
        } else if (mode === 1) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.02; done; exec hyprsunset -t 4500"])
        } else if (mode === 2) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.02; done; exec hyprsunset -t 3000"])
        }
    }

    Process {
        id: nightUpdater
        running: true
        command: ["bash", "-c", "out=$(pgrep -a hyprsunset); if [ -z \"$out\" ]; then echo 'off'; elif echo \"$out\" | grep -q '3000'; then echo 'intense'; else echo 'soft'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - dashboardContent.lastNightChange < 1500) return
                let s = this.text.trim()
                if (s === "intense") dashboardContent.nightMode = 2
                else if (s === "soft") dashboardContent.nightMode = 1
                else dashboardContent.nightMode = 0
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 3000; repeat: true; running: panel.expanded; triggeredOnStart: true
        onTriggered: {
            wifiUpdater.running = false; wifiUpdater.running = true
            btUpdater.running = false; btUpdater.running = true
            nightUpdater.running = false; nightUpdater.running = true
        }
    }
    
    Process {
        id: wifiUpdater
        command: ["bash", "-c", "nmcli -t -c no -f TYPE,NAME connection show --active | grep 802-11-wireless | cut -d':' -f2- | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = this.text.trim()
                if (s !== "" && dashboardContent.currentWifiName === "Searching...") {
                    statusTimer.interval = 3000 // reset back
                }
                dashboardContent.currentWifiName = s === "" ? "Wi-Fi" : s
            }
        }
    }
    
    Process {
        id: btUpdater
        command: ["bash", "-c", "if bluetoothctl show | grep -q 'Powered: yes'; then echo on; else echo off; fi; bluetoothctl devices Connected | head -n1 | cut -d ' ' -f 3-"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n")
                let powered = (lines[0] || "").trim() === "on"
                let s = (lines[1] || "").trim()
                if (powered && dashboardContent.currentBtName === "Searching...") {
                    statusTimer.interval = 3000
                }
                dashboardContent.btPowered = powered
                dashboardContent.currentBtName = s === "" ? "Bluetooth" : s
            }
        }
    }

    MprisSelect { id: mprisSel }
    MprisArtwork { id: mprisArt; player: mprisSel.player; root: dashboardContent.root }
    
    property string curTitle: mprisSel.player ? (mprisSel.player.trackTitle || "") : ""
    property string curArtist: mprisSel.player ? (mprisSel.player.trackArtist || "") : ""
    property string curArtUrl: mprisArt.source
    readonly property bool hasMultiplePlayers: mprisSel.count > 1

    // ── Live Time & Date State for Aesthetic Clock Widget ──
    FontLoader {
        id: biggerFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Unknown Vendor/OpenType/Bigger/Bigger_Display.otf"
    }

    property date now: new Date()
    Timer {
        interval: 1000
        running: panel.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: dashboardContent.now = new Date()
    }

    readonly property string clockHours: {
        var h = dashboardContent.now.getHours()
        if (root && root.clock12h) {
            h = h % 12
            if (h === 0) h = 12
        }
        return h < 10 ? "0" + h : String(h)
    }

    readonly property string clockMinutes: {
        var m = dashboardContent.now.getMinutes()
        return m < 10 ? "0" + m : String(m)
    }

    readonly property string clockAmPm: {
        if (!root || !root.clock12h) return ""
        return dashboardContent.now.getHours() < 12 ? "AM" : "PM"
    }

    readonly property string timeGreeting: {
        var h = dashboardContent.now.getHours()
        if (h >= 5 && h < 12) return "Good Morning"
        if (h >= 12 && h < 17) return "Good Afternoon"
        if (h >= 17 && h < 22) return "Good Evening"
        return "Night Owl"
    }

    function getWeekNumber() {
        var d = new Date(Date.UTC(dashboardContent.now.getFullYear(), dashboardContent.now.getMonth(), dashboardContent.now.getDate()))
        var dayNum = d.getUTCDay() || 7
        d.setUTCDate(d.getUTCDate() + 4 - dayNum)
        var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
    }

    readonly property int dayProgressPercent: {
        var totalSecs = dashboardContent.now.getHours() * 3600 + dashboardContent.now.getMinutes() * 60 + dashboardContent.now.getSeconds()
        return Math.min(100, Math.max(0, Math.round((totalSecs / 86400) * 100)))
    }

    readonly property string remainingHoursToday: {
        var remMins = 1440 - (dashboardContent.now.getHours() * 60 + dashboardContent.now.getMinutes())
        var remH = Math.floor(remMins / 60)
        var remM = remMins % 60
        return remH + "h " + remM + "m left"
    }

    // Media Display Mode: Show Media Player only if actively playing or manually requested while paused
    property bool showMediaManually: false
    readonly property bool isMediaPlaying: mprisSel.playing && curTitle !== ""
    readonly property bool showMediaPlayer: isMediaPlaying || (showMediaManually && curTitle !== "")

    Connections {
        target: mprisSel
        function onPlayingChanged() {
            if (mprisSel.playing && dashboardContent.curTitle !== "") {
                dashboardContent.showMediaManually = true
            }
        }
    }
    
    property real curPos: 0
    property real curLen: 0
    property real _lastRead: -1
    
    function fmtTime(s) {
        if (!s || s <= 0 || isNaN(s)) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec)
    }

    function seekTo(ratio) {
        if (!mprisSel.player || curLen <= 0) return
        var target = Math.max(0, Math.min(1, ratio)) * curLen
        if (typeof mprisSel.player.setPosition === "function") {
            mprisSel.player.setPosition(target)
        } else {
            mprisSel.player.position = target
        }
        curPos = target
    }

    Timer {
        id: posTimer
        interval: 250; repeat: true
        running: mprisSel.active
        triggeredOnStart: true
        onTriggered: {
            if (!mprisSel.player) return
            var p = mprisSel.player.position || 0
            dashboardContent.curLen = mprisSel.player.length || 0
            if (Math.abs(p - dashboardContent._lastRead) > 0.05) {
                dashboardContent.curPos = p
                dashboardContent._lastRead = p
            } else if (mprisSel.playing) {
                dashboardContent.curPos = Math.min(dashboardContent.curLen, dashboardContent.curPos + 0.25)
            }
        }
    }

    Connections {
        target: mprisSel
        function onPlayerChanged() {
            dashboardContent.curPos = 0
            dashboardContent._lastRead = -1
            dashboardContent.curLen = mprisSel.player ? (mprisSel.player.length || 0) : 0
            dashboardContent.fetchLocalLyrics()
        }
    }

    readonly property string currentTrackId: {
        var t = curTitle ? curTitle.trim() : ""
        var a = curArtist ? curArtist.trim() : ""
        return (t || a) ? (t + "||" + a) : ""
    }

    property var mprisPanel: null
    property var localLyricsList: []
    property int localLyricIndex: -1
    property string localLyricsTrackId: ""
    property int _localLyricsFetchSeq: 0

    readonly property bool mprisHasTrackLyrics: mprisPanel !== null && mprisPanel !== undefined && mprisPanel.lyricsTrackId !== "" && mprisPanel.lyricsTrackId === currentTrackId && mprisPanel.lyricsList && mprisPanel.lyricsList.length > 0
    readonly property bool localHasTrackLyrics: localLyricsTrackId !== "" && localLyricsTrackId === currentTrackId && localLyricsList && localLyricsList.length > 0

    readonly property var activeLyricsList: mprisHasTrackLyrics ? mprisPanel.lyricsList : (localHasTrackLyrics ? localLyricsList : [])
    readonly property int activeLyricIndex: mprisHasTrackLyrics ? mprisPanel.currentLyricIndex : (localHasTrackLyrics ? localLyricIndex : -1)
    readonly property bool hasSyncedLyrics: mprisSel.active && activeLyricsList && activeLyricsList.length > 0 && activeLyricIndex >= 0 && activeLyricIndex < activeLyricsList.length
    readonly property string activeLyricText: hasSyncedLyrics ? activeLyricsList[activeLyricIndex].text : ""
    readonly property string nextLyricText: (hasSyncedLyrics && (activeLyricIndex + 1) < activeLyricsList.length) ? activeLyricsList[activeLyricIndex + 1].text : ""

    function syncLocalLyricIndex() {
        if (!localLyricsList || localLyricsList.length === 0) {
            if (localLyricIndex !== -1) localLyricIndex = -1
            return
        }
        var pos = dashboardContent.curPos
        var idx = -1
        for (var i = 0; i < localLyricsList.length; i++) {
            if (pos >= localLyricsList[i].time) {
                idx = i
            } else {
                break
            }
        }
        if (idx !== localLyricIndex) localLyricIndex = idx
    }

    function cleanTrackTitle(str) {
        if (!str) return ""
        return str.replace(/\s*[\(\[](feat\.|ft\.|remaster|live|official|deluxe|bonus|version|radio|edit|mono|stereo|anniversary).*?[\)\]]/gi, "")
                  .replace(/\s*-\s*(remaster|live|radio|deluxe|bonus|anniversary).*$/gi, "")
                  .trim()
    }

    function parseLocalLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return []
        var parsed = []
        var offsetSec = 0
        var offsetMatch = /\[offset:\s*([+-]?\d+)\]/i.exec(lrcText)
        if (offsetMatch) {
            offsetSec = (parseFloat(offsetMatch[1]) || 0) / 1000.0
        }

        var lines = lrcText.split('\n')
        var tagRegex = /\[(\d{1,2}):(\d{2}(?:\.\d+)?)\]/g
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || /^\[[a-zA-Z]+:/.test(line)) continue
            var timestamps = []
            var match
            tagRegex.lastIndex = 0
            while ((match = tagRegex.exec(line)) !== null) {
                var m = parseFloat(match[1])
                var s = parseFloat(match[2])
                timestamps.push((m * 60) + s)
            }
            if (timestamps.length > 0) {
                var txt = line.replace(/\[\d{1,2}:\d{2}(?:\.\d+)?\]/g, "").trim()
                if (txt.length > 0) {
                    for (var t = 0; t < timestamps.length; t++) {
                        var adjustedTime = Math.max(0, timestamps[t] + offsetSec)
                        parsed.push({ time: adjustedTime, text: txt })
                    }
                }
            }
        }
        parsed.sort(function(a, b) { return a.time - b.time })
        return parsed
    }

    function fetchLocalLyrics() {
        var title = curTitle ? curTitle.trim() : ""
        var artist = curArtist ? curArtist.trim() : ""
        var album = mprisSel.player ? (mprisSel.player.trackAlbum || "").trim() : ""
        var dur = Math.round(mprisSel.player ? (mprisSel.player.length || dashboardContent.curLen || 0) : (dashboardContent.curLen || 0))
        var trackId = (title || artist) ? (title + "||" + artist) : ""

        var seq = ++_localLyricsFetchSeq

        if (!title || !mprisSel.active) {
            localLyricsList = []
            localLyricIndex = -1
            localLyricsTrackId = ""
            return
        }

        // If mprisPanel is provided and actively managing lyrics for this track, let it handle it
        if (mprisPanel && mprisPanel.currentTrackId === trackId) {
            return
        }

        localLyricsList = []
        localLyricIndex = -1
        localLyricsTrackId = ""

        var cleaned = cleanTrackTitle(title)
        var targetTitle = cleaned !== "" ? cleaned : title

        function pickBestResult(resp) {
            if (!resp) return null
            if (!Array.isArray(resp) && resp.syncedLyrics) {
                return parseLocalLrc(resp.syncedLyrics)
            }
            if (Array.isArray(resp) && resp.length > 0) {
                var candidates = []
                for (var i = 0; i < resp.length; i++) {
                    var item = resp[i]
                    if (item && item.syncedLyrics && typeof item.syncedLyrics === "string" && item.syncedLyrics.trim().length > 0) {
                        var diff = dur > 0 && item.duration ? Math.abs(item.duration - dur) : 9999
                        candidates.push({ item: item, diff: diff })
                    }
                }
                if (candidates.length === 0) return null
                candidates.sort(function(a, b) { return a.diff - b.diff })
                return parseLocalLrc(candidates[0].item.syncedLyrics)
            }
            return null
        }

        function queryUrl(url, fallback) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, true)
            xhr.setRequestHeader("User-Agent", "Quickshell-Lyrics/2.0 (Linux)")
            xhr.timeout = 5000
            xhr.ontimeout = function() { if (fallback) fallback(); }
            xhr.onerror = function() { if (fallback) fallback(); }
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (seq !== dashboardContent._localLyricsFetchSeq || dashboardContent.currentTrackId !== trackId) {
                        return
                    }
                    if (xhr.status === 200) {
                        try {
                            var resp = JSON.parse(xhr.responseText)
                            var parsed = pickBestResult(resp)
                            if (parsed && parsed.length > 0) {
                                dashboardContent.localLyricsTrackId = trackId
                                dashboardContent.localLyricsList = parsed
                                dashboardContent.syncLocalLyricIndex()
                                return
                            }
                        } catch(e) {}
                    }
                    if (fallback) fallback()
                }
            }
            xhr.send()
        }

        var getUrl = dur > 0
            ? ("https://lrclib.net/api/get?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist) + (album ? "&album_name=" + encodeURIComponent(album) : "") + "&duration=" + dur)
            : ""
        var url1 = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist)
        var url2 = "https://lrclib.net/api/search?q=" + encodeURIComponent(targetTitle + " " + artist)

        if (getUrl !== "") {
            queryUrl(getUrl, function() {
                queryUrl(url1, function() {
                    queryUrl(url2, null)
                })
            })
        } else {
            queryUrl(url1, function() {
                queryUrl(url2, null)
            })
        }
    }

    onCurTitleChanged: {
        if (root && curTitle !== "") root.lastMediaTitle = curTitle
        fetchLocalLyrics()
    }
    onCurArtistChanged: {
        if (root && curArtist !== "") root.lastMediaArtist = curArtist
        fetchLocalLyrics()
    }
    onCurArtUrlChanged: { if (root && curArtUrl !== "") root.lastMediaArtUrl = curArtUrl }

    Connections {
        target: mprisSel.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { dashboardContent.fetchLocalLyrics() }
        function onTrackArtistChanged() { dashboardContent.fetchLocalLyrics() }
    }

    onCurPosChanged: {
        if (localLyricsList && localLyricsList.length > 0) {
            syncLocalLyricIndex()
        }
    }

    onRootChanged: {
        if (root) {
            recalculateGridLayout()
            if (mprisSel.player && mprisSel.player.trackTitle) {
                root.lastMediaTitle = mprisSel.player.trackTitle || ""
                root.lastMediaArtist = mprisSel.player.trackArtist || ""
            }
            if (mprisArt.source) root.lastMediaArtUrl = mprisArt.source
        }
    }

    // ── MAIN CONTROLS (Two Columns: Controls on Left, Media Player on Right) ──
    Item {
        id: mainControls
        anchors.fill: parent
        visible: (opacity > 0.001)
        opacity: dashboardContent.activeDetailView === "" ? 1.0 : 0.0
        scale: dashboardContent.activeDetailView === "" ? 1.0 : 0.98
        transform: Translate {
            y: dashboardContent.activeDetailView === "" ? 0 : (root && root.barPosition === "bottom" ? -10 : 10)
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 14

            // ── LEFT COLUMN: Sliders & Quick Settings Tiles ──
            Column {
                id: leftCol
                width: Math.round((parent.width - parent.spacing) / 2)
                spacing: 12

            // ── TOP CONTROL AREA (Sliders in Normal Mode, Edit Header in Edit Mode) ──
            Item {
                id: topControlArea
                width: parent.width
                height: 86

                // --- SLIDERS (Full Material You size) ---
                Column {
                    id: slidersCol
                    anchors.fill: parent
                    spacing: 10
                    visible: opacity > 0.001
                    opacity: dashboardContent.editTilesMode ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                
                // Brightness Container
                Row {
                    width: parent.width
                    spacing: 10
                    
                    // Brightness Slider
                    Rectangle {
                        id: briSlider
                        width: parent.width - 38 - 8
                        height: 38
                        radius: 19
                        color: root.fillIdle
                        
                        property bool sliding: false
                        property int localValue: dashboardContent.currentBrightness
                        
                        Item {
                            id: briFillItem
                            property real val: briSlider.sliding ? briSlider.localValue : dashboardContent.currentBrightness
                            property real gap: val > 85 ? 19 * (100 - val) / 15 : 19
                            property real barOpacity: val > 85 ? (100 - val) / 15 : 1
                            
                            width: Math.max(parent.height, parent.width * (val / 100))
                            height: parent.height
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            
                            // The actual fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width - briFillItem.gap)
                                radius: 9.5 + (9.5 * (1 - briFillItem.barOpacity))
                                color: root.seal
                                
                                // fully rounded on the left
                                Rectangle {
                                    width: parent.height
                                    height: parent.height
                                    radius: height / 2
                                    color: root.seal
                                    anchors.left: parent.left
                                }
                            }
                            
                            // The vertical bar with "padding"
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: parent.height
                                color: "transparent"
                                opacity: briFillItem.barOpacity
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: parent.height - 14
                                    radius: 1.5
                                    color: root.seal
                                }
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10
                            IconText { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: "light_mode"
                                color: root.paper
                                font.pixelSize: 18 
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(briFillItem.val) + "%"
                                color: briFillItem.width > 64 ? root.paper : root.ink
                                font.pixelSize: 12
                                font.family: root.barFont
                                font.weight: Font.DemiBold
                                opacity: briSlider.sliding ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onPressed: { briSlider.sliding = true }
                            onPositionChanged: (mouse) => {
                                if (pressed) briSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                            }
                            onReleased: (mouse) => {
                                briSlider.sliding = false
                                let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                dashboardContent.currentBrightness = pct
                                Quickshell.execDetached(["bash", "-c", "brightnessctl set " + pct + "%"])
                            }
                        }
                    }
                    
                    // Night Light Toggle (44x44, dual-mode: Soft / Intense)
                    Rectangle {
                        id: localNightToggle
                        width: 38
                        height: 38
                        radius: 19
                        
                        readonly property int mode: dashboardContent.nightMode
                        
                        color: mode === 2 ? root.color01 : (mode === 1 ? root.color03 : root.fillIdle)
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        HoverHandler {
                            id: localNightHov
                        }
                        
                        IconText { 
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            text: "nightlight_round"
                            color: localNightToggle.mode > 0 ? root.paper : root.ink
                            opacity: localNightToggle.mode > 0 ? 1.0 : 0.6
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Dual toggle indicator dashes
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3

                            Rectangle {
                                width: 5
                                height: 3
                                radius: 1.5
                                color: localNightToggle.mode > 0 ? root.paper : root.ink
                                opacity: localNightToggle.mode >= 1 ? 0.95 : 0.25
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Rectangle {
                                width: 5
                                height: 3
                                radius: 1.5
                                color: localNightToggle.mode > 0 ? root.paper : root.ink
                                opacity: localNightToggle.mode === 2 ? 0.95 : 0.25
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            id: localNightMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    dashboardContent.setNightMode(0)
                                } else {
                                    dashboardContent.cycleNightMode()
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    if (dashboardContent.nightMode < 2) dashboardContent.setNightMode(dashboardContent.nightMode + 1)
                                } else if (wheel.angleDelta.y < 0) {
                                    if (dashboardContent.nightMode > 0) dashboardContent.setNightMode(dashboardContent.nightMode - 1)
                                }
                            }
                        }
                    }
                }

                // Audio Container
                Row {
                    width: parent.width
                    spacing: 10
                    
                    // Audio Slider
                    Rectangle {
                        id: audSlider
                        width: parent.width - 38 - 8
                        height: 38
                        radius: 19
                        color: root.fillIdle
                        
                        property bool sliding: false
                        property int localValue: audioData.volume
                        
                        Item {
                            id: audFillItem
                            property real val: audSlider.sliding ? audSlider.localValue : audioData.volume
                            property real gap: val > 85 ? 19 * (100 - val) / 15 : 19
                            property real barOpacity: val > 85 ? (100 - val) / 15 : 1
                            
                            width: Math.max(parent.height, parent.width * (val / 100))
                            height: parent.height
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            
                            // The actual fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width - audFillItem.gap)
                                radius: 9.5 + (9.5 * (1 - audFillItem.barOpacity))
                                color: audioData.muted ? root.fillHover : root.seal
                                
                                // fully rounded on the left
                                Rectangle {
                                    width: parent.height
                                    height: parent.height
                                    radius: height / 2
                                    color: audioData.muted ? root.fillHover : root.seal
                                    anchors.left: parent.left
                                }
                            }
                            
                            // The vertical bar with "padding"
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: parent.height
                                color: "transparent"
                                opacity: audFillItem.barOpacity
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: parent.height - 14
                                    radius: 1.5
                                    color: audioData.muted ? root.fillHover : root.seal
                                }
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10
                            IconText { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: audioData.muted ? "volume_off" : "volume_up"
                                color: audioData.muted ? root.ink : root.paper
                                font.pixelSize: 18 
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(audFillItem.val) + "%"
                                color: audioData.muted ? root.ink : (audFillItem.width > 64 ? root.paper : root.ink)
                                font.pixelSize: 12
                                font.family: root.barFont
                                font.weight: Font.DemiBold
                                opacity: audSlider.sliding ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onPressed: { audSlider.sliding = true }
                            onPositionChanged: (mouse) => {
                                if (pressed) audSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                            }
                            onReleased: (mouse) => {
                                audSlider.sliding = false
                                let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%"])
                            }
                        }
                    }
                    
                    // Audio Settings / Detail Toggle (38x38)
                    Rectangle {
                        id: audSettingsToggle
                        width: 38
                        height: 38
                        radius: 19
                        color: dashboardContent.activeDetailView === "volume" ? root.seal : root.fillIdle
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        HoverHandler {
                            id: audTuneHov
                        }
                        
                        IconText { 
                            anchors.centerIn: parent
                            text: "tune"
                            color: dashboardContent.activeDetailView === "volume" ? root.paper : root.ink
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        SpringPress {}
                        MouseArea {
                            id: audTuneMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (dashboardContent.activeDetailView === "volume") {
                                    dashboardContent.activeDetailView = ""
                                    if (root) root.dashboardDetail = ""
                                } else {
                                    dashboardContent.activeDetailView = "volume"
                                    if (root) root.dashboardDetail = "volume"
                                }
                            }
                        }
                    }
                }
            } // end slidersCol

            // ── EDIT TILES HEADER (Direct copy of UI from image) ──
            Item {
                id: editTilesHeader
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: dashboardContent.editTilesMode ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                // Top Action Bar
                Row {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 32

                    // Back arrow button (<-)
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: backMa.containsMouse ? root.fillHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        IconText {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            color: root.ink
                            font.pixelSize: 20
                        }

                        TooltipMixin {
                            id: backTip
                            root: dashboardContent.root
                            owner: parent
                            text: "Exit tile editing"
                        }

                        MouseArea {
                            id: backMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: backTip.show()
                            onExited: backTip.hide()
                            onClicked: {
                                backTip.hide()
                                dashboardContent.editTilesMode = false
                                dashboardContent.saveTilesLayout()
                            }
                        }
                    }

                    Item { width: Math.max(10, parent.width - 32 - rightBtns.width - 10); height: 1 }

                    Row {
                        id: rightBtns
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        // Move Earlier / Left button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            visible: dashboardContent.selectedTileId !== ""
                            color: movePrevMa.containsMouse ? root.fillHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                color: root.ink
                                font.pixelSize: 22
                            }

                            TooltipMixin {
                                id: movePrevTip
                                root: dashboardContent.root
                                owner: parent
                                text: "Move selected tile left/earlier"
                            }

                            MouseArea {
                                id: movePrevMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: movePrevTip.show()
                                onExited: movePrevTip.hide()
                                onClicked: {
                                    dashboardContent.moveSelectedTile(-1)
                                }
                            }
                        }

                        // Move Later / Right button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            visible: dashboardContent.selectedTileId !== ""
                            color: moveNextMa.containsMouse ? root.fillHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                color: root.ink
                                font.pixelSize: 22
                            }

                            TooltipMixin {
                                id: moveNextTip
                                root: dashboardContent.root
                                owner: parent
                                text: "Move selected tile right/later"
                            }

                            MouseArea {
                                id: moveNextMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: moveNextTip.show()
                                onExited: moveNextTip.hide()
                                onClicked: {
                                    dashboardContent.moveSelectedTile(1)
                                }
                            }
                        }

                        // Undo / Reset button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: undoMa.containsMouse ? root.fillHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "undo"
                                color: root.ink
                                font.pixelSize: 20
                            }

                            TooltipMixin {
                                id: undoTip
                                root: dashboardContent.root
                                owner: parent
                                text: "Reset tiles to default"
                            }

                            MouseArea {
                                id: undoMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: undoTip.show()
                                onExited: undoTip.hide()
                                onClicked: {
                                    undoTip.hide()
                                    dashboardContent.resetTilesLayout()
                                }
                            }
                        }

                        // "Done" pill button (styled like the pill in the screenshot)
                        Rectangle {
                            height: 32
                            width: doneText.implicitWidth + 24
                            radius: 16
                            color: doneMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: doneText
                                anchors.centerIn: parent
                                text: "Done"
                                color: root.paper
                                font.pixelSize: 12
                                font.family: root.barFont
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: doneMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    dashboardContent.editTilesMode = false
                                    dashboardContent.saveTilesLayout()
                                }
                            }
                        }
                    }
                }

                // Title & Subtitle: "Edit tiles" / "Select tiles to rearrange and resize"
                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    spacing: 2

                    Text {
                        text: "Edit tiles"
                        color: root.ink
                        font.pixelSize: 18
                        font.family: root.barFont
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Select tiles to rearrange and resize"
                        color: root.ink
                        opacity: 0.65
                        font.pixelSize: 11
                        font.family: root.barFont
                    }
                }
            }
        } // end topControlArea

        // --- MATERIAL YOU TILES (Dynamic Pager with Resizable & Movable Tiles) ---
        Item {
            id: tilesPagerContainer
            width: parent.width
            height: 126

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
        } // end leftCol

        // ── RIGHT COLUMN: Media Player & Lyrics Drawer ──
        Item {
            id: rightCol
            width: parent.width - leftCol.width - parent.spacing
            height: leftCol.height

            // --- MATERIAL YOU MEDIA PLAYER WITH EXTENDED LYRICS SECTION ---
            Item {
                id: mediaWithLyricsGroup
                anchors.fill: parent
                readonly property real lyricsVisibleHeight: Math.max(60, height - mediaCard.height)

                visible: opacity > 0.001
                opacity: dashboardContent.showMediaPlayer ? 1.0 : 0.0
                scale: dashboardContent.showMediaPlayer ? 1.0 : 0.96
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                // Extended Lyrics Drawer (Starts from the back of the media player and extends down)
                Rectangle {
                    id: lyricsExtender
                    z: 1
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: 22

                    readonly property bool hasBrightDom: mediaCard.hasDominant && (mediaCard.domCol.r * 0.299 + mediaCard.domCol.g * 0.587 + mediaCard.domCol.b * 0.114 > 0.15)
                    color: mediaCard.hasDominant
                        ? Qt.rgba(mediaCard.domCol.r * 0.32, mediaCard.domCol.g * 0.32, mediaCard.domCol.b * 0.32, lyricsMa.containsMouse ? 0.75 : 0.60)
                        : (lyricsMa.containsMouse ? root.fillHover : root.fillIdle)
                    border.color: mediaCard.hasDominant
                        ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, lyricsMa.containsMouse ? 0.50 : 0.32)
                        : (lyricsMa.containsMouse ? root.islandBorder : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16))
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }

                    // Frosted acrylic glass styling with ambient dominant glow
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 22
                        color: "transparent"

                        // Specular glass gradient
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(1, 1, 1, lyricsMa.containsMouse ? 0.08 : 0.04)
                                }
                                GradientStop {
                                    position: 0.40
                                    color: Qt.rgba(1, 1, 1, 0.01)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "transparent"
                                }
                            }
                        }

                        // Subtle dominant ambient glow
                        Rectangle {
                            anchors.fill: parent
                            visible: mediaCard.hasDominant
                            opacity: lyricsMa.containsMouse ? 0.30 : 0.18
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: mediaCard.domCol
                                }
                                GradientStop {
                                    position: 0.85
                                    color: "transparent"
                                }
                            }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: lyricsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dashboardContent.mprisPanel) {
                                dashboardContent.mprisPanel.showingLyrics = !dashboardContent.mprisPanel.showingLyrics
                            }
                        }
                    }

                    // Visible extension area extending below mediaCard
                    Item {
                        id: lyricVisibleArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: mediaWithLyricsGroup.lyricsVisibleHeight

                        // Floating Pill Actions (Right aligned)
                        Row {
                            id: lyricsActionsRow
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Reload Lyrics Icon Button
                            Rectangle {
                                id: reloadLyricsBtn
                                width: 24
                                height: 24
                                radius: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: reloadLyricsMa.containsMouse ? (lyricsPillTag.isShowing ? Qt.rgba(1, 1, 1, 0.30) : root.fillHover) : Qt.rgba(1, 1, 1, 0.14)
                                border.color: Qt.rgba(1, 1, 1, 0.28)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                IconText {
                                    id: reloadIcon
                                    anchors.centerIn: parent
                                    text: "refresh"
                                    font.pixelSize: 13
                                    color: (mprisPanel && mprisPanel._isFetchingLyrics) ? root.seal : (root ? root.ink : "#ffffff")

                                    RotationAnimation on rotation {
                                        running: mprisPanel ? mprisPanel._isFetchingLyrics : false
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 800
                                    }
                                }

                                TooltipMixin {
                                    id: reloadLyricsTip
                                    root: dashboardContent.root
                                    owner: reloadLyricsBtn
                                    text: "Reload lyrics"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: reloadLyricsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var trackId = dashboardContent.currentTrackId
                                        if (mprisPanel) {
                                            if (trackId && mprisPanel._lyricsCache) {
                                                delete mprisPanel._lyricsCache[trackId]
                                            }
                                            mprisPanel.lyricsTrackId = ""
                                            mprisPanel._lyricsRetryCount = 0
                                            mprisPanel._isFetchingLyrics = false
                                            mprisPanel.fetchLyrics()
                                        }
                                        dashboardContent.localLyricsTrackId = ""
                                        dashboardContent.fetchLocalLyrics()
                                    }
                                }
                            }

                            // Floating Pill Toggle Tag
                            Rectangle {
                                id: lyricsPillTag
                                height: 24
                                radius: 12
                                readonly property bool isShowing: (dashboardContent.mprisPanel && dashboardContent.mprisPanel.showingLyrics)
                                color: isShowing
                                    ? mediaCard.pillBg
                                    : (lyricsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                                border.color: isShowing
                                    ? (mediaCard.hasVibrantDom ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.45) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15))
                                    : Qt.rgba(1, 1, 1, 0.28)
                                border.width: 1
                                width: tagRow.implicitWidth + 14

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    id: tagRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    IconText {
                                        text: lyricsPillTag.isShowing ? "visibility" : "subtitles"
                                        font.pixelSize: 12
                                        color: lyricsPillTag.isShowing ? root.ink : "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: lyricsPillTag.isShowing ? "FLOAT ON" : "LYRICS"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.8
                                        color: lyricsPillTag.isShowing ? root.ink : "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Realtime Animated Multi-line Lyrics Viewport (Vertically centered)
                        Item {
                            id: lyricTextContainer
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: lyricsActionsRow.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - 12
                            clip: true

                            // Fallback container when no synced lyrics available
                            Column {
                                id: fallbackLyricsCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                visible: !dashboardContent.hasSyncedLyrics

                                Text {
                                    text: mprisSel.active ? (curTitle !== "" ? curTitle : "No synced lyrics available") : "Play music to see lyrics"
                                    color: "#FFFFFF"
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Text {
                                    text: mprisSel.active
                                        ? (curArtist !== "" ? curArtist + "  •  No synced lyrics" : "No synced lyrics available")
                                        : "Tap to open lyrics panel"
                                    color: Qt.rgba(1, 1, 1, 0.50)
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    visible: text !== ""
                                }
                            }

                            // Reel column when synced lyrics are available - max 2 lines visible at a time
                            Item {
                                id: syncedReelViewport
                                anchors.fill: parent
                                visible: dashboardContent.hasSyncedLyrics
                                clip: true

                                Column {
                                    id: lyricReelCol
                                    width: parent.width
                                    spacing: 4

                                    property real glideOffset: 0
                                    readonly property real baseRestingY: {
                                        var twoLinesH = line1Text.implicitHeight + (lyricReelCol.nextText !== "" ? (spacing + line2Text.implicitHeight) : 0)
                                        return Math.max(0, Math.round((syncedReelViewport.height - twoLinesH) / 2))
                                    }

                                    y: baseRestingY + glideOffset

                                    property int curIdx: -1
                                    property string activeText: ""
                                    property string nextText: ""
                                    property string thirdText: ""
                                    property string pendingActiveText: ""
                                    property string pendingNextText: ""

                                    function resetImmediate() {
                                        glideOffset = 0
                                        line1Text.opacity = 1.0
                                        line2Text.opacity = lyricReelCol.nextText !== "" ? 0.50 : 0.0
                                        line3Text.opacity = 0.0
                                        line3Text.text = ""
                                    }

                                    // Active lyric (Current line) - multi-line WordWrap with comfortable spacing
                                    Text {
                                        id: line1Text
                                        width: parent.width
                                        text: lyricReelCol.activeText
                                        color: "#FFFFFF"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        opacity: 1.0
                                    }

                                    // Upcoming preview lyric (Next line) - glides up to line 1 during reel animation
                                    Text {
                                        id: line2Text
                                        width: parent.width
                                        text: lyricReelCol.nextText
                                        color: "#FFFFFF"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        opacity: text !== "" ? 0.50 : 0.0
                                    }

                                    // Incoming preview lyric (Only fades in as next line during reel animation, invisible at rest)
                                    Text {
                                        id: line3Text
                                        width: parent.width
                                        text: lyricReelCol.thirdText
                                        color: "#FFFFFF"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        opacity: 0.0
                                    }
                                }

                                // High-performance, silky smooth vertical glide animation
                                ParallelAnimation {
                                    id: lyricReelAnim
                                    property real shiftDistance: -(line1Text.implicitHeight + lyricReelCol.spacing)

                                    NumberAnimation {
                                        target: lyricReelCol
                                        property: "glideOffset"
                                        from: 0
                                        to: lyricReelAnim.shiftDistance
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: line1Text
                                        property: "opacity"
                                        to: 0.0
                                        duration: 260
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        target: line2Text
                                        property: "opacity"
                                        to: 1.0
                                        duration: 320
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        target: line3Text
                                        property: "opacity"
                                        to: 0.50
                                        duration: 320
                                        easing.type: Easing.OutQuad
                                    }

                                    onFinished: {
                                        lyricReelCol.activeText = lyricReelCol.pendingActiveText
                                        lyricReelCol.nextText = lyricReelCol.pendingNextText
                                        lyricReelCol.thirdText = ""
                                        lyricReelCol.glideOffset = 0
                                        line1Text.opacity = 1.0
                                        line2Text.opacity = lyricReelCol.nextText !== "" ? 0.50 : 0.0
                                        line3Text.opacity = 0.0
                                    }
                                }

                                function updateFromIndex(idx) {
                                    if (!dashboardContent.hasSyncedLyrics || idx < 0) {
                                        if (lyricReelAnim.running) lyricReelAnim.stop()
                                        lyricReelCol.curIdx = -1
                                        lyricReelCol.activeText = ""
                                        lyricReelCol.nextText = ""
                                        lyricReelCol.thirdText = ""
                                        lyricReelCol.resetImmediate()
                                        return
                                    }

                                    var list = dashboardContent.activeLyricsList
                                    var newAct = (list && list[idx]) ? list[idx].text : ""
                                    var newNext = (list && idx + 1 < list.length) ? list[idx + 1].text : ""
                                    var newThird = (list && idx + 2 < list.length) ? list[idx + 2].text : ""

                                    if (lyricReelCol.curIdx >= 0 && idx === lyricReelCol.curIdx + 1 && !lyricReelAnim.running) {
                                        // Sequential advance: smoothly glide next lyric into current container
                                        lyricReelCol.pendingActiveText = newAct
                                        lyricReelCol.pendingNextText = newNext
                                        lyricReelCol.thirdText = newThird
                                        lyricReelCol.curIdx = idx
                                        lyricReelAnim.shiftDistance = -(line1Text.implicitHeight + lyricReelCol.spacing)
                                        lyricReelAnim.restart()
                                    } else {
                                        // Non-sequential change (seek, track skip, initial load): update directly
                                        if (lyricReelAnim.running) lyricReelAnim.stop()
                                        lyricReelCol.curIdx = idx
                                        lyricReelCol.activeText = newAct
                                        lyricReelCol.nextText = newNext
                                        lyricReelCol.thirdText = ""
                                        lyricReelCol.resetImmediate()
                                    }
                                }

                                Connections {
                                    target: dashboardContent
                                    function onCurrentTrackIdChanged() {
                                        syncedReelViewport.updateFromIndex(-1)
                                    }
                                    function onActiveLyricIndexChanged() {
                                        syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                                    }
                                    function onHasSyncedLyricsChanged() {
                                        syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                                    }
                                }

                                Component.onCompleted: {
                                    syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                                }
                            }
                        }
                    }
                }

                // --- MATERIAL YOU MEDIA PLAYER ---
                Rectangle {
                    id: mediaCard
                    z: 2
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 144
                    radius: 22

                    readonly property bool isSpotify: mprisSel.player && /spotify/i.test((mprisSel.player.identity || "") + " " + (mprisSel.player.dbusName || ""))
                    readonly property bool isYouTube: mprisSel.player && (/youtube/i.test(mprisSel.player.trackTitle || "") || /youtube/i.test(mprisSel.player.identity || "") || /firefox|zen|chromium|chrome|brave/i.test(mprisSel.player.identity || "") || /firefox|zen|chromium|chrome|brave/i.test(mprisSel.player.dbusName || ""))

                    WheelHandler {
                        target: null
                        onWheel: (event) => {
                            if (!dashboardContent.hasMultiplePlayers) return
                            if (event.angleDelta.x > 30 || event.angleDelta.y < -40) {
                                mprisSel.nextPlayer()
                            } else if (event.angleDelta.x < -30 || event.angleDelta.y > 40) {
                                mprisSel.prevPlayer()
                            }
                        }
                    }

                    readonly property bool hasDominant: mprisArt.dominantColor && String(mprisArt.dominantColor) !== "#00000000" && String(mprisArt.dominantColor) !== "transparent"
                    readonly property color domCol: hasDominant ? mprisArt.dominantColor : root.seal
                    readonly property bool hasVibrantDom: hasDominant && (domCol.r * 0.299 + domCol.g * 0.587 + domCol.b * 0.114 > 0.18)
                    color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r * 0.45, mediaCard.domCol.g * 0.45, mediaCard.domCol.b * 0.45, 0.5) : root.fillIdle
                    border.color: hasVibrantDom ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.45) : root.islandBorder
                    border.width: 1
                    // Clean pastel / paper color for the pill play button matching Android Material You
                    readonly property color pillBg: {
                        if (!hasDominant) return root.paper
                        var maxC = Math.max(domCol.r, domCol.g, domCol.b)
                        var minC = Math.min(domCol.r, domCol.g, domCol.b)
                        var sat = maxC > 0 ? (maxC - minC) / maxC : 0
                        // If dominant color is murky/dark/grey, fall back to clean, bright root.paper
                        if (sat < 0.25 || maxC < 0.35) {
                            return root.paper
                        }
                        // Soft pastel tint of root.paper
                        return Qt.tint(root.paper, Qt.rgba(domCol.r, domCol.g, domCol.b, 0.35))
                    }

                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // Inner clipping container ensures artwork and overlays are clipped to the rounded corners
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 22
                        color: "transparent"

                        // Full-bleed album art background
                        Image {
                            id: cardBgArt
                            anchors.fill: parent
                            source: mprisArt.source || root.lastMediaArtUrl
                            sourceSize: Qt.size(512, 512)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        // Smooth darkening and tint overlays so text/buttons pop
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.50) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.70) }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.28) : "transparent"
                        }
                    }

                    // TOP ROW: App Icon / Switcher (Left) + Output / Clock Controls (Right)
                    Item {
                        id: topRow
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        height: 22

                        Row {
                            id: topRowLeft
                            anchors.left: parent.left
                            anchors.right: topRowRight.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            clip: true

                            // ── Multi-Player Source Switcher (modeled after DesktopContextMenu wallpaper picker) ──
                            Row {
                                id: playerSwitcherRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                visible: dashboardContent.hasMultiplePlayers

                                Repeater {
                                    model: dashboardContent.hasMultiplePlayers ? mprisSel.playersList : []
                                    delegate: ClippingRectangle {
                                        id: playerPillItem
                                        required property var modelData
                                        required property int index
                                        readonly property bool isCurrent: index === mprisSel.selectedIndex
                                        width: isCurrent ? 84 : 22
                                        height: 22
                                        radius: 11
                                        color: isCurrent ? Qt.rgba(1, 1, 1, 0.28) : (playerPillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.36))
                                        border.color: isCurrent ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.18)
                                        border.width: 1

                                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        // Artwork / Thumbnail background preview if available
                                        Image {
                                            anchors.fill: parent
                                            source: modelData.trackArtUrl || ""
                                            sourceSize: Qt.size(96, 96)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            opacity: playerPillItem.isCurrent ? 0.35 : 0.55
                                            visible: status === Image.Ready
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            // App Icon
                                            Item {
                                                width: 14; height: 14
                                                anchors.verticalCenter: parent.verticalCenter
                                                readonly property bool isSpot: /spotify/i.test((modelData.identity || "") + " " + (modelData.dbusName || ""))
                                                readonly property bool isYt: /youtube/i.test(modelData.trackTitle || "") || /firefox|zen|chromium|chrome|brave/i.test(modelData.identity || "")

                                                Image {
                                                    anchors.fill: parent
                                                    source: "file:///home/hery/.config/quickshell/bar/spotify.svg"
                                                    visible: parent.isSpot
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 3
                                                    color: "#e50914"
                                                    visible: !parent.isSpot && parent.isYt

                                                    IconText {
                                                        anchors.centerIn: parent
                                                        text: "play_arrow"
                                                        color: "#ffffff"
                                                        font.pixelSize: 9
                                                    }
                                                }

                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "music_note"
                                                    color: "#ffffff"
                                                    font.pixelSize: 13
                                                    visible: !parent.isSpot && !parent.isYt
                                                }
                                            }

                                            // Identity Name when expanded
                                            Text {
                                                visible: playerPillItem.isCurrent
                                                text: {
                                                    var idStr = modelData.identity || "Media"
                                                    return idStr.length > 7 ? idStr.substring(0, 6) + "…" : idStr
                                                }
                                                color: "#ffffff"
                                                font.family: root.barFont
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // Checkmark badge when active
                                            IconText {
                                                visible: playerPillItem.isCurrent
                                                text: "check"
                                                color: "#ffffff"
                                                font.pixelSize: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: playerPillMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mprisSel.selectPlayer(index)
                                        }

                                        TooltipMixin {
                                            root: dashboardContent.root
                                            owner: parent
                                            text: modelData.trackTitle ? (modelData.trackTitle + " (" + (modelData.identity || "Media") + ")") : (modelData.identity || "Media Player")
                                        }
                                    }
                                }
                            }

                            // Single-player App icon badge (visible when only 1 player active)
                            Item {
                                width: 20; height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !dashboardContent.hasMultiplePlayers

                                Image {
                                    id: spotLogo
                                    anchors.fill: parent
                                    source: "file:///home/hery/.config/quickshell/bar/spotify.svg"
                                    visible: mediaCard.isSpotify && status === Image.Ready
                                }

                                Rectangle {
                                    id: ytBadge
                                    anchors.fill: parent
                                    radius: 5
                                    color: "#e50914"
                                    visible: !spotLogo.visible && mediaCard.isYouTube

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "play_arrow"
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                    }
                                }

                                IconText {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    color: "#ffffff"
                                    font.pixelSize: 18
                                    visible: !spotLogo.visible && !ytBadge.visible
                                }
                            }

                            // Last Played / Now Playing Tag (Visible when not multiple players)
                            Rectangle {
                                id: statusTag
                                height: 20
                                radius: 6
                                visible: !dashboardContent.hasMultiplePlayers
                                color: (dashboardContent.curTitle === "" && root.lastMediaTitle !== "")
                                    ? Qt.rgba(1, 1, 1, 0.30)
                                    : (mprisSel.playing ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.30))
                                border.color: Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: statusTxt.implicitWidth + 12

                                Text {
                                    id: statusTxt
                                    anchors.centerIn: parent
                                    text: {
                                        if (dashboardContent.curTitle === "" && root.lastMediaTitle !== "") return "LAST PLAYED"
                                        if (mprisSel.playing) return "NOW PLAYING"
                                        return "PAUSED"
                                    }
                                    color: "#ffffff"
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        // Right side controls
                        Row {
                            id: topRowRight
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Switch to Clock Widget Button
                            Rectangle {
                                id: switchToClockBtn
                                width: 22
                                height: 22
                                radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                color: switchToClockMa.containsMouse ? root.fillHover : root.fillIdle
                                border.color: root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                IconText {
                                    anchors.centerIn: parent
                                    text: "schedule"
                                    font.pixelSize: 13
                                    color: switchToClockMa.containsMouse ? root.seal : (root ? root.ink : "#ffffff")
                                }

                                TooltipMixin {
                                    root: dashboardContent.root
                                    owner: switchToClockBtn
                                    text: "Show Clock"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: switchToClockMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dashboardContent.showMediaManually = false
                                    }
                                }
                            }

                            // Output Pill (e.g. "This device" / Audio Sink)
                            Rectangle {
                                id: outputPill
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                radius: 11
                                color: Qt.rgba(1, 1, 1, 0.22)
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                                width: outRow.implicitWidth + 14

                                Row {
                                    id: outRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    IconText {
                                        text: "speaker"
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: {
                                            var desc = (audioData.sink && audioData.sink.description) ? audioData.sink.description : "This device"
                                            return desc.length > 18 ? desc.substring(0, 16) + "…" : desc
                                        }
                                        color: "#ffffff"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                TooltipMixin {
                                    root: dashboardContent.root
                                    owner: outputPill
                                    text: audioData.sink ? (audioData.sink.description || "Audio Output") : "Audio Output"
                                }
                            }
                        }
                    }

                    // MIDDLE ROW: Title & Artist (Left) + Pill Play/Pause Button (Right)
                    Item {
                        id: midRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -1
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        height: 44

                        // Track Title & Artist
                        Column {
                            id: textCol
                            anchors.left: parent.left
                            anchors.right: playPill.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            // Song Title with Marquee (only scrolls when title overflows container)
                            Item {
                                id: marqueeTitleContainer
                                width: parent.width
                                height: 22
                                clip: true

                                readonly property bool shouldMarquee: marqueeTitleContainer.width > 20 && marqueeTitleText.implicitWidth > (marqueeTitleContainer.width + 4)

                                function resetMarquee() {
                                    marqueeAnim.stop()
                                    marqueeTitleText.x = 0
                                    if (shouldMarquee) marqueeAnim.start()
                                }

                                onWidthChanged: resetMarquee()
                                onShouldMarqueeChanged: resetMarquee()

                                Text {
                                    id: marqueeTitleText
                                    text: root.lastMediaTitle || "No media"
                                    color: "#ffffff"
                                    font.family: root.barFont
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter

                                    onTextChanged: marqueeTitleContainer.resetMarquee()

                                    SequentialAnimation on x {
                                        id: marqueeAnim
                                        loops: Animation.Infinite
                                        running: marqueeTitleContainer.shouldMarquee
                                        onRunningChanged: {
                                            if (!running) marqueeTitleText.x = 0
                                        }
                                        PauseAnimation { duration: 2000 }
                                        NumberAnimation {
                                            from: 0
                                            to: -(marqueeTitleText.implicitWidth - marqueeTitleContainer.width + 16)
                                            duration: Math.max(1200, (marqueeTitleText.implicitWidth - marqueeTitleContainer.width) * 25)
                                            easing.type: Easing.Linear
                                        }
                                        PauseAnimation { duration: 1800 }
                                        NumberAnimation {
                                            to: 0
                                            duration: 400
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }

                            Text {
                                text: root.lastMediaArtist || "Nothing in queue"
                                color: Qt.rgba(1, 1, 1, 0.80)
                                font.family: root.barFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Pill Play/Pause Button (Material You rectangle pill style)
                        Rectangle {
                            id: playPill
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 54
                            height: 34
                            radius: 17
                            readonly property color iconCol: {
                                var c = mediaCard.pillBg
                                var luma = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
                                return luma > 0.55 ? "#1e1b18" : "#ffffff"
                            }
                            color: playMa.pressed ? Qt.darker(mediaCard.pillBg, 1.15) : (playMa.containsMouse ? Qt.lighter(mediaCard.pillBg, 1.08) : mediaCard.pillBg)
                            border.color: Qt.rgba(0, 0, 0, 0.08)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Geometric pause bars (100% mathematically centered)
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                visible: mprisSel.playing

                                Rectangle {
                                    width: 3.5
                                    height: 14
                                    radius: 1.75
                                    color: playPill.iconCol
                                }
                                Rectangle {
                                    width: 3.5
                                    height: 14
                                    radius: 1.75
                                    color: playPill.iconCol
                                }
                            }

                            // Play arrow icon (when paused)
                            IconText {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1.5
                                text: "play_arrow"
                                font.pixelSize: 22
                                color: playPill.iconCol
                                visible: !mprisSel.playing
                            }

                            SpringPress {}
                            MouseArea {
                                id: playMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mprisSel.player) mprisSel.player.togglePlaying()
                            }
                        }
                    }

                    // BOTTOM ROW: Prev + Wavy Progress Bar + Next + Song Length
                    Row {
                        id: bottomRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        height: 24
                        spacing: 8

                        // Previous Button
                        Item {
                            width: 24; height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                font.pixelSize: 22
                                color: "#ffffff"
                                opacity: (mprisSel.player && mprisSel.player.canGoPrevious) ? 0.95 : 0.4
                            }

                            SpringPress {}
                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                scale: pressed ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                onClicked: if (mprisSel.player) mprisSel.player.previous()
                            }
                        }

                        // Wavy Seekable Progress Bar
                        Item {
                            id: wavyBarContainer
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, parent.width - 24 - 24 - (positionTxt ? positionTxt.implicitWidth : 36) - (8 * 3))
                            height: 24

                            property real progress: dashboardContent.curLen > 0 
                                ? Math.max(0, Math.min(1, dashboardContent.curPos / dashboardContent.curLen)) 
                                : 0

                            Canvas {
                                id: waveCanvas
                                anchors.fill: parent
                                property real wavePhase: 0
                                property real waveAmp: mprisSel.playing ? 3.5 : 0

                                Behavior on waveAmp {
                                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                                }
                                onWaveAmpChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cy = height / 2
                                    var p = wavyBarContainer.progress
                                    var progressX = Math.max(0, Math.min(width, width * p))
                                    var scrubberW = 4
                                    var scrubberH = (seekArea.pressed || seekArea.containsMouse) ? 14 : 10
                                    var baseAmp = waveCanvas.waveAmp

                                    // 1. Unplayed straight horizontal line (from progressX to width)
                                    if (progressX < width) {
                                        ctx.beginPath()
                                        ctx.moveTo(progressX, cy)
                                        ctx.lineTo(width, cy)
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.32)
                                        ctx.lineWidth = 3
                                        ctx.lineCap = "round"
                                        ctx.stroke()
                                    }

                                    // 2. Played portion: wavy sine line when playing, flat straight line when paused
                                    if (progressX > 0) {
                                        var wavelength = 34 // Slightly increased frequency
                                        ctx.beginPath()
                                        ctx.moveTo(0, cy)
                                        if (baseAmp > 0.05) {
                                            for (var x = 0; x <= progressX; x += 1.5) {
                                                var distToEnd = progressX - x
                                                var taper = distToEnd < 14 ? (distToEnd / 14) : 1.0
                                                var y = cy + baseAmp * taper * Math.sin((x / wavelength) * 2 * Math.PI - wavePhase)
                                                ctx.lineTo(x, y)
                                            }
                                        } else {
                                            ctx.lineTo(progressX, cy)
                                        }
                                        ctx.strokeStyle = "#ffffff"
                                        ctx.lineWidth = 3
                                        ctx.lineCap = "round"
                                        ctx.stroke()
                                    }

                                    // 3. Vertical pill scrubber head (fixed vertically in center: stationary at cy)
                                    ctx.beginPath()
                                    ctx.moveTo(progressX, cy - scrubberH / 2)
                                    ctx.lineTo(progressX, cy + scrubberH / 2)
                                    ctx.strokeStyle = "#ffffff"
                                    ctx.lineWidth = scrubberW
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }
                            }

                            Timer {
                                interval: 33
                                running: mprisSel.playing && panel.expanded
                                repeat: true
                                onTriggered: {
                                    waveCanvas.wavePhase += 0.08
                                    waveCanvas.requestPaint()
                                }
                            }

                            Connections {
                                target: dashboardContent
                                function onCurPosChanged() { waveCanvas.requestPaint() }
                                function onCurLenChanged() { waveCanvas.requestPaint() }
                            }

                            Connections {
                                target: mprisSel
                                function onPlayingChanged() { waveCanvas.requestPaint() }
                            }

                            // Floating Timestamp Tooltip during scrub / hover
                            Rectangle {
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 4
                                x: Math.max(0, Math.min(parent.width - width, wavyBarContainer.width * wavyBarContainer.progress - width / 2))
                                width: timeTxt.implicitWidth + 12
                                height: 18
                                radius: 9
                                color: Qt.rgba(0, 0, 0, 0.85)
                                border.color: Qt.rgba(1, 1, 1, 0.25)
                                border.width: 1
                                visible: (seekArea.containsMouse || seekArea.pressed) && dashboardContent.curLen > 0

                                Text {
                                    id: timeTxt
                                    anchors.centerIn: parent
                                    text: dashboardContent.fmtTime(dashboardContent.curPos) + " / " + dashboardContent.fmtTime(dashboardContent.curLen)
                                    color: "#ffffff"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    dashboardContent.seekTo(mouse.x / width)
                                    waveCanvas.requestPaint()
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        dashboardContent.seekTo(mouse.x / width)
                                        waveCanvas.requestPaint()
                                    }
                                }
                            }
                        }

                        // Next Button
                        Item {
                            width: 24; height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: "skip_next"
                                font.pixelSize: 22
                                color: "#ffffff"
                                opacity: (mprisSel.player && mprisSel.player.canGoNext) ? 0.95 : 0.4
                            }

                            SpringPress {}
                            MouseArea {
                                id: nextMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                scale: pressed ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                onClicked: if (mprisSel.player) mprisSel.player.next()
                            }
                        }

                        // Current Song Position Display
                        Text {
                            id: positionTxt
                            text: dashboardContent.fmtTime(dashboardContent.curPos)
                            color: Qt.rgba(1, 1, 1, 0.85)
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                } // end mediaCard
            } // end mediaWithLyricsGroup

            // --- COOL AESTHETIC TIME & DATE WIDGET (Zero borders, unified canvas) ---
            Item {
                id: timeDateWidget
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: !dashboardContent.showMediaPlayer ? 1.0 : 0.0
                scale: !dashboardContent.showMediaPlayer ? 1.0 : 0.96
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                // Seamless smoked glass foundation (Zero borders)
                Rectangle {
                    id: timeCanvasBg
                    anchors.fill: parent
                    radius: 22
                    color: Qt.rgba(root.paper.r * 0.20 + 0.03, root.paper.g * 0.20 + 0.03, root.paper.b * 0.20 + 0.03, 0.72)

                    // Clipping container for smooth ambient gradient and edge lighting
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 22
                        color: "transparent"

                        // Top-right ambient aurora glow
                        Rectangle {
                            width: 240
                            height: 240
                            radius: 120
                            anchors.top: parent.top
                            anchors.topMargin: -60
                            anchors.right: parent.right
                            anchors.rightMargin: -40
                            opacity: 0.16
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.seal }
                                GradientStop { position: 0.7; color: Qt.rgba(root.color06.r, root.color06.g, root.color06.b, 0.3) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Bottom-left subtle warm secondary ambient tint
                        Rectangle {
                            width: 180
                            height: 180
                            radius: 90
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -60
                            anchors.left: parent.left
                            anchors.leftMargin: -40
                            opacity: 0.09
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.color03 }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }
                }

                // Breathing pulse item for colon
                Item {
                    id: colonPulse
                    property real pulse: 0.9
                    SequentialAnimation {
                        running: timeDateWidget.visible
                        loops: Animation.Infinite
                        NumberAnimation { target: colonPulse; property: "pulse"; to: 0.35; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { target: colonPulse; property: "pulse"; to: 0.95; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }

                // Main Widget Layout Container
                Item {
                    anchors.fill: parent
                    anchors.margins: 18

                    // ── TOP ROW: Date & Editorial Status Pill ──
                    Item {
                        id: topTimeRow
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 24

                        Item {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: calRow.implicitWidth

                            Row {
                                id: calRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                IconText {
                                    text: "calendar_today"
                                    font.pixelSize: 14
                                    color: root.seal
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: Qt.formatDate(dashboardContent.now, "dddd, MMMM d")
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: root.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dashboardContent.activeDetailView = "calendar"
                                    if (root) root.dashboardDetail = "calendar"
                                }
                            }
                        }

                        // Right Pill: Live Greeting Tag
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22
                            radius: 11
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            width: greetingRow.implicitWidth + 16

                            Row {
                                id: greetingRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: dashboardContent.timeGreeting
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.4
                                    color: root.seal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // ── BOTTOM ROW: Day Progress or Resume Track ──
                    Item {
                        id: bottomTimeRow
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 26

                        // State A: Resume Track Chip (if a song was paused)
                        Rectangle {
                            anchors.fill: parent
                            radius: 13
                            visible: dashboardContent.curTitle !== ""
                            color: resumeMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.09)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                IconText {
                                    text: "play_arrow"
                                    font.pixelSize: 16
                                    color: root.seal
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Resume: " + dashboardContent.curTitle
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: root.ink
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, timeDateWidget.width - 80)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: resumeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dashboardContent.showMediaManually = true
                                    if (mprisSel.player) mprisSel.player.play()
                                }
                            }
                        }

                        // State B: Day Completion Bar (when no media is paused/loaded)
                        Item {
                            anchors.fill: parent
                            visible: dashboardContent.curTitle === ""

                            Row {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                spacing: 4

                                IconText {
                                    text: "bedtime"
                                    font.pixelSize: 12
                                    color: root.sumiHi
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: dashboardContent.dayProgressPercent + "% of day completed"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: root.sumiHi
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                text: dashboardContent.remainingHoursToday
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: root.seal
                                opacity: 0.85
                            }

                            // Sleek continuous micro-bar (borderless)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -4
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 3
                                radius: 1.5
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(height, parent.width * (dashboardContent.dayProgressPercent / 100))
                                    radius: 1.5
                                    color: root.seal
                                }
                            }
                        }
                    }
                }

                // ── CENTER HERO: Massive Display Clock (Dead Center of the Whole Pill) ──
                Item {
                    id: heroClockContainer
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 5
                    width: heroClockRow.implicitWidth
                    height: heroClockRow.implicitHeight
                    scale: clockMa.pressed ? 0.96 : (clockMa.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Row {
                        id: heroClockRow
                        anchors.centerIn: parent
                        spacing: 3

                        // Hour Digits
                        Text {
                            text: dashboardContent.clockHours
                            font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                            font.pixelSize: 76
                            font.weight: Font.Bold
                            font.letterSpacing: 0.0
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Soft Breathing Colon
                        Text {
                            text: ":"
                            font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                            font.pixelSize: 64
                            font.weight: Font.Light
                            color: root.seal
                            opacity: colonPulse.pulse
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -4
                        }

                        // Minute Digits
                        Text {
                            text: dashboardContent.clockMinutes
                            font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                            font.pixelSize: 76
                            font.weight: Font.Bold
                            font.letterSpacing: 0.0
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Right Metadata: AM/PM + Week Number
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 2
                            spacing: 3
                            leftPadding: 8

                            Text {
                                text: dashboardContent.clockAmPm
                                font.family: root.barFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: root.ink
                                opacity: 0.75
                                visible: text !== ""
                            }

                            Text {
                                text: "W" + dashboardContent.getWeekNumber()
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: root.color03
                                opacity: 0.85
                            }
                        }
                    }

                    MouseArea {
                        id: clockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dashboardContent.activeDetailView = "calendar"
                            if (root) root.dashboardDetail = "calendar"
                        }
                    }

                    TooltipMixin {
                        root: dashboardContent.root
                        owner: heroClockContainer
                        text: "Open Calendar"
                    }
                }
            }
        } // end rightCol
    } // end Row

    // ── Dragged Tile Floating Preview (Follows mouse across any page) ──
    Item {
        id: dragPreviewItem
        visible: dashboardContent.draggingTileId !== ""
        enabled: false
        z: 9999
        width: dashboardContent.dragTileSpan === 2 ? dashboardContent.tileDoubleWidth : dashboardContent.tileUnitWidth
        height: 56
        scale: 1.05
        opacity: 0.92

        property real currentMouseX: 0
        property real currentMouseY: 0
        x: currentMouseX - width / 2
        y: currentMouseY - height / 2

        DashboardTile {
            anchors.fill: parent
            dashContent: dashboardContent
            tileId: dashboardContent.draggingTileId || "wifi"
            span: dashboardContent.dragTileSpan
            tileIndex: -1
        }
    }
} // end mainControls

    // ── DETAIL OVERLAY (Phone-style sub-page sheet) ──
    Item {
        id: detailOverlay
        anchors.fill: parent
        visible: (opacity > 0.001)
        opacity: dashboardContent.activeDetailView !== "" ? 1.0 : 0.0
        scale: dashboardContent.activeDetailView !== "" ? 1.0 : 0.98
        transform: Translate {
            y: dashboardContent.activeDetailView !== "" ? 0 : (root && root.barPosition === "bottom" ? 14 : -14)
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        z: 10

        // Subpage Header Bar
        Item {
            id: detailHeaderBar
            width: parent.width
            height: 0
            visible: false
            anchors.top: parent.top

            // Back button pill
            Rectangle {
                id: detailBackBtn
                height: 32
                width: backContentRow.width + 16
                radius: 16
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: detailBackMa.containsMouse ? root.fillHover : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: backContentRow
                    anchors.centerIn: parent
                    spacing: 5
                    IconText {
                        text: "arrow_back"
                        color: root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Back"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                SpringPress {}
                MouseArea {
                    id: detailBackMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardContent.activeDetailView = ""
                        if (root) root.dashboardDetail = ""
                    }
                }
            }

            // Section Title
            Text {
                anchors.centerIn: parent
                text: {
                    switch (dashboardContent.activeDetailView) {
                        case "wifi": return "Wi-Fi & Network"
                        case "bluetooth": return "Bluetooth"
                        case "cpu": return "CPU Performance"
                        case "memory": return "Memory Usage"
                        case "battery": return "Battery & Power"
                        case "screentime": return "Screen Time"
                        case "volume": return "Sound & Volume"
                        case "system": return "System & Power"
                        case "calendar": return "Calendar & Notes"
                        case "notifications": return "Notifications"
                        case "updates": return "Software Updates"
                        case "packages": return "Software Updates"
                        case "theme": return "Themes"
                        case "wallpaper": return "Wallpapers"
                        case "plugins": return "Omarchy Plugins"
                        case "notes": return "Notes"
                        case "lockscreen": return "Lock Screen Settings"
                        default: return ""
                    }
                }
                color: root.ink
                font.family: root.barFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            // Close button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: detailCloseMa.containsMouse ? root.fillHover : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    color: root.ink
                    font.pixelSize: 16
                }

                SpringPress {}
                MouseArea {
                    id: detailCloseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardContent.activeDetailView = ""
                        if (root) root.dashboardDetail = ""
                    }
                }
            }
        }

        // Subpage Content Area
        Item {
            id: detailContentArea
            anchors.fill: parent
            clip: true

            component DetailLoader: Loader {
                required property string viewName
                anchors.fill: parent
                active: dashboardContent.activeDetailView === viewName
                visible: active
                Connections {
                    target: item
                    ignoreUnknownSignals: true
                    function onCloseRequested() {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                    }
                }
            }

            DetailLoader { id: wifiDetailLoader;  viewName: "wifi";          sourceComponent: WifiDetailSection          { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: btDetailLoader;    viewName: "bluetooth";     sourceComponent: BluetoothDetailSection     { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: cpuDetailLoader;   viewName: "cpu";           sourceComponent: CpuDetailSection           { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: memDetailLoader;   viewName: "memory";        sourceComponent: MemoryDetailSection        { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: batDetailLoader;   viewName: "battery";       sourceComponent: BatteryDetailSection       { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: stDetailLoader;    viewName: "screentime";    sourceComponent: ScreentimeDetailSection    { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: volDetailLoader;   viewName: "volume";        sourceComponent: VolumeDetailSection        { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader {
                id: sysDetailLoader
                viewName: "system"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: SystemDetailSection { root: dashboardContent.root; panel: dashboardContent.panel }
            }
            DetailLoader {
                id: pluginsDetailLoader
                viewName: "plugins"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: PluginsDetailSection { root: dashboardContent.root; panel: dashboardContent.panel }
            }
            DetailLoader { id: calDetailLoader;   viewName: "calendar";      sourceComponent: CalendarDetailSection      { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader {
                id: notifDetailLoader
                viewName: "notifications"
                sourceComponent: NotificationDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                }
            }
            DetailLoader {
                id: updatesDetailLoader
                viewName: "updates"
                active: dashboardContent.activeDetailView === "updates" || dashboardContent.activeDetailView === "packages"
                sourceComponent: UpdatesDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                }
            }
            DetailLoader {
                id: notesDetailLoader
                viewName: "notes"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: NotesDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                    onCloseRequested: {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                    }
                }
            }
            DetailLoader {
                id: lockscreenDetailLoader
                viewName: "lockscreen"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: LockscreenDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                    onCloseRequested: {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                    }
                }
            }
            DetailLoader {
                id: themeLoader
                viewName: "theme"
                active: dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper"
                visible: active
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: ThemeWallpaperSwitcher {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                    activeMode: dashboardContent.activeDetailView === "wallpaper" ? "wallpaper" : "theme"
                    onCloseRequested: {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) {
                            dashboardContent.root.dashboardDetail = ""
                            dashboardContent.root.dashboardExpanded = false
                        }
                    }
                }
            }
        }
    }

    // ── POMODORO TIMER POPUP (Sleek Material You modal to view, pause, or disable the timer) ──
    Item {
        id: pomodoroPopupBackdrop
        anchors.fill: parent
        z: 1000
        visible: opacity > 0.001
        opacity: dashboardContent.showPomodoroPopup ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // Dimmer background (Clicking closes the popup)
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea {
                anchors.fill: parent
                onClicked: dashboardContent.showPomodoroPopup = false
            }
        }

        // Pomodoro Card
        Rectangle {
            id: pomodoroCard
            anchors.centerIn: parent
            width: 310
            height: 220
            radius: 20
            color: Qt.rgba(root.paper.r * 0.92 + 0.04, root.paper.g * 0.92 + 0.04, root.paper.b * 0.92 + 0.04, 0.97)
            border.color: root.islandBorder
            border.width: 1

            scale: dashboardContent.showPomodoroPopup ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            // Prevent clicks inside card from closing
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "timer"
                            color: (root && root.timerActive) ? root.color03 : root.seal
                            font.pixelSize: 20
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Pomodoro Timer"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    // Close button
                    Item {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26

                        Rectangle {
                            anchors.fill: parent
                            radius: 13
                            color: closePomoMa.containsMouse ? root.fillHover : "transparent"
                        }

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.ink
                            opacity: 0.7
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: closePomoMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dashboardContent.showPomodoroPopup = false
                        }
                    }
                }

                // Countdown Display
                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (!root || !root.timerActive) return "25:00"
                            let sec = root.timerRemaining || 0
                            let m = Math.floor(sec / 60)
                            let s = sec % 60
                            return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
                        }
                        font.family: root.barFont
                        font.pixelSize: 36
                        font.weight: Font.Bold
                        color: (root && root.timerActive && !root.timerPaused) ? root.color03 : root.ink
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (!root || !root.timerActive) return "Ready to focus"
                            if (root.timerPaused) return "Paused"
                            return (root.timerLabel || "Focus") + " • In Progress"
                        }
                        font.family: root.barFont
                        font.pixelSize: 12
                        color: root.ink
                        opacity: 0.65
                    }
                }

                // Action Controls Row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    // Start / Resume / Pause button
                    Rectangle {
                        height: 38
                        width: (root && root.timerActive) ? 124 : 160
                        radius: 19
                        color: (root && root.timerActive && !root.timerPaused) ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : root.seal
                        border.color: root.seal
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (!root || !root.timerActive || root.timerPaused) ? "play_arrow" : "pause"
                                color: (!root || !root.timerActive || root.timerPaused) ? root.paper : root.seal
                                font.pixelSize: 18
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (!root || !root.timerActive) ? "Start 25m" : (root.timerPaused ? "Resume" : "Pause")
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: (!root || !root.timerActive || root.timerPaused) ? root.paper : root.seal
                            }
                        }

                        MouseArea {
                            id: pStartMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root) {
                                    if (!root.timerActive) root.startTimer(25, "Focus")
                                    else root.toggleTimer()
                                }
                            }
                        }
                    }

                    // Disable / Reset button
                    Rectangle {
                        visible: root && root.timerActive
                        height: 38
                        width: 124
                        radius: 19
                        color: Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.18)
                        border.color: root.color01
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "stop"
                                color: root.color01
                                font.pixelSize: 18
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Disable / Reset"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: root.color01
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root) root.resetTimer()
                            }
                        }
                    }
                }

                // Quick Presets (when timer is idle)
                Row {
                    visible: !root || !root.timerActive
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "25m Focus", mins: 25, type: "Focus" },
                            { label: "5m Break", mins: 5, type: "Short Break" },
                            { label: "15m Break", mins: 15, type: "Long Break" }
                        ]

                        Rectangle {
                            height: 26
                            width: chipTxt.implicitWidth + 16
                            radius: 13
                            color: chipMa.containsMouse ? root.fillHover : root.fillIdle

                            Text {
                                id: chipTxt
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: root.barFont
                                font.pixelSize: 11
                                color: root.ink
                                opacity: 0.85
                            }

                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root) root.startTimer(modelData.mins, modelData.type)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
