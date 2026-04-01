import qs.modules.ii.sidebarLeft.assistant
import QtQuick

/**
 * Assistant.qml — thin shim; delegates everything to AssistantPanel.
 * Keeps the existing SidebarLeftContent interface:
 *   - property inputField
 *   - function receiveEvent(event, payload)
 *   - onFocusChanged
 */
Item {
    id: root
    anchors.fill: parent
    property var inputField: panel.inputField

    onFocusChanged: focus => { if (focus) panel.inputField.forceActiveFocus() }

    function receiveEvent(event, payload) {
        panel.receiveEvent(event, payload)
    }

    AssistantPanel {
        id: panel
        anchors.fill: parent
    }
}
