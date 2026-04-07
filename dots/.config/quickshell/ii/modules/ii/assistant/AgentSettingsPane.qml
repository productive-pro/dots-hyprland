pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    required property var controller

    property string configFilepath: "/home/archer/.local/state/letta_assistant/config.json"
    
    // UI local config cache
    property var configStore: ({})

    // UI States
    property bool llmConfigOpen: true
    property bool metadataOpen: false

    property string errorStr: ""
    property var modelList: []

    Process {
        id: modelFetcher
        command: ["python", "/home/archer/.dotfiles/libs/letta_assistant/src/letta_assistant/ui_helper.py", "models"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    if (res.success && res.data && res.data.length > 0) {
                        root.modelList = res.data
                        root.errorStr = ""
                    } else if (res.error) {
                        root.errorStr = res.error
                    }
                } catch(e) {
                    root.errorStr = text.trim()
                }
            }
        }
    }

    function loadConfig() {
        reader.running = true
    }

    function saveConfig(key, value) {
        configStore[key] = value
        const str = JSON.stringify(configStore)
        writer.command = ["bash", "-c", `echo '${str}' > ${configFilepath}`]
        writer.running = true
    }
    
    function setModelConfig(key, value) {
        controller.runSlashCommand(`/model set ${key} ${value}`)
    }

    Process {
        id: reader
        command: ["cat", root.configFilepath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.configStore = JSON.parse(text)
                } catch(e) {}
            }
        }
    }

    Process {
        id: writer
        running: false
    }

    Component.onCompleted: loadConfig()

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 0
        clip: true

        ScrollView {
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: -1
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                StyledText {
                    text: root.errorStr === "" ? "" : "SETUP REQUIRED"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.errorStr === "" ? Appearance.colors.colSubtext : Appearance.colors.colError
                    font.capitalization: Font.AllUppercase
                    font.bold: true
                    visible: root.errorStr !== ""
                }
                
                ColumnLayout {
                    visible: root.errorStr !== ""
                    Layout.fillWidth: true
                    spacing: 12
                    StyledText {
                        text: root.errorStr
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: "Enter your Letta API Key to continue. It will be stored securely in the system keyring."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    TextField {
                        id: apiKeyInput
                        Layout.fillWidth: true
                        placeholderText: "sk-..."
                        echoMode: TextInput.Password
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        background: Rectangle {
                            color: Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r, Appearance.m3colors.m3surfaceContainerHighest.g, Appearance.m3colors.m3surfaceContainerHighest.b, 0.4)
                            border.width: 0
                            radius: Appearance.rounding.small
                        }
                    }
                    RippleButton {
                        implicitWidth: 160
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        enabled: apiKeyInput.text.trim().length > 0
                        onClicked: {
                            // Store via secret-tool as defined in AGENTS.md
                            const key = apiKeyInput.text.trim().replace(/'/g, "")
                            writer.command = ["bash", "-c", `echo -n '${key}' | secret-tool store --label='Letta API Key' service sensvault username letta_key`]
                            writer.running = true
                            root.errorStr = "Saved! Restarting or retrying..."
                            // slight delay then retry
                            retryTimer.running = true
                        }
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: "Save API Key"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
                
                Timer {
                    id: retryTimer
                    interval: 1000
                    running: false
                    onTriggered: modelFetcher.running = true
                }

                // Main sections, hidden if setup fails
                ColumnLayout {
                    visible: root.errorStr === ""
                    Layout.fillWidth: true
                    spacing: 16

                // Name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                         text: "Name"
                         font.pixelSize: Appearance.font.pixelSize.tiny
                         color: Appearance.colors.colSubtext
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: controller.agentId || "Default Agent"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        background: Rectangle {
                            color: Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r, Appearance.m3colors.m3surfaceContainerHighest.g, Appearance.m3colors.m3surfaceContainerHighest.b, 0.4)
                            border.width: 0
                            radius: Appearance.rounding.small
                        }
                    }
                }

                // Description
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                         text: "Description"
                         font.pixelSize: Appearance.font.pixelSize.tiny
                         color: Appearance.colors.colSubtext
                    }
                    TextArea {
                        Layout.fillWidth: true
                        text: "A persistent coding agent."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        wrapMode: Text.WordWrap
                        background: Rectangle {
                            color: Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r, Appearance.m3colors.m3surfaceContainerHighest.g, Appearance.m3colors.m3surfaceContainerHighest.b, 0.4)
                            border.width: 0
                            radius: Appearance.rounding.small
                        }
                    }
                }

                // Model
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                         text: "Model"
                         font.pixelSize: Appearance.font.pixelSize.tiny
                         color: Appearance.colors.colSubtext
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        model: root.modelList
                        currentIndex: Math.max(0, model.indexOf(controller.modelName))
                        background: Rectangle {
                            color: Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r, Appearance.m3colors.m3surfaceContainerHighest.g, Appearance.m3colors.m3surfaceContainerHighest.b, 0.4)
                            border.width: 0
                            radius: Appearance.rounding.small
                        }
                        contentItem: Text {
                            text: parent.displayText
                            color: Appearance.m3colors.m3onSurface
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                    }
                }

                // System Instructions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                         text: "System Instructions"
                         font.pixelSize: Appearance.font.pixelSize.tiny
                         color: Appearance.colors.colSubtext
                    }
                    TextArea {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 80
                        text: "You are Letta Code..."
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                        background: Rectangle {
                            color: Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r, Appearance.m3colors.m3surfaceContainerHighest.g, Appearance.m3colors.m3surfaceContainerHighest.b, 0.4)
                            border.width: 0
                            radius: Appearance.rounding.small
                        }
                    }
                }

                // METADATA Section
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.2)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MouseArea {
                        Layout.fillWidth: true
                        height: 24
                        onClicked: root.metadataOpen = !root.metadataOpen
                        RowLayout {
                            anchors.fill: parent
                            StyledText {
                                text: "METADATA  " + (root.metadataOpen ? "▲" : "▼")
                                font.pixelSize: Appearance.font.pixelSize.tiny
                                font.bold: true
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                    ColumnLayout {
                        visible: root.metadataOpen
                        Layout.fillWidth: true
                        StyledText {
                            text: "No metadata"
                            font.pixelSize: Appearance.font.pixelSize.tiny
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // LLM CONFIG Section
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.2)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    MouseArea {
                        Layout.fillWidth: true
                        height: 24
                        onClicked: root.llmConfigOpen = !root.llmConfigOpen
                        RowLayout {
                            anchors.fill: parent
                            StyledText {
                                text: "LLM CONFIG  " + (root.llmConfigOpen ? "▲" : "▼")
                                font.pixelSize: Appearance.font.pixelSize.tiny
                                font.bold: true
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                    
                    ColumnLayout {
                        visible: root.llmConfigOpen
                        Layout.fillWidth: true
                        spacing: 16

                        // Reasoning toggle
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: "Reasoning"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.fillWidth: true
                            }
                            Switch {
                                checked: configStore["ui_reasoning"] === "on"
                                onCheckedChanged: {
                                    saveConfig("ui_reasoning", checked ? "on" : "off")
                                    setModelConfig("reasoning", checked ? "on" : "off")
                                }
                            }
                        }

                        // Parallel Tool Calls
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: "Parallel tool calls"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.fillWidth: true
                            }
                            Switch {
                                checked: configStore["ui_parallel_tool_calls"] !== "off"
                                onCheckedChanged: {
                                    saveConfig("ui_parallel_tool_calls", checked ? "on" : "off")
                                    setModelConfig("parallel", checked ? "on" : "off")
                                }
                            }
                        }
                        
                        // Temperature
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Temperature"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    text: parseFloat(tempSlider.value).toFixed(1)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            Slider {
                                id: tempSlider
                                Layout.fillWidth: true
                                from: 0.0
                                to: 2.0
                                value: configStore["ui_temperature"] !== undefined ? configStore["ui_temperature"] : 0.7
                                onValueChanged: saveConfig("ui_temperature", value)
                                onPressedChanged: {
                                    if (!pressed) setModelConfig("temp", value.toFixed(1))
                                }
                            }
                        }

                        // Context Window
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Context window"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    text: Math.round(ctxSlider.value)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            Slider {
                                id: ctxSlider
                                Layout.fillWidth: true
                                from: 4096
                                to: 272000
                                stepSize: 4096
                                value: configStore["ui_context_window"] !== undefined ? configStore["ui_context_window"] : 128000
                                onValueChanged: saveConfig("ui_context_window", value)
                                onPressedChanged: {
                                    if (!pressed) setModelConfig("ctx", Math.round(value))
                                }
                            }
                        }

                        // Max tokens
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: "Max output tokens"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    text: Math.round(tokensSlider.value)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            Slider {
                                id: tokensSlider
                                Layout.fillWidth: true
                                from: 1024
                                to: 32768
                                stepSize: 1024
                                value: configStore["ui_max_tokens"] !== undefined ? configStore["ui_max_tokens"] : 4096
                                onValueChanged: saveConfig("ui_max_tokens", value)
                                onPressedChanged: {
                                    if (!pressed) setModelConfig("max", Math.round(value))
                                }
                            }
                        }
                    }
                }
                } // End Main Sections Col
            }
        }
    }
}
