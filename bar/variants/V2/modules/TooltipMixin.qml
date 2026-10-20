import QtQuick

// Shared hover-tooltip controller. Encapsulates the 320ms hover delay plus the
// show/hide calls that every bar widget previously duplicated (~10 lines each).
// Each widget keeps its own MouseArea (click/wheel logic differs) and just calls
// tip.show() / tip.hide(); show() is a no-op while `text` is empty.
Item {
    id: mixin
    required property var root      // Theme — provides showTooltip()/hideTooltip()
    required property var owner     // the widget Item: anchor + tooltip owner key
    property string text: ""
    property int    delay: 320

    function show() { /* Hover tooltips disabled per user request */ }
    function hide() { delayTimer.stop(); if (root && root.hideTooltip) root.hideTooltip(owner) }

    // live-update the visible tooltip while THIS widget owns it (e.g. volume %
    // changing under the cursor) — showTooltip() only captures a snapshot.
    onTextChanged: if (root && root.tooltipOwner === owner) root.tooltipText = text

    Timer {
        id: delayTimer
        interval: mixin.delay
        running: false
    }
}
