import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Combined AI-usage pill (Claude Code + OpenAI Codex + OpenCode). The bar shows ONE tool
// (root.aiTool) as a themed-tinted SVG with a bottom-up usage fill; the tooltip
// shows all tracked tools; clicking opens the AiUsagePanel where the tool can be switched.
// Gating is unchanged: root.modClaude is the on/off toggle for the whole pill.
Item {
    id: rootMod
    required property var root

    // ── which tool the bar pill displays ──
    readonly property bool isOpenCode: root.aiTool === "opencode"
    readonly property bool isAgy: root.aiTool === "agy"
    readonly property bool isLogo: isOpenCode || isAgy
    readonly property url  logoSource: Qt.resolvedUrl(isOpenCode ? "../assets/opencode-mark.svg" : "../../../antigravity.svg")
    readonly property var  logoSourceSize: isAgy ? Qt.size(16, 16) : Qt.size(20, 12)
    readonly property int  ocMarkW: 20
    readonly property int  ocMarkH: 12

    // ── Claude: process detection is local (drives the pill's visibility); all
    //    usage data comes from root.ai* — the single shared parse in Theme.qml that
    //    AiUsagePanel renders from too, so the two views can't drift apart. ──
    property bool clActive: false
    readonly property bool   clFresh:     root.aiClFresh
    readonly property int    clPct5h:     root.aiClPct5h
    readonly property int    clPct7d:     root.aiClPct7d
    readonly property bool   clBlocked:   root.aiClBlocked
    readonly property string clTokens:    root.aiClTokens
    readonly property string clRate:      root.aiClRate
    readonly property int    clReset5hTs: root.aiClReset5hTs
    readonly property int    clReset7dTs: root.aiClReset7dTs
    readonly property int    clToday:     root.aiClToday
    readonly property bool   clHas:       root.aiClHas


    // ── OpenCode ──
    property bool ocActive: false
    readonly property bool   ocFresh:     root.aiOcFresh
    readonly property int    ocPct5h:     root.aiOcPct5h
    readonly property int    ocPct7d:     root.aiOcPct7d
    readonly property string ocPlan:      root.aiOcPlan
    readonly property string ocTokens:    root.aiOcTokens
    readonly property string ocRate:      root.aiOcRate
    readonly property string ocModel:     root.aiOcModel
    readonly property int    ocToday:     root.aiOcToday
    readonly property bool   ocHas:       root.aiOcHas

    // ── Antigravity ──
    property bool agActive: false
    readonly property bool agSignal: agActive

    // ── per-tool signal (active OR fresh non-zero usage) ──
    readonly property bool clSignal: clActive || (clPct5h > 0 && clFresh)
    readonly property bool ocSignal: ocActive || ((ocPct5h > 0 || ocToday > 0) && ocFresh)

    // ── selected-tool display values ──
    readonly property int  pct5h:   isOpenCode ? ocPct5h : (isAgy ? 0 : clPct5h)
    readonly property int  pct5hStep: Math.round(pct5h / 5) * 5
    readonly property bool selFresh: isOpenCode ? ocFresh : (isAgy ? true : clFresh)
    readonly property bool selSignal: isOpenCode ? ocSignal : (isAgy ? agSignal : clSignal)
    readonly property bool blocked:  (isOpenCode || isAgy) ? false : clBlocked
    readonly property color contentColor: root.widgetContentColor("G7", root.widgetIconColor)

    // show whenever the gate is on; the pill stays
    // reachable (to open the panel + switch) even if the selected tool is idle
    readonly property bool shown: root.modClaude

    readonly property string tooltipText: {
        var lines = []
        if (clHas || clActive) {
            lines.push("Claude Code")
            var cr = root.aiFmtReset(clReset5hTs)
            lines.push("5h: " + clPct5h + "%" + (cr ? "  (reset in " + cr + ")" : ""))
            var c7 = root.aiFmtReset(clReset7dTs)
            if (clPct7d > 0) lines.push("7d: " + clPct7d + "%" + (c7 ? "  (reset in " + c7 + ")" : ""))
            if (clTokens)    lines.push(clTokens + " tokens" + (clRate ? "  · " + clRate : ""))
            if (clToday > 0) lines.push("today: " + (clToday / 1e6).toFixed(2) + "M tok")
        }

        if (ocHas || ocActive) {
            if (lines.length) lines.push("")
            lines.push("OpenCode" + (ocPlan ? "  (" + ocPlan + ")" : ""))
            lines.push("5h: " + ocPct5h + "%  ·  7d: " + ocPct7d + "%")
            if (ocTokens) lines.push(ocTokens + " tokens" + (ocRate ? "  · " + ocRate : ""))
            if (ocToday > 0) lines.push("today: " + (ocToday / 1e6).toFixed(2) + "M tok")
            if (ocModel) lines.push(ocModel)
        }
        if (agActive || isAgy) {
            if (lines.length) lines.push("")
            lines.push("Antigravity CLI")
            lines.push(agActive ? "Process active" : "Process idle")
        }
        return lines.length ? lines.join("\n") : "AI usage"
    }

    // keep rendered until the collapse animation finishes
    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    // ── process detection ──
    Process {
        id: detectClaude
        command: ["bash", "-c", "(pgrep -x claude >/dev/null 2>&1 || pgrep -x agy >/dev/null 2>&1) && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.clActive = (this.text.trim() === "1") } }
    }

    Process {
        id: detectOpenCode
        command: ["bash", "-c", "ps -eo args | grep -E '(^|/| )opencode( |$)|opencode-ai' | grep -vE 'grep|opencode-usage' >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.ocActive = (this.text.trim() === "1") } }
    }
    Process {
        id: detectAgy
        command: ["bash", "-c", "pgrep -x agy >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.agActive = (this.text.trim() === "1") } }
    }
    Timer {
        interval: 5000; running: root.modClaude || root.aiUsageVisible; repeat: true; triggeredOnStart: true
        onTriggered: {
            detectClaude.running = false; detectClaude.running = true
            detectOpenCode.running = false; detectOpenCode.running = true
            detectAgy.running = false; detectAgy.running = true
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // icon with bottom-to-top usage fill. Claude keeps its nerd-font glyph;
        // Codex/OpenCode use vector marks themed via the shared logo tint shader.
        Item {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: rootMod.isOpenCode ? rootMod.ocMarkW
                : (rootMod.isAgy ? 16 : 15)
            implicitHeight: rootMod.isOpenCode ? rootMod.ocMarkH
                : (rootMod.isAgy ? 16 : 15)
            width: implicitWidth
            height: implicitHeight

            // ── Claude: nerd-font glyph (original look) ──
            Item {
                anchors.centerIn: parent
                visible: !rootMod.isLogo
                implicitWidth: glyphBase.implicitWidth
                implicitHeight: glyphBase.implicitHeight

                UiText {
                    id: glyphBase
                    text: String.fromCodePoint(0xF167A)
                    renderType: Text.QtRendering
                    color: Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.25)
                    font.family: root.mono
                    font.pixelSize: 14
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.25))
                        : 0
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    UiText {
                        anchors.bottom: parent.bottom
                        text: String.fromCodePoint(0xF167A)
                        renderType: Text.QtRendering
                        color: rootMod.contentColor
                        font.family: root.mono
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // ── Logo tools: tinted SVG ──
            Item {
                anchors.fill: parent
                visible: rootMod.isLogo

                Image {
                    id: codexBase
                    anchors.fill: parent
                    source: rootMod.logoSource
                    sourceSize: rootMod.logoSourceSize
                    fillMode: Image.PreserveAspectFit
                    smooth: !rootMod.isOpenCode
                    mipmap: !rootMod.isOpenCode
                    // thinner-stroked than the Claude glyph → needs more presence
                    // than the glyph's 0.25 faint base to stay recognizable
                    opacity: 0.5
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: ShaderEffect {
                        property color tintColor: rootMod.contentColor
                        fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                    }
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.22))
                        : 0
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Image {
                        width: iconItem.width; height: iconItem.height
                        anchors.bottom: parent.bottom
                        source: rootMod.logoSource
                        sourceSize: rootMod.logoSourceSize
                        fillMode: Image.PreserveAspectFit
                        smooth: !rootMod.isOpenCode
                        mipmap: !rootMod.isOpenCode
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: ShaderEffect {
                            property color tintColor: rootMod.contentColor
                            fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                        }
                    }
                }
            }
        }

        UiText {
            visible: !root.iconOnly("G7")
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.blocked
                ? "BLK"
                : (rootMod.selSignal ? String(rootMod.pct5h).padStart(2, "0") + "%" : "··")
            color: rootMod.contentColor
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: if (shown) { root.refreshAiUsage(); tip.show() }
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.aiUsageVisible = !root.aiUsageVisible }
    }
}
