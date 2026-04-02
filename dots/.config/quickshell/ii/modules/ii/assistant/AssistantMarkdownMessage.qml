pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

ColumnLayout {
    id: root

    property string content: ""
    property bool renderMarkdown: true
    property bool enableMouseSelection: true
    property bool userOnPrimary: false
    property var messageData: ({})

    spacing: 8
    Layout.fillWidth: true

    Repeater {
        model: StringUtils.splitMarkdownBlocks(root.content || "")

        delegate: Item {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData.type === "code" ? codeBlock.implicitHeight : textBlock.implicitHeight

            TextArea {
                id: textBlock
                visible: modelData.type !== "code"
                anchors.left: parent.left
                anchors.right: parent.right
                readOnly: true
                selectByMouse: root.enableMouseSelection
                wrapMode: TextEdit.Wrap
                textFormat: root.renderMarkdown ? TextEdit.MarkdownText : TextEdit.PlainText
                text: modelData.content
                background: Item {}
                padding: 0
                color: root.userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                font.family: Appearance.font.family.reading
                font.pixelSize: Appearance.font.pixelSize.small
                onLinkActivated: (link) => {
                    if (/^https?:\/\//.test(link) || /^mailto:/.test(link)) {
                        Qt.openUrlExternally(link)
                    }
                }
            }

            AssistantCodeBlock {
                id: codeBlock
                visible: modelData.type === "code"
                anchors.left: parent.left
                anchors.right: parent.right
                code: modelData.content
                language: modelData.lang || "txt"
                messageData: root.messageData
            }
        }
    }
}
