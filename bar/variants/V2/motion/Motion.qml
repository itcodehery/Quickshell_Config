pragma Singleton
import QtQuick

// Material 3 Expressive motion-physics tokens + shared "who is being touched" state.
//
// M3E replaces easing/duration with springs. Each token is (damping ratio, stiffness):
//   expressive spatial  fast (0.6, 800)  default (0.8, 380)  slow (0.8, 200)   <- bouncy, overshoots
//   expressive effects  fast (1, 3800)   default (1, 1600)   slow (1, 800)     <- no overshoot
// Qt's SpringAnimation uses its own (spring, damping) scale, so these are the M3E tokens
// translated into that scale: lower damping = more bounce, higher spring = snappier.
QtObject {
    // Spatial springs (position, size, scale, radius) - overshoot on purpose
    readonly property real spatialFastSpring: 6.5
    readonly property real spatialFastDamping: 0.20
    readonly property real spatialSpring: 4.2
    readonly property real spatialDamping: 0.24
    readonly property real spatialSlowSpring: 2.6
    readonly property real spatialSlowDamping: 0.28

    // Click-reaction springs: loose and bouncy (low spring = soft, low damping = wobbly)
    readonly property real pressSpring: 2.6
    readonly property real pressDamping: 0.11
    readonly property real pushSpring: 1.7
    readonly property real pushDamping: 0.09

    // Effects springs (color, opacity) - critically damped, no overshoot
    readonly property real effectsSpring: 9
    readonly property real effectsDamping: 0.9

    // Interaction state shared by every SpringPress so neighbours can react to a touch
    property var source: null        // the SpringPress currently pressed
    property real strength: 0        // 1 = pressed, 0 = idle
}
