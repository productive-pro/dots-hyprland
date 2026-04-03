✦ Quickshell uses a Python virtual environment in ~/.local/state/quickshell (often referred to as $ILLOGICAL_IMPULSE_VIRTUAL_ENV in the scripts) to handle complex tasks
  that require third-party Python libraries.

  Here is why it exists and why that specific location is used:

  1. Dependency Management
  Several core features of this configuration rely on Python scripts that require external packages:
   - Material You Color Generation: Uses the materialyoucolor package to generate dynamic M3 color schemes from your wallpapers.
   - Image Analysis: Uses opencv-python (cv2) and numpy for colorfulness detection (to choose between neutral or tonal-spot schemes) and finding "least busy" regions on
     the wallpaper to place widgets.
   - Hyprland Integration: Scripts like get_keybinds.py and hyprconfigurator.py parse and manage Hyprland configurations.

  Using a virtual environment ensures these dependencies (which aren't usually available as system-wide packages on all distros) are isolated and don't interfere with
  your system's global Python installation.

  2. XDG Standards Compliance
  The choice of ~/.local/state/quickshell follows the XDG Base Directory Specification:
   - ~/.config/quickshell: Stores your static configuration files (QML, JSON settings).
   - ~/.cache/quickshell: Stores temporary data like thumbnails or favicons.
   - ~/.local/state/quickshell: Stores persistent state data that should survive reboots but isn't a configuration, such as:
       - The Python virtual environment.
       - Generated color schemes (user/generated/material_colors.scss).
       - User data like your todo.json, notes.txt, and AI chat history.

  This separation keeps your configuration directory clean and ensures that user-generated data and the runtime environment are stored in the appropriate system location
  for persistent state.
