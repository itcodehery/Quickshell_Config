# Quickshell V2 Config

This repository contains my configuration for [Quickshell](https://outfoxxed.github.io/quickshell/), upgraded to the **V2 Bar** architecture.

## What is the V2 Bar?

The V2 Bar is a complete overhaul of the original (V1) quickshell setup. While it maintains the previous panel functionalities (such as Battery, Bluetooth, CPU, Network, etc.), the V2 architecture introduces a new modular component structure located under `bar/variants/V2`. It allows for richer customization and adds several new monitoring widgets and panels that expand the capabilities of the desktop shell.

## New Changes in V2

The V2 update brings a variety of new features and specialized panels:

- **GPU & Thermals Monitoring**: Added new panels (`GpuPanel.qml` and `ThermalsPanel.qml`) to keep track of system temperatures and graphics performance.
- **Storage Panel**: A dedicated `StoragePanel.qml` to monitor disk usage.
- **Power Notch**: A new notch-style panel (`PowerNotchPanel.qml`) specifically designed for power management.
- **Enhanced UI Modularization**: Improved separation of concerns, providing a highly customizable framework built on modular QML variants.
- **Custom Desktop Context Menu**: A fully customized, feature-rich right-click menu tailored for the desktop environment.

## Custom Right-Click Menu

One of the highlight features of the V2 config is the custom-built **Desktop Context Menu** (`DesktopContextMenu.qml`), which activates upon right-clicking the desktop. It is built to be both aesthetically pleasing and highly functional:

- **Dynamic Info Bubble**: Displays a time-based greeting (e.g., "Good Morning") alongside a random motivational quote (pulled from `quotes.txt`).
- **Media Integration**: When media is playing, the quote bubble automatically transforms into an MPRIS media player showing scrolling track title, artist info, and playback controls.
- **Audio Visualizer**: Integrates directly with `cava` (using PipeWire) to display a live audio visualization within the menu itself when music is playing.
- **System Stats**: Dynamically fetches and displays current monitor refresh rates using `hyprctl`.
- **Sensory Feedback**: Features smooth reveal animations and plays a subtle sound effect (`pop.wav`) upon opening.
