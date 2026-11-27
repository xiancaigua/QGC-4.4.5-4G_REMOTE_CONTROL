import QtQuick                  2.12
import QtQuick.Layouts          1.12

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.Palette   1.0
import QGroundControl.ScreenTools 1.0

Item {
    id: panel

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var sourcePanel: null
    property bool expanded: false
    property real requestedX: parent.width - width - 20
    property real requestedY: sourcePanel ? sourcePanel.y + sourcePanel.height + 8 : ScreenTools.defaultFontPixelHeight * 11
    property bool commandPending: false
    property string resultText: qsTr("No command sent")
    property string commandName: ""
    readonly property bool linkReady: !!vehicle && vehicle.px4Firmware &&
                                       !vehicle.vehicleLinkManager.communicationLost
    readonly property int actuatorNumber: actuatorSelect.currentIndex + 1

    width: Math.max(0, Math.min(parent.width - 20, ScreenTools.defaultFontPixelWidth * 50))
    height: expanded ? header.height + content.implicitHeight + 16 : header.height
    x: Math.max(0, Math.min(Math.max(0, parent.width - width), requestedX))
    y: Math.max(0, Math.min(Math.max(0, parent.height - height), requestedY))
    z: QGroundControl.zOrderTopMost + 2
    visible: !QGroundControl.videoManager.fullScreen

    function parseActuatorValue(text) {
        if (!text || !text.trim().length) return NaN
        var value = Number(text)
        return isFinite(value) && value >= -1 && value <= 1 ? value : NaN
    }

    function sendValue(value, name) {
        if (!linkReady || commandPending || cooldown.running || !isFinite(value)) {
            resultText = qsTr("Command blocked: check link, range or pending ACK")
            return
        }
        if (!vehicle.sendPayloadActuator(actuatorNumber, value)) {
            resultText = qsTr("Vehicle rejected send request")
            return
        }
        commandName = qsTr("Actuator %1 %2").arg(actuatorNumber).arg(name)
        commandPending = true
        resultText = qsTr("%1 sent; awaiting MAVLink ACK").arg(commandName)
        ackTimeout.start()
    }

    function resetState(message) {
        commandPending = false
        ackTimeout.stop()
        resultText = message
    }

    onVehicleChanged: resetState(qsTr("Vehicle changed; command state cleared"))
    onLinkReadyChanged: if (!linkReady) resetState(qsTr("Vehicle link lost"))

    Connections {
        target: panel.vehicle
        onMavCommandResult: {
            if (command !== 187 || !panel.commandPending || !panel.vehicle ||
                    vehicleId !== panel.vehicle.id) return
            panel.commandPending = false
            ackTimeout.stop()
            cooldown.start()
            panel.resultText = failureCode === 0 && ackResult === 0 ?
                    qsTr("%1 ACK accepted; servo position not confirmed").arg(panel.commandName) :
                    qsTr("%1 failed (ACK %2, failure %3)").arg(panel.commandName).arg(ackResult).arg(failureCode)
        }
    }

    Timer { id: cooldown; interval: 750 }
    Timer {
        id: ackTimeout
        interval: 15000
        onTriggered: {
            panel.commandPending = false
            panel.resultText = qsTr("ACK timeout; output state unknown")
            cooldown.start()
        }
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
            QGCLabel { text: qsTr("Payload Control"); Layout.fillWidth: true }
            QGCLabel { text: panel.linkReady ? qsTr("LINK") : qsTr("OFFLINE") }
            QGCButton { text: panel.expanded ? "−" : "+"; onClicked: panel.expanded = !panel.expanded }
        }
    }

    Column {
        id: content
        visible: panel.expanded
        x: 8
        y: header.height + 4
        width: parent.width - 16
        spacing: 5

        QGCLabel { text: qsTr("PX4 Actuator Set 1 output") }
        Row {
            spacing: 8
            QGCLabel { text: qsTr("Actuator") }
            QGCComboBox {
                id: actuatorSelect
                model: [1, 2, 3, 4, 5, 6]
                enabled: !panel.commandPending && !cooldown.running
                onActivated: {
                    openValue.text = ""
                    closeValue.text = ""
                    customValue.text = ""
                }
            }
        }
        QGCLabel { text: qsTr("Configure normalized positions [-1, 1] for this servo before use."); width: parent.width; wrapMode: Text.Wrap }
        Row {
            spacing: 5
            QGCLabel { text: qsTr("OPEN") }
            QGCTextField { id: openValue; width: ScreenTools.defaultFontPixelWidth * 8; placeholderText: qsTr("value") }
            QGCButton {
                text: qsTr("Send OPEN")
                enabled: panel.linkReady && !panel.commandPending && !cooldown.running &&
                         isFinite(panel.parseActuatorValue(openValue.text))
                onClicked: panel.sendValue(panel.parseActuatorValue(openValue.text), qsTr("OPEN"))
            }
        }
        Row {
            spacing: 5
            QGCLabel { text: qsTr("CLOSE") }
            QGCTextField { id: closeValue; width: ScreenTools.defaultFontPixelWidth * 8; placeholderText: qsTr("value") }
            QGCButton {
                text: qsTr("Send CLOSE")
                enabled: panel.linkReady && !panel.commandPending && !cooldown.running &&
                         isFinite(panel.parseActuatorValue(closeValue.text))
                onClicked: panel.sendValue(panel.parseActuatorValue(closeValue.text), qsTr("CLOSE"))
            }
        }
        Row {
            spacing: 5
            QGCLabel { text: qsTr("Custom") }
            QGCTextField { id: customValue; width: ScreenTools.defaultFontPixelWidth * 8; placeholderText: qsTr("value") }
            QGCButton {
                text: qsTr("Send")
                enabled: panel.linkReady && !panel.commandPending && !cooldown.running &&
                         isFinite(panel.parseActuatorValue(customValue.text))
                onClicked: panel.sendValue(panel.parseActuatorValue(customValue.text), qsTr("Custom"))
            }
        }
        QGCLabel { text: panel.resultText; width: parent.width; wrapMode: Text.Wrap }
        QGCLabel { text: qsTr("MAVLink ACK does not prove mechanical travel. Test without propellers."); width: parent.width; wrapMode: Text.Wrap }
    }
}
