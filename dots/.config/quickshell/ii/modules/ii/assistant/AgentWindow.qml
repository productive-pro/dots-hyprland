pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

// AgentWindow — replaces AssistantWindow.qml.
//
// Two-mode centered shell window:
//   CHAT mode  (agentModeActive=false): 42% width, content-driven height, centered
//   AGENT mode (agentModeActive=true):  88% width, 88% height fixed, split layout
//
// Ctrl+O is handled via Keys.onPressed on the focused card Rectangle,
// exactly mirroring SidebarLeft's extend pattern. No Hyprland global keybind
// needed — WlrKeyboardFocus.OnDemand gives the panel keyboard ownership
// whenever the window is visible.
//
// Flicker fixes vs. old AssistantWindow:
//   1. Height debounced (64ms timer) — never live-bound during streaming.
//   2. AGENT mode: fixed height, no content binding at all.
//   3. Single states+transitions block owns all card geometry.
//   4. No competing Behaviors on width/height.
//   5. Workspace Loader kept alive after first activation via Connections flag.
//   6. msgList never reparented — AgentChatColumn always present in tree.
//   7. Open/close: opacity+scale only, no Translate fighting geometry.

PanelWindow {
    id: root
    required property var assistantRoot
    property alias controller: controller

    visible: GlobalStates.voiceAssistantActive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:voiceAssistant"
    // OnDemand: window captures keyboard when visible — same as sidebarLeft
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true

    // ── Public interface (identical signature to AssistantWindow) ─────────
    function receiveEvent(event, payload) { controller.receiveEvent(event, payload) }
    function openAssistant()   { GlobalStates.voiceAssistantActive = true }
    function closeAssistant()  { assistantRoot.closeAssistant() }
    function toggleAssistant() { GlobalStates.voiceAssistantActive = !GlobalStates.voiceAssistantActive }

    onVisibleChanged: {
        if (!visible) {
            controller.reset()
        } else {
            Qt.callLater(() => chatColumn.focusPrompt())
        }
    }

    // ── Scrim ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: GlobalStates.voiceAssistantActive ? 0.32 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: root.closeAssistant() }
    }

    // ── Card anchor — purely centers the card ─────────────────────────────
    Item {
        id: cardAnchor
        anchors.centerIn: parent
        width: card.width
        height: card.height

        opacity: GlobalStates.voiceAssistantActive ? 1.0 : 0.0
        scale:   GlobalStates.voiceAssistantActive ? 1.0 : 0.97
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // ── Card ──────────────────────────────────────────────────────────
        Rectangle {
            id: card

            // ── Keys: Ctrl+O (same pattern as SidebarLeft line 153-167) ──
            // Card receives focus implicitly when the window captures keyboard
            // via WlrKeyboardFocus.OnDemand. We don't need a Hyprland bind.
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.closeAssistant()
                    event.accepted = true
                    return
                }
                if (event.modifiers === Qt.ControlModifier) {
                    if (event.key === Qt.Key_O) {
                        GlobalStates.agentModeActive = !GlobalStates.agentModeActive
                        event.accepted = true
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // Geometry state machine — THREE EXCLUSIVE STATES
            // ─────────────────────────────────────────────────────────────
            states: [
                State {
                    name: "IDLE"
                    when: !GlobalStates.agentModeActive
                          && controller.messages.length === 0
                    PropertyChanges {
                        target: card
                        width:  Math.min(root.width * 0.42, 860)
                        height: card.idleHeight
                    }
                },
                State {
                    name: "CHAT"
                    when: !GlobalStates.agentModeActive
                          && controller.messages.length > 0
                    PropertyChanges {
                        target: card
                        width:  Math.min(root.width * 0.42, 860)
                        height: card.chatHeight
                    }
                },
                State {
                    name: "AGENT"
                    when: GlobalStates.agentModeActive
                    PropertyChanges {
                        target: card
                        width:  Math.min(root.width * 0.88, 1500)
                        // Fixed! No content-driven binding in agent mode.
                        height: root.height * 0.88
                    }
                }
            ]

            // All geometry animated by one single Transition (no per-property Behaviors).
            transitions: Transition {
                NumberAnimation {
                    properties: "width,height"
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            // ── Stable height inputs (one-way reads from chatColumn) ───────
            // Using Binding items avoids a circular binding: maxChatHeight on
            // chatColumn would read chatColumn's own properties if we weren't
            // explicit here.
            property real composerH: 52   // updated via Binding below
            property real slashH:    0    // updated via Binding below

            Binding { target: card; property: "composerH"; value: chatColumn.composerImplicitHeight }
            Binding { target: card; property: "slashH";    value: chatColumn.slashStripHeight }

            // IDLE height: just composer + slash + padding
            readonly property real idleHeight: composerH + slashH + 28 + 24

            // CHAT target: live computed, committed by debounce timer
            readonly property real chatTarget: {
                const maxH   = root.height * 0.72
                const panelH = Math.max(0, maxH - composerH - slashH - 52)
                const hasMsg = controller.messages.length > 0
                return Math.min(maxH, (hasMsg ? panelH : 0) + composerH + slashH + 28 + 24)
            }

            // chatHeight is the debounced committed value used by the CHAT state.
            property real chatHeight: idleHeight

            onChatTargetChanged: {
                if (!controller.isProcessing) {
                    // Idle: commit immediately so UI stays sharp
                    card.chatHeight = card.chatTarget
                } else {
                    // Streaming: debounce to prevent every-token geometry thrash
                    heightTimer.restart()
                }
            }

            Timer {
                id: heightTimer
                interval: 64
                repeat: false
                onTriggered: card.chatHeight = card.chatTarget
            }

            // Commit final height the moment streaming stops
            Connections {
                target: controller
                function onIsProcessingChanged() {
                    if (!controller.isProcessing) {
                        heightTimer.stop()
                        card.chatHeight = card.chatTarget
                    }
                }
            }

            // ── Visual style ──────────────────────────────────────────────
            radius: Appearance.rounding.large
            color: Qt.rgba(
                Appearance.m3colors.m3surfaceContainer.r,
                Appearance.m3colors.m3surfaceContainer.g,
                Appearance.m3colors.m3surfaceContainer.b, 0.97)
            border.width: 1
            border.color: Qt.rgba(
                Appearance.colors.colOutlineVariant.r,
                Appearance.colors.colOutlineVariant.g,
                Appearance.colors.colOutlineVariant.b, 0.18)
            clip: true

            // Eat all card-area clicks so scrim doesn't fire
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: (m) => m.accepted = true
            }

            // ── Interior layout ───────────────────────────────────────────
            RowLayout {
                anchors { fill: parent; margins: 12; topMargin: 14 }
                spacing: 10

                // ── Settings Loader ──
                Loader {
                    id: settingsLoader
                    property bool keepAlive: false
                    active: keepAlive 
                    visible: GlobalStates.agentModeActive
                    opacity: GlobalStates.agentModeActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.preferredWidth: GlobalStates.agentModeActive ? Math.round(card.width * 0.22) - 10 : 0
                    Layout.fillHeight: true
                    sourceComponent: AgentSettingsPane { controller: controller }
                }

                // ── Chat column (ALWAYS present, NEVER unmounted) ─────────
                AgentChatColumn {
                    id: chatColumn
                    controller: controller

                    // Chat mode: full card width.
                    // Agent mode: left 40% — stable fraction, not content-driven.
                    Layout.preferredWidth: GlobalStates.agentModeActive
                        ? Math.round(card.width * 0.43) - 16
                        : card.width - 24
                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

                    Layout.fillHeight: true

                    // maxChatHeight reads card's own composerH/slashH to avoid
                    // any self-referential binding inside chatColumn.
                    maxChatHeight: Math.max(80,
                        card.height - card.composerH - card.slashH - 52)

                    onEscapeRequested: root.closeAssistant()
                }

                // ── Workspace pane — Loader-gated, never unloaded once seen ─
                Loader {
                    id: workspaceLoader

                    // keepAlive is set exactly once (on first agent mode entry)
                    // via the Connections block below — no side-effect inside binding.
                    property bool keepAlive: false

                    active:  keepAlive   // once true, stays true for session lifetime
                    visible: GlobalStates.agentModeActive

                    opacity: GlobalStates.agentModeActive ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    // Synchronous: prevents a blank frame during the first
                    // card-width animation when Ctrl+O is pressed.
                    asynchronous: false

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    sourceComponent: AgentWorkspacePane {
                        controller: controller
                    }
                }

                // One-shot latch: activate workspaceLoader on first Ctrl+O
                Connections {
                    target: GlobalStates
                    function onAgentModeActiveChanged() {
                        if (GlobalStates.agentModeActive && !workspaceLoader.keepAlive) {
                            workspaceLoader.keepAlive = true
                        }
                        if (GlobalStates.agentModeActive && !settingsLoader.keepAlive) {
                            settingsLoader.keepAlive = true
                        }
                    }
                }
            }
        } // card Rectangle
    } // cardAnchor Item

    // ── Controller (unchanged component — no modifications needed) ────────
    AssistantController {
        id: controller
        onFocusPromptRequested: Qt.callLater(() => chatColumn.focusPrompt())
        onScrollRequested: (force) => Qt.callLater(() => chatColumn.scrollToEnd(force))
    }
}
