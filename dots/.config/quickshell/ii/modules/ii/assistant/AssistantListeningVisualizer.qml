pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    property bool listening: false
    property bool processing: false

    implicitWidth: 240
    implicitHeight: 180

    Repeater {
        model: 3
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: 76 + index * 32
            height: width
            radius: width / 2
            border.width: 1
            border.color: Qt.rgba(
                Appearance.colors.colPrimary.r,
                Appearance.colors.colPrimary.g,
                Appearance.colors.colPrimary.b,
                0.2 + index * 0.1
            )
            color: Qt.rgba(
                Appearance.colors.colPrimary.r,
                Appearance.colors.colPrimary.g,
                Appearance.colors.colPrimary.b,
                0.06
            )
            opacity: root.listening || root.processing ? 1 : 0.5
            scale: 0.9 + index * 0.06

            SequentialAnimation on scale {
                running: root.listening || root.processing
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1.08 + index * 0.03
                    duration: 1000 + index * 140
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    to: 0.9 + index * 0.06
                    duration: 1000 + index * 140
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 96
        height: 96
        radius: 48
        color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            root.listening || root.processing ? 0.18 : 0.10
        )
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            0.28
        )

        Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: Appearance.colors.colPrimary
        }
    }
}
