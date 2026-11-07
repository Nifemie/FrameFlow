# FrameFlow Studio 🎬

[![Flutter](https://img.shields.io/badge/Flutter-Windows-02569B?logo=flutter)](https://flutter.dev)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://microsoft.com)

**FrameFlow Studio** is a fast, timeline-free desktop application for creators that turns still images and voice-over audio into synced MP4 videos with auto-calculated cuts, real-time live stamping, and bundled FFmpeg export.

---

## ✨ Key Features

- ⚡ **Timeline-Free Workflow:** Say goodbye to complex multi-track video editing software. Import your images, set your cut marks, and export.
- ⏱️ **Auto-Snapping Timing Engine:** Automatically calculates each clip's start time and duration, dynamically auto-snapping the final clip to match the exact audio length.
- 🎹 **Live Hotkey Stamping:** Play your audio preview and press `M` (or click **Stamp Cut**) in real time to split and pace images on the beat.
- 📝 **Bulk Timestamp Import/Export:** Paste or import cut timestamps in text/CSV format (`00:05`, `00:12.500`, etc.) in seconds.
- 🖼️ **Flexible Image Fit Modes:** 
  - Letterbox / Fit
  - Fill & Crop
  - Blurred Background (ambient fill)
  - Center Original
- 📐 **Multiple Export Presets:**
  - 16:9 Landscape (YouTube / Standard)
  - 9:16 Portrait (TikTok / Shorts / Reels)
  - 1:1 Square (Instagram)
  - 720p, 1080p Full HD, and 4K Ultra HD at 24, 30, or 60 FPS.
- 💾 **Project Persistence:** Save and open `.frameflow` project files with automatic crash/autosave recovery (`Ctrl+S`, `Ctrl+O`, `Ctrl+N`).
- 📦 **100% Offline & Bundled:** Operates entirely locally on your machine with no cloud dependencies or API keys required.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (v3.24+ recommended)
- Visual Studio 2022 with "Desktop development with C++" workload
- FFmpeg binaries placed in `assets/bin/` (`ffmpeg.exe` and `ffprobe.exe`)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/Nifemie/FrameFlow.git
   cd FrameFlow
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run in Debug mode:
   ```bash
   flutter run -d windows
   ```

4. Build Release:
   ```bash
   flutter build windows --release
   ```

---

## 🛠️ Architecture

FrameFlow Studio is built with Flutter and follows clean single-responsibility modular architecture:

- `lib/core/engine/`: `TimingEngine` and `TimeParser` for frame-accurate millisecond calculations.
- `lib/core/services/`: `FFmpegService` for filtergraph rendering, `AudioProbeService` for fast audio metadata inspection, and `ProjectStorageService` for project persistence.
- `lib/features/`: Modular UI separated into Media Bin, Preview Player, Timeline Container, Clip Inspector, and Top Navigation.

---

## 📄 License

This project is licensed under the Apache 2.0 License.
