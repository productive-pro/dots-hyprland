pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

// AgentMemoryView — Three tabs: CORE MEMORY | ARCHIVAL | SHARED/FS
//
// CORE MEMORY: local git-backed ~/.letta/agents/{id}/memory/ filesystem.
//              Loaded via silent Process running /memory json.
//              Shows folder tree with nested files. CRUD ops supported.
//
// ARCHIVAL:    Letta passages API — semantic search + add.
//
// SHARED/FS:   Letta cloud folders API.

Item {
    id: root
    required property var controller

    readonly property string daemonBin: root.controller.daemonBin

    // ── State ────────────────────────────────────────────────────────────────
    property string mode: "core"           // "core" | "archival" | "shared"
    property var    memFolders: []         // [{id, name, files:[{id,name}]}]
    property bool   loading: false
    property string errorText: ""
    property int    selectedFolderIndex: -1
    property string selectedFileId: ""

    // ── Silent process for /memory json ──────────────────────────────────────
    Process {
        id: memProc
        running: false
        stdout: StdioCollector {
            id: memCollector
            onStreamFinished: {
                root.loading = false
                const raw = memCollector.text.trim()
                const jsonStart = raw.indexOf("{")
                if (jsonStart < 0) {
                    root.errorText = "No JSON in response"
                    return
                }
                try {
                    const tree = JSON.parse(raw.slice(jsonStart))
                    const folders = tree.folders || []
                    root.memFolders = []
                    root.memFolders = folders
                    root.errorText = ""
                } catch (e) {
                    root.errorText = "Parse error: " + e.message
                }
            }
        }
    }

    // ── Silent process for write/delete ops ──────────────────────────────────
    Process {
        id: opProc
        running: false
        stdout: StdioCollector {
            id: opCollector
            onStreamFinished: {
                const out = opCollector.text.trim()
                if (out.indexOf("[OK]") >= 0 || out.indexOf("[INFO]") >= 0) {
                    root.refreshMemory()   // reload after successful op
                }
            }
        }
    }

    // ── Helper functions ──────────────────────────────────────────────────────
    function agentId() {
        return root.controller.agentId || ""
    }

    function refreshMemory() {
        const aid = root.agentId()
        if (!aid) { root.errorText = "No active agent"; return }
        root.loading = true
        root.errorText = ""
        memCollector.text = ""   // reset collector
        memProc.command = [
            "bash", "-lc",
            `printf '/memory json\\n' | ${root.daemonBin} text 2>&1`
        ]
        memProc.running = true
    }

    function runOp(cmd) {
        opCollector.text = ""
        opProc.command = [
            "bash", "-lc",
            `printf '%s\\n' ${JSON.stringify(cmd)} | ${root.daemonBin} text 2>&1`
        ]
        opProc.running = true
    }

    // Auto-load when mode switches to core
    onModeChanged: {
        if (mode === "core" && root.memFolders.length === 0 && !root.loading) {
            Qt.callLater(root.refreshMemory)
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "memory"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: "Memory"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.bold: true
                color: Appearance.m3colors.m3onSurface
            }

            // Refresh button
            RippleButton {
                visible: root.mode === "core"
                implicitWidth: 32; implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Qt.rgba(1,1,1,0.08)
                onClicked: root.refreshMemory()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.loading ? "hourglass_top" : "refresh"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // ── Tab row ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { id: "core",      label: "Core",     icon: "article" },
                    { id: "archival",  label: "Archival", icon: "archive" },
                    { id: "shared",    label: "Shared",   icon: "folder_shared" },
                ]

                delegate: RippleButton {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.small
                    colBackground: root.mode === modelData.id
                        ? Appearance.colors.colPrimary
                        : Qt.rgba(1,1,1,0.04)
                    colBackgroundHover: root.mode === modelData.id
                        ? Appearance.colors.colPrimary
                        : Qt.rgba(1,1,1,0.10)
                    onClicked: root.mode = modelData.id

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 13
                            color: root.mode === modelData.id
                                ? Appearance.m3colors.m3onPrimary
                                : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: root.mode === modelData.id
                            color: root.mode === modelData.id
                                ? Appearance.m3colors.m3onPrimary
                                : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Appearance.colors.colOutline.r,
                           Appearance.colors.colOutline.g,
                           Appearance.colors.colOutline.b, 0.15)
        }

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // CORE MEMORY — local fs tree
            Item {
                anchors.fill: parent
                visible: root.mode === "core"

                // Loading / empty / error state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.loading || root.errorText.length > 0
                              || root.memFolders.length === 0
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.loading ? "hourglass_top"
                              : root.errorText.length > 0 ? "error_outline"
                              : "folder_open"
                        iconSize: 28
                        color: Qt.rgba(Appearance.colors.colSubtext.r,
                                       Appearance.colors.colSubtext.g,
                                       Appearance.colors.colSubtext.b, 0.5)
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.loading ? "Loading…"
                              : root.errorText.length > 0 ? root.errorText
                              : "No memory files yet"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Qt.rgba(Appearance.colors.colSubtext.r,
                                       Appearance.colors.colSubtext.g,
                                       Appearance.colors.colSubtext.b, 0.6)
                    }
                    RippleButton {
                        visible: !root.loading
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 90; implicitHeight: 28
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                        onClicked: root.refreshMemory()
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: "Load"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }
                    }
                }

                // Folder/file tree
                ScrollView {
                    anchors.fill: parent
                    visible: !root.loading && root.errorText.length === 0
                             && root.memFolders.length > 0
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ListView {
                        id: folderList
                        width: parent.width
                        model: root.memFolders
                        spacing: 8

                        delegate: Item {
                            id: folderDelegate
                            required property var modelData
                            required property int index
                            width: folderList.width - 8
                            height: folderHeader.height + filesCol.height + 8
                            anchors.horizontalCenter: parent.horizontalCenter

                            property bool expanded: true

                            // Folder header
                            Rectangle {
                                id: folderHeader
                                width: parent.width
                                height: 30
                                radius: Appearance.rounding.small
                                color: Qt.rgba(Appearance.colors.colPrimary.r,
                                               Appearance.colors.colPrimary.g,
                                               Appearance.colors.colPrimary.b, 0.10)

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    spacing: 6

                                    MaterialSymbol {
                                        text: folderDelegate.expanded ? "folder_open" : "folder"
                                        iconSize: 15
                                        color: Appearance.colors.colPrimary
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: folderDelegate.modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.bold: true
                                        color: Appearance.m3colors.m3onSurface
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        text: folderDelegate.modelData.files.length
                                        font.pixelSize: 10
                                        color: Appearance.colors.colSubtext
                                    }

                                    // Delete folder
                                    RippleButton {
                                        implicitWidth: 24; implicitHeight: 24
                                        buttonRadius: 4
                                        colBackground: "transparent"
                                        colBackgroundHover: Qt.rgba(1,0,0,0.1)
                                        onClicked: root.runOp(`/memory rmdir ${folderDelegate.modelData.id}`)
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            iconSize: 13
                                            color: Qt.rgba(Appearance.colors.colError.r,
                                                           Appearance.colors.colError.g,
                                                           Appearance.colors.colError.b, 0.7)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: folderDelegate.expanded = !folderDelegate.expanded
                                }
                            }

                            // Files column
                            ColumnLayout {
                                id: filesCol
                                anchors.top: folderHeader.bottom
                                anchors.topMargin: 2
                                width: parent.width
                                spacing: 2
                                visible: folderDelegate.expanded

                                Repeater {
                                    model: folderDelegate.modelData.files

                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Appearance.rounding.small
                                        color: Qt.rgba(1,1,1,0.03)

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 20; rightMargin: 6 }
                                            spacing: 6

                                            MaterialSymbol {
                                                text: "draft"
                                                iconSize: 13
                                                color: Appearance.colors.colSubtext
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.m3colors.m3onSurface
                                                elide: Text.ElideRight
                                            }

                                            // Read button
                                            RippleButton {
                                                implicitWidth: 24; implicitHeight: 24
                                                buttonRadius: 4
                                                colBackground: "transparent"
                                                colBackgroundHover: Qt.rgba(1,1,1,0.08)
                                                onClicked: {
                                                    root.controller.sendText(
                                                        `/memory read ${modelData.id}`)
                                                }
                                                contentItem: MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: "open_in_new"
                                                    iconSize: 12
                                                    color: Appearance.colors.colSubtext
                                                }
                                            }

                                            // Delete file
                                            RippleButton {
                                                implicitWidth: 24; implicitHeight: 24
                                                buttonRadius: 4
                                                colBackground: "transparent"
                                                colBackgroundHover: Qt.rgba(1,0,0,0.10)
                                                onClicked: root.runOp(`/memory delete ${modelData.id}`)
                                                contentItem: MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: "delete"
                                                    iconSize: 12
                                                    color: Qt.rgba(Appearance.colors.colError.r,
                                                                   Appearance.colors.colError.g,
                                                                   Appearance.colors.colError.b, 0.6)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Commit button — bottom right
                RippleButton {
                    anchors { bottom: parent.bottom; right: parent.right; margins: 8 }
                    visible: root.memFolders.length > 0 && !root.loading
                    implicitWidth: 90; implicitHeight: 28
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimary
                    onClicked: root.runOp("/memory commit")
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "save"
                            iconSize: 13
                            color: Appearance.m3colors.m3onPrimary
                        }
                        StyledText {
                            text: "Commit"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }
            }

            // ARCHIVAL MEMORY — passages
            ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "archival"
                spacing: 8

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    text: "Archival Memory"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.bold: true
                    color: Appearance.m3colors.m3onSurface
                }

                // Quick search
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Appearance.rounding.small
                        color: Qt.rgba(1,1,1,0.06)
                        border.color: Qt.rgba(1,1,1,0.10)
                        TextInput {
                            id: passageSearch
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Appearance.m3colors.m3onSurface
                            font.pixelSize: Appearance.font.pixelSize.small
                            selectByMouse: true
                            Keys.onReturnPressed: {
                                const q = passageSearch.text.trim()
                                if (q) root.controller.sendText(`/passages ${q}`)
                            }
                        }
                    }
                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimary
                        onClicked: {
                            const q = passageSearch.text.trim()
                            root.controller.sendText(q ? `/passages ${q}` : "/passages")
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "search"
                            iconSize: 15
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }

                Item { Layout.fillWidth: true; Layout.fillHeight: true }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Results appear in chat"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Qt.rgba(Appearance.colors.colSubtext.r,
                                   Appearance.colors.colSubtext.g,
                                   Appearance.colors.colSubtext.b, 0.5)
                }
                Item { Layout.preferredHeight: 16 }
            }

            // SHARED / FS MEMORY — Letta cloud folders
            ColumnLayout {
                anchors { fill: parent; topMargin: 8 }
                visible: root.mode === "shared"
                spacing: 8

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Shared Memory (Cloud Folders)"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.bold: true
                    color: Appearance.m3colors.m3onSurface
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Use /memfs json in chat to load"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Qt.rgba(Appearance.colors.colSubtext.r,
                                   Appearance.colors.colSubtext.g,
                                   Appearance.colors.colSubtext.b, 0.5)
                }
                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 100; implicitHeight: 28
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: root.controller.sendText("/memfs json")
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        text: "List Folders"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
