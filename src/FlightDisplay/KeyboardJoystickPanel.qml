import QtQuick                  2.12
import QtQuick.Layouts          1.12
import QtQuick.Window           2.2

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.Palette   1.0
import QGroundControl.ScreenTools 1.0

FocusScope {
    id: panel

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool expanded: false
    property bool controlEnabled: false
    property real sensitivity: 0.6
    property real throttleRate: 0.35 // Full throttle travel per second
    property real throttle: 0
    // Updated only after a MANUAL_CONTROL sample has been handed to Vehicle.
    property double lastSentMs: 0
    property real requestedX: parent.width - width - 20
    property real requestedY: ScreenTools.defaultFontPixelHeight * 5
    property bool keyW: false
    property bool keyS: false
    property bool keyA: false
    property bool keyD: false
    property bool keyUp: false
    property bool keyDown: false
    property bool keyLeft: false
    property bool keyRight: false
    readonly property bool touchJoystickEnabled: QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
    readonly property bool windowActive: !!Window.window && Window.window.active
    readonly property bool canControl: !!vehicle && !vehicle.joystickEnabled &&
                                       !vehicle.vehicleLinkManager.communicationLost &&
                                       vehicle.joystickLinkReady() && !touchJoystickEnabled
    readonly property real yaw: ((keyD ? 1 : 0) - (keyA ? 1 : 0)) * sensitivity
    readonly property real roll: ((keyRight ? 1 : 0) - (keyLeft ? 1 : 0)) * sensitivity
    readonly property real pitch: ((keyUp ? 1 : 0) - (keyDown ? 1 : 0)) * sensitivity

    width: Math.max(0, Math.min(parent.width - 20, ScreenTools.defaultFontPixelWidth * 48))
    height: expanded ? content.implicitHeight + header.height + 16 : header.height
    x: Math.max(0, Math.min(Math.max(0, parent.width - width), isFinite(requestedX) ? requestedX : 0))
    y: Math.max(0, Math.min(Math.max(0, parent.height - height), isFinite(requestedY) ? requestedY : 0))
    z: QGroundControl.zOrderTopMost + 2
    visible: !QGroundControl.videoManager.fullScreen

    function clearKeys() {
        keyW = false; keyS = false; keyA = false; keyD = false
        keyUp = false; keyDown = false; keyLeft = false; keyRight = false
    }

    function stopControl() {
        controlEnabled = false
        clearKeys()
        throttle = 0
        lastSentMs = 0
    }

    function prepareForSourceSwitch() {
        if (!canControl || !windowActive || !visible) return false
        controlEnabled = true
        forceActiveFocus()
        // Focus delivery is asynchronous after a confirmation dialog closes.
        // The caller checks streamReady() after the first timer samples.
        return true
    }

    function streamReady() {
        return controlEnabled && activeFocus && canControl && vehicle.joystickLinkReady() && windowActive &&
               lastSentMs > 0 && Date.now() - lastSentMs < 200
    }

    function setKey(key, pressed) {
        switch (key) {
        case Qt.Key_W: keyW = pressed; return true
        case Qt.Key_S: keyS = pressed; return true
        case Qt.Key_A: keyA = pressed; return true
        case Qt.Key_D: keyD = pressed; return true
        case Qt.Key_Up: keyUp = pressed; return true
        case Qt.Key_Down: keyDown = pressed; return true
        case Qt.Key_Left: keyLeft = pressed; return true
        case Qt.Key_Right: keyRight = pressed; return true
        }
        return false
    }

    onVehicleChanged: stopControl()
    onCanControlChanged: if (!canControl) stopControl()
    onVisibleChanged: if (!visible) stopControl()
    onActiveFocusChanged: if (!activeFocus) stopControl()
    onWindowActiveChanged: if (!windowActive) stopControl()
    onControlEnabledChanged: {
        clearKeys()
        if (controlEnabled) {
            throttle = 0
            forceActiveFocus()
        }
    }

    Keys.onPressed: {
        if (controlEnabled && canControl && setKey(event.key, true)) {
            event.accepted = true
        }
    }
    Keys.onReleased: {
        if (controlEnabled && canControl && setKey(event.key, event.isAutoRepeat)) {
            event.accepted = true
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: panel.controlEnabled && panel.activeFocus && panel.windowActive && panel.visible && panel.canControl
        onTriggered: {
            if (!panel.vehicle || !panel.canControl || !panel.vehicle.joystickLinkReady()) {
                panel.stopControl()
                return
            }
            var direction = (panel.keyW ? 1 : 0) - (panel.keyS ? 1 : 0)
            panel.throttle = Math.max(0, Math.min(1, panel.throttle + direction * panel.throttleRate * interval / 1000))
            panel.vehicle.virtualTabletJoystickValue(panel.roll, panel.pitch, panel.yaw, panel.throttle)
            panel.lastSentMs = Date.now()
        }
    }

    QGCPalette { id: pal; colorGroupEnabled: true }

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: pal.window
        border.color: pal.text
        border.width: 1
        opacity: 0.93
    }

    Item {
        id: header
        width: parent.width
        height: ScreenTools.defaultFontPixelHeight * 2.8

        MouseArea {
            anchors.fill: parent
            property real grabX: 0
            property real grabY: 0
            onPressed: {
                grabX = mouse.x
                grabY = mouse.y
                panel.forceActiveFocus()
            }
            onPositionChanged: {
                if (pressed) {
                    var point = mapToItem(panel.parent, mouse.x, mouse.y)
                    panel.requestedX = point.x - grabX
                    panel.requestedY = point.y - grabY
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6
            QGCLabel { text: qsTr("Keyboard Joystick"); Layout.fillWidth: true }
            QGCLabel { text: panel.controlEnabled ? qsTr("ON") : qsTr("OFF") }
            QGCButton {
                text: panel.controlEnabled ? qsTr("Disable") : qsTr("Enable")
                enabled: panel.controlEnabled || panel.canControl
                onClicked: {
                    panel.controlEnabled = !panel.controlEnabled
                    if (panel.controlEnabled) panel.forceActiveFocus()
                }
            }
            QGCButton {
                text: panel.expanded ? "−" : "+"
                onClicked: panel.expanded = !panel.expanded
            }
        }
    }

    Column {
        id: content
        visible: panel.expanded
        x: 8
        y: header.height + 4
        width: parent.width - 16
        spacing: 5

        QGCLabel {
            text: !panel.vehicle ? qsTr("Connect a vehicle to enable") :
                  panel.vehicle.joystickEnabled ? qsTr("Physical joystick active") :
                  panel.touchJoystickEnabled ? qsTr("Disable touch joystick first") :
                  panel.activeFocus && panel.controlEnabled ? qsTr("Keyboard focus active") : qsTr("Click Enable to capture keys")
        }

        Row {
            spacing: 12

            Column {
                spacing: 4
                QGCLabel { text: qsTr("Left: W/S throttle, A/D yaw") }
                Rectangle {
                    width: 120; height: 120; radius: 60
                    color: pal.button; border.color: pal.text
                    Rectangle { width: 1; height: parent.height; x: parent.width / 2; color: pal.text; opacity: 0.4 }
                    Rectangle { height: 1; width: parent.width; y: parent.height / 2; color: pal.text; opacity: 0.4 }
                    Rectangle {
                        width: 18; height: 18; radius: 9; color: pal.primaryButton
                        x: (parent.width - width) / 2 + panel.yaw * (parent.width - width) / 2
                        y: (parent.height - height) * (1 - panel.throttle)
                    }
                }
                QGCLabel { text: qsTr("Yaw %1  Throttle %2").arg(panel.yaw.toFixed(2)).arg(panel.throttle.toFixed(2)) }
            }

            Column {
                spacing: 4
                QGCLabel { text: qsTr("Right: arrows pitch/roll") }
                Rectangle {
                    width: 120; height: 120; radius: 60
                    color: pal.button; border.color: pal.text
                    Rectangle { width: 1; height: parent.height; x: parent.width / 2; color: pal.text; opacity: 0.4 }
                    Rectangle { height: 1; width: parent.width; y: parent.height / 2; color: pal.text; opacity: 0.4 }
                    Rectangle {
                        width: 18; height: 18; radius: 9; color: pal.primaryButton
                        x: (parent.width - width) / 2 + panel.roll * (parent.width - width) / 2
                        y: (parent.height - height) / 2 - panel.pitch * (parent.height - height) / 2
                    }
                }
                QGCLabel { text: qsTr("Roll %1  Pitch %2").arg(panel.roll.toFixed(2)).arg(panel.pitch.toFixed(2)) }
            }
        }

        QGCLabel { text: qsTr("Sensitivity: %1").arg(panel.sensitivity.toFixed(2)) }
        Rectangle {
            width: content.width; height: 12; radius: 6; color: pal.button; border.color: pal.text
            Rectangle { width: 12; height: 12; radius: 6; color: pal.primaryButton; x: (parent.width - width) * (panel.sensitivity - 0.1) / 0.9 }
            MouseArea { anchors.fill: parent; onPressed: setFromPosition(mouse.x); onPositionChanged: if (pressed) setFromPosition(mouse.x)
                function setFromPosition(pos) { panel.sensitivity = Math.max(0.1, Math.min(1, 0.1 + 0.9 * pos / width)) }
            }
        }
        QGCLabel { text: qsTr("Throttle speed: %1 /s").arg(panel.throttleRate.toFixed(2)) }
        Rectangle {
            width: content.width; height: 12; radius: 6; color: pal.button; border.color: pal.text
            Rectangle { width: 12; height: 12; radius: 6; color: pal.primaryButton; x: (parent.width - width) * (panel.throttleRate - 0.1) / 0.9 }
            MouseArea { anchors.fill: parent; onPressed: setFromPosition(mouse.x); onPositionChanged: if (pressed) setFromPosition(mouse.x)
                function setFromPosition(pos) { panel.throttleRate = Math.max(0.1, Math.min(1, 0.1 + 0.9 * pos / width)) }
            }
        }
    }
}
