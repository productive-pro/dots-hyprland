import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// AssistantStatus.qml — floating status pill
Item {
    id: root
    property bool listening:  false
    property bool processing: false

    implicitWidth:  col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 4

        // ── Listening / Thinking pill ──────────────────────────────────────
        Rectangle {
            visible: root.listening || root.processing
            Layout.alignment: Qt.AlignHCenter
            implicitWidth:  pillRow.implicitWidth + 20
            implicitHeight: pillRow.implicitHeight + 8
            radius: height / 2
            color: Appearance.colors.colLayer2

            RowLayout {
                id: pillRow
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: root.listening ? "mic" : "psychology"
                    iconSize: 14
                    color: root.listening
                        ? Appearance.colors.colRed
                        : Appearance.colors.colYellow

                    SequentialAnimation on opacity {
                        running: root.listening || root.processing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }

                StyledText {
                    text: root.listening ? "Listening…" : "Thinking…"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
