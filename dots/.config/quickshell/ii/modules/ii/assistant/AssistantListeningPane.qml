pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    property bool listening: false
    property bool processing: false
    property string transcript: ""
    property string transcriptMode: ""
    property int countdown: 0
    property int wordCount: 0

    signal sendRequested()
    signal editRequested()
    signal cancelRequested()
    signal undoRequested()

    Layout.fillWidth: true
    spacing: 10
    implicitWidth: 500
    implicitHeight: transcriptPreview.implicitHeight + visualizer.implicitHeight + 12

    AssistantTranscriptPreview {
        id: transcriptPreview
        Layout.fillWidth: true
        transcript: root.transcript
        transcriptMode: root.transcriptMode
        transcriptCountdown: root.countdown
        wordCount: root.wordCount
        listening: root.listening
        processing: root.processing
        onSendRequested: root.sendRequested()
        onEditRequested: root.editRequested()
        onCancelRequested: root.cancelRequested()
        onUndoRequested: root.undoRequested()
    }

    AssistantListeningVisualizer {
        id: visualizer
        Layout.alignment: Qt.AlignHCenter
        listening: root.listening
        processing: root.processing
    }
}
