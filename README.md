<p align="center"><img src="art/hero.png" alt="EarShare: two parents watching a movie with earbuds while the kids sleep"></p>

<h1 align="center"><img src="art/AppIcon-256.png" width="96" alt=""><br>EarShare</h1>
<p align="center"><b>Two headphones. One movie. Sleeping kids.</b></p>

## Why
The kids are finally asleep, and the two of you want to watch a movie — without the TV waking anyone up.
macOS only plays sound to **one** pair of headphones at a time. EarShare plays your Mac's audio on **both of your AirPods (or any headphones and speakers) at once**, each with its own volume.

## Features
- 🍿 Two (or more) AirPods, headphones or speakers playing together
- 🔊 Separate volume for each person
- 🔗 Connect paired Bluetooth headphones right from the menu bar
- ↩️ Stop puts your normal output back
- 🧠 Remembers your last pick
- No drivers, no kernel extensions — it uses macOS's own Multi-Output Device under the hood

## Install
1. Download `EarShare.zip` from [Releases](../../releases/latest) and unzip.
2. Drag **EarShare.app** to Applications.
3. First launch: EarShare isn't notarized by Apple yet, so macOS will block it.
   Open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
   Or in Terminal: `xattr -dr com.apple.quarantine /Applications/EarShare.app`
4. Allow Bluetooth access when asked.

Requires macOS 14 (Sonoma) or later. Apple Silicon and Intel.

## Use
1. Click the 🍿 icon in the menu bar.
2. Connect both pairs of headphones (from EarShare or the Bluetooth menu).
3. Tick them → **Play on selected**.
4. Each of you sets your own volume. **Stop** when the credits roll.

## Good to know
- If an app uses an AirPods **microphone** (Zoom, FaceTime), those AirPods drop to low-quality call audio and may break the combo — use the Mac's mic instead.
- Bluetooth devices can drift a few milliseconds apart; macOS's drift correction keeps them in sync.
- If a device doesn't expose volume control, its slider is greyed out.

## Build from source
Needs only the Xcode Command Line Tools (`xcode-select --install`):
```bash
./build.sh
open build/EarShare.app
```

## License
MIT
