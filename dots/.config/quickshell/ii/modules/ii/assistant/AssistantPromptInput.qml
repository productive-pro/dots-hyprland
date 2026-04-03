pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

FocusScope {
    id: root

    property string text: ""
    property string placeholderText: "Ask something"

    signal sendRequested(string text)
    signal escapeRequested()
    signal clearRequested()
    signal stopRequested()

    function focusInput() {
        input.forceActiveFocus()
    }

    implicitHeight: scrollView.implicitHeight
    implicitWidth: scrollView.implicitWidth

    // Whenever the FocusScope itself gains focus, forward it into the TextArea
    onActiveFocusChanged: {
        if (activeFocus)
            input.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: input.activeFocus
            ? Appearance.colors.colPrimary
            : Appearance.colors.colOutlineVariant
        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        // Allow the view to grow with content, capped by the parent
        implicitHeight: Math.min(root.parent ? root.parent.height * 3 / 5 : 200,
                                 input.implicitHeight + 20)
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        TextArea {
            id: input
            // Give Qt a proper focus chain entry point
            focus: true
            activeFocusOnPress: true
            selectByMouse: true
            persistentSelection: true

            wrapMode: TextEdit.Wrap
            padding: 10
            background: Item {}

            text: root.text
            placeholderText: root.placeholderText

            font.family: Appearance.font.family.reading
            font.pixelSize: Appearance.font.pixelSize.small
            color: activeFocus
                ? Appearance.m3colors.m3onSurface
                : Appearance.m3colors.m3onSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            onTextChanged: root.text = text

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.escapeRequested()
                    event.accepted = true
                    return
                }
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        && !(event.modifiers & Qt.ShiftModifier)) {
                    root.sendRequested(input.text)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                    root.clearRequested()
                    event.accepted = true
                }
            }
        }
    }
}
