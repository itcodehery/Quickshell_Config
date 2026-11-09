.pragma library

function normalizeSpan(span) {
    if (span === 4 || span === "2x2") return 4
    if (span === 2 || span === "1x2") return 2
    return 1
}

function cycleSpan(curSpan) {
    let s = normalizeSpan(curSpan)
    if (s === 1) return 2
    if (s === 2) return 4
    return 1
}

function recalculateGridLayout(dc, tilesModel, tilesPager, smoothScrollAnim) {
    if (!tilesModel || tilesModel.count === 0) return

    let pages = []
    function getPageGrid(p) {
        while (pages.length <= p) {
            pages.push([
                [null, null, null, null],
                [null, null, null, null]
            ])
        }
        return pages[p]
    }

    let maxPage = 0

    for (let i = 0; i < tilesModel.count; i++) {
        let item = tilesModel.get(i)
        let s = normalizeSpan(item.span)
        let w = (s === 2 || s === 4) ? 2 : 1
        let h = (s === 4) ? 2 : 1

        let placed = false
        let p = 0
        while (!placed) {
            let grid = getPageGrid(p)
            for (let r = 0; r <= 2 - h; r++) {
                for (let c = 0; c <= 4 - w; c++) {
                    let canFit = true
                    for (let dr = 0; dr < h; dr++) {
                        for (let dcIdx = 0; dcIdx < w; dcIdx++) {
                            if (grid[r + dr][c + dcIdx] !== null) {
                                canFit = false
                                break
                            }
                        }
                        if (!canFit) break
                    }
                    if (canFit) {
                        for (let dr = 0; dr < h; dr++) {
                            for (let dcIdx = 0; dcIdx < w; dcIdx++) {
                                grid[r + dr][c + dcIdx] = item.id
                            }
                        }
                        tilesModel.setProperty(i, "gridPage", p)
                        tilesModel.setProperty(i, "gridRow", r)
                        tilesModel.setProperty(i, "gridCol", c)
                        if (p > maxPage) maxPage = p
                        placed = true
                        break
                    }
                }
                if (placed) break
            }
            if (!placed) p++
        }
    }

    dc.totalPageCount = Math.max(1, maxPage + 1)
    if (tilesPager) {
        let maxScroll = Math.max(0, (dc.totalPageCount - 1) * dc.pageStride)
        if (tilesPager.contentY > maxScroll) {
            smoothScrollAnim.stop()
            smoothScrollAnim.to = maxScroll
            smoothScrollAnim.start()
        }
    }
}

function setTileSpan(dc, tilesModel, id, newSpan) {
    let s = normalizeSpan(newSpan)
    for (let i = 0; i < tilesModel.count; i++) {
        if (tilesModel.get(i).id === id) {
            tilesModel.setProperty(i, "span", s)
            break
        }
    }
    recalculateGridLayout(dc, tilesModel, dc.tilesPager, dc.smoothScrollAnim)
    saveTilesLayout(tilesModel, dc.saveLayoutProc)
}

function cycleTileSpan(dc, tilesModel, id) {
    let cur = getTileSpan(tilesModel, id)
    let next = cycleSpan(cur)
    setTileSpan(dc, tilesModel, id, next)
}

function getTileSpan(tilesModel, id) {
    for (let i = 0; i < tilesModel.count; i++) {
        if (tilesModel.get(i).id === id) return normalizeSpan(tilesModel.get(i).span)
    }
    return 1
}

function toggleEditMode(dc, tilesModel, id) {
    if (!dc.editTilesMode) {
        dc.editTilesMode = true
        dc.selectedTileId = id || (tilesModel.count > 0 ? tilesModel.get(0).id : "")
    } else {
        if (id && id !== dc.selectedTileId) {
            dc.selectedTileId = id
        } else {
            dc.editTilesMode = false
            dc.selectedTileId = ""
            dc.dropTargetTileId = ""
            dc.saveTilesLayout()
        }
    }
}

function moveSelectedTile(dc, tilesModel, dir) {
    if (!dc.selectedTileId) return
    let idx = -1
    for (let i = 0; i < tilesModel.count; i++) {
        if (tilesModel.get(i).id === dc.selectedTileId) {
            idx = i
            break
        }
    }
    if (idx === -1) return
    let targetIdx = idx + dir
    if (targetIdx < 0 || targetIdx >= tilesModel.count) return

    tilesModel.move(idx, targetIdx, 1)
    dc.recalculateGridLayout()
    dc.saveTilesLayout()

    dc.goToPage(dc.getTilePageIndex(dc.selectedTileId))
}

function startDraggingTile(dc, dragPreviewItem, id, globalX, globalY) {
    dc.draggingTileId = id
    dc.selectedTileId = id
    dc.dropTargetTileId = ""
    dc.dragTileSpan = dc.getTileSpan(id)
    if (dragPreviewItem) {
        dragPreviewItem.currentMouseX = globalX
        dragPreviewItem.currentMouseY = globalY
    }
}

function updateDraggingTile(dc, tilesModel, tilesPager, autoScrollTimer, dragPreviewItem, globalX, globalY) {
    if (dc.draggingTileId === "") return
    if (dragPreviewItem) {
        dragPreviewItem.currentMouseX = globalX
        dragPreviewItem.currentMouseY = globalY
    }

    let pt = tilesPager.mapFromItem(dc, globalX, globalY)

    if (pt.y < 12 && !autoScrollTimer.running) {
        autoScrollTimer.dir = -1
        autoScrollTimer.restart()
        dc.pageUp()
    } else if (pt.y > tilesPager.height - 12 && !autoScrollTimer.running) {
        autoScrollTimer.dir = 1
        autoScrollTimer.restart()
        dc.pageDown()
    }

    let curPage = Math.max(0, Math.min(dc.totalPageCount - 1, Math.round(tilesPager.contentY / dc.pageStride)))
    let localY = pt.y + tilesPager.contentY - 2
    let localX = pt.x - 2

    let targetId = ""
    for (let i = 0; i < tilesModel.count; i++) {
        let t = tilesModel.get(i)
        if (t.gridPage !== curPage) continue
        let tX = t.gridCol * (dc.tileUnitWidth + 10)
        let tY = t.gridPage * dc.pageStride + (t.gridRow === 0 ? 0 : 66)
        let tW = (t.span === 2 || t.span === 4) ? dc.tileDoubleWidth : dc.tileUnitWidth
        let tH = (t.span === 4) ? 122 : 56
        if (localX >= tX - 4 && localX <= tX + tW + 4 &&
            localY >= tY - 4 && localY <= tY + tH + 4) {
            targetId = t.id
            break
        }
    }
    dc.dropTargetTileId = targetId
}

function finishDraggingTile(dc, tilesModel) {
    if (dc.draggingTileId !== "" && dc.dropTargetTileId !== "" && dc.draggingTileId !== dc.dropTargetTileId) {
        let fromIdx = -1
        let toIdx = -1
        for (let i = 0; i < tilesModel.count; i++) {
            if (tilesModel.get(i).id === dc.draggingTileId) fromIdx = i
            if (tilesModel.get(i).id === dc.dropTargetTileId) toIdx = i
        }
        if (fromIdx !== -1 && toIdx !== -1) {
            tilesModel.move(fromIdx, toIdx, 1)
            dc.recalculateGridLayout()
        }
    }
    dc.draggingTileId = ""
    dc.dropTargetTileId = ""
    dc.saveTilesLayout()
}

function getTilePageIndex(tilesModel, id) {
    if (!id) return 0
    for (let i = 0; i < tilesModel.count; i++) {
        if (tilesModel.get(i).id === id) {
            return tilesModel.get(i).gridPage
        }
    }
    return 0
}

function initTiles(dc, tilesModel, tilesLayoutFile) {
    if (tilesModel.count > 0) return
    try {
        let txt = tilesLayoutFile.text().trim()
        if (txt.length > 0) {
            let parsed = JSON.parse(txt)
            if (Array.isArray(parsed) && parsed.length > 0) {
                dc.loadCustomTiles(parsed)
                return
            }
        }
    } catch(e) {}
    dc.loadDefaultTiles()
}

function loadDefaultTiles(dc, tilesModel) {
    tilesModel.clear()
    for (let i = 0; i < dc.defaultTiles.length; i++) {
        tilesModel.append({
            id: dc.defaultTiles[i].id,
            span: dc.defaultTiles[i].span,
            gridPage: 0,
            gridRow: 0,
            gridCol: 0
        })
    }
    dc.recalculateGridLayout()
    if (tilesModel.count > 0 && (dc.selectedTileId === "" || !getTileSpan(tilesModel, dc.selectedTileId))) {
        dc.selectedTileId = tilesModel.get(0).id
    }
}

function loadCustomTiles(dc, tilesModel, savedList) {
    let knownIds = dc.defaultTiles.map(t => t.id)
    let result = []
    let savedMap = {}
    for (let i = 0; i < savedList.length; i++) {
        let item = savedList[i]
        if (knownIds.indexOf(item.id) !== -1 && !savedMap[item.id]) {
            result.push({ id: item.id, span: normalizeSpan(item.span) })
            savedMap[item.id] = true
        }
    }
    for (let j = 0; j < dc.defaultTiles.length; j++) {
        let dt = dc.defaultTiles[j]
        if (!savedMap[dt.id]) {
            result.push({ id: dt.id, span: normalizeSpan(dt.span) })
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
    recalculateGridLayout(dc, tilesModel, dc.tilesPager, dc.smoothScrollAnim)
    if (tilesModel.count > 0 && (dc.selectedTileId === "" || !getTileSpan(tilesModel, dc.selectedTileId))) {
        dc.selectedTileId = tilesModel.get(0).id
    }
}

function saveTilesLayout(tilesModel, saveLayoutProc) {
    if (!saveLayoutProc) return
    let toSave = []
    for (let i = 0; i < tilesModel.count; i++) {
        let item = tilesModel.get(i)
        toSave.push({ id: item.id, span: normalizeSpan(item.span) })
    }
    saveLayoutProc.jsonContent = JSON.stringify(toSave, null, 2)
    saveLayoutProc.running = true
}

function navigateTile(dc, tilesModel, dir) {
    if (!tilesModel || tilesModel.count === 0) return

    let curIdx = -1
    for (let i = 0; i < tilesModel.count; i++) {
        if (tilesModel.get(i).id === dc.selectedTileId) {
            curIdx = i
            break
        }
    }

    if (curIdx === -1) {
        dc.selectedTileId = tilesModel.get(0).id
        dc.goToPage(tilesModel.get(0).gridPage)
        return
    }

    let cur = tilesModel.get(curIdx)
    let curPage = cur.gridPage
    let curRow = cur.gridRow
    let curCol = cur.gridCol
    let curSpan = (cur.span === 2 || cur.span === 4) ? 2 : 1
    let curHeight = (cur.span === 4) ? 2 : 1
    let curCenter = curCol + (curSpan - 1) / 2.0

    let targetIdx = -1

    if (dir === "left") {
        let bestCol = -1
        for (let i = 0; i < tilesModel.count; i++) {
            let t = tilesModel.get(i)
            if (t.gridPage === curPage && (t.gridRow === curRow || curHeight === 2 || t.span === 4) && t.gridCol < curCol) {
                if (t.gridCol > bestCol) {
                    bestCol = t.gridCol
                    targetIdx = i
                }
            }
        }
        if (targetIdx === -1) {
            if (curRow > 0 && curHeight === 1) {
                bestCol = -1
                for (let i = 0; i < tilesModel.count; i++) {
                    let t = tilesModel.get(i)
                    if (t.gridPage === curPage && t.gridRow === curRow - 1) {
                        if (t.gridCol > bestCol) {
                            bestCol = t.gridCol
                            targetIdx = i
                        }
                    }
                }
            } else if (curPage > 0) {
                bestCol = -1
                for (let i = 0; i < tilesModel.count; i++) {
                    let t = tilesModel.get(i)
                    if (t.gridPage === curPage - 1) {
                        if (t.gridCol > bestCol) {
                            bestCol = t.gridCol
                            targetIdx = i
                        }
                    }
                }
            }
        }
        if (targetIdx === -1 && curIdx > 0) {
            targetIdx = curIdx - 1
        }
    } else if (dir === "right") {
        let bestCol = 999
        for (let i = 0; i < tilesModel.count; i++) {
            let t = tilesModel.get(i)
            if (t.gridPage === curPage && (t.gridRow === curRow || curHeight === 2 || t.span === 4) && t.gridCol > curCol) {
                if (t.gridCol < bestCol) {
                    bestCol = t.gridCol
                    targetIdx = i
                }
            }
        }
        if (targetIdx === -1) {
            if (curRow === 0 && curHeight === 1) {
                bestCol = 999
                for (let i = 0; i < tilesModel.count; i++) {
                    let t = tilesModel.get(i)
                    if (t.gridPage === curPage && t.gridRow === 1) {
                        if (t.gridCol < bestCol) {
                            bestCol = t.gridCol
                            targetIdx = i
                        }
                    }
                }
            } else if (curPage < dc.totalPageCount - 1) {
                bestCol = 999
                for (let i = 0; i < tilesModel.count; i++) {
                    let t = tilesModel.get(i)
                    if (t.gridPage === curPage + 1 && t.gridRow === 0) {
                        if (t.gridCol < bestCol) {
                            bestCol = t.gridCol
                            targetIdx = i
                        }
                    }
                }
            }
        }
        if (targetIdx === -1 && curIdx < tilesModel.count - 1) {
            targetIdx = curIdx + 1
        }
    } else if (dir === "up") {
        let targetPage = curPage
        let targetRow = curRow - 1
        if (targetRow < 0) {
            targetPage = curPage - 1
            targetRow = 1
        }
        if (targetPage >= 0) {
            let minDiff = 999
            for (let i = 0; i < tilesModel.count; i++) {
                let t = tilesModel.get(i)
                if (t.gridPage === targetPage && (t.gridRow === targetRow || t.span === 4)) {
                    let tSpan = (t.span === 2 || t.span === 4) ? 2 : 1
                    let tCenter = t.gridCol + (tSpan - 1) / 2.0
                    let diff = Math.abs(tCenter - curCenter)
                    if (diff < minDiff) {
                        minDiff = diff
                        targetIdx = i
                    }
                }
            }
            if (targetIdx === -1) {
                for (let i = 0; i < tilesModel.count; i++) {
                    let t = tilesModel.get(i)
                    if (t.gridPage === targetPage) {
                        targetIdx = i
                        break
                    }
                }
            }
        }
    } else if (dir === "down") {
        let targetPage = curPage
        let targetRow = curHeight === 2 ? 2 : (curRow + 1)
        if (targetRow > 1) {
            targetPage = curPage + 1
            targetRow = 0
        }
        if (targetPage < dc.totalPageCount) {
            let minDiff = 999
            for (let i = 0; i < tilesModel.count; i++) {
                let t = tilesModel.get(i)
                if (t.gridPage === targetPage && (t.gridRow === targetRow || t.span === 4)) {
                    let tSpan = (t.span === 2 || t.span === 4) ? 2 : 1
                    let tCenter = t.gridCol + (tSpan - 1) / 2.0
                    let diff = Math.abs(tCenter - curCenter)
                    if (diff < minDiff) {
                        minDiff = diff
                        targetIdx = i
                    }
                }
            }
            if (targetIdx === -1) {
                for (let i = 0; i < tilesModel.count; i++) {
                    let t = tilesModel.get(i)
                    if (t.gridPage === targetPage) {
                        targetIdx = i
                        break
                    }
                }
            }
        }
    }

    if (targetIdx >= 0 && targetIdx < tilesModel.count) {
        let t = tilesModel.get(targetIdx)
        dc.selectedTileId = t.id
        dc.goToPage(t.gridPage)
    }
}

function triggerTileAction(dc, tileId) {
    var root = dc.root
    switch (tileId) {
        case "wifi":
        case "bluetooth":
        case "notifications":
        case "screentime":
        case "battery":
        case "plugins":
        case "updates":
        case "theme":
        case "wallpaper":
        case "notes":
        case "calendar":
            if (dc.activeDetailView === tileId) {
                dc.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else {
                dc.activeDetailView = tileId
                if (root) root.dashboardDetail = tileId
            }
            break
        case "nightlight":
            dc.cycleNightMode()
            break
        case "caffeine":
            dc.toggleCaffeine()
            break
        case "temperature":
            dc.refreshCpuTemp()
            break
        case "pomodoro":
            dc.showPomodoroPopup = !dc.showPomodoroPopup
            break
        case "quickshare":
            dc.launchQuickshare()
            break
    }
}

function getWeekNumber(nowDate) {
    var d = new Date(Date.UTC(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate()))
    var dayNum = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - dayNum)
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
}

function fmtTime(s) {
    if (!s || s <= 0 || isNaN(s)) return "0:00"
    var m = Math.floor(s / 60)
    var sec = Math.floor(s % 60)
    return m + ":" + (sec < 10 ? "0" + sec : "" + sec)
}

function seekTo(dc, mprisSel, ratio) {
    if (!mprisSel.player || dc.curLen <= 0) return
    var target = Math.max(0, Math.min(1, ratio)) * dc.curLen
    if (typeof mprisSel.player.setPosition === "function") {
        mprisSel.player.setPosition(target)
    } else {
        mprisSel.player.position = target
    }
    dc.curPos = target
}

function handleKeyPressed(dc, event) {
    var root = dc.root
    var panel = dc.panel
    var mprisSel = dc.mprisSel
    var sysDetailSection = dc.sysDetailSection
    var pluginsDetailSection = dc.pluginsDetailSection
    var themeDetailSection = dc.themeDetailSection
    var notesDetailSection = dc.notesDetailSection
    var calDetailSection = dc.calDetailSection
    var wifiDetailSection = dc.wifiDetailSection
    var btDetailSection = dc.btDetailSection

    if (dc.editTilesMode) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_E) {
            dc.editTilesMode = false
            dc.saveTilesLayout()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_S || event.key === Qt.Key_R || event.key === Qt.Key_Space) {
            if (dc.selectedTileId) {
                cycleTileSpan(dc, dc.tilesModel, dc.selectedTileId)
                event.accepted = true
                return
            }
        }
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            navigateTile(dc, dc.tilesModel, "left")
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            navigateTile(dc, dc.tilesModel, "right")
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            navigateTile(dc, dc.tilesModel, "up")
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            navigateTile(dc, dc.tilesModel, "down")
            event.accepted = true
            return
        }
    }
    if (dc.activeDetailView === "system") {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_X) {
            dc.activeDetailView = ""
            if (root) root.dashboardDetail = ""
            event.accepted = true
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
            if (sysDetailSection) sysDetailSection.focusedIndex = (sysDetailSection.focusedIndex + 1) % 4
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
            if (sysDetailSection) sysDetailSection.focusedIndex = (sysDetailSection.focusedIndex - 1 + 4) % 4
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (sysDetailSection) sysDetailSection.triggerOption(sysDetailSection.focusedIndex)
            event.accepted = true
        }
        return
    }
    if (dc.activeDetailView === "plugins") {
        if (event.key === Qt.Key_Escape) {
            if (pluginsDetailSection && pluginsDetailSection.filterText.length > 0) {
                pluginsDetailSection.filterText = ""
            } else {
                dc.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            }
            event.accepted = true
        } else if (event.key === Qt.Key_H) {
            if (event.modifiers & Qt.ShiftModifier) {
                dc.jumpPrevCategory()
            } else {
                dc.prevOption()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            if (event.modifiers & Qt.ShiftModifier) {
                dc.jumpNextCategory()
            } else {
                dc.nextOption()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            if (pluginsDetailSection) {
                var count = pluginsDetailSection.filteredCount || 1
                pluginsDetailSection.focusedIndex = (pluginsDetailSection.focusedIndex + 1) % count
            }
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            if (pluginsDetailSection) {
                var count = pluginsDetailSection.filteredCount || 1
                pluginsDetailSection.focusedIndex = (pluginsDetailSection.focusedIndex - 1 + count) % count
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (pluginsDetailSection) pluginsDetailSection.triggerLaunch(pluginsDetailSection.focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            if (pluginsDetailSection) pluginsDetailSection.togglePinCurrent(pluginsDetailSection.focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Slash) {
            if (pluginsDetailSection && pluginsDetailSection.focusSearch) {
                pluginsDetailSection.focusSearch()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            if (pluginsDetailSection && pluginsDetailSection.filterText.length > 0) {
                pluginsDetailSection.filterText = pluginsDetailSection.filterText.slice(0, -1)
            }
            event.accepted = true
        }
        return
    }
    if (dc.activeDetailView === "theme" || dc.activeDetailView === "wallpaper") {
        if (event.key === Qt.Key_Escape) {
            dc.activeDetailView = ""
            if (root) root.dashboardDetail = ""
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (themeDetailSection && themeDetailSection.applySelected) themeDetailSection.applySelected()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (themeDetailSection && themeDetailSection.setMode) {
                themeDetailSection.setMode(themeDetailSection.activeMode === "theme" ? "wallpaper" : "theme")
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            if (themeDetailSection && themeDetailSection.moveSel) themeDetailSection.moveSel(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (themeDetailSection && themeDetailSection.moveSel) themeDetailSection.moveSel(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            if (themeDetailSection && themeDetailSection.setMode) {
                themeDetailSection.setMode(themeDetailSection.activeMode === "theme" ? "wallpaper" : "theme")
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            if (themeDetailSection && themeDetailSection.filterText.length > 0) {
                themeDetailSection.filterText = themeDetailSection.filterText.slice(0, -1)
            }
            event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                   && event.text.charCodeAt(0) !== 127
                   && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            if (themeDetailSection) {
                themeDetailSection.filterText += event.text
            }
            event.accepted = true
        }
        return
    }
    if (dc.activeDetailView === "notes") {
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
            dc.activeDetailView = ""
            if (root) root.dashboardDetail = ""
            event.accepted = true
        }
        return
    }
    if ((calDetailSection && calDetailSection.isInputFocused) ||
        (notesDetailSection && notesDetailSection.isInputFocused)) {
        return
    }
    if (dc.activeDetailView === "") {
        if (event.key === Qt.Key_E) {
            dc.toggleEditMode(dc.selectedTileId)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            navigateTile(dc, dc.tilesModel, "left")
            event.accepted = true
            return
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            navigateTile(dc, dc.tilesModel, "right")
            event.accepted = true
            return
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            if (event.modifiers & Qt.ShiftModifier) {
                dc.pageUp()
            } else {
                navigateTile(dc, dc.tilesModel, "up")
            }
            event.accepted = true
            return
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            if (event.modifiers & Qt.ShiftModifier) {
                dc.pageDown()
            } else {
                navigateTile(dc, dc.tilesModel, "down")
            }
            event.accepted = true
            return
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            let tid = dc.selectedTileId || (dc.tilesModel && dc.tilesModel.count > 0 ? dc.tilesModel.get(0).id : "")
            if (tid) {
                dc.selectedTileId = tid
                triggerTileAction(dc, tid)
                event.accepted = true
                return
            }
        }
    } else {
        if ((event.key === Qt.Key_H || event.key === Qt.Key_Left) &&
            dc.activeDetailView !== "system" &&
            dc.activeDetailView !== "plugins" &&
            dc.activeDetailView !== "theme" &&
            dc.activeDetailView !== "wallpaper" &&
            dc.activeDetailView !== "notes") {
            dc.activeDetailView = ""
            if (root) root.dashboardDetail = ""
            event.accepted = true
            return
        } else if ((event.key === Qt.Key_L || event.key === Qt.Key_Right) &&
            dc.activeDetailView !== "system" &&
            dc.activeDetailView !== "plugins" &&
            dc.activeDetailView !== "theme" &&
            dc.activeDetailView !== "wallpaper" &&
            dc.activeDetailView !== "notes") {
            dc.jumpNextCategory()
            event.accepted = true
            return
        }
    }
    if (event.key === Qt.Key_Tab) {
        if (panel && panel.searchOpen) {
            panel.toggleSearchEngine()
        } else if (event.modifiers & Qt.ShiftModifier) {
            dc.jumpPrevCategory()
        } else {
            dc.jumpNextCategory()
        }
        event.accepted = true
    } else if (event.key === Qt.Key_Backtab) {
        dc.jumpPrevCategory()
        event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
        if (dc.activeDetailView !== "") {
            dc.activeDetailView = ""
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
        if (mprisSel.player && mprisSel.player.playbackStatus) {
            mprisSel.player.togglePlaying()
            event.accepted = true
        } else if (dc.activeDetailView === "wifi" && wifiDetailSection) {
            wifiDetailSection.startSpeedTestWithSweep()
            event.accepted = true
        } else if (dc.activeDetailView === "bluetooth" && btDetailSection) {
            btDetailSection.doTogglePower()
            event.accepted = true
        } else if (dc.activeDetailView === "" && dc.selectedTileId) {
            triggerTileAction(dc, dc.selectedTileId)
            event.accepted = true
        }
    } else if (event.key === Qt.Key_C) {
        if (calDetailSection && calDetailSection.isInputFocused) {
            return;
        }
        if (dc.activeDetailView === "calendar") {
            dc.activeDetailView = ""
            if (root) root.dashboardDetail = ""
        } else {
            dc.activeDetailView = "calendar"
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
        if (dc.activeDetailView === "system") {
            dc.activeDetailView = ""
            if (root) root.dashboardDetail = ""
        } else {
            dc.activeDetailView = "system"
            if (root) root.dashboardDetail = "system"
        }
        event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (dc.activeDetailView === "wifi" && wifiDetailSection) {
            wifiDetailSection.startSpeedTestWithSweep()
            event.accepted = true
        } else if (dc.activeDetailView === "bluetooth" && btDetailSection) {
            btDetailSection.doTogglePower()
            event.accepted = true
        }
    }
}

function syncLocalLyricIndex(dc) {
    if (!dc.localLyricsList || dc.localLyricsList.length === 0) {
        if (dc.localLyricIndex !== -1) dc.localLyricIndex = -1
        return
    }
    var pos = dc.curPos
    var idx = -1
    for (var i = 0; i < dc.localLyricsList.length; i++) {
        if (pos >= dc.localLyricsList[i].time) {
            idx = i
        } else {
            break
        }
    }
    if (idx !== dc.localLyricIndex) dc.localLyricIndex = idx
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

function fetchLocalLyrics(dc) {
    var mprisSel = dc.mprisSel
    var mprisPanel = dc.mprisPanel
    var title = dc.curTitle ? dc.curTitle.trim() : ""
    var artist = dc.curArtist ? dc.curArtist.trim() : ""
    var album = mprisSel.player ? (mprisSel.player.trackAlbum || "").trim() : ""
    var dur = Math.round(mprisSel.player ? (mprisSel.player.length || dc.curLen || 0) : (dc.curLen || 0))
    var trackId = (title || artist) ? (title + "||" + artist) : ""

    var seq = ++dc._localLyricsFetchSeq

    if (!title || !mprisSel.active) {
        dc.localLyricsList = []
        dc.localLyricIndex = -1
        dc.localLyricsTrackId = ""
        return
    }

    // If mprisPanel is provided and actively managing lyrics for this track, let it handle it
    if (mprisPanel && mprisPanel.currentTrackId === trackId) {
        return
    }

    dc.localLyricsList = []
    dc.localLyricIndex = -1
    dc.localLyricsTrackId = ""

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
                if (seq !== dc._localLyricsFetchSeq || dc.currentTrackId !== trackId) {
                    return
                }
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText)
                        var parsed = pickBestResult(resp)
                        if (parsed && parsed.length > 0) {
                            dc.localLyricsTrackId = trackId
                            dc.localLyricsList = parsed
                            dc.syncLocalLyricIndex()
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
