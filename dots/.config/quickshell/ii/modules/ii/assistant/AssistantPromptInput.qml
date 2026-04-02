pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

    implicitHeight: input.implicitHeight
    implicitWidth: input.implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    TextArea {
        id: input
        anchors.fill: parent
        anchors.margins: 10
        text: root.text
        placeholderText: root.placeholderText
        background: Item {}
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        font.family: Appearance.font.family.reading
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnLayer1
        onTextChanged: root.text = text
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.escapeRequested()
                event.accepted = true
                return
            }
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
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
