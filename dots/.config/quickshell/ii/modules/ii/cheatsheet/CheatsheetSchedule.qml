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
    readonly property real sectionPad: 20

    implicitWidth: mainLayout.implicitWidth + sectionPad * 2
    implicitHeight: mainLayout.implicitHeight + sectionPad * 2

    // ── State ─────────────────────────────────────────────────
    property bool showFullSchedule: false
    property bool editingPath: false

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
        if (t === "review")  return "#ffd600";
        return "#90a4ae";
    }


    // ── JSON file reader ──────────────────────────────────────
    property var parsedDays: ({})

    function reloadSchedule() {
        var p = Persistent.states.cheatsheet.schedulePath;
        if (!p || p.trim() === "") {
            root.parsedDays = {};
            return;
        }
        scheduleFileView.path = Qt.resolvedUrl("file://" + p);
        scheduleFileView.reload();
    }

    Component.onCompleted: reloadSchedule()

    FileView {
        id: scheduleFileView
        onLoaded: {
            try {
                var obj = JSON.parse(scheduleFileView.text());
                if (obj.days && typeof obj.days === "object")
                    root.parsedDays = obj.days;
                else
                    root.parsedDays = obj;
            } catch(e) {
                root.parsedDays = {};
                console.warn("[Schedule] JSON parse error:", e);
            }
        }
        onLoadFailed: (error) => {
            root.parsedDays = {};
            console.warn("[Schedule] Failed to load file:", error);
        }
    }

    // ── Schedule model for today / full week ─────────────────
    property var scheduleModel: {
        var result = [];
        var src = root.parsedDays;
        var keys = Object.keys(src).sort();
        for (var ki = 0; ki < keys.length; ki++) {
            var date = keys[ki];
            if (!root.showFullSchedule && date !== root.todayStr) continue;
            var events = src[date] || [];
            for (var ei = 0; ei < events.length; ei++) {
                result.push({ date: date, event: events[ei] });
            }
        }
        return result;
    }

    property bool hasData: Object.keys(root.parsedDays).length > 0
    property bool todayHasEvents: (root.parsedDays[root.todayStr] || []).length > 0

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

            MaterialSymbol {
                text: "calendar_month"
                iconSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colTheme
            }

            StyledText {
                text: root.showFullSchedule ? "Full Schedule" : root.todayStr
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: Appearance.colors.colOnLayer0
                Layout.fillWidth: true
            }

            // Path editor toggle chip
            RippleButton {
                implicitHeight: 34
                implicitWidth: pathEditRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.full
                colBackground: root.editingPath
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colLayer2

                onClicked: root.editingPath = !root.editingPath

                contentItem: RowLayout {
                    id: pathEditRow
                    spacing: 6
                    anchors.centerIn: parent
                    MaterialSymbol {
                        text: root.editingPath ? "close" : "folder_open"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.editingPath
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        text: {
                            if (root.editingPath) return "Close";
                            if (Persistent.states.cheatsheet.schedulePath === "") return "Set Path";
                            return "Change";
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.editingPath
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnLayer2
                    }
                }
            }

            // Show Full / Today toggle
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
                        text: root.showFullSchedule ? "Today" : "Full"
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
            implicitHeight: pathColumn.implicitHeight + 16
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.small
            border.width: 1
            border.color: Appearance.colors.colLayer1Border

            ColumnLayout {
                id: pathColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 8

                StyledText {
                    text: "Paste the absolute path to your schedule.json file and press Enter:"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "insert_drive_file"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }

                    TextField {
                        id: pathField
                        Layout.fillWidth: true
                        placeholderText: "/home/user/path/to/schedule.json"
                        text: Persistent.states.cheatsheet.schedulePath
                        color: Appearance.colors.colOnLayer1
                        placeholderTextColor: Appearance.colors.colSubtext
                        font {
                            family: Appearance.font.family.main
                            pixelSize: Appearance.font.pixelSize.small
                            variableAxes: Appearance.font.variableAxes.main
                        }
                        renderType: Text.NativeRendering
                        selectedTextColor: Appearance.colors.colOnSecondaryContainer
                        selectionColor: Appearance.colors.colSecondaryContainer

                        background: Rectangle {
                            color: Appearance.colors.colLayer2
                            radius: Appearance.rounding.small
                            border.width: pathField.activeFocus ? 2 : 1
                            border.color: pathField.activeFocus
                                ? Appearance.colors.colTheme
                                : Appearance.colors.colLayer2Border
                        }

                        padding: 10

                        onAccepted: {
                            Persistent.states.cheatsheet.schedulePath = text.trim();
                            root.editingPath = false;
                            root.reloadSchedule();
                        }

                        Keys.onEscapePressed: {
                            root.editingPath = false;
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
                            root.reloadSchedule();
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "check"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }

                StyledText {
                    visible: Persistent.states.cheatsheet.schedulePath !== ""
                    text: "Current: " + Persistent.states.cheatsheet.schedulePath
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        // ── Empty states ─────────────────────────────────────
        ColumnLayout {
            visible: Persistent.states.cheatsheet.schedulePath === ""
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Item { implicitHeight: 40 }

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
                text: 'Click "Set Path" to load your schedule.json'
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        ColumnLayout {
            visible: Persistent.states.cheatsheet.schedulePath !== "" && !root.hasData
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Item { implicitHeight: 40 }

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

        ColumnLayout {
            visible: root.hasData && !root.showFullSchedule && !root.todayHasEvents
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Item { implicitHeight: 40 }

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
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: 'Try "Full" to see the entire week'
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        // ── Schedule timeline ────────────────────────────────
        Flickable {
            id: scrollArea
            visible: root.scheduleModel.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: timelineColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: StyledScrollBar {}

            ColumnLayout {
                id: timelineColumn
                width: scrollArea.width
                spacing: 0

                Repeater {
                    model: root.scheduleModel

                    delegate: ColumnLayout {
                        id: eventDelegate
                        required property var modelData
                        required property int index

                        width: timelineColumn.width
                        spacing: 0

                        // Date header (full schedule mode, new date)
                        Rectangle {
                            visible: root.showFullSchedule && (eventDelegate.index === 0 || root.scheduleModel[eventDelegate.index - 1].date !== eventDelegate.modelData.date)
                            Layout.fillWidth: true
                            Layout.topMargin: eventDelegate.index > 0 ? 12 : 0
                            Layout.bottomMargin: 4
                            height: 32
                            color: "transparent"

                            RowLayout {
                                anchors { fill: parent; leftMargin: 4 }
                                spacing: 8

                                Rectangle {
                                    width: 3; height: 18; radius: 2
                                    color: Appearance.colors.colTheme
                                }

                                StyledText {
                                    text: {
                                        var d = eventDelegate.modelData.date;
                                        return d === root.todayStr ? d + "  ·  Today" : d;
                                    }
                                    font {
                                        family: Appearance.font.family.title
                                        pixelSize: Appearance.font.pixelSize.normal
                                        variableAxes: Appearance.font.variableAxes.title
                                    }
                                    color: eventDelegate.modelData.date === root.todayStr
                                        ? Appearance.colors.colTheme
                                        : Appearance.colors.colOnLayer0Variant
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Event row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.preferredHeight: 44

                            // Timeline dot + connector
                            Item {
                                implicitWidth: 20
                                Layout.fillHeight: true

                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 7
                                    color: root.catColor(eventDelegate.modelData.event[3])
                                }

                                Rectangle {
                                    visible: eventDelegate.index < root.scheduleModel.length - 1
                                    width: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 19
                                    anchors.bottom: parent.bottom
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                }
                            }

                            // Time
                            StyledText {
                                text: eventDelegate.modelData.event[0]
                                font {
                                    family: Appearance.font.family.title
                                    pixelSize: Appearance.font.pixelSize.normal
                                    variableAxes: Appearance.font.variableAxes.title
                                }
                                color: root.catColor(eventDelegate.modelData.event[3])
                                Layout.preferredWidth: 54
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Event name
                            StyledText {
                                text: eventDelegate.modelData.event[2]
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer0
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                            }

                            // Duration chip
                            Rectangle {
                                implicitWidth: durText.implicitWidth + 16
                                height: 24; radius: 12
                                color: Qt.rgba(1, 1, 1, 0.06)
                                Layout.alignment: Qt.AlignVCenter

                                StyledText {
                                    id: durText
                                    anchors.centerIn: parent
                                    text: eventDelegate.modelData.event[1] + " min"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer0Variant
                                }
                            }

                            // Category chip
                            Rectangle {
                                implicitWidth: catLabel.implicitWidth + 16
                                height: 24; radius: 12
                                color: Qt.rgba(
                                    parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(1,3), 16) / 255,
                                    parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(3,5), 16) / 255,
                                    parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(5,7), 16) / 255,
                                    0.18
                                )
                                border.color: root.catColor(eventDelegate.modelData.event[3])
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter

                                StyledText {
                                    id: catLabel
                                    anchors.centerIn: parent
                                    text: eventDelegate.modelData.event[3]
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: root.catColor(eventDelegate.modelData.event[3])
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
