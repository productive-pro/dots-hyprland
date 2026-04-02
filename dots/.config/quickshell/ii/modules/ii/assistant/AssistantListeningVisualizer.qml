pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool listening: false
    property bool processing: false

    implicitWidth: 320
    implicitHeight: 220

    Rectangle {
        anchors.centerIn: parent
        width: 228
        height: 228
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(
                    Appearance.colors.colPrimary.r,
                    Appearance.colors.colPrimary.g,
                    Appearance.colors.colPrimary.b,
                    root.listening || root.processing ? 0.10 : 0.05
                )
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
        opacity: 0.9
    }

    Repeater {
        model: 3
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: 104 + index * 44
            height: width
            radius: width / 2
            border.width: 1
            border.color: Qt.rgba(
                Appearance.colors.colPrimary.r,
                Appearance.colors.colPrimary.g,
                Appearance.colors.colPrimary.b,
                0.20 + index * 0.07
            )
            color: Qt.rgba(
                Appearance.colors.colPrimary.r,
                Appearance.colors.colPrimary.g,
                Appearance.colors.colPrimary.b,
                0.02 + index * 0.01
            )
            opacity: root.listening || root.processing ? 1 : 0.45
            scale: 0.84 + index * 0.08

            SequentialAnimation on scale {
                running: root.listening || root.processing
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1.03 + index * 0.05
                    duration: 1200 + index * 160
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    to: 0.84 + index * 0.08
                    duration: 1200 + index * 160
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 124
        height: 124
        radius: 62
        color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            root.listening || root.processing ? 0.20 : 0.10
        )
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            0.30
        )

        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: 16
            color: Appearance.colors.colPrimary
        }
    }

    StyledText {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 6
        }
        text: root.listening ? "Listening" : root.processing ? "Working" : "Idle"
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
    }
}
