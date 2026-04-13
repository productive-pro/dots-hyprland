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

    // ── Color aliases from Appearance system (dynamic/reactive) ───────────────
    readonly property color clrBg:                Appearance.colors.colLayer0
    readonly property color clrSurface:           Appearance.colors.colLayer1
    readonly property color clrSurfaceHigh:       Appearance.colors.colLayer2
    readonly property color clrSurfaceHighest:    Appearance.colors.colLayer3
    readonly property color clrOutline:           Appearance.colors.colLayer0Border
    readonly property color clrOutlineBright:     Appearance.colors.colLayer1Active
    readonly property color clrPrimary:           Appearance.colors.colPrimary
    readonly property color clrPrimaryContainer:  Appearance.colors.colLayer1
    readonly property color clrSecondary:         Appearance.colors.colPrimaryHover
    readonly property color clrOnPrimary:         Appearance.colors.colOnPrimary
    readonly property color clrOnSurface:         Appearance.colors.colOnLayer1
    readonly property color clrOnSurfaceVariant:  Appearance.colors.colOnLayer1Inactive
    readonly property color clrSubtext:           Appearance.colors.colSubtext
    readonly property color clrError:             Appearance.m3colors.m3error
    readonly property color clrWarning:           Appearance.m3colors.m3tertiary

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

    // ── Root background ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.clrBg
        radius: Appearance.rounding.large || 12
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // ── Layout ────────────────────────────────────────────────
    ColumnLayout {
        id: mainLayout
        anchors {
            fill: parent
            margins: root.sectionPad
        }
        spacing: 14

        // ── Header row ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Calendar icon container — subtle tinted chip
            Rectangle {
                width: 36; height: 36
                radius: 10
                color: Qt.rgba(
                    parseInt(root.clrPrimary.toString().slice(1,3), 16) / 255,
                    parseInt(root.clrPrimary.toString().slice(3,5), 16) / 255,
                    parseInt(root.clrPrimary.toString().slice(5,7), 16) / 255,
                    0.10
                )
                
                Behavior on color { ColorAnimation { duration: 200 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "calendar_month"
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.clrPrimary
                }
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: false

                StyledText {
                    text: root.showFullSchedule ? "Full Schedule" : "Today"
                    font {
                        family: Appearance.font.family.title
                        pixelSize: Appearance.font.pixelSize.title
                        variableAxes: Appearance.font.variableAxes.title
                    }
                    color: root.clrOnPrimary
                }

                StyledText {
                    text: root.todayStr
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.clrSubtext
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Path editor toggle chip
            Rectangle {
                implicitHeight: 32
                implicitWidth: pathEditRowInner.implicitWidth + 20
                radius: 8
                color: root.editingPath
                    ? Qt.rgba(0.63, 0.63, 0.67, 0.18)
                    : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: root.editingPath
                    ? Qt.rgba(0.63, 0.63, 0.67, 0.35)
                    : root.clrOutline

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: pathEditRowInner
                    spacing: 5
                    anchors.centerIn: parent

                    MaterialSymbol {
                        text: root.editingPath ? "close" : "folder_open"
                        iconSize: Appearance.font.pixelSize.small
                        color: root.editingPath ? root.clrPrimary : root.clrOnSurfaceVariant
                    }
                    StyledText {
                        text: {
                            if (root.editingPath) return "Close";
                            if (Persistent.states.cheatsheet.schedulePath === "") return "Set Path";
                            return "Change";
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.editingPath ? root.clrPrimary : root.clrOnSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editingPath = !root.editingPath
                }
            }

            // Show Full / Today toggle
            Rectangle {
                visible: root.hasData
                implicitHeight: 32
                implicitWidth: toggleRowInner.implicitWidth + 20
                radius: 8
                color: root.showFullSchedule
                    ? Qt.rgba(0.63, 0.63, 0.67, 0.18)
                    : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: root.showFullSchedule
                    ? Qt.rgba(0.63, 0.63, 0.67, 0.35)
                    : root.clrOutline

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: toggleRowInner
                    spacing: 5
                    anchors.centerIn: parent

                    MaterialSymbol {
                        text: root.showFullSchedule ? "today" : "calendar_view_week"
                        iconSize: Appearance.font.pixelSize.small
                        color: root.showFullSchedule ? root.clrPrimary : root.clrOnSurfaceVariant
                    }
                    StyledText {
                        text: root.showFullSchedule ? "Today" : "Full"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.showFullSchedule ? root.clrPrimary : root.clrOnSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showFullSchedule = !root.showFullSchedule
                }
            }
        }

        // ── Thin separator line ──────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.clrOutline            
            Behavior on color { ColorAnimation { duration: 200 } }        }

        // ── Path editor (collapsible) ────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.editingPath
            implicitHeight: pathColumn.implicitHeight + 20
            color: root.clrSurface
            radius: 10
            border.width: 1
            border.color: root.clrOutlineBright
            clip: true
            
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            // Top accent line
            Rectangle {
                width: parent.width; height: 2
                anchors.top: parent.top
                radius: 10
                color: root.clrPrimary
                opacity: 0.5
                
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            ColumnLayout {
                id: pathColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                StyledText {
                    text: "Schedule JSON path"
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        family: Appearance.font.family.title
                        variableAxes: Appearance.font.variableAxes.title
                    }
                    color: root.clrPrimary
                }

                StyledText {
                    text: "Paste absolute path and press Enter"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.clrSubtext
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Input field
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: root.clrBg
                        border.width: pathField.activeFocus ? 1 : 1
                        border.color: pathField.activeFocus
                            ? root.clrPrimary
                            : root.clrOutlineBright

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            MaterialSymbol {
                                text: "insert_drive_file"
                                iconSize: Appearance.font.pixelSize.small
                                color: root.clrSubtext
                            }

                            TextField {
                                id: pathField
                                Layout.fillWidth: true
                                placeholderText: "/home/user/path/to/schedule.json"
                                text: Persistent.states.cheatsheet.schedulePath
                                color: root.clrOnSurface
                                placeholderTextColor: root.clrSubtext
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: Appearance.font.pixelSize.small
                                    variableAxes: Appearance.font.variableAxes.main
                                }
                                renderType: Text.NativeRendering
                                selectedTextColor: root.clrBg
                                selectionColor: root.clrPrimary
                                background: Item {}
                                padding: 0

                                onAccepted: {
                                    Persistent.states.cheatsheet.schedulePath = text.trim();
                                    root.editingPath = false;
                                    root.reloadSchedule();
                                }
                                Keys.onEscapePressed: root.editingPath = false;
                            }
                        }
                    }

                    // Confirm button
                    Rectangle {
                        width: 36; height: 36
                        radius: 8
                        color: root.clrPrimary
                        
                        Behavior on color { ColorAnimation { duration: 200 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "check"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.clrBg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Persistent.states.cheatsheet.schedulePath = pathField.text.trim();
                                root.editingPath = false;
                                root.reloadSchedule();
                            }
                        }
                    }
                }

                StyledText {
                    visible: Persistent.states.cheatsheet.schedulePath !== ""
                    text: "↳ " + Persistent.states.cheatsheet.schedulePath
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.clrSubtext
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        // ── Empty states ─────────────────────────────────────
        // No path set
        ColumnLayout {
            visible: Persistent.states.cheatsheet.schedulePath === ""
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Item { implicitHeight: 32 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64; height: 64; radius: 18
                color: Qt.rgba(0.63, 0.63, 0.67, 0.08)
                border.width: 1
                border.color: root.clrOutlineBright
                
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "upload_file"
                    iconSize: 28
                    color: root.clrSubtext
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "No schedule loaded"
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: root.clrOnSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: 'Tap "Set Path" above to load your schedule.json'
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.clrSubtext
            }

            Item { implicitHeight: 16 }
        }

        // Parse error
        ColumnLayout {
            visible: Persistent.states.cheatsheet.schedulePath !== "" && !root.hasData
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Item { implicitHeight: 32 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64; height: 64; radius: 18
                color: Qt.rgba(0.80, 0.19, 0.19, 0.10)
                border.width: 1
                border.color: Qt.rgba(0.80, 0.19, 0.19, 0.25)
                
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "warning"
                    iconSize: 28
                    color: root.clrError
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Could not parse schedule"
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: root.clrOnSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Persistent.states.cheatsheet.schedulePath
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.clrSubtext
                elide: Text.ElideMiddle
            }

            Item { implicitHeight: 16 }
        }

        // No events today
        ColumnLayout {
            visible: root.hasData && !root.showFullSchedule && !root.todayHasEvents
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Item { implicitHeight: 32 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64; height: 64; radius: 18
                color: Qt.rgba(0.63, 0.63, 0.67, 0.08)
                border.width: 1
                border.color: root.clrOutlineBright
                
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "free_cancellation"
                    iconSize: 28
                    color: root.clrSubtext
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing scheduled today"
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: root.clrOnSurface
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: 'Tap "Full" to see the entire week'
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.clrSubtext
            }

            Item { implicitHeight: 16 }
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

                        // ── Date header (full schedule mode) ─────────────
                        Rectangle {
                            visible: root.showFullSchedule && (
                                eventDelegate.index === 0 ||
                                root.scheduleModel[eventDelegate.index - 1].date !== eventDelegate.modelData.date
                            )
                            Layout.fillWidth: true
                            Layout.topMargin: eventDelegate.index > 0 ? 16 : 0
                            Layout.bottomMargin: 4
                            height: 30
                            radius: 6
                            color: eventDelegate.modelData.date === root.todayStr
                                ? Qt.rgba(0.63, 0.63, 0.67, 0.10)
                                : "transparent"
                            
                            Behavior on color { ColorAnimation { duration: 200 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                spacing: 8

                                Rectangle {
                                    width: 3; height: 14; radius: 2
                                    color: eventDelegate.modelData.date === root.todayStr
                                        ? root.clrPrimary
                                        : root.clrSubtext
                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                StyledText {
                                    text: {
                                        var d = eventDelegate.modelData.date;
                                        return d === root.todayStr ? d + "  ·  Today" : d;
                                    }
                                    font {
                                        family: Appearance.font.family.title
                                        pixelSize: Appearance.font.pixelSize.small
                                        variableAxes: Appearance.font.variableAxes.title
                                    }
                                    color: eventDelegate.modelData.date === root.todayStr
                                        ? root.clrPrimary
                                        : root.clrSubtext
                                    Layout.fillWidth: true
                                }

                                // Event count badge for this date
                                Rectangle {
                                    implicitWidth: dateCountText.implicitWidth + 10
                                    height: 18; radius: 9
                                    color: Qt.rgba(0.63, 0.63, 0.67, 0.12)
                                    visible: eventDelegate.modelData.date === root.todayStr
                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    StyledText {
                                        id: dateCountText
                                        anchors.centerIn: parent
                                        text: (root.parsedDays[eventDelegate.modelData.date] || []).length + " events"
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: root.clrSubtext
                                    }
                                }
                            }
                        }

                        // ── Event row ───────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: eventRowLayout.implicitHeight + 10
                            radius: 8
                            color: "transparent"

                            // Subtle hover highlight
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.0)
                                id: eventHoverBg
                                
                                Behavior on color { ColorAnimation { duration: 200 } }

                                MouseArea {
                                    id: eventHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: eventHoverBg.color = Qt.rgba(1, 1, 1, 0.025)
                                    onExited:  eventHoverBg.color = Qt.rgba(1, 1, 1, 0.0)
                                }
                            }

                            RowLayout {
                                id: eventRowLayout
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 4; rightMargin: 4 }
                                spacing: 10

                                // ── Timeline dot + connector ────────────
                                Item {
                                    implicitWidth: 18
                                    Layout.fillHeight: true
                                    Layout.preferredHeight: 44

                                    // Outer ring
                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        color: "transparent"
                                        border.width: 2
                                        border.color: root.catColor(eventDelegate.modelData.event[3])
                                        opacity: 0.6
                                    }

                                    // Inner dot
                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 9
                                        color: root.catColor(eventDelegate.modelData.event[3])
                                    }

                                    // Connector line
                                    Rectangle {
                                        visible: eventDelegate.index < root.scheduleModel.length - 1
                                        width: 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        anchors.bottom: parent.bottom
                                        color: root.clrOutlineBright
                                        
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                // ── Time ───────────────────────────────
                                StyledText {
                                    text: eventDelegate.modelData.event[0]
                                    font {
                                        family: Appearance.font.family.title
                                        pixelSize: Appearance.font.pixelSize.small
                                        variableAxes: Appearance.font.variableAxes.title
                                    }
                                    color: root.catColor(eventDelegate.modelData.event[3])
                                    Layout.preferredWidth: 50
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // ── Event name ─────────────────────────
                                StyledText {
                                    text: eventDelegate.modelData.event[2]
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: root.clrOnSurface
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                // ── Duration chip ──────────────────────
                                Rectangle {
                                    implicitWidth: durText.implicitWidth + 14
                                    height: 22; radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: root.clrOutline
                                    Layout.alignment: Qt.AlignVCenter                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                    StyledText {
                                        id: durText
                                        anchors.centerIn: parent
                                        text: eventDelegate.modelData.event[1] + "m"
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: root.clrSubtext
                                    }
                                }

                                // ── Category chip ──────────────────────
                                Rectangle {
                                    implicitWidth: catLabel.implicitWidth + 14
                                    height: 22; radius: 6
                                    color: Qt.rgba(
                                        parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(1,3), 16) / 255,
                                        parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(3,5), 16) / 255,
                                        parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(5,7), 16) / 255,
                                        0.14
                                    )
                                    border.color: Qt.rgba(
                                        parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(1,3), 16) / 255,
                                        parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(3,5), 16) / 255,
                                        parseInt(root.catColor(eventDelegate.modelData.event[3]).slice(5,7), 16) / 255,
                                        0.45
                                    )
                                    border.width: 1
                                    Layout.alignment: Qt.AlignVCenter
                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }

                                    StyledText {
                                        id: catLabel
                                        anchors.centerIn: parent
                                        text: eventDelegate.modelData.event[3]
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: root.catColor(eventDelegate.modelData.event[3])
                                    }
                                }
                            }
                        }

                        // ── Divider ─────────────────────────────────────
                        Rectangle {
                            visible: eventDelegate.index < root.scheduleModel.length - 1
                            Layout.fillWidth: true
                            height: 1
                            color: root.clrOutline
                            Layout.leftMargin: 28
                            Layout.rightMargin: 4                            
                            Behavior on color { ColorAnimation { duration: 200 } }                        }
                    }
                }
            }
        }
    }
}
