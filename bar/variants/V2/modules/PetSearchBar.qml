import "../motion"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "SearchCalc.js" as Calc

Item {
    id: searchBar
    required property var root

    property bool isOpen: false
    property string engine: "ddg" // "ddg" | "youtube" | "claude"
    property real maxContentWidth: 220
    readonly property real contentHeight: 28

    signal focusLostOrClosed()
    signal searchSubmitted()

    // Keep the dropdown above sibling pills in the header row
    z: 20

    // ── Live web suggestions and inline calculator state ────────────
    property var webSuggestions: []
    property var rows: []
    property int selectedIndex: -1
    property string calcResult: ""   // text shown in the pill, e.g. "= 84"
    property string calcCopy: ""     // text copied on Enter
    property var rateCache: ({})
    property var pendingCurrency: null
    property string suggestPending: ""
    property string suggestInFlight: ""
    readonly property bool calcActive: calcCopy !== ""
    readonly property string typed: textInput.text

    onTypedChanged: {
        selectedIndex = -1
        updateCalc()
        suggestTimer.restart()
        rebuildRows()
    }
    onEngineChanged: {
        webSuggestions = []
        suggestTimer.restart()
        rebuildRows()
    }
    onIsOpenChanged: {
        if (isOpen) { selectedIndex = -1; rebuildRows() }
    }
    function rebuildRows() {
        var q = textInput.text.trim().toLowerCase()
        var out = []
        var seen = {}
        function push(t) {
            var key = t.toLowerCase()
            if (seen[key] || out.length >= 7) return
            seen[key] = true
            out.push({ text: t })
        }
        if (q !== "" && !calcActive && calcResult === "") {
            for (var k = 0; k < webSuggestions.length; k++) push(webSuggestions[k])
        }
        rows = out
    }

    // ── Calculator ──────────────────────────────────────────────────
    function updateCalc() {
        var res = Calc.evaluate(textInput.text)
        pendingCurrency = null
        if (!res) {
            calcResult = ""; calcCopy = ""
            return
        }
        if (res.currency) {
            var c = rateCache[res.from]
            if (c && (Date.now() - c.ts) < 6 * 3600 * 1000 && c.rates && c.rates[res.to] !== undefined) {
                var cr = Calc.currencyResult(res.amount, c.rates[res.to], res.to)
                calcResult = cr.display; calcCopy = cr.copy
            } else {
                calcResult = "…"; calcCopy = ""
                pendingCurrency = res
                currencyTimer.restart()
            }
            return
        }
        calcResult = res.display
        calcCopy = res.copy
    }

    Timer {
        id: currencyTimer
        interval: 350
        onTriggered: {
            if (!searchBar.pendingCurrency) return
            currencyProc.running = false
            currencyProc.command = ["curl", "-s", "--max-time", "5", "https://open.er-api.com/v6/latest/" + searchBar.pendingCurrency.from]
            currencyProc.requestedFrom = searchBar.pendingCurrency.from
            currencyProc.running = true
        }
    }

    Process {
        id: currencyProc
        property string requestedFrom: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    if (d.result === "success") {
                        var cache = searchBar.rateCache
                        cache[currencyProc.requestedFrom] = { ts: Date.now(), rates: d.rates }
                        searchBar.rateCache = cache
                        searchBar.updateCalc()
                        searchBar.rebuildRows()
                        return
                    }
                } catch (e) {}
                if (searchBar.calcResult === "…") searchBar.calcResult = ""
            }
        }
    }

    // ── Web suggestions (DuckDuckGo / YouTube autocomplete) ─────────
    Timer {
        id: suggestTimer
        interval: 180
        onTriggered: searchBar.fetchSuggestions()
    }

    function fetchSuggestions() {
        var q = textInput.text.trim()
        if (!isOpen || q === "" || engine === "claude" || calcResult !== "") {
            webSuggestions = []
            rebuildRows()
            return
        }
        if (suggestProc.running) { suggestPending = q; return }
        startSuggest(q)
    }

    function startSuggest(q) {
        suggestInFlight = q
        suggestPending = ""
        var url = engine === "youtube"
            ? "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=" + encodeURIComponent(q)
            : "https://duckduckgo.com/ac/?type=list&q=" + encodeURIComponent(q)
        suggestProc.command = ["curl", "-sL", "--max-time", "3", url]
        suggestProc.running = true
    }

    Process {
        id: suggestProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (searchBar.suggestInFlight !== textInput.text.trim()) return
                try {
                    var d = JSON.parse(this.text)
                    if (Array.isArray(d) && Array.isArray(d[1])) {
                        searchBar.webSuggestions = d[1].filter(function(x) { return typeof x === "string" }).slice(0, 6)
                        searchBar.rebuildRows()
                    }
                } catch (e) {}
            }
        }
        onExited: {
            if (searchBar.suggestPending !== "" && searchBar.suggestPending !== searchBar.suggestInFlight)
                searchBar.startSuggest(searchBar.suggestPending)
        }
    }

    // Smoothly expands width from 0 to maxContentWidth
    implicitWidth: isOpen ? Math.max(120, maxContentWidth) : 0
    implicitHeight: contentHeight
    visible: implicitWidth > 0.1
    opacity: implicitWidth > 1 ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function toggle() {
        if (isOpen) {
            close()
        } else {
            open()
        }
    }

    function setEngine(name) {
        if (engine === name) return
        engine = name
    }

    // Cycles DuckDuckGo -> YouTube -> Claude -> DuckDuckGo
    function toggleEngine() {
        engine = (engine === "ddg" ? "youtube" : (engine === "youtube" ? "claude" : "ddg"))
    }

    function open() {
        isOpen = true
        Qt.callLater(() => textInput.forceActiveFocus())
    }

    function close() {
        isOpen = false
        textInput.focus = false
        focusLostOrClosed()
    }

    function copyCalc() {
        Quickshell.execDetached(["wl-copy", calcCopy])
        textInput.text = ""
        searchSubmitted()
        close()
    }

    function doSearch() {
        if (selectedIndex >= 0 && selectedIndex < rows.length) {
            searchFor(rows[selectedIndex].text)
        } else if (calcActive) {
            copyCalc()
        } else if (calcResult === "…") {
            return // still fetching the exchange rate
        } else {
            searchFor(textInput.text.trim())
        }
    }

    function searchFor(query) {
        var url = ""
        if (engine === "ddg") {
            url = query === "" ? "https://duckduckgo.com" : "https://duckduckgo.com/?q=" + encodeURIComponent(query)
        } else if (engine === "youtube") {
            url = query === "" ? "https://www.youtube.com" : "https://www.youtube.com/results?search_query=" + encodeURIComponent(query)
        } else {
            url = query === "" ? "https://claude.ai" : "https://claude.ai/new?q=" + encodeURIComponent(query)
        }

        if (query !== "") {
            Quickshell.execDetached(["wl-copy", query])
        }
        Quickshell.execDetached(["xdg-open", url])
        Quickshell.execDetached(["bash", "-c", "sleep 0.1 && hyprctl dispatch focuswindow class:zen"])

        textInput.text = ""
        searchSubmitted()
        close()
    }

    readonly property color engineColor: engine === "ddg" ? "#E35934" : (engine === "youtube" ? "#FF3B30" : "#D97757")
    readonly property color iconOnEngine: "#2B1710"

    // Main search pill (engine-coloured, like a chat composer)
    Rectangle {
        id: pillBody
        anchors.fill: parent
        clip: true
        radius: searchBar.contentHeight / 2
        color: searchBar.engineColor
        Behavior on color { ColorAnimation { duration: 180 } }

        // Engine icon buttons (DuckDuckGo, YouTube, Claude) sitting directly on the pill
        Row {
            id: engineRow
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Item {
                id: ddgBtn
                width: 24
                height: searchBar.contentHeight

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.env("HOME") + "/.config/quickshell/bar/duckduckgo.svg"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: searchBar.iconOnEngine
                    }
                    opacity: searchBar.engine === "ddg" ? 1.0 : (ddgMa.containsMouse ? 0.7 : 0.45)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                SpringPress {}
                MouseArea {
                    id: ddgMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchBar.setEngine("ddg")
                        textInput.forceActiveFocus()
                    }
                }
            }

            Item {
                id: ytBtn
                width: 24
                height: searchBar.contentHeight

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.env("HOME") + "/.config/quickshell/bar/youtube.svg"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: searchBar.iconOnEngine
                    }
                    opacity: searchBar.engine === "youtube" ? 1.0 : (ytMa.containsMouse ? 0.7 : 0.45)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                SpringPress {}
                MouseArea {
                    id: ytMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchBar.setEngine("youtube")
                        textInput.forceActiveFocus()
                    }
                }
            }

            Item {
                id: claudeBtn
                width: 24
                height: searchBar.contentHeight

                Image {
                    anchors.centerIn: parent
                    width: 13
                    height: 13
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.env("HOME") + "/.config/quickshell/bar/claude.svg"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: searchBar.iconOnEngine
                    }
                    opacity: searchBar.engine === "claude" ? 1.0 : (claudeMa.containsMouse ? 0.7 : 0.45)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                SpringPress {}
                MouseArea {
                    id: claudeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchBar.setEngine("claude")
                        textInput.forceActiveFocus()
                    }
                }
            }
        }

        // Light inner subsection holding the input, clear and go buttons
        Rectangle {
            id: innerSection
            anchors.left: engineRow.right
            anchors.leftMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            height: searchBar.contentHeight - 6
            radius: height / 2
            color: root.paper

            Row {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 3
                spacing: 5

                Item {
                    id: inputContainer
                    width: Math.max(40, parent.width - goBtn.width - (clearBtn.width > 0 ? clearBtn.width + parent.spacing : 0) - parent.spacing)
                    height: parent.height
                    clip: true

                    // Inline calculator / converter answer
                    Text {
                        id: calcLabel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchBar.calcResult !== ""
                        text: searchBar.calcResult
                        color: searchBar.engineColor
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    TextInput {
                        id: textInput
                        anchors.left: parent.left
                        anchors.right: calcLabel.visible ? calcLabel.left : parent.right
                        anchors.rightMargin: calcLabel.visible ? 4 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.ink
                        selectionColor: searchBar.engineColor
                        selectedTextColor: "#FFFFFF"
                        selectByMouse: true
                        clip: true

                        Keys.onTabPressed: (event) => { searchBar.toggleEngine(); event.accepted = true }
                        Keys.onBacktabPressed: (event) => { searchBar.toggleEngine(); event.accepted = true }
                        Keys.onEscapePressed: (event) => { searchBar.close(); event.accepted = true }

                        Keys.onDownPressed: (event) => {
                            if (searchBar.rows.length > 0)
                                searchBar.selectedIndex = Math.min(searchBar.rows.length - 1, searchBar.selectedIndex + 1)
                            event.accepted = true
                        }
                        Keys.onUpPressed: (event) => {
                            searchBar.selectedIndex = Math.max(-1, searchBar.selectedIndex - 1)
                            event.accepted = true
                        }

                        onAccepted: searchBar.doSearch()

                        UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: searchBar.engine === "ddg" ? "Search web..." : (searchBar.engine === "youtube" ? "Search YouTube..." : "Ask Claude...")
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: root.ink
                            opacity: 0.4
                            visible: textInput.text === ""
                        }
                    }
                }

                Item {
                    id: clearBtn
                    width: textInput.text.length > 0 ? 16 : 0
                    height: 20
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    Behavior on width { NumberAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 12
                        color: root.ink
                        opacity: clearMa.containsMouse ? 0.9 : 0.5
                    }

                    SpringPress {}
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            textInput.text = ""
                            textInput.forceActiveFocus()
                        }
                    }
                }

                Item {
                    id: goBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20

                    IconText {
                        anchors.centerIn: parent
                        text: searchBar.calcActive ? "content_copy" : (textInput.text.trim() === "" ? "search" : "arrow_forward")
                        font.pixelSize: 13
                        color: goMa.containsMouse ? searchBar.engineColor : root.ink
                        opacity: goMa.containsMouse ? 1.0 : 0.7
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    SpringPress {}
                    MouseArea {
                        id: goMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchBar.doSearch()
                    }
                }
            }
        }
    }

    // ── Live suggestions dropdown ──────────────────────────────
    Rectangle {
        id: dropdown
        z: 100
        y: searchBar.contentHeight + 6
        width: Math.max(searchBar.width, 240)
        height: dropdownColumn.implicitHeight + 8
        radius: 14
        color: root.paper
        border.width: 1
        border.color: Qt.rgba(searchBar.engineColor.r, searchBar.engineColor.g, searchBar.engineColor.b, 0.5)
        visible: opacity > 0.01
        opacity: (searchBar.isOpen && searchBar.rows.length > 0 && searchBar.width > 150) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Column {
            id: dropdownColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4

            Repeater {
                model: searchBar.rows
                delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    required property int index
                    width: dropdownColumn.width
                    height: 26
                    radius: 11
                    readonly property bool selected: searchBar.selectedIndex === index
                    color: selected
                        ? Qt.rgba(searchBar.engineColor.r, searchBar.engineColor.g, searchBar.engineColor.b, 0.22)
                        : (rowMa.containsMouse ? Qt.rgba(searchBar.engineColor.r, searchBar.engineColor.g, searchBar.engineColor.b, 0.12) : "transparent")

                    IconText {
                        id: rowIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: searchBar.engine === "youtube" ? "smart_display" : "search"
                        font.pixelSize: 13
                        color: root.ink
                        opacity: 0.55
                    }

                    Text {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.modelData.text
                        elide: Text.ElideRight
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.ink
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchBar.searchFor(rowItem.modelData.text)
                    }
                }
            }
        }
    }
}
