import CoreAudio
import Foundation

@main struct SelfTest {
    static func check(_ c: Bool, _ msg: String) {
        if !c { print("FAIL: \(msg)"); exit(1) }
    }

    static func defaultOutputUID() -> String? {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id) == noErr else { return nil }
        var ua = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                                            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var cf: CFString? = nil
        size = UInt32(MemoryLayout<CFString?>.size)
        guard withUnsafeMutablePointer(to: &cf, { AudioObjectGetPropertyData(id, &ua, 0, nil, &size, $0) }) == noErr else { return nil }
        return cf as String?
    }

    static func uidResolves(_ uid: String) -> Bool {
        var cf: CFString = uid as CFString
        var out = AudioDeviceID(0)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let st = withUnsafeMutablePointer(to: &cf) {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, UInt32(MemoryLayout<CFString>.size), $0, &size, &out)
        }
        return st == noErr && out != 0 && out != kAudioObjectUnknown
    }

    static func main() {
        let engine = AudioEngine()
        let devs = engine.outputDevices()
        for d in devs {
            let v = engine.volume(of: d.id).map { String($0) } ?? "nil"
            print("device: \(d.name) | uid=\(d.uid) | bt=\(d.isBluetooth) | volume=\(v) | canSetVolume=\(engine.canSetVolume(of: d.id))")
        }

        do { try engine.startMultiOutput(uids: [devs.first?.uid ?? "x"]); check(false, "1 uid should throw") }
        catch AudioEngineError.needAtLeastTwo { print("ok: needAtLeastTwo thrown") }
        catch { check(false, "wrong error \(error)") }

        if devs.count >= 2 {
            let original = defaultOutputUID()
            defer { engine.stopMultiOutput() } // always restore default output
            do { try engine.startMultiOutput(uids: [devs[0].uid, devs[1].uid]) }
            catch { check(false, "start failed: \(error)") }
            check(engine.isRunning, "isRunning after start")
            check(defaultOutputUID() == AudioEngine.aggregateUID, "default output is aggregate, got \(defaultOutputUID() ?? "nil")")
            engine.stopMultiOutput()
            check(!engine.isRunning, "not running after stop")
            check(defaultOutputUID() == original, "default restored: \(defaultOutputUID() ?? "nil") vs \(original ?? "nil")")
            check(!uidResolves(AudioEngine.aggregateUID), "aggregate gone")
            engine.stopMultiOutput() // idempotent
            print("ok: aggregate start/stop")
        } else {
            print("SKIP aggregate test (need 2 outputs)")
        }
        print("SELFTEST PASS")
    }
}
