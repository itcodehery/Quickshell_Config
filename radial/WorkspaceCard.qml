import QtQuick
import QtQuick.Window
import Quickshell

Item {
    id: root

    property int index
    property int wsId
    property bool isEmpty: false
    property var clientsData: []
    property bool isActive: false
    property bool isHovered: false
    property bool isOpen: false

    property real centerAngleDeg
    property real targetDistFromCenter: Theme.cardDist
    property real distFromCenter: isOpen ? targetDistFromCenter : 0

    Behavior on distFromCenter { 
        NumberAnimation { 
            duration: Theme.animDurationOpen 
            easing.type: Easing.OutBack 
        } 
    }
    
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDurationOpen
            easing.type: Easing.OutCubic
        }
    }

    opacity: isOpen ? 1 : 0

    width: Theme.cardWidth
    height: Theme.cardHeight
    
    // Position the card
    property real centerAngleRad: centerAngleDeg * Math.PI / 180
    x: distFromCenter * Math.cos(centerAngleRad) - width / 2
    y: distFromCenter * Math.sin(centerAngleRad) - height / 2

    // Card styling
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Theme.cardRadius
        
        color: root.isActive ? Theme.lighterBg : (root.isHovered ? Theme.background : Theme.darkBg)
        border.color: root.isActive ? Theme.accent : (root.isHovered ? Theme.accent : (root.isEmpty ? Theme.muted : Theme.selection))
        border.width: root.isActive || root.isHovered ? 1 : (root.isEmpty ? 1 : 1)
        
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.margins: -2
            anchors.verticalCenterOffset: 3
            radius: Theme.cardRadius + 2
            color: Theme.withAlpha("#000000", 0.3)
            visible: true
        }

        scale: root.isHovered ? 1.04 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animDurationHover; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cardRadius
            color: "transparent"
            border.color: Theme.accent
            border.width: root.isActive ? 2 : 0
            opacity: root.isActive ? 0.3 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.animDurationHover } }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cardRadius
            opacity: root.isHovered ? 0.4 : (root.isActive ? 0.2 : 0.0)
            Behavior on opacity { NumberAnimation { duration: Theme.animDurationHover; easing.type: Easing.OutCubic } }
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.accent }
            }
        }
        
        Text {
            visible: root.isEmpty
            text: "+"
            anchors.centerIn: parent
            color: Theme.muted
            font.pixelSize: 36
            font.family: "DM Sans"
            font.bold: true
            opacity: root.isHovered ? 1.0 : 0.5
        }
        
        Item {
            visible: !root.isEmpty
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            height: 14
            
            Text {
                text: {
                    if (root.isEmpty) return "";
                    if (root.clientsData.length === 0) return "Empty";
                    let first = root.clientsData[0].class || root.clientsData[0].title || "Unknown";
                    first = first.charAt(0).toUpperCase() + first.slice(1);
                    if (root.clientsData.length === 1) return first;
                    return first + " & " + (root.clientsData.length - 1) + " other" + (root.clientsData.length > 2 ? "s" : "");
                }
                anchors.left: parent.left
                anchors.right: iconImg.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: root.isActive ? Theme.accent : Theme.foreground
                font.pixelSize: 10
                font.family: "DM Sans"
                font.letterSpacing: 0.5
                font.bold: true
                elide: Text.ElideRight
                opacity: 0.8
            }
            
            Image {
                id: iconImg
                property string resolvedIcon: {
                    if (root.isEmpty || root.clientsData.length === 0) return "";
                    let cls = root.clientsData[0].class || "";
                    let initCls = root.clientsData[0].initialClass || "";
                    
                    let fallback = "application-x-executable";
                    let name = cls.toLowerCase();
                    if (name.includes("zen-alpha") || name === "zen") return Quickshell.iconPath("zen-browser", fallback);
                    if (name.includes("chrome") || name.includes("brave")) return Quickshell.iconPath("google-chrome", fallback);
                    
                    if (typeof DesktopEntries !== "undefined") {
                        let entry = DesktopEntries.heuristicLookup(cls) || DesktopEntries.heuristicLookup(initCls);
                        if (entry && entry.icon) {
                            let p = Quickshell.iconPath(entry.icon);
                            if (p) return p;
                        }
                    }
                    return Quickshell.iconPath(cls.toLowerCase(), fallback);
                }
                
                visible: resolvedIcon !== ""
                source: resolvedIcon
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 14
                sourceSize.height: 14
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        Item {
            visible: !root.isEmpty && root.clientsData.length > 0
            anchors.top: parent.top
            anchors.topMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            
            property real logicalWidth: Screen.width
            property real logicalHeight: Screen.height
            
            Repeater {
                model: root.clientsData
                
                Rectangle {
                    x: (modelData.at[0] / parent.logicalWidth) * parent.width
                    y: (modelData.at[1] / parent.logicalHeight) * parent.height
                    width: Math.max((modelData.size[0] / parent.logicalWidth) * parent.width, 2)
                    height: Math.max((modelData.size[1] / parent.logicalHeight) * parent.height, 2)
                    
                    color: Theme.lighterBg
                    border.color: Theme.muted
                    border.width: 1
                    radius: 2
                    
                    Image {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 4, 12)
                        height: Math.min(parent.height - 4, 12)
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 12
                        sourceSize.height: 12
                        visible: width >= 8 && height >= 8
                        source: {
                            let cls = modelData.class || "";
                            let fallback = "application-x-executable";
                            let name = cls.toLowerCase();
                            if (name.includes("zen-alpha") || name === "zen") return Quickshell.iconPath("zen-browser", fallback);
                            if (name.includes("chrome") || name.includes("brave")) return Quickshell.iconPath("google-chrome", fallback);
                            
                            if (typeof DesktopEntries !== "undefined") {
                                let entry = DesktopEntries.heuristicLookup(cls);
                                if (entry && entry.icon) {
                                    let p = Quickshell.iconPath(entry.icon);
                                    if (p) return p;
                                }
                            }
                            return Quickshell.iconPath(cls.toLowerCase(), fallback);
                        }
                    }
                }
            }
        }
    }
}
