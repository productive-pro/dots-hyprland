pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

Item {
    id: root
    property real spacing: 20
    property real titleSpacing: 7
    property real padding: 20
    implicitWidth: Math.max(900, layoutColumn.implicitWidth + padding * 2)
    implicitHeight: Math.max(600, layoutColumn.implicitHeight + padding * 2)

    property bool showFullSchedule: false

    property string todayStr: {
        var d = new Date();
        var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
        return local.toISOString().split('T')[0];
    }
    
    FileView {
        id: scheduleFile
        path: Persistent.states.cheatsheet.schedulePath
        watchChanges: true
    }

    property var scheduleData: {
        if (!scheduleFile.data) return [];
        try {
            var fullData = JSON.parse(scheduleFile.data);
            var result = [];
            
            if (root.showFullSchedule) {
                // Get sorted dates
                var dates = Object.keys(fullData).sort();
                for (var i = 0; i < dates.length; i++) {
                    var date = dates[i];
                    var events = fullData[date];
                    for (var j = 0; j < events.length; j++) {
                        result.push({ isHeader: false, date: date, event: events[j] });
                    }
                }
            } else {
                var todayEvents = fullData[todayStr] || [];
                for (var j = 0; j < todayEvents.length; j++) {
                    result.push({ isHeader: false, date: todayStr, event: todayEvents[j] });
                }
            }
            return result;
        } catch(e) {
            return [];
        }
    }

    Process {
        id: filePickerProcess
        running: false
        command: ["bash", "-c", "zenity --file-selection --title='Select Schedule JSON' --file-filter='*.json'"]
        stdout: StdioCollector {
            id: pickerStdout
            onStreamFinished: {
                var selectedFile = pickerStdout.text.trim();
                if (selectedFile !== "") {
                    Persistent.states.cheatsheet.schedulePath = selectedFile;
                }
            }
        }
    }

    ColumnLayout {
        id: layoutColumn
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.spacing

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: "Schedule: " + (root.showFullSchedule ? "Full Week" : root.todayStr)
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnLayer0
                Layout.fillWidth: true
            }

            RippleButton {
                implicitWidth: 160
                implicitHeight: 40
                visible: Persistent.states.cheatsheet.schedulePath !== ""
                onClicked: {
                    root.showFullSchedule = !root.showFullSchedule;
                }
                contentItem: StyledText {
                    text: root.showFullSchedule ? "Show Today" : "Show Full Schedule"
                    anchors.centerIn: parent
                }
            }

            RippleButton {
                implicitWidth: 160
                implicitHeight: 40
                onClicked: {
                    filePickerProcess.running = true;
                }
                contentItem: StyledText {
                    text: Persistent.states.cheatsheet.schedulePath === "" ? "Load Schedule" : "Change Schedule"
                    anchors.centerIn: parent
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 0 // Reset spacing for table feel

                StyledText {
                    visible: Persistent.states.cheatsheet.schedulePath === ""
                    text: "No schedule.json loaded. Please select a file."
                    color: Appearance.colors.colOnLayer0
                    Layout.topMargin: 20
                }

                StyledText {
                    visible: Persistent.states.cheatsheet.schedulePath !== "" && scheduleFile.data === ""
                    text: "Loading schedule..."
                    color: Appearance.colors.colOnLayer0
                    Layout.topMargin: 20
                }

                StyledText {
                    visible: Persistent.states.cheatsheet.schedulePath !== "" && scheduleFile.data !== "" && root.scheduleData.length === 0
                    text: "No events to show."
                    color: Appearance.colors.colOnLayer0
                    Layout.topMargin: 20
                }

                // Table Header
                Rectangle {
                    visible: root.scheduleData.length > 0
                    Layout.fillWidth: true
                    height: 40
                    color: Appearance.colors.colLayer0
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 15

                        StyledText {
                            text: "DATE"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0Variant
                            font.bold: true
                            Layout.preferredWidth: 90
                            visible: root.showFullSchedule
                        }

                        StyledText {
                            text: "TIME"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0Variant
                            font.bold: true
                            Layout.preferredWidth: 60
                        }

                        StyledText {
                            text: "EVENT"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0Variant
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: "DURATION"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0Variant
                            font.bold: true
                            Layout.preferredWidth: 80
                        }

                        StyledText {
                            text: "CATEGORY"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0Variant
                            font.bold: true
                            Layout.preferredWidth: 100
                        }
                    }
                }

                // Separator Below Header
                Rectangle {
                    visible: root.scheduleData.length > 0
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.2) // brighter header separator
                }

                Repeater {
                    model: root.scheduleData
                    delegate: ColumnLayout {
                        width: parent.width
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            height: 45
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 15

                                StyledText {
                                    text: modelData.date
                                    font.pixelSize: Appearance.font.pixelSize.text
                                    color: Appearance.colors.colOnLayer0Variant
                                    Layout.preferredWidth: 90
                                    visible: root.showFullSchedule
                                }

                                StyledText {
                                    text: modelData.event[0] // Time
                                    font.pixelSize: Appearance.font.pixelSize.text
                                    color: Appearance.colors.colTheme
                                    font.bold: true
                                    Layout.preferredWidth: 60
                                }

                                StyledText {
                                    text: modelData.event[2] // Name
                                    font.pixelSize: Appearance.font.pixelSize.text
                                    color: Appearance.colors.colOnLayer0
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: modelData.event[1] + " mins" // Duration
                                    font.pixelSize: Appearance.font.pixelSize.text
                                    color: Appearance.colors.colOnLayer0Variant
                                    Layout.preferredWidth: 80
                                }

                                Rectangle {
                                    Layout.preferredWidth: Math.max(80, categoryText.implicitWidth + 20)
                                    height: 24
                                    radius: 12
                                    color: Appearance.colors.colLayer1
                                    border.color: Qt.rgba(1, 1, 1, 0.1)
                                    border.width: 1
                                    
                                    StyledText {
                                        id: categoryText
                                        anchors.centerIn: parent
                                        text: modelData.event[3] // Category
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer1
                                    }
                                }
                            }
                        }

                        // Row separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.05) // light gray/faint line
                        }
                    }
                }
            }
        }
    }
}
