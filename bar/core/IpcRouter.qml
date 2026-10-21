import QtQuick
import Quickshell.Io

Item {
    id: router

    required property var variantHost

    property var pendingThemePayload: undefined
    property var pendingLauncherPayload: undefined
    property bool pendingThemeReload: false
    property string pendingPickerMode: ""
    property bool pendingSystemRefresh: false

    width: 0
    height: 0

    function canDispatch() {
        return variantHost.ready && variantHost.activeItem !== null
    }

    function invoke(method, first, second) {
        if (!canDispatch()) return false
        var fn = variantHost.activeItem[method]
        if (!fn) return false

        if (second !== undefined) fn(first, second)
        else if (first !== undefined) fn(first)
        else fn()
        return true
    }

    function applyTheme(payload) {
        if (!invoke("applyTheme", payload)) pendingThemePayload = payload
    }

    function applyLauncher(payload) {
        if (!invoke("applyLauncher", payload)) pendingLauncherPayload = payload
    }

    function reloadTheme() {
        if (!invoke("reloadTheme")) pendingThemeReload = true
    }

    function openPicker(mode) {
        if (!invoke("openPicker", mode)) pendingPickerMode = mode
    }

    function systemRefresh() {
        if (!invoke("systemUpdateRefresh")) pendingSystemRefresh = true
    }

    function flush() {
        if (!canDispatch()) return

        if (pendingThemePayload !== undefined) {
            invoke("applyTheme", pendingThemePayload)
            pendingThemePayload = undefined
        }
        if (pendingLauncherPayload !== undefined) {
            invoke("applyLauncher", pendingLauncherPayload)
            pendingLauncherPayload = undefined
        }
        if (pendingThemeReload) {
            invoke("reloadTheme")
            pendingThemeReload = false
        }
        if (pendingSystemRefresh) {
            invoke("systemUpdateRefresh")
            pendingSystemRefresh = false
        }
        if (pendingPickerMode !== "") {
            invoke("openPicker", pendingPickerMode)
            pendingPickerMode = ""
        }
    }

    IpcHandler {
        target: "lifecycle"
        function version(): string {
            return router.variantHost.runningVariant === "v2" ? "V2" : "V1"
        }
        function ready(): bool { return router.variantHost.ready }
    }

    IpcHandler {
        target: "variant"
        function current(): string { return router.variantHost.runningVariant }
        function state(): string { return router.variantHost.phase }
        function error(): string { return router.variantHost.lastError }
        function activate(version: string) { router.variantHost.requestSwitch(version) }
    }

    IpcHandler {
        target: "layout"
        function lock() { router.invoke("layoutLock") }
        function unlock() { router.invoke("layoutUnlock") }
        function hover(on: bool) { router.invoke("setHover", on) }
        function togglebar() { router.invoke("toggleBar") }
        function toggledashboard() { router.invoke("toggleDashboard") }
        function opendetail(name: string) { router.invoke("openDashboardDetail", name) }
        // Lock-screen slide: retract before hyprlock, reveal after unlock.
        function lockretract() { router.invoke("lockRetract") }
        function lockreveal() { router.invoke("lockReveal") }
        function shellstyle(): string {
            if (!router.canDispatch()) return ""
            var fn = router.variantHost.activeItem.currentShellStyle
            return fn ? String(fn()) : ""
        }
    }

    IpcHandler {
        target: "osd"
        function show(kind: string, value: int) {
            router.invoke("showIslandOsd", kind, value)
        }
    }

    IpcHandler {
        target: "notif"
        function peek(app: string, summary: string, body: string) {
            router.invoke("triggerNotifPeek", app, summary, body, "")
        }
        function dismiss(id: int) {
            router.invoke("dismissNotifPeek", id)
        }
    }

    IpcHandler {
        target: "timer"
        function start(minutes: int, label: string) {
            router.invoke("startTimer", minutes, label)
        }
        function toggle() {
            router.invoke("toggleTimer")
        }
        function reset() {
            router.invoke("resetTimer")
        }
        function stopwatch() {
            router.invoke("startStopwatch")
        }
    }

    IpcHandler {
        target: "task"
        function start(label: string, percent: int) {
            router.invoke("startSysTask", label, percent)
        }
        function update(percent: int) {
            router.invoke("updateSysTask", percent)
        }
        function done() {
            router.invoke("finishSysTask")
        }
    }

    IpcHandler {
        target: "omarchy.system-update"
        function refresh() { router.systemRefresh() }
    }

    IpcHandler {
        target: "reactor"
        function test(kind: string, arg: string) { router.invoke("runReactor", kind, arg) }
        function monsweep() { router.invoke("runReactor", "monsweep", "") }
        function clear() { router.invoke("runReactor", "clear", "") }
    }

    IpcHandler {
        target: "theme"
        function apply(payload: string) { router.applyTheme(payload) }
        function applyLauncher(payload: string) { router.applyLauncher(payload) }
        function reload() { router.reloadTheme() }
    }

    IpcHandler {
        target: "picker"
        function theme() { router.openPicker("theme") }
        function wallpaper() { router.openPicker("wallpaper") }
        function screenshots() { router.openPicker("screenshots") }
        function videos() { router.openPicker("videos") }
        function style(name: string) { router.invoke("setPickerStyle", name) }
    }

    IpcHandler {
        target: "charging"
        function test(pct: int) { router.invoke("triggerChargingPopup", pct) }
    }

    IpcHandler {
        target: "dictation"
        function toggle() { router.invoke("toggleDictation") }
        function test(st: string) { router.invoke("testDictationState", st) }
    }

    Connections {
        target: router.variantHost
        function onPhaseChanged() {
            if (router.variantHost.ready) router.flush()
        }
    }
}
