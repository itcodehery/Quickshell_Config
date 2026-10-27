# Quickshell V2 Desktop Suite

A modern, fluid, modular Wayland desktop shell environment built with [Quickshell](https://outfoxxed.github.io/quickshell/) and QtQuick / QML, designed specifically for Hyprland.

Featuring the **V2 Bar** architecture with an adaptive **Dynamic Island** (Live Activities), an expansive **Homescreen Dashboard**, a reactive notification pipeline with click-to-invoke actions, rich hardware telemetry, 3D carousel wallpaper and theme switchers, and a sensory desktop context menu.

---

## Core Highlights

### 1. Dynamic Island "Live Activities" (Island Mode)
The signature bar mode is the **Dynamic Island** capsule that rests cleanly at the top of the workspace and morphs dynamically with fluid spring physics:
- **Notification Peek Banner**: When high-priority or incoming notifications arrive (e.g. WhatsApp, Discord, Slack, Screenshot notifications), the island smoothly morphs into an expanded notification banner displaying the app badge/icon, sender title, and multi-line body snippet.
  - **Click-to-Invoke Action**: Clicking on the notification peek immediately executes the notification's native action (e.g., jumps to the WhatsApp conversation, confirms a notification test, or opens the screenshot in an image editor) and dismisses the alert.
  - **Manual Close**: A dedicated dismiss (`×`) button allows closing the peek without firing the action.
- **Hardware Privacy Glow**: An ambient bottom laser glow rendered with `MultiEffect` horizontal gradients:
  - 🟠 **Amber (`#F59E0B`)**: Microphone active / audio recording stream.
  - 🟢 **Emerald (`#10B981`)**: Webcam active / video stream.
  - 🔵 **Blue / Red (`#3B82F6`)**: Screen sharing / OBS recording active.
  - Shows a seamless tricolor split when all hardware streams are active concurrently.
- **Micro Pomodoro & Countdown Pill**: Displays a countdown ring and remaining timer directly inside the collapsed island during focus sessions.
- **System Task Progress**: Thin progress ring reflecting pending Arch Linux updates (`pacman` / `yay`) and background task completion.
- **Synced Lyrics Display**: Live synchronized karaoke lyrics stream directly through the collapsed capsule when playing tracks via MPRIS.

---

### 2. Homescreen Dashboard (`HomescreenDashboardContent.qml`)
An expansive, macOS / iOS-inspired control center that opens smoothly beneath the bar:
- **Quick Control Toggles**:
  - Wi-Fi and Bluetooth power toggles.
  - Do Not Disturb (DND) toggle.
  - Blue Light / Night Light screen temperature filter.
  - Caffeine / Idle Inhibitor (`systemd-inhibit`) to prevent system sleep.
  - Quick power and session actions (Lock, Suspend, Restart, Shutdown).
- **Expandable Detail Cards**:
  - **Volume & Mixer Card**: Master volume slider with dynamic output/input sink selection, and a full **Per-App Audio Mixer** allowing individual volume levels and mute states for each active audio client.
  - **Network & Wi-Fi Card**: Live SSID scan, signal strength metrics, IP details, and one-click connection management.
  - **Bluetooth Card**: Paired and discovered device browser with quick connect/disconnect toggles and battery percentages.
  - **Battery & Power Card**: Battery health percentage, charging status, time-to-empty, and power profile selection (Performance, Balanced, Power Saver).
  - **System & Hardware Telemetry**: Live CPU, GPU, Memory, Disk Storage, and temperature graphs.
  - **Application Screentime**: Real-time app usage tracking powered by an internal screentime daemon.

---

### 3. Notification Center (`NotificationPanel.qml`)
A complete, non-intrusive notification management system:
- **Grouped Notifications**: Messages are grouped intelligently by application with collapsible stacks and expand/collapse chevrons.
- **Interactive Gestures**: Smooth horizontal drag-and-swipe to dismiss individual notifications or entire app stacks.
- **Action Invocation**: Full D-Bus libnotify action execution (`ActionInvoked`) upon clicking any notification, seamlessly directing users to web apps, chats, or tools.
- **Polished Glass Footer**:
  - **History Mode**: Re-inspect dismissed notifications retained in local persistent storage.
  - **Do Not Disturb (DND)**: Instantly mute notification sounds and toasts.
  - **Clear All**: Refined translucent glass pill with smooth hover effects to purge pending notifications safely.
- **Suppressed Popups**: Traditional noisy desktop notification popups are suppressed in favor of the clean island peek banner and centralized widget.

---

### 4. Custom Desktop Context Menu (`DesktopContextMenu.qml`)
Right-clicking the desktop wallpaper summons an interactive menu with rich media and sensory feedback:
- **Greeting & Motivational Quotes**: Dynamic greeting (Morning, Afternoon, Evening) paired with random quotes loaded from `quotes.txt`.
- **Integrated MPRIS & Audio Visualizer**: Automatically transforms into a mini-player when music is playing, complete with album art, track information, playback controls, and a live PipeWire `cava` audio visualizer.
- **Monitor Refresh Rate Switcher**: One-click toggle between standard and high refresh rates (via `toggle-refresh-rate` and `hyprctl`).
- **Sensory Audio Feedback**: Gentle sound effect (`pop.wav`) played through PipeWire on reveal.

---

### 5. 3D Wallpaper & Theme Pickers (`ImageCarouselPanel.qml`)
Fast visual pickers featuring a 3D Hearthstone / Cover Flow card carousel:
- **Wallpaper Picker**: Browse desktop wallpapers with live previews and apply them instantly to the active workspace.
- **Theme Picker**: Switch color palettes (Kanagawa, Rise, Catppuccin, Gruvbox, etc.) across the entire shell with real-time UI theme propagation.
- **Keyboard Navigation**: Full arrow-key and search navigation.

---

### 6. Interactive Status Modules
The bar houses a suite of modular status indicators:
- **Workspaces Widget**: Workspace pill indicators with active window states.
- **System Pet (`SystemPet.qml`)**: Mood-driven desktop companion that reacts to system activity, featuring an integrated quick search launcher (`PetSearchBar.qml`).
- **Arch Updater (`ArchUpdaterWidget.qml`)**: Real-time counter for pending `pacman` and `yay` updates with an interactive changelog inspector.
- **GitHub Activity Heatmap**: Real-time contribution matrix visualization.
- **Weather Widget**: Real-time temperature, condition glyphs, and detailed forecast popups.
- **Clock & Calendar**: Multi-format time display with full month calendar view.
- **System Tray**: SNI-compatible system tray for background application icons.

---

## Directory Structure

```
~/.config/quickshell/
├── bar/
│   ├── shell.qml                     # Bar entry point
│   ├── variants/
│   │   └── V2/
│   │       ├── BarSlot.qml           # Main bar component & Dynamic Island implementation
│   │       ├── Theme.qml             # Centralized design system, palette, and live activity states
│   │       ├── VariantRoot.qml       # Panel window manager and root overlay bindings
│   │       ├── modules/              # Reusable widget components (Audio, Clock, Battery, etc.)
│   │       │   ├── SystemPet.qml     # Interactive desktop pet
│   │       │   ├── NotificationWidget.qml
│   │       │   └── ...
│   │       ├── panels/               # Full popup surfaces and detailed views
│   │       │   ├── HomescreenDashboardContent.qml  # Unified control center
│   │       │   ├── NotificationPanel.qml          # Notification center
│   │       │   ├── DesktopContextMenu.qml         # Right-click context menu
│   │       │   ├── ImageCarouselPanel.qml         # 3D theme/wallpaper picker
│   │       │   ├── LyricsPanel.qml                # Synced lyrics display
│   │       │   └── ...
│   │       └── scripts/              # Supporting Python & Bash daemons
│   └── scripts/
│       └── notif_stream.sh           # Inotify-based real-time notification streamer
├── bin/
│   ├── qs-barctl                     # IPC command-line controller
│   └── toggle-refresh-rate           # Refresh rate switching utility
├── radial/                           # Auxiliary radial launcher shell
├── screenshots/                      # Visual documentation & preview images
└── README.md                         # Project documentation
```

---

## Keybindings & Shortcuts

The following keybindings are configured in Hyprland (`~/.config/hypr/bindings.conf` / `bindings.lua`):

| Shortcut | Action | Command / Target |
| :--- | :--- | :--- |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Space</kbd> | Open Wallpaper Picker | `qs-barctl ipc picker wallpaper` |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Ctrl</kbd> + <kbd>Space</kbd> | Open Theme Picker | `qs-barctl ipc picker theme` |
| <kbd>Right Click</kbd> (Desktop) | Open Desktop Context Menu | Native desktop layer mouse trigger |
| <kbd>Click</kbd> (Island Peek) | Perform Notification Action | `quickshell ipc call notifications invoke <id>` |
| <kbd>Click</kbd> (Notification Pill) | Toggle Notification Center | Opens `NotificationPanel.qml` |

---

## Dependencies & Requirements

- **Shell Engine**: [Quickshell](https://outfoxxed.github.io/quickshell/) (`quickshell-git`)
- **Compositor**: [Hyprland](https://hyprland.org/)
- **Audio & Visualizer**: PipeWire, WirePlumber, `cava`
- **Utilities**: `jq`, `inotify-tools`, `python3`
- **Fonts**: `Genova`, Material Symbols / Material Icons
