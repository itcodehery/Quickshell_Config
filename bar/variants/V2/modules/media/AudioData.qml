import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Default-sink volume / mute, read natively from PipeWire with a wpctl fallback
// when Pipewire.defaultAudioSink is unavailable or not yet ready.
Item {
    id: audio

    property bool poll:     false
    property int  interval: 2000

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool pwReady: !!(sink && sink.ready && sink.audio && !isNaN(sink.audio.volume))

    property int _wpctlVolume: 0
    property bool _wpctlMuted: false

    readonly property int volume: pwReady ? Math.round(sink.audio.volume * 100) : _wpctlVolume
    readonly property bool muted: pwReady ? sink.audio.muted : _wpctlMuted

    PwObjectTracker { objects: audio.sink ? [audio.sink] : [] }

    Process {
        id: wpctlReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = String(this.text || "").trim()
                var m = txt.match(/Volume:\s*([0-9]+(?:\.[0-9]+)?)/)
                if (m) {
                    audio._wpctlVolume = Math.max(0, Math.min(100, Math.round(parseFloat(m[1]) * 100)))
                }
                audio._wpctlMuted = txt.indexOf("[MUTED]") >= 0
            }
        }
    }

    function refresh() {
        if (!wpctlReadProc.running) {
            wpctlReadProc.running = true
        }
    }

    function setVolume(pct) {
        var clamped = Math.max(0, Math.min(100, Math.round(pct)))
        _wpctlVolume = clamped
        if (pwReady) {
            sink.audio.volume = clamped / 100.0
        }
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped + "%"])
    }

    Timer {
        interval: 2000
        repeat: true
        running: !audio.pwReady
        triggeredOnStart: true
        onTriggered: audio.refresh()
    }

    Component.onCompleted: refresh()
}
