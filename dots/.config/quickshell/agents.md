# End4Dots Quickshell Architecture & AI Agent Guide

This document is the "source of truth" to guide AI agents and developers through the [end4dots](https://github.com/end-4/dots) Quickshell integration (`~/.config/quickshell/ii/`).

---

## 🏗️ 1. Shell Root & Panel Families

Quickshell on this system is initialized via `shell.qml`.
- **Panel Families**: The shell supports dynamic switching of visual paradigms (currently `ii` and `waffle`).
- **Family Registration**: Declared in `panelFamilies/`. `shell.qml` uses `LazyLoader` to switch the entire desktop interface context at runtime without killing Quickshell.
- **PanelLoader Strategy**: Most visual modules inside a family (e.g., `Bar`, `Dock`, `Cheatsheet`) are wrapped in `PanelLoader`. This automatically spawns the widget across **all connected monitors**, providing built-in multi-monitor support without manually iterating `Quickshell.screens`.

---

## 🗄️ 2. Core Directories

- `modules/common/`: Shared, family-independent widgets (`StyledText.qml`, `StyledButton.qml`, `MaterialSymbol.qml`) and Singletons (`Config.qml`, `Appearance.qml`).
- `modules/ii/` and `modules/waffle/`: Visual implementations for specific desktop aesthetics. 
- `services/`: "Backend" logic written in QML structure. These interface directly with system binaries, D-Bus, or APIs.
- `scripts/`: Python and bash scripts acting as heavy-duty bridges (AI scripts, color material generation, screen snipping).
- `translations/`: JSON strings. Managed by `Translation.qml`.

---

## 🧠 3. State Management (Singletons)

All major UI interactions rely heavily on QML Singletons (pragmas).
- **`Config`**: Persistent user settings. Modifiable via `settings.qml` frontend. Access via `Config.options.param`.
- **`Directories`**: File path normalization. Always use this over hardcoded paths (e.g., `Directories.assetsPath`).
- **`Appearance`**: Material-3 inspired token system.
  - `Appearance.colors.colLayer0` (backgrounds)
  - `Appearance.font.pixelSize.normal` (fonts) 
  - Never hardcode color hexes or raw pixel sizes.
- **`GlobalStates`**: Transient booleans governing the visible state of UI components (e.g., `sidebarRightOpen`, `dictationActive`). Bound to visibility properties or `Loader.active`.
- **`Persistent`**: Values that outlive a Quickshell restart (e.g., last used Ollama model).

---

## 🔌 4. Services Deep Dive

Services live in `/services/` and abstract system logic into QML APIs:
- **`HyprlandData` / `HyprlandXkb`**: Live ingestion of Hyprland state (`activeWorkspace`, `clients`, keyboard layouts).
- **`Audio`**: Pulseaudio/Wireplumber interface for volume and sink states.
- **`Notifications`**: Desktop notification daemon integration.
- **`Ai`**: Integration with Gemini, OpenAI, Claude, and local Ollama, utilizing `ApiStrategy` traits.

---

## 🎨 5. UI Implementation Patterns

### File Declarations
Every UI QML component must begin with:
```qml
pragma ComponentBehavior: Bound
import QtQuick
```
This forces strict QML boundary checking.

### Execution & Polling
- **Fire & Forget**: Use `Quickshell.execDetached("command")`.
- **System Polling**: Use `Process {}` + `SplitParser`. 
- **Filesystem Observation**: If watching a transient file (like cache states), use `Process` triggered by a `Timer`, heavily preferred over `FileView` if the file creation/destruction lifecycle is volatile.

### OSD & IPC Patterns (Floating Overlays)
When creating floating overlays (On Screen Displays, like Volume or Dictation HUD):
1. **Lazy Loading**: Build the `PanelWindow` sourceComponent inside a `Loader`. Bind the loader's `active` property strictly to a `GlobalStates` boolean.
2. **IPC Handlers**: Instead of direct global keys, use an `IpcHandler { target: "feature" }` inside the shell so external bash scripts or hyprland binds can toggle the UI cleanly via `quickshell ipc call feature toggle`.
3. **Appearance**: Use `StyledRectangularShadow` to cast a consistent drop shadow from the inner `Rectangle` (the pill).

---

## 🐍 6. Python Integration Ecosystem

- **Virtual Environment**: Python scripts utilize an isolated quickshell venv at `~/.local/state/quickshell/`.
- Scripts interact heavily with `.cache` IPC files for low-latency state transfer into QML. 

## 🛠️ Modding Guide summary for Agents
1. Do not hardcode UI logic in `shell.qml`.
2. Add transient state to `GlobalStates.qml`.
3. Scaffold new modules inside `modules/ii/yourFeature/`.
4. Inject them into `panelFamilies/IllogicalImpulseFamily.qml` wrapped in a `PanelLoader`.
5. Expose manual control hooks via `IpcHandler`.
