# 🎧 DualAudio

Play your Mac's sound on **two (or more) AirPods, headphones or speakers at the same time** — with a separate volume slider for each one.

A tiny menu-bar app. No drivers, no kernel extensions: it uses macOS's built-in Multi-Output Device under the hood, so you don't have to fiddle with Audio MIDI Setup.

## Features
- ✅ Combine any outputs: AirPods + AirPods, AirPods + speakers, Bose + JBL…
- 🔊 Independent volume per device
- 🔗 Connect paired Bluetooth headphones right from the menu
- ↩️ Stop restores your previous output
- Remembers your last selection

## Install
1. Download `DualAudio.zip` from [Releases](../../releases/latest) and unzip.
2. Drag **DualAudio.app** to Applications.
3. First launch: the app isn't notarized by Apple yet, so macOS will block it.
   Open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
   Or in Terminal: `xattr -dr com.apple.quarantine /Applications/DualAudio.app`
4. Allow Bluetooth access when asked.

Requires macOS 14 (Sonoma) or later. Apple Silicon and Intel.

## Use
1. Click 🎧 in the menu bar.
2. Connect your headphones (from the app or the Bluetooth menu).
3. Tick two or more outputs → **Play on selected**.
4. Adjust each slider. **Stop** when done.

## Good to know
- If an app uses an AirPods **microphone** (Zoom, FaceTime), those AirPods drop to low-quality call audio and may break the combo — use the Mac's mic instead.
- Bluetooth devices can drift a few milliseconds apart; macOS's drift correction keeps them in sync.
- If a device doesn't expose volume control, its slider is greyed out.

## Build from source
Needs only the Xcode Command Line Tools (`xcode-select --install`):
```bash
./build.sh
open build/DualAudio.app
```

## License
MIT
