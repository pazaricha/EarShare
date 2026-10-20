# EarShare — plan

Menu-bar macOS app (macOS 14+, Swift, SwiftUI `MenuBarExtra`, no Xcode — built with `swiftc` from Command Line Tools).

## How it works
- macOS already supports playing to many outputs at once via a **stacked aggregate device** ("Multi-Output Device").
  We create one programmatically with `AudioHardwareCreateAggregateDevice`, keys:
  `kAudioAggregateDeviceIsStackedKey = 1`, `kAudioAggregateDeviceIsPrivateKey = 0` (private aggregates cannot be the system default; stale one is cleaned up by UID on next start),
  `kAudioAggregateDeviceMainSubDeviceKey` = first selected device UID,
  sub-device list with `kAudioSubDeviceDriftCompensationKey = 1` on every non-main device.
- Set it as system default output (`kAudioHardwarePropertyDefaultOutputDevice`). Restore previous default on stop/quit.
- Per-device volume: set `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` (AudioToolbox, Float32 0..1) on each
  REAL device (not the aggregate). If not settable, the slider is disabled.
- Bluetooth: list paired-but-disconnected audio devices via IOBluetooth and offer "Connect" (`openConnection()`).

## Interface contract (both agents code against this EXACTLY)

```swift
// Sources/AudioEngine.swift  (agent A)
import CoreAudio
struct OutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isBluetooth: Bool          // transport == kAudioDeviceTransportTypeBluetooth/BluetoothLE
}
enum AudioEngineError: Error { case coreAudio(String, OSStatus), needAtLeastTwo }
final class AudioEngine {
    init()
    func outputDevices() -> [OutputDevice]                 // real output devices, excludes aggregates (incl. our own)
    func startMultiOutput(uids: [String]) throws           // creates aggregate, makes it default output; replaces an existing one
    func stopMultiOutput()                                 // restores previous default, destroys aggregate; safe to call twice
    var isRunning: Bool { get }
    func volume(of deviceID: AudioDeviceID) -> Float?      // nil = not readable
    func canSetVolume(of deviceID: AudioDeviceID) -> Bool
    func setVolume(_ v: Float, of deviceID: AudioDeviceID) // clamps 0...1
    func onDevicesChanged(_ cb: @escaping () -> Void)      // listener on kAudioHardwarePropertyDevices, cb on main queue
}

// Sources/Bluetooth.swift  (agent B)
struct PairedAudioDevice: Identifiable, Hashable { let id: String /*address*/; let name: String; let isConnected: Bool }
enum Bluetooth {
    static func pairedAudioDevices() -> [PairedAudioDevice]   // IOBluetoothDevice.pairedDevices(), audio major class 0x04
    static func connect(address: String) -> Bool              // openConnection() == kIOReturnSuccess
}
```

## Files / owners
| file | owner |
|---|---|
| Sources/AudioEngine.swift, Tests/selftest.swift | Agent A (Sonnet) |
| Sources/Bluetooth.swift, Sources/App.swift, Info.plist, build.sh | Agent B (Sonnet) |

## Order
A ∥ B → integrate & build (me) → test checklist
