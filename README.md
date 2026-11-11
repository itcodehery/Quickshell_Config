# Quickshell V2 Desktop Suite

A modern, fluid, modular Wayland desktop shell suite built with [Quickshell](https://outfoxxed.github.io/quickshell/) and QtQuick / QML for Hyprland.

Every component in the repository is organized into categorized folders with strictly modular files (< 1,000 lines per file), unified theme synchronization via Omarchy (`colors.toml`), and zero-downtime hot-swappable updates.

---

## Complete Feature List

### 1. Adaptive Bar & Dynamic Island (`bar/variants/V2/bar/`)
- **Multi-Monitor Bar & Recovery (`VariantRoot.qml`, `BarSlot.qml`)**:
  - Automatically binds a bar instance to each active Wayland output, ignores transient 0×0 placeholder screens, and recovers individual layer-shell windows on `resourcesLost` / `closed` without restarting the shell.
  - Supports **Island Mode** (floating center capsule) and **Full Bar Mode**, configurable per-edge (`top` / `bottom`) with live drag-and-drop widget slot reordering (`BarSlotRow.qml`, `BarSlotRegistry.qml`) and persistent layout state.
- **Dynamic Island "Live Activities" (`BarSlotIsland.qml`, `BarSlotIslandOverlays.qml`, `BarSlotCollapsedContent.qml`)**:
  - **Window Title & Synced Lyrics Ticker**: Smoothly crossfades active window titles or real-time synchronized karaoke lyrics (`lrclib.net` / local `.lrc`) when music is playing.
  - **Inline OSD Capsule**: Morphs into an inline volume or screen brightness progress bar with animated icons (`osd-action.sh`).
  - **Notification Peek Banner**: Expands with spring physics on incoming high-priority notifications (WhatsApp, Discord, Slack, Screenshot alerts), supporting **Click-to-Invoke** (`ActionInvoked`) and manual dismiss (`×`).
  - **Voice Dictation & Recording Pill (`VoxtypeWidget.qml`)**: Live 3-bar theme-accent waveform during speech-to-text listening and transcribing states.
  - **Battery Charging Animation**: Morphing charging indicator when AC power is connected.
  - **Micro Pomodoro & Stopwatch Pill**: Live countdown ring and remaining timer inside the collapsed island.
  - **Hardware Privacy Dots & Ambient Glow (`PrivacyDots.qml`, `privacy_probe.sh`)**:
    - 🟠 **Amber (`#F59E0B`)**: Microphone active / audio input stream.
    - 🟢 **Emerald (`#10B981`)**: Webcam active / video capture stream.
    - 🔵 **Blue / Red (`#3B82F6`)**: Screen sharing / PipeWire screen recording active.

---

### 2. Hover Quick Settings & Omarchy Control Center (`bar/variants/V2/panels/quicksettings/`)
- **Dual-Mode Hover Panel (`HoverQuickSettingsPanel.qml`)**:
  - **Standard Quick Settings View (`HoverQuickSettingsStandardView.qml`, `HoverQuickSettingsMediaCard.qml`)**:
    - 2×2 quick toggles grid (Wi-Fi, Bluetooth, Do Not Disturb, Idle Inhibitor / Caffeine).
    - Live Screen Time usage summary card and pending Updates / Notes quick cards.
    - Integrated MPRIS media player card with artwork, track controls, and seek bar.
  - **Omarchy Control Center View (`HoverQuickSettingsOmarchyView.qml`, `HoverQuickSettingsSystemInfoTab.qml`)**:
    - Quick launcher actions, shell style switcher, and full-height interactive GitHub contribution heatmap.
    - Dedicated **System Info Tab** displaying CPU model/cores, RAM breakdown, GPU card info, and display resolution/refresh rate.
- **Classic Control & Power Panels (`ControlPanel.qml`, `PowerNotchPanel.qml`)**:
  - Quick session controls (Lock, Suspend, Reboot, Shutdown) with keyboard navigation.

---

### 3. Homescreen Dashboard (`bar/variants/V2/panels/homescreen/`)
An expansive, multi-page control center docked directly into the bar (`HomescreenDashboardContent.qml`):
- **Top Controls & Sliders (`HomescreenTopControls.qml`)**:
  - Smooth brightness and master volume sliders, Night Light / Blue Light filter toggle, and interactive tile-edit mode.
- **Customizable Paged Tile Grid (`HomescreenTilesPager.qml`, `DashboardTile.qml`, `HomescreenHelpers.js`)**:
  - Multi-page flickable dashboard tiles with drag-and-drop reordering, size customization, and keyboard navigation.
- **Material You Media Player & Synced Lyrics Drawer (`HomescreenMediaLyricsCard.qml`, `HomescreenLyricsDrawer.qml`)**:
  - Multi-player MPRIS switcher (Spotify, browsers, local players), marquee title, animated wavy seekable progress bar, and expandable live-synced lyrics drawer.
- **Aesthetic Clock & Pomodoro Modal (`HomescreenClockWidget.qml`, `HomescreenPomodoroPopup.qml`)**:
  - Live time/date card with a visual day-completion progress bar and a full Pomodoro focus timer modal with custom duration presets.

---

### 4. Expandable Dashboard Detail Sections (`bar/variants/V2/panels/details/`)
Clicking any dashboard tile or sidebar item opens a two-column detail view (`HomescreenDetailOverlay.qml`):
- **Wi-Fi & Cloudflare Speed Test (`WifiDetailSection.qml`, `WifiDetailRightColumn.qml`, `CloudflareSpeedTest.qml`)**:
  - Live SSID scanner, signal strength, frequency band (2.4 / 5 GHz), inline password prompt for secured networks, saved network management, and an integrated **Cloudflare Speed Test** with an animated ignition tachometer sweep (Download, Upload, Ping, and Edge location).
- **Bluetooth Manager (`BluetoothDetailSection.qml`, `BluetoothDetailRightColumn.qml`)**:
  - Connected device hero spotlight (with custom headphone vector artwork and inline battery gauge), plus Paired and All devices tabs with one-click Connect, Disconnect, Pair, and Forget actions.
- **Volume, Per-App Mixer & Mic Peak Meter (`VolumeDetailSection.qml`, `VolumeDetailRightColumn.qml`, `MicrophonePeakMonitor.qml`)**:
  - Master output slider, **Per-App PipeWire Audio Mixer** (individual volume sliders and mute buttons per playing app), real-time **Microphone Input Peak Meter** (-55 dB noise floor), and output sink quick switcher.
- **Battery & Power Profiles (`BatteryDetailSection.qml`)**:
  - Battery percentage, charge/discharge wattage rate, battery health %, cycle count, power profile selector (Performance, Balanced, Power Saver), and top CPU process killer.
- **CPU & Memory Telemetry (`CpuDetailSection.qml`, `MemoryDetailSection.qml`)**:
  - Per-core and aggregate CPU/RAM usage graphs, temperature readouts, swap telemetry, and interactive top-process tables with one-click process termination.
- **Application Screen Time (`ScreentimeDetailSection.qml`, `screentime_daemon.py`)**:
  - Daily and historical per-application usage breakdown tracked by a lightweight background daemon.
- **System & Lock Screen Settings (`SystemDetailSection.qml`, `LockscreenDetailSection.qml`)**:
  - Session power actions and live customization of lock screen clock typography, weather, and bento widget visibility.

---

### 5. Productivity, Notes, Calendar & Notifications (`bar/variants/V2/panels/productivity/`)
- **Calendar & Date Reminders (`CalendarDetailSection.qml`, `CalendarDetailMonthlyGrid.qml`, `CalendarDetailNotesColumn.qml`)**:
  - 42-day monthly calendar grid paired with per-date persistent notes, reminders, and quick date navigation.
- **Markdown Notes & Scratchpad (`NotesDetailSection.qml`, `NotesDetailEditor.qml`, `NotesPanel.qml`)**:
  - Multi-note manager with full-text search, pinning, color tags, word/character counts, and instant auto-save.
- **Notification Center (`NotificationDetailSection.qml`, `get_notifications.py`, `notif_stream.sh`)**:
  - Application-grouped notification stacks, horizontal swipe-to-dismiss gestures, D-Bus `ActionInvoked` click handling, History view for dismissed alerts, Do Not Disturb (DND), and Clear All.
- **Weather & GitHub Activity Panels (`WeatherPanel.qml`, `GithubHeatmapPanel.qml`)**:
  - Detailed local weather forecast and theme-tinted GitHub contribution matrix.

---

### 6. Arch Linux, Theme & Shell Update Center (`bar/variants/V2/panels/updates/`, `bin/`)
- **Unified Update Inspector (`ArchUpdaterPanel.qml`, `ArchUpdaterHeader.qml`, `UpdatesDetailSection.qml`)**:
  - **Packages Tab (`ArchUpdaterPackagesTab.qml`)**: Tracks pending official (`pacman`) and AUR (`yay`) updates, AUR blacklist/safety gates, and launches supervised terminal upgrades.
  - **Themes Tab (`ArchUpdaterThemesTab.qml`, `qs-theme-update-check.sh`, `qs-theme-apply-update.sh`)**: Checks git status across installed Omarchy themes and applies clean fast-forward updates.
  - **Shell Update Tab (`ShellUpdateTab.qml`, `qs-shell-check-update.sh`, `qs-shell-apply-update.sh`, `qs-shell-apply-update-lib.sh`)**: Single-flight atomic shell updater with commit lineage verification, staged Quickshell smoke testing, companion systemd unit snapshotting, and automatic rollback on failure.

---

### 7. 3D Wallpaper, Theme & Media Pickers (`bar/variants/V2/panels/appearance/`, `panels/media/`)
- **4-Stage Visual Switchers (`ThemeWallpaperSwitcher.qml`, `ThemeWallpaperStage.qml`, `ImageCarousel*.qml`, `MediaBrowser*.qml`)**:
  - Browse and apply Omarchy themes, desktop wallpapers, and local screenshots/recordings across four visual stage layouts:
    1. **Tanzaku** (vertical hanging strips)
    2. **Hearthstone** (3D tilted card hand)
    3. **Carousel / Cover Flow** (3D perspective slices)
    4. **Gravemind** (grid/deck layout)
  - Full keyboard arrow navigation, fuzzy search filtering, and live theme palette propagation (`Palette.js`).
- **Standalone Media & Lyrics Popups (`MprisPanel.qml`, `LyricsPanel.qml`)**:
  - Dedicated floating MPRIS controller and synchronized lyrics viewer.

---

### 8. Plugins Manager, Overlays & Desktop Context Menu (`bar/variants/V2/panels/plugins/`, `panels/overlays/`)
- **Omarchy Plugins Manager & Corner Drawer (`PluginsDetailSection.qml`, `PluginsDetailSpotlight.qml`, `PluginsDrawer.qml`, `PluginsCornerHotspot.qml`)**:
  - Manage, pin, and configure shell plugins and trigger quick tools from a screen-corner hotspot drawer.
- **Sensory Desktop Context Menu (`DesktopContextMenu.qml`, `DesktopContextMenuListCard.qml`)**:
  - Right-click desktop menu featuring dynamic time-of-day greetings, random motivational quotes (`bar/assets/data/quotes.txt`), quick web/AI app shortcuts (WhatsApp, Spotify, Gemini, Claude, Zen), an integrated MPRIS mini-player, monitor refresh-rate toggle (`toggle-refresh-rate`), and PipeWire audio feedback (`bar/assets/audio/pop.wav`).
- **Workspace, System Tray & Screen Overlays (`WorkspacePanel.qml`, `TrayPanel.qml`, `TrayMenu.qml`, `ScreenCornersOverlay.qml`, `TooltipOverlay.qml`)**:
  - Workspace overview popup, SNI system tray drawer and context menus, rounded screen corners overlay, and shared hover tooltips.

---

### 9. Modular Bar Widgets (`bar/variants/V2/modules/`)
44 modular bar widgets organized by domain:
- **System (`modules/system/`)**: `CpuWidget`, `CpuTemperatureWidget`, `MemoryWidget`, `GpuWidget`, `StorageWidget`, `BatteryWidget`, `PowerProfileWidget`, `BrightnessWidget`, `IdleInhibitorWidget`, `IdleWidget`.
- **Connectivity (`modules/connectivity/`)**: `NetworkWidget`, `BluetoothWidget`, `CloudflareSpeedTest`.
- **Media & Voice (`modules/media/`)**: `AudioWidget`, `AudioData`, `MprisWidget`, `MprisArtwork`, `MprisSelect`, `MediaBrowserWidget`, `ScreenRecordWidget`, `VoxtypeWidget`.
- **Productivity & AI (`modules/productivity/`)**: `ClockWidget`, `WeatherWidget`, `NotesWidget`, `ScreentimeWidget`, `GithubHeatmapWidget`, `ClaudeWidget` (Claude / OpenCode / Codex AI token & cost telemetry), `ArchUpdaterWidget`, `UpdateWidget`.
- **Shell & Companion (`modules/shell/`)**: `WorkspaceWidget`, `LauncherWidget`, `TrayWidget`, `NotificationWidget`, `NotificationSilenceWidget`, `PluginsDrawerWidget`, `ThemeDisplayWidget`, `SystemPet` (mood-reactive desktop pet), `PetSearchBar` (web/YouTube/Claude/GitHub/calculator launcher with `SearchCalc.js`).
- **Common Primitives (`modules/common/`)**: `IconText`, `UiText`, `TooltipMixin`, `PillShadow`, `PanelPointer`, `ConnectedBarInset`, `ConnectedPanelSurface`, `ConnectedTabCard`, `AiBarInset`, `AiPanelSurface`.

---

### 10. Bento Lock Screen (`lock/`)
Launched via `bin/qs-lock` (`qs -c lock`):
- **Frosted Workspace Depth (`LockBackground.qml`)**: Captures a live `grim` workspace snapshot with multi-pass blur, vignette, and smooth zoom/fade entrance & unlock transitions.
- **Greeting & Synced Lyrics Header (`LockHeader.qml`, `LockLyrics.js`)**: Time-of-day greeting that morphs into a live-synced karaoke lyrics banner when music is playing.
- **6-Tile Bento Grid**:
  - **Tile 1 & 2 (`LockClockWeather.qml`)**: Stacked/inline display clock and conversational weather forecast card.
  - **Tile 3 (`LockMediaTile.qml`)**: MPRIS media player with album art, marquee title, and animated wavy seekable progress bar.
  - **Tile 4 (`LockCalendarTile.qml`)**: Interactive week calendar ribbon with scroll navigation and "Jump to Today".
  - **Tile 5 & 6 (`LockSystemTiles.qml`)**: Battery/charging status card and live CPU, RAM, and Screen Time telemetry card.
- **PAM Authentication Pill (`LockPasswordPill.qml`)**: Breathing idle state, animated typing dots, verifying spinner, and error shake animation backed by `Quickshell.Services.Pam`.

---

### 11. Auxiliary Shells: Radial Workspace Switcher (`radial/`) & Cursor Dot (`cursor-dot/`)
- **Radial Workspace Switcher (`radial/shell.qml`, `radial/components/WorkspaceCard.qml`)**:
  - Summoned via `radial/toggle.sh` (<kbd>Super</kbd> + <kbd>Z</kbd> or mouse side button), rendering a circular radial menu of active Hyprland workspaces with window lists and hover/click switching.
- **Shake-to-Find Cursor Dot (`cursor-dot/shell.qml`, `cursor-dot/scripts/tracker.py`, `CursorDotOverlay.qml`)**:
  - Tracks pointer velocity and enlarges a high-visibility cursor overlay when shaking the mouse to locate the cursor across monitors.

---

## Categorized Directory Structure

```text
~/.config/quickshell/
├── bar/
│   ├── shell.qml                             # Bar entry point
│   ├── assets/                               # Categorized bar-wide assets
│   │   ├── audio/                            # UI sound effects (pop.wav, pop.mp3, pop.ogg)
│   │   ├── data/                             # Quotes database (quotes.txt)
│   │   └── icons/                            # App & AI SVG icons (claude, gemini, spotify, etc.)
│   ├── core/                                 # Core bootstrap, IPC router, state & variant host
│   ├── scripts/                              # Python & Bash telemetry/notification helpers
│   └── variants/
│       └── V2/
│           ├── VariantRoot.qml               # Multi-screen window manager & lazy panel host
│           ├── qmldir                        # V2 root module type registry
│           ├── assets/                       # V2 hardware & launcher vector/raster assets
│           ├── bar/                          # BarSlot, Dynamic Island, overlays & slot rows
│           ├── modules/                      # Categorized bar status widgets
│           │   ├── qmldir                    # Module type registry
│           │   ├── common/                   # Shared UI primitives, surfaces, shadows & mixins
│           │   ├── connectivity/             # Network, Bluetooth & Cloudflare speed test
│           │   ├── media/                    # Audio, MPRIS, screen record & Voxtype dictation
│           │   ├── productivity/             # Clock, Weather, Notes, Screentime, GitHub, AI, Updates
│           │   ├── shell/                    # Workspaces, Launcher, Tray, Notifications, SystemPet
│           │   └── system/                   # CPU, Temp, RAM, GPU, Storage, Battery, Brightness
│           ├── motion/                       # Spring physics & press animations
│           ├── panels/                       # Categorized popup panels & dashboard sections
│           │   ├── qmldir                    # Panel type registry
│           │   ├── appearance/               # 3D Theme & Wallpaper switchers & carousels
│           │   ├── details/                  # Wi-Fi, Bluetooth, Volume, Battery, CPU, RAM details
│           │   ├── homescreen/               # Homescreen dashboard, tiles pager, clock & media cards
│           │   ├── media/                    # Floating MPRIS, Lyrics & Media Browser popups
│           │   ├── overlays/                 # Desktop Context Menu, Tray, Workspaces & screen overlays
│           │   ├── plugins/                  # Omarchy Plugins detail view & corner hotspot drawer
│           │   ├── productivity/             # Calendar, Notes, Notifications, Weather & GitHub panels
│           │   ├── quicksettings/            # Hover Quick Settings & Omarchy Control Center
│           │   └── updates/                  # Arch package, Omarchy theme & QS-Shell update panels
│           ├── scripts/                      # V2 background screentime daemon
│           ├── shaders/                      # Compiled QtQuick fragment shaders (.qsb)
│           ├── theme/                        # Modular Theme state, workers & palette parser
│           └── utils/                        # Shared icon map & Omarchy power/backlight helpers
├── bin/                                      # CLI controllers & atomic update scripts
│   ├── qs-barctl                             # Bar lifecycle & IPC command-line controller
│   ├── qs-lock                               # Lock screen launcher with workspace snapshot
│   ├── qs-project-ctl                        # Project controller utility
│   ├── qs-shell-check-update.sh              # Shell update checker
│   ├── qs-shell-apply-update.sh              # Atomic shell updater
│   ├── qs-shell-apply-update-lib.sh          # Companion rollback & staged smoke-test library
│   ├── qs-theme-update-check.sh              # Omarchy theme update checker
│   ├── qs-theme-apply-update.sh              # Omarchy theme updater
│   └── toggle-refresh-rate                   # Monitor refresh rate switcher
├── cursor-dot/                               # Shake-to-locate cursor overlay shell
│   ├── shell.qml
│   ├── assets/                               # Cursor vector icon
│   └── scripts/                              # Mouse velocity & shake tracker daemon
├── lock/                                     # Bento Wayland session lock screen
│   ├── shell.qml                             # Lock screen entry point & PAM controller
│   ├── config.json                           # Lock screen widget configuration
│   ├── components/                           # Modular Bento tiles, header, background & PAM pill
│   └── utils/                                # Track title cleaner & LRC lyrics fetcher
├── radial/                                   # Radial workspace switcher shell
│   ├── shell.qml                             # Radial menu entry point
│   ├── qmldir                                # Radial module registry
│   ├── toggle.sh                             # Toggle helper script
│   └── components/                           # Radial Theme singleton & WorkspaceCard
├── screenshots/                              # Visual previews & documentation screenshots
└── README.md                                 # Project documentation
```

---

## Keybindings & CLI Shortcuts

| Shortcut | Action | Command / Target |
| :--- | :--- | :--- |
| <kbd>Alt</kbd> + <kbd>Space</kbd> | Toggle Homescreen Dashboard | `qs-barctl ipc layout toggledashboard` |
| <kbd>Super</kbd> + <kbd>N</kbd> | Open Notifications Detail | `qs-barctl ipc layout opendetail notifications` |
| <kbd>Super</kbd> + <kbd>Escape</kbd> | Open System / Power Menu | `qs-barctl ipc layout opendetail system` |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Space</kbd> | Open Wallpaper Picker | `qs-barctl ipc picker wallpaper` |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Ctrl</kbd> + <kbd>Space</kbd> | Open Theme Picker | `qs-barctl ipc picker theme` |
| <kbd>Super</kbd> + <kbd>Z</kbd> | Toggle Radial Workspace Menu | `~/.config/quickshell/radial/toggle.sh` |
| <kbd>Right Click</kbd> (Desktop) | Open Desktop Context Menu | Native desktop layer mouse trigger |

---

## Dependencies & Requirements

- **Shell Engine**: [Quickshell](https://outfoxxed.github.io/quickshell/) (`quickshell-git`)
- **Compositor**: [Hyprland](https://hyprland.org/)
- **Audio & Visualizer**: PipeWire, WirePlumber, `pactl`, `wpctl`, `cava`
- **Utilities**: `jq`, `inotify-tools`, `python3`, `grim`, `brightnessctl`, `upower`, `bluetoothctl`, `nmcli`
- **Fonts**: `Genova`, `JetBrainsMono Nerd Font`, `Bigger Display`, Material Symbols Rounded
