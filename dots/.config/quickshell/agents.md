# Quickshell Configuration Guide for AI Agents

This document outlines the architecture, coding patterns, and directory conventions for the `illogical-impulse` (ii) and `waffle` shell configurations. Use this to maintain consistency, reusability, and maintainability.

---

## 🏗️ Architecture

### 1. Global Singletons
The shell relies heavily on QML Singletons for state management and services. Always check existing singletons before implementing new logic.

- **`Config`**: Global settings handler. Access options via `Config.options`.
- **`Directories`**: Centralized path definitions. Use this instead of hardcoding paths.
- **`Appearance`**: Centralized styling (colors, fonts, animations, sizes).
- **`Persistent`**: State that survives restarts (e.g., current AI model, widget positions).
- **`GlobalStates`**: Transient UI states (e.g., is the sidebar open?).
- **`Translation`**: Localization service. Always wrap user-facing strings in `Translation.tr("string")`.

### 2. Services (`ii/services/`)
Services are singletons that interface with the system or provide complex logic:
- **`Ai`**: LLM integration.
- **`Audio`**: Volume and player controls.
- **`HyprlandData`**: Real-time Hyprland state (workspaces, windows).
- **`Notifications`**: Desktop notification management.

---

## 📂 Directory Structure

- `ii/`: Root for the "Illogical Impulse" configuration.
  - `assets/`: Icons and images.
  - `modules/`: UI components and sub-modules.
    - `common/`: Reusable singletons and functions.
    - `ii/`: Components specific to the "ii" family.
  - `scripts/`: Bash and Python scripts.
  - `services/`: Core logic singletons.
  - `translations/`: JSON translation files.

---

## 🎨 Coding Patterns

### 1. File Headers
Always use `pragma Singleton` for services/config and `pragma ComponentBehavior: Bound` for all QML files to ensure type safety and performance.

```qml
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
```

### 2. Styling (Appearance)
Never hardcode colors or sizes. Use `Appearance.colors`, `Appearance.font`, and `Appearance.sizes`.

```qml
Rectangle {
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.normal
    Text {
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.normal
        color: Appearance.colors.colOnLayer1
    }
}
```

### 3. File Paths
Always use `Directories` for system paths and `Quickshell.shellPath()` for internal assets.

```qml
property string icon: Quickshell.shellPath("assets/icons/spark-symbolic.svg")
property string todoFile: Directories.todoPath
```

### 4. System Commands
Use `Quickshell.execDetached()` for one-off commands and the `Process` component for commands requiring output handling.

```qml
Process {
    id: myProc
    command: ["ls", "-la"]
    stdout: StdioCollector {
        onStreamFinished: console.log(text)
    }
}
```

### 5. Translations
Wrap all literal strings.
```qml
text: Translation.tr("Hello World")
```

### 6. OSD & IPC Patterns
When creating floating overlays (On Screen Displays), follow the established `Loader` + `PanelWindow` + `IpcHandler` pattern:
1. **Lazy Loading**: Wrap `PanelWindow` in a `Loader` driven by a `GlobalStates` boolean to save resources and avoid stealing focus when hidden.
2. **IPC Triggering**: Use `IpcHandler` to expose `show()`, `hide()`, and `toggle()` methods to bash scripts (e.g. `quickshell ipc call dictation toggle`).
3. **Polling vs Watchers**: If reading transient state files (e.g., in `~/.cache/`), prefer using `Process` triggered by a `Timer` rather than `FileView`, as `FileView` fails if the file doesn't exist at startup.

---

## 🐍 Python & Scripts

- **Virtual Env**: A Python venv is located at `~/.local/state/quickshell`.
- **Environment Variable**: Scripts use `$ILLOGICAL_IMPULSE_VIRTUAL_ENV` to find this venv.
- **Usage**: Use Python for complex logic like image processing (`opencv`), color generation, or advanced parsing.

---

## 🛠️ Development Workflow for Agents

1. **Research**: Check `Directories.qml` and `Config.qml` to see if your feature already has a place for configuration.
2. **Implementation**:
   - Use `ii/modules/common/widgets/` for UI building blocks.
   - Use `ii/services/` for logic.
   - Keep UI and logic separate.
3. **Consistency**: Follow the Material 3 (M3) naming conventions found in `Appearance.m3colors`.
4. **Validation**: Ensure scripts are executable and handle errors gracefully (especially `Process` exits).
