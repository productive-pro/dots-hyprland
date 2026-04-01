import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

// AssistantMemory.qml — collapsible Letta memory block viewer + inline editor
Item {
    id: root
    property var blocks: ({})     // {human, persona, goals, projects, habits}
    property var fileContents: ({})
    property string agentId: ""
    property string memoryRootPath: root.agentId ? `/home/archer/.letta/agents/${root.agentId}/memory` : ""
    property var memoryFiles: []
    property string activeEditLabel: ""
    property string voiceAssistantBin: "/home/archer/.dotfiles/nix/modules/programs/bin/scripts/voice-assistant"
    implicitHeight: collapsed ? headerRow.implicitHeight + 8 : fullHeight
    property bool collapsed: true
    property real fullHeight: headerRow.implicitHeight + 8 + blocksColumn.implicitHeight + filesColumn.implicitHeight + 16

    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
    }

    clip: true

    function refreshFiles() {
        refreshContents()
    }

    function refreshContents() {
        if (!root.memoryRootPath) {
            root.fileContents = ({})
            root.memoryFiles = []
            return
        }
        contentProc.exec([
            "/usr/bin/python3",
            "-c",
            "import json, pathlib, sys; root = pathlib.Path(sys.argv[1]); files = {}; "
            + "files.update({p.relative_to(root).as_posix(): p.read_text(encoding='utf-8', errors='replace') for p in sorted(root.rglob('*.md'))}); "
            + "print(json.dumps(files))",
            root.memoryRootPath
        ])
    }

    function normalizeMemoryKey(path) {
        return (path || "")
            .replace(/^system\//, "")
            .replace(/\.md$/, "")
    }

    function displayValue(label) {
        const keys = [
            label,
            `${label}.md`,
            `system/${label}.md`,
        ]
        for (const key of keys) {
            if (root.fileContents && Object.prototype.hasOwnProperty.call(root.fileContents, key))
                return root.fileContents[key]
        }
        if (root.fileContents && Object.prototype.hasOwnProperty.call(root.fileContents, normalizeMemoryKey(label)))
            return root.fileContents[normalizeMemoryKey(label)]
        return root.blocks[label] ?? ""
    }

    function fileContentFor(path) {
        const rel = (path || "").replace(/^system\//, "")
        const keys = [
            path,
            rel,
            normalizeMemoryKey(path) + ".md",
            normalizeMemoryKey(rel) + ".md",
        ]
        for (const key of keys) {
            if (root.fileContents && Object.prototype.hasOwnProperty.call(root.fileContents, key))
                return root.fileContents[key]
        }
        return ""
    }

    function openEditor(label) {
        root.activeEditLabel = label
        root.collapsed = false
    }

    function loadActiveAgentId() {
        if (root.agentId && root.agentId.length > 0)
            return
        agentProc.running = true
    }

    function closeEditor() {
        root.activeEditLabel = ""
    }

    onAgentIdChanged: {
        refreshFiles()
        refreshContents()
    }
    Component.onCompleted: {
        loadActiveAgentId()
        refreshFiles()
        refreshContents()
    }

    function isMemoryBlockShown(label) {
        return root.displayValue(label).trim().length > 0
    }

    // ── Header bar ────────────────────────────────────────────────────────
    RowLayout {
        id: headerRow
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
        spacing: 4

        MaterialSymbol {
            text: "memory"
            iconSize: 14
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: "Memory"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            Layout.fillWidth: true
        }
        RippleButton {
            implicitWidth: 24; implicitHeight: 24
            buttonRadius: Appearance.rounding.verysmall
            onClicked: root.collapsed = !root.collapsed
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.collapsed ? "expand_more" : "expand_less"
                iconSize: 16
                color: Appearance.colors.colSubtext
            }
            StyledToolTip { text: root.collapsed ? "Show memory blocks" : "Hide memory blocks" }
        }
    }

    // ── Block list ────────────────────────────────────────────────────────
    ColumnLayout {
        id: blocksColumn
        visible: !root.collapsed
        anchors {
            top: headerRow.bottom; topMargin: 4
            left: parent.left; right: parent.right; margins: 4
        }
        spacing: 4

        Repeater {
            model: ["human", "goals", "projects", "habits", "persona"]
            delegate: MemoryBlockRow {
                label:   modelData
                value:   root.displayValue(modelData)
                agentId: root.agentId
                Layout.fillWidth: true
                visible: root.activeEditLabel === modelData || root.isMemoryBlockShown(modelData)
            }
        }

        StyledText {
            visible: !root.collapsed && root.memoryFiles.length === 0
            text: "No memory files found"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            Layout.fillWidth: true
            Layout.topMargin: 4
        }

        StyledText {
            visible: root.memoryFiles.length > 0
            text: "Memory files"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            Layout.fillWidth: true
            Layout.topMargin: 4
        }

        ColumnLayout {
            id: filesColumn
            visible: root.memoryFiles.length > 0
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.memoryFiles
                delegate: Rectangle {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    implicitHeight: fileHeader.implicitHeight + fileBody.implicitHeight + 20

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            id: fileHeader
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "description"
                                iconSize: 16
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.replace(/^.*\//, "")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.bold: true
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            id: fileBody
                            Layout.fillWidth: true
                            text: root.fileContentFor(modelData)
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ── Inline block row component ────────────────────────────────────────
    component MemoryBlockRow: Rectangle {
        id: blockRow
        property string label
        property string value
        property string agentId
        property bool editing: false

        implicitHeight: editing
            ? Math.max(labelText.implicitHeight + editorColumn.implicitHeight + 32, 420)
            : labelText.implicitHeight + valueText.implicitHeight + 16
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 4

            // Label row
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    id: labelText
                    text: blockRow.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colPrimary
                    font.bold: true
                    Layout.fillWidth: true
                }
                // Edit toggle
                RippleButton {
                    visible: !blockRow.editing
                    implicitWidth: 32; implicitHeight: 32
                    buttonRadius: Appearance.rounding.verysmall
                    onClicked: {
                        blockRow.editing = true
                        root.openEditor(blockRow.label)
                        editField.text = blockRow.value
                        editField.forceActiveFocus()
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "edit"; iconSize: 18
                        color: Appearance.colors.colSubtext
                    }
                    StyledToolTip { text: "Edit block" }
                }
            }

            // Read view
            StyledText {
                id: valueText
                visible: !blockRow.editing
                Layout.fillWidth: true
                text: blockRow.value.trim() || "(empty)"
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: blockRow.value.trim()
                    ? Appearance.colors.colOnLayer2
                    : Appearance.colors.colSubtext
            }

            // Edit view
            ColumnLayout {
                visible: blockRow.editing
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    implicitHeight: editorColumn.implicitHeight + 24
                    Layout.minimumHeight: 440

                    ColumnLayout {
                        id: editorColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        Layout.fillHeight: true
                        spacing: 6

                        StyledText {
                            text: "Markdown edit"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            Layout.fillWidth: true
                        }

                        StyledTextArea {
                            id: editField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            implicitHeight: Math.max(contentHeight + 48, 360)
                            wrapMode: TextArea.Wrap
                            background: Rectangle {
                                color: Appearance.colors.colLayer2
                                radius: Appearance.rounding.small
                            }
                            padding: 10
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        RowLayout {
                            spacing: 4
                            Item { Layout.fillWidth: true }
                            ApiCommandButton {
                                buttonText: "cancel"
                                downAction: () => {
                                    blockRow.editing = false
                                    root.closeEditor()
                                }
                            }
                            ApiCommandButton {
                                buttonText: "save"
                                downAction: () => {
                                    saveProc.command = [
                                        root.voiceAssistantBin,
                                        "pipe-set",
                                        blockRow.label,
                                        editField.text
                                    ]
                                    saveProc.running = true
                                    // Optimistic update via IPC instead of waiting for proc
                                    let updated = Object.assign({}, root.blocks)
                                    updated[blockRow.label] = editField.text
                                    root.blocks = updated
                                    blockRow.editing = false
                                    let files = Object.assign({}, root.fileContents)
                                    files[blockRow.label] = editField.text
                                    root.fileContents = files
                                    root.closeEditor()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: agentProc
        command: [
            "/usr/bin/python3",
            "-c",
            "import json, pathlib; p = pathlib.Path.home() / '.ai' / 'config.json'; data = json.loads(p.read_text()) if p.exists() else {}; print(data.get('letta', {}).get('agent_id', ''))"
        ]
        running: false
        stdout: StdioCollector {
            id: agentCollector
            onStreamFinished: {
                const id = (this.text || "").trim()
                if (id.length > 0)
                    root.agentId = id
            }
        }
    }

    Process {
        id: saveProc
        running: false
    }

    Process {
        id: contentProc
        running: false
        stdout: StdioCollector {
            id: contentCollector
            onStreamFinished: {
                try {
                    const files = JSON.parse((this.text || "").trim() || "{}")
                    root.fileContents = files
                    root.memoryFiles = Object.keys(files).sort()
                } catch (e) {
                    root.fileContents = ({})
                    root.memoryFiles = []
                }
            }
        }
    }
}
