import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property var tabButtonList: [
        {"icon": "record_voice_over", "name": Translation.tr("Assistant")},
        ...(root.aiChatEnabled     ? [{"icon": "neurology",  "name": Translation.tr("Intelligence")}] : []),
        ...(root.translatorEnabled ? [{"icon": "translate",  "name": Translation.tr("Translator")}]  : []),
    ]
    property int tabCount: tabButtonList.length

    function focusActiveItem() {
        pageStack.currentItem.forceActiveFocus()
    }

    function switchToAssistant() {
        pageStack.currentIndex = 0  // Assistant is always first
    }

    function relayAssistantEvent(event: string, payload: string): void {
        if (assistantPage && typeof assistantPage.receiveEvent === "function")
            assistantPage.receiveEvent(event, payload)
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                pageStack.currentIndex = Math.min(pageStack.count - 1, pageStack.currentIndex + 1)
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                pageStack.currentIndex = Math.max(0, pageStack.currentIndex - 1)
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Toolbar {
            visible: tabButtonList.length > 0
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                currentIndex: pageStack.currentIndex
                onCurrentIndexChanged: pageStack.currentIndex = currentIndex
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: pageStack.implicitWidth
            implicitHeight: pageStack.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            StackLayout { // Content pages
                id: pageStack
                anchors.fill: parent

                clip: true

                Assistant {
                    id: assistantPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                AiChat {
                    visible: root.aiChatEnabled
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                Translator {
                    visible: root.translatorEnabled
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
