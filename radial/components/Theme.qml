pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: theme

    // Colors
    property color background: Qt.rgba(0.176, 0.207, 0.231, 0.75) // #2d353b with 75% opacity
    property color foreground: "#d3c6aa"
    property color accent: "#7fbbb3"
    property color lighterBg: Qt.rgba(0.204, 0.247, 0.267, 0.85) // #343f44 with 85% opacity
    property color darkBg: Qt.rgba(0.13, 0.153, 0.173, 0.6) // #21272c with 60% opacity
    property color selection: "#3d484d"
    property color muted: "#475258"
    property color scrim: Qt.rgba(0, 0, 0, 0.4) // Dim scrim

    // Geometry/Animation constants
    property real cardWidth: 120
    property real cardHeight: 75
    property real cardRadius: 8
    property real cardDist: 140
    property int animDurationOpen: 350
    property int animDurationClose: 150
    property int animDurationHover: 200

    function withAlpha(colorStr, alpha) {
        let c = Qt.color(colorStr);
        c.a = alpha;
        return c;
    }

    property var fileView: FileView {
        path: "/home/hery/.local/state/omarchy/current/theme/colors.toml"
        watchChanges: true
        onLoaded: {
            let lines = text().split('\n');
            let colors = {};
            for (let i = 0; i < lines.length; i++) {
                let m = lines[i].match(/([a-z0-9_]+)\s*=\s*"([^"]+)"/);
                if (m) {
                    colors[m[1]] = m[2];
                }
            }
            
            let bg = colors["background"] || colors["color0"] || "#2d353b";
            theme.background = theme.withAlpha(bg, 0.75);
            theme.foreground = colors["foreground"] || colors["color7"] || "#d3c6aa";
            theme.accent = colors["accent"] || colors["color4"] || "#7fbbb3";
            theme.selection = colors["selection"] || colors["color8"] || theme.accent;
            theme.muted = colors["muted"] || colors["color8"] || theme.foreground;
            
            let dbg = colors["dark_background"] || bg;
            theme.darkBg = theme.withAlpha(dbg, 0.60);
            
            let lbg = colors["lighter_background"] || colors["selection"] || colors["color8"] || bg;
            theme.lighterBg = theme.withAlpha(lbg, 0.85);
        }
    }
}
