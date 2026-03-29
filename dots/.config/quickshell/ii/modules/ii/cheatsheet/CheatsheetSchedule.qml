pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

Item {
    id: root
    readonly property real cardSpacing: 8
    readonly property real sectionPad: 20

    implicitWidth: mainLayout.implicitWidth + sectionPad * 2
    implicitHeight: mainLayout.implicitHeight + sectionPad * 2

    // ── State ─────────────────────────────────────────────────
    property bool showFullSchedule: false
    property bool editingPath: false
    property var parsedJson: ({})

    readonly property string todayStr: {
        var d = new Date();
        var off = d.getTimezoneOffset() * 60000;
        return new Date(d.getTime() - off).toISOString().split('T')[0];
    }

    // ── Colour palette per category tag ──────────────────────
    function catColor(tag) {
        var t = (tag || "").toLowerCase();
        if (t === "mlp")     return "#7c4dff";
        if (t === "gate")    return "#00b0ff";
        if (t === "bdm")     return "#00bfa5";
        if (t === "anchor")  return "#ff6d00";
        if (t === "routine") return "#4caf50";
        if (t === "break")   return "#78909c";
        if (t === "oppe")    return "#f06292";
        if (t === "suzen")   return "#ff7043";
        if (t === "wind")    return "#ab47bc";
        return "#90a4ae";
    }

    // ── JSON loader via XHR ───────────────────────────────────
    function loadJson(path) {
        if (!path || path.trim() === "") return;
        var xhr = new XMLHttpRequest();
        var uri = path.startsWith("file://") ? path : ("file://" + path);
        xhr.open("GET", uri, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        root.parsedJson = JSON.parse(xhr.responseText);
                    } catch(e) {
                        root.parsedJson = {};
                        console.warn("CheatsheetSchedule: JSON parse error:", e);
                    }
                } else {
                    root.parsedJson = {};
                    console.warn("CheatsheetSchedule: could not load file, status:", xhr.status);
                }
            }
        };
        xhr.send();
    }

    onEditingPathChanged: {
        if (!editingPath) {
            // Reload when the user closes the path editor
            root.loadJson(Persistent.states.cheatsheet.schedulePath);
        }
    }

    Component.onCompleted: {
        root.loadJson(Persistent.states.cheatsheet.schedulePath);
    }

    // ── Schedule model for today / full week ─────────────────
    property var scheduleModel: {
        var result = [];
        var keys = Object.keys(root.parsedJson).sort();
        for (var ki = 0; ki < keys.length; ki++) {
            var date = keys[ki];
            if (!root.showFullSchedule && date !== root.todayStr) continue;
            var events = root.parsedJson[date] || [];
            for (var ei = 0; ei < events.length; ei++) {
                result.push({ date: date, event: events[ei] });
            }
        }
        return result;
    }

    property bool hasData: Object.keys(root.parsedJson).length > 0
    property bool todayHasEvents: (root.parsedJson[root.todayStr] || []).length > 0

    // ── Layout ────────────────────────────────────────────────
    ColumnLayout {
        id: mainLayout
        anchors {
            fill: parent
            margins: root.sectionPad
        }
        spacing: 16

        // ── Header row ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Icon + Title
            MaterialSymbol {
                text: "calendar_month"
                iconSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colTheme
            }

            StyledText {
                text: root.showFullSchedule ? "Full Schedule" : "Today — " + root.todayStr
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: Appearance.colors.colOnLayer0
                Layout.fillWidth: true
            }

            // Toggle path editor chip
            RippleButton {
                id: pathEditBtn
                implicitHeight: 34
                implicitWidth: pathEditRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.full
                colBackground: root.editingPath
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colLayer2

                onClicked: {
                    root.editingPath = !root.editingPath;
                }

                contentItem: RowLayout {
                    id: pathEditRow
                    spacing: 6
                    anchors.centerIn: parent
                    MaterialSymbol {
                        text: root.editingPath ? "check" : "folder_open"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.editingPath
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        text: root.editingPath ? "Save Path" : (Persistent.states.cheatsheet.schedulePath === "" ? "Load JSON" : "Change JSON")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.editingPath
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnLayer2
                    }
                }
            }

            // Show Full / Today toggle — only when data is loaded
            RippleButton {
                visible: root.hasData
                implicitHeight: 34
                implicitWidth: toggleRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.full
                colBackground: root.showFullSchedule
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer2

                onClicked: root.showFullSchedule = !root.showFullSchedule

                contentItem: RowLayout {
                    id: toggleRow
                    spacing: 6
                    anchors.centerIn: parent
                    MaterialSymbol {
                        text: root.showFullSchedule ? "today" : "calendar_view_week"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.showFullSchedule
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        text: root.showFullSchedule ? "Show Today" : "Full Schedule"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.showFullSchedule
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        // ── Path editor (collapsible) ────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.editingPath
            height: root.editingPath ? pathRow.implicitHeight + 16 : 0
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer1Border

            RowLayout {
                id: pathRow
                anchors { fill: parent; margins: 8 }
                spacing: 8

                MaterialSymbol {
                    text: "insert_drive_file"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: pathField
                    Layout.fillWidth: true
                    placeholderText: "/home/you/path/to/schedule.json"
                    text: Persistent.states.cheatsheet.schedulePath
                    onAccepted: {
                        Persistent.states.cheatsheet.schedulePath = text.trim();
                        root.editingPath = false;
                    }
                    Component.onCompleted: {
                        if (root.editingPath) forceActiveFocus();
                    }
                }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimary
                    onClicked: {
                        Persistent.states.cheatsheet.schedulePath = pathField.text.trim();
                        root.editingPath = false;
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "check"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }

        // ── Empty states ─────────────────────────────────────
        Item {
            visible: Persistent.states.cheatsheet.schedulePath === ""
            Layout.fillWidth: true
            implicitHeight: emptyCol1.implicitHeight
            ColumnLayout {
                id: emptyCol1
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "upload_file"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No schedule loaded"
                    font.pixelSize: Appearance.font.pixelSize.title
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Click "Load JSON" above to set the path to your schedule.json"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Item {
            visible: Persistent.states.cheatsheet.schedulePath !== "" && !root.hasData
            Layout.fillWidth: true
            implicitHeight: emptyCol2.implicitHeight
            ColumnLayout {
                id: emptyCol2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "warning"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Could not parse schedule"
                    font.pixelSize: Appearance.font.pixelSize.title
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Persistent.states.cheatsheet.schedulePath
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Item {
            visible: root.hasData && !root.showFullSchedule && !root.todayHasEvents
            Layout.fillWidth: true
            implicitHeight: emptyCol3.implicitHeight
            ColumnLayout {
                id: emptyCol3
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "free_cancellation"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No events for today"
                    font.pixelSize: Appearance.font.pixelSize.title
                    color: Appearance.colors.colOnLayer0
                }
            }
        }

        // ── Schedule scroll area ─────────────────────────────
        StyledFlickable {
            id: scrollArea
            visible: root.scheduleModel.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: timelineColumn.implicitHeight

            ScrollBar.vertical: StyledScrollBar {}

            ColumnLayout {
                id: timelineColumn
                width: scrollArea.width
                spacing: 0

                Repeater {
                    model: root.scheduleModel

                    delegate: Item {
                        id: eventDelegate
                        required property var modelData
                        required property int index
                        readonly property var evt: modelData.event
                        readonly property string evtDate: modelData.date
                        readonly property bool isNewDate: index === 0 || root.scheduleModel[index - 1].date !== modelData.date

                        Layout.fillWidth: true
                        width: timelineColumn.width
                        height: itemColumn.implicitHeight

                        ColumnLayout {
                            id: itemColumn
                            width: parent.width
                            spacing: 0

                            // Date header (only for full schedule view when date changes)
                            Rectangle {
                                visible: root.showFullSchedule && eventDelegate.isNewDate
                                Layout.fillWidth: true
                                height: 36
                                color: "transparent"

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: false
                                        width: 3
                                        height: 18
                                        radius: 2
                                        color: Appearance.colors.colTheme
                                    }

                                    StyledText {
                                        text: eventDelegate.evtDate === root.todayStr
                                            ? eventDelegate.evtDate + "  ·  Today"
                                            : eventDelegate.evtDate
                                        font {
                                            family: Appearance.font.family.title
                                            pixelSize: Appearance.font.pixelSize.normal
                                            variableAxes: Appearance.font.variableAxes.title
                                        }
                                        color: eventDelegate.evtDate === root.todayStr
                                            ? Appearance.colors.colTheme
                                            : Appearance.colors.colOnLayer0Variant
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            // Event card row
                            RowLayout {
                                width: parent.width
                                spacing: 10
                                height: 52

                                // Timeline dot + line
                                ColumnLayout {
                                    spacing: 0
                                    width: 20
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 14

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: root.catColor(eventDelegate.evt[3])
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Rectangle {
                                        visible: eventDelegate.index < root.scheduleModel.length - 1
                                        width: 2
                                        height: 30
                                        Layout.alignment: Qt.AlignHCenter
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                    }
                                }

                                // Time column
                                StyledText {
                                    text: eventDelegate.evt[0]
                                    font {
                                        family: Appearance.font.family.title
                                        pixelSize: Appearance.font.pixelSize.normal
                                        variableAxes: Appearance.font.variableAxes.title
                                    }
                                    color: root.catColor(eventDelegate.evt[3])
                                    Layout.preferredWidth: 54
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Event name
                                StyledText {
                                    text: eventDelegate.evt[2]
                                    font.pixelSize: Appearance.font.pixelSize.text
                                    color: Appearance.colors.colOnLayer0
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                // Duration chip
                                Rectangle {
                                    implicitWidth: durText.implicitWidth + 16
                                    height: 24
                                    radius: 12
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    Layout.alignment: Qt.AlignVCenter

                                    StyledText {
                                        id: durText
                                        anchors.centerIn: parent
                                        text: eventDelegate.evt[1] + " min"
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer0Variant
                                    }
                                }

                                // Category chip
                                Rectangle {
                                    implicitWidth: catLabel.implicitWidth + 16
                                    height: 24
                                    radius: 12
                                    color: Qt.rgba(
                                        parseInt(root.catColor(eventDelegate.evt[3]).slice(1,3), 16) / 255,
                                        parseInt(root.catColor(eventDelegate.evt[3]).slice(3,5), 16) / 255,
                                        parseInt(root.catColor(eventDelegate.evt[3]).slice(5,7), 16) / 255,
                                        0.18
                                    )
                                    border.color: root.catColor(eventDelegate.evt[3])
                                    border.width: 1
                                    Layout.alignment: Qt.AlignVCenter

                                    StyledText {
                                        id: catLabel
                                        anchors.centerIn: parent
                                        text: eventDelegate.evt[3]
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.catColor(eventDelegate.evt[3])
                                    }
                                }
                            }

                            // Faint divider
                            Rectangle {
                                visible: eventDelegate.index < root.scheduleModel.length - 1
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.04)
                                Layout.leftMargin: 30
                            }
                        }
                    }
                }
            }
        }
    }
}
