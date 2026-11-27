import QtQuick                  2.12
import QtQuick.Layouts          1.12
import QtQuick.Dialogs          1.3

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.Palette   1.0
import QGroundControl.ScreenTools 1.0

Item {
    id: panel

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var keyboardPanel: null
    property bool expanded: false
    property real requestedX: parent.width - width - 20
    property real requestedY: keyboardPanel ? keyboardPanel.y + keyboardPanel.height + 8 : ScreenTools.defaultFontPixelHeight * 8
    property var modeFact: vehicle && vehicle.parameterManager.parametersReady &&
                           vehicle.parameterManager.parameterExists(-1, "COM_RC_IN_MODE") ?
                           vehicle.parameterManager.getParameter(-1, "COM_RC_IN_MODE") : null
    property int pendingMode: -1
    property int observedMode: -1
    property bool awaitingReadback: false
    property string status: qsTr("No switch requested")

    readonly property bool linkReady: !!vehicle && vehicle.px4Firmware &&
                                       !vehicle.vehicleLinkManager.communicationLost
    // Ground trial only until source handoff has been validated in SITL and on a bench.
    readonly property bool switchReady: linkReady && !vehicle.armed
    readonly property bool rcReported: linkReady && vehicle.rcRSSI > 0 && vehicle.rcRSSI < 255
    readonly property int selectedMode: observedMode

    width: Math.max(0, Math.min(parent.width - 20, ScreenTools.defaultFontPixelWidth * 52))
    height: expanded ? header.height + contentViewport.height + 12 : header.height
    x: Math.max(0, Math.min(Math.max(0, parent.width - width), requestedX))
    y: Math.max(0, Math.min(Math.max(0, parent.height - height), requestedY))
    z: QGroundControl.zOrderTopMost + 2
    visible: !QGroundControl.videoManager.fullScreen

    function sourceName(mode) {
        if (mode === 0) return qsTr("RC only")
        if (mode === 1) return qsTr("4G / MAVLink only")
        if (mode >= 2) return qsTr("Other mode (%1)").arg(mode)
        return qsTr("Unknown")
    }

    function cancelSwitch(message) {
        pendingMode = -1
        awaitingReadback = false
        prepareTimer.stop()
        readbackTimer.stop()
        timeoutTimer.stop()
        status = message
    }

    function beginSwitch(mode) {
        if (pendingMode !== -1 || !switchReady || !modeFact) {
            status = qsTr("Switch blocked: check link, parameter and disarmed state")
            return
        }
        if (selectedMode === mode) {
            status = qsTr("Parameter already selects %1; actual input unverified").arg(sourceName(mode))
            return
        }
        if (mode === 0) {
            if (!rcReported) {
                status = qsTr("RC signal not reported; switch blocked")
                return
            }
            writeMode(0)
        } else {
            if (!keyboardPanel || !keyboardPanel.prepareForSourceSwitch()) {
                status = qsTr("Keyboard stream could not start")
                return
            }
            status = qsTr("Waiting for keyboard MANUAL_CONTROL stream")
            prepareTimer.start()
        }
    }

    function writeMode(mode) {
        if (!switchReady || !modeFact) {
            cancelSwitch(qsTr("Switch stopped: link, parameter or disarmed state changed"))
            return
        }
        pendingMode = mode
        awaitingReadback = false
        status = qsTr("Writing COM_RC_IN_MODE=%1").arg(mode)
        modeFact.rawValue = mode
        readbackTimer.start()
        timeoutTimer.start()
    }

    onVehicleChanged: {
        observedMode = -1
        cancelSwitch(qsTr("Vehicle changed; switch state cleared"))
    }
    onModeFactChanged: if (modeFact && pendingMode < 0) observedMode = Number(modeFact.rawValue)
    onLinkReadyChanged: if (!linkReady) cancelSwitch(qsTr("Link lost; switch result unknown"))
    onSwitchReadyChanged: if (!switchReady && pendingMode >= 0) cancelSwitch(qsTr("Vehicle armed or link changed; switch result unknown"))
    onExpandedChanged: if (expanded && linkReady && vehicle.parameterManager.parametersReady) {
        var names = ["COM_RC_IN_MODE", "COM_DL_LOSS_T", "NAV_DLL_ACT", "COM_FAIL_ACT_T",
                     "COM_DLL_EXCEPT", "COM_RC_LOSS_T", "NAV_RCL_ACT", "COM_RCL_EXCEPT"]
        for (var i = 0; i < names.length; ++i)
            if (vehicle.parameterManager.parameterExists(-1, names[i]))
                vehicle.parameterManager.refreshParameter(-1, names[i])
    }

    Timer {
        id: prepareTimer
        interval: 250
        onTriggered: {
            if (!panel.keyboardPanel || !panel.keyboardPanel.streamReady()) {
                panel.cancelSwitch(qsTr("No recent keyboard sample; switch blocked"))
                return
            }
            panel.writeMode(1)
        }
    }

    Timer {
        id: readbackTimer
        interval: 500
        repeat: true
        onTriggered: {
            if (panel.pendingMode < 0 || !panel.linkReady) {
                stop()
            } else if (!panel.vehicle.parameterManager.pendingWrites) {
                panel.awaitingReadback = true
                panel.vehicle.parameterManager.refreshParameter(-1, "COM_RC_IN_MODE")
                stop()
            }
        }
    }

    Timer {
        id: timeoutTimer
        interval: 6000
        onTriggered: panel.cancelSwitch(qsTr("No parameter readback; actual source unknown"))
    }

    Connections {
        target: panel.vehicle ? panel.vehicle.parameterManager : null
        onParameterValueReceived: {
            if (name !== "COM_RC_IN_MODE" || !panel.modeFact ||
                    componentId !== panel.modeFact.componentId) return
            panel.observedMode = Number(value)
            if (!panel.awaitingReadback || panel.pendingMode < 0) return
            var requested = panel.pendingMode
            panel.cancelSwitch(Number(value) === requested ?
                    qsTr("Parameter read back: %1. Active input still unverified").arg(panel.sourceName(requested)) :
                    qsTr("Readback differs; switch failed or was overridden"))
            if (requested === 0 && Number(value) === 0 && panel.keyboardPanel)
                panel.keyboardPanel.stopControl()
        }
    }

    MessageDialog {
        id: rcTo4gConfirm
        title: qsTr("Transfer control to 4G")
        text: qsTr("RC signal is present. Confirm the RC operator agrees to transfer control. PX4 will ignore RC sticks while COM_RC_IN_MODE=1. Continue?")
        standardButtons: StandardButton.Yes | StandardButton.No
        onYes: panel.beginSwitch(1)
    }

    QGCPalette { id: pal; colorGroupEnabled: true }
    Rectangle {
        anchors.fill: parent
        radius: 5
        color: pal.window
        border.color: pal.text
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
            onPressed: { grabX = mouse.x; grabY = mouse.y }
            onPositionChanged: if (pressed) {
                var point = mapToItem(panel.parent, mouse.x, mouse.y)
                panel.requestedX = point.x - grabX
                panel.requestedY = point.y - grabY
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            QGCLabel { text: qsTr("Flight Control Source"); Layout.fillWidth: true }
            QGCLabel { text: panel.pendingMode >= 0 ? qsTr("Switching") : panel.sourceName(panel.selectedMode) }
            QGCButton { text: panel.expanded ? "−" : "+"; onClicked: panel.expanded = !panel.expanded }
        }
    }

    Flickable {
        id: contentViewport
        visible: panel.expanded
        x: 8
        y: header.height + 4
        width: parent.width - 16
        height: Math.min(content.implicitHeight, ScreenTools.defaultFontPixelHeight * 18)
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

      Column {
        id: content
        width: contentViewport.width
        spacing: 4

        QGCLabel { text: qsTr("RC signal: %1").arg(panel.rcReported ? qsTr("reported (%1%)").arg(panel.vehicle.rcRSSI) : qsTr("invalid or unknown")) }
        QGCLabel { text: qsTr("MAVLink: %1").arg(panel.linkReady ? qsTr("connected") : qsTr("unavailable")) }
        QGCLabel { text: qsTr("Keyboard stream: %1").arg(panel.keyboardPanel && panel.keyboardPanel.streamReady() ? qsTr("recent samples") : qsTr("not ready")) }
        QGCLabel { text: qsTr("Source switching is limited to disarmed ground trials."); width: parent.width; wrapMode: Text.Wrap }
        Row {
            spacing: 6
            QGCButton {
                text: qsTr("RC Control")
                enabled: panel.switchReady && !!panel.modeFact && panel.pendingMode < 0 && panel.rcReported
                onClicked: panel.beginSwitch(0)
            }
            QGCButton {
                text: qsTr("4G Control")
                enabled: panel.switchReady && !!panel.modeFact && panel.pendingMode < 0 && panel.keyboardPanel && panel.keyboardPanel.canControl
                onClicked: panel.rcReported ? rcTo4gConfirm.open() : panel.beginSwitch(1)
            }
        }
        QGCLabel { text: qsTr("Last FC-reported COM_RC_IN_MODE: %1").arg(panel.selectedMode); wrapMode: Text.Wrap; width: parent.width }
        QGCLabel { text: panel.status; wrapMode: Text.Wrap; width: parent.width }
        QGCLabel {
            text: qsTr("Source selection is not active-stick feedback. Verify in SITL or on a propeller-free bench.")
            wrapMode: Text.Wrap; width: parent.width
        }

        Rectangle { width: parent.width; height: 1; color: pal.text; opacity: 0.5 }
        QGCLabel { text: qsTr("4G Link Failsafe Status") }
        QGCLabel { text: qsTr("GCS heartbeat at PX4: not exposed by standard QGC telemetry"); wrapMode: Text.Wrap; width: parent.width }
        QGCLabel { text: qsTr("HyperLTE-only outage: cannot distinguish if another GCS heartbeat remains"); wrapMode: Text.Wrap; width: parent.width }
        QGCLabel { text: qsTr("COM_DL_LOSS_T: %1 s").arg(panel.parameterValue("COM_DL_LOSS_T")) }
        QGCLabel { text: qsTr("NAV_DLL_ACT: %1 (%2)").arg(panel.parameterValue("NAV_DLL_ACT")).arg(isNaN(panel.parameterNumber("NAV_DLL_ACT")) ? qsTr("unknown") : panel.parameterNumber("NAV_DLL_ACT") === 2 ? qsTr("Return") : qsTr("not Return")) }
        QGCLabel { text: qsTr("COM_FAIL_ACT_T: %1 s").arg(panel.parameterValue("COM_FAIL_ACT_T")) }
        QGCLabel { text: qsTr("COM_DLL_EXCEPT: %1").arg(panel.parameterValue("COM_DLL_EXCEPT")) }
        QGCLabel { text: qsTr("Data-link exception in current mode: %1").arg(panel.exceptionStatus("COM_DLL_EXCEPT")); width: parent.width; wrapMode: Text.Wrap }
        QGCLabel { text: qsTr("COM_RC_LOSS_T: %1 s").arg(panel.parameterValue("COM_RC_LOSS_T")) }
        QGCLabel { text: qsTr("NAV_RCL_ACT: %1").arg(panel.parameterValue("NAV_RCL_ACT")) }
        QGCLabel { text: qsTr("COM_RCL_EXCEPT: %1").arg(panel.parameterValue("COM_RCL_EXCEPT")) }
        QGCLabel { text: qsTr("Manual-input exception in current mode: %1").arg(panel.exceptionStatus("COM_RCL_EXCEPT")); width: parent.width; wrapMode: Text.Wrap }
        QGCLabel { text: qsTr("Exception masks: inspect in Vehicle Setup; this panel does not change failsafe parameters."); wrapMode: Text.Wrap; width: parent.width }
      }
    }

    function parameterNumber(name) {
        if (!vehicle || !vehicle.parameterManager.parametersReady ||
                !vehicle.parameterManager.parameterExists(-1, name)) return NaN
        return Number(vehicle.parameterManager.getParameter(-1, name).rawValue)
    }
    function parameterValue(name) {
        var value = parameterNumber(name)
        return isNaN(value) ? qsTr("unavailable") : value
    }
    function exceptionStatus(name) {
        var mask = parameterNumber(name)
        if (isNaN(mask) || !vehicle) return qsTr("unknown / parameter unavailable")
        var mode = String(vehicle.flightMode).toLowerCase()
        var bit = mode.indexOf("mission") >= 0 ? 0 :
                  mode.indexOf("hold") >= 0 ? 1 :
                  mode.indexOf("offboard") >= 0 ? 2 : -1
        if (bit < 0) return qsTr("no listed exception for %1").arg(vehicle.flightMode)
        return (mask & (1 << bit)) ? qsTr("YES, masked in %1").arg(vehicle.flightMode) :
                                    qsTr("not masked in %1").arg(vehicle.flightMode)
    }
}
