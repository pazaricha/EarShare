import AudioToolbox
import CoreAudio
import Foundation

struct OutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isBluetooth: Bool          // transport == kAudioDeviceTransportTypeBluetooth/BluetoothLE
}

enum AudioEngineError: Error { case coreAudio(String, OSStatus), needAtLeastTwo }

final class AudioEngine {
    static let aggregateUID = "com.paz.dualaudio.aggregate"
    private var aggregateID: AudioDeviceID?
    private var savedDefault: AudioDeviceID?
    private var listener: AudioObjectPropertyListenerBlock?

    init() {}
    deinit { stopMultiOutput() }

    var isRunning: Bool { aggregateID != nil }

    // MARK: property helpers

    private func addr(_ sel: AudioObjectPropertySelector,
                      _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                      _ el: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: el)
    }

    private func get<T>(_ obj: AudioObjectID, _ a: AudioObjectPropertyAddress, _ initial: T) -> T? {
        var a = a
        var v = initial
        var size = UInt32(MemoryLayout<T>.size)
        let st = withUnsafeMutablePointer(to: &v) { AudioObjectGetPropertyData(obj, &a, 0, nil, &size, $0) }
        return st == noErr ? v : nil
    }

    private func set<T>(_ obj: AudioObjectID, _ a: AudioObjectPropertyAddress, _ value: T) -> OSStatus {
        var a = a
        var v = value
        return withUnsafeMutablePointer(to: &v) {
            AudioObjectSetPropertyData(obj, &a, 0, nil, UInt32(MemoryLayout<T>.size), $0)
        }
    }

    private func string(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        let s: CFString?? = get(obj, addr(sel), Optional<CFString>.none)
        return (s ?? nil) as String?
    }

    private func defaultOutput() -> AudioDeviceID? {
        get(AudioObjectID(kAudioObjectSystemObject), addr(kAudioHardwarePropertyDefaultOutputDevice), AudioDeviceID(0))
    }

    private func deviceID(forUID uid: String) -> AudioDeviceID? {
        var cf: CFString = uid as CFString
        var out = AudioDeviceID(kAudioObjectUnknown)
        var a = addr(kAudioHardwarePropertyTranslateUIDToDevice)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let st = withUnsafeMutablePointer(to: &cf) {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a,
                                       UInt32(MemoryLayout<CFString>.size), $0, &size, &out)
        }
        return (st == noErr && out != kAudioObjectUnknown) ? out : nil
    }

    // MARK: devices

    func outputDevices() -> [OutputDevice] {
        var a = addr(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            var ca = addr(kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeOutput)
            var csize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &ca, 0, nil, &csize) == noErr, csize > 0 else { return nil }
            let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(csize), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { raw.deallocate() }
            guard AudioObjectGetPropertyData(id, &ca, 0, nil, &csize, raw) == noErr else { return nil }
            let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
            guard list.reduce(0, { $0 + Int($1.mNumberChannels) }) > 0 else { return nil }

            let transport: UInt32 = get(id, addr(kAudioDevicePropertyTransportType), 0) ?? 0
            // virtual loopbacks (Zoom, Teams) can't be default, and neither can an aggregate containing them
            let canDefault: UInt32 = get(id, addr(kAudioDevicePropertyDeviceCanBeDefaultDevice, kAudioDevicePropertyScopeOutput), 0) ?? 0
            guard transport != kAudioDeviceTransportTypeAggregate, canDefault != 0,
                  let uid = string(id, kAudioDevicePropertyDeviceUID),
                  let name = string(id, kAudioObjectPropertyName) else { return nil }
            let bt = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
            return OutputDevice(id: id, uid: uid, name: name, isBluetooth: bt)
        }
    }

    func onDevicesChanged(_ cb: @escaping () -> Void) {
        var a = addr(kAudioHardwarePropertyDevices)
        let sys = AudioObjectID(kAudioObjectSystemObject)
        if let old = listener { AudioObjectRemovePropertyListenerBlock(sys, &a, DispatchQueue.main, old) }
        let block: AudioObjectPropertyListenerBlock = { _, _ in cb() }
        listener = block
        AudioObjectAddPropertyListenerBlock(sys, &a, DispatchQueue.main, block)
    }

    // MARK: multi-output

    func startMultiOutput(uids: [String]) throws {
        guard uids.count >= 2 else { throw AudioEngineError.needAtLeastTwo }
        if isRunning { stopMultiOutput() }
        // leftover from a crashed run
        if let stale = deviceID(forUID: Self.aggregateUID) {
            if defaultOutput() == stale { savedDefault = nil }
            AudioHardwareDestroyAggregateDevice(stale)
        }
        let current = defaultOutput()
        savedDefault = current

        let subs: [[String: Any]] = uids.enumerated().map { i, uid in
            [kAudioSubDeviceUIDKey: uid, kAudioSubDeviceDriftCompensationKey: i == 0 ? 0 : 1]
        }
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "DualAudio",
            kAudioAggregateDeviceUIDKey: Self.aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: 0, // private aggregates can never be the system default output
            kAudioAggregateDeviceIsStackedKey: 1,
            kAudioAggregateDeviceMainSubDeviceKey: uids[0],
            kAudioAggregateDeviceSubDeviceListKey: subs,
        ]
        var agg = AudioDeviceID(0)
        let st = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &agg)
        guard st == noErr else { savedDefault = nil; throw AudioEngineError.coreAudio("create aggregate device", st) }
        aggregateID = agg

        // CoreAudio needs a moment before the new device is alive
        for _ in 0..<20 {
            let alive: UInt32 = get(agg, addr(kAudioDevicePropertyDeviceIsAlive), 0) ?? 0
            if alive != 0 { break }
            Thread.sleep(forTimeInterval: 0.05)
        }

        let sys = AudioObjectID(kAudioObjectSystemObject)
        let s1 = set(sys, addr(kAudioHardwarePropertyDefaultOutputDevice), agg)
        // verify: CoreAudio can return noErr yet leave the default unchanged
        var applied = false
        for _ in 0..<10 where s1 == noErr {
            if defaultOutput() == agg { applied = true; break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        if !applied {
            stopMultiOutput()
            throw AudioEngineError.coreAudio("set default output", s1 == noErr ? kAudioHardwareIllegalOperationError : s1)
        }
        _ = set(sys, addr(kAudioHardwarePropertyDefaultSystemOutputDevice), agg) // non-fatal
    }

    func stopMultiOutput() {
        guard let agg = aggregateID else { return }
        aggregateID = nil
        let sys = AudioObjectID(kAudioObjectSystemObject)
        if let saved = savedDefault, saved != agg, deviceExists(saved) {
            _ = set(sys, addr(kAudioHardwarePropertyDefaultOutputDevice), saved)
            _ = set(sys, addr(kAudioHardwarePropertyDefaultSystemOutputDevice), saved)
        }
        savedDefault = nil
        AudioHardwareDestroyAggregateDevice(agg)
    }

    private func deviceExists(_ id: AudioDeviceID) -> Bool {
        string(id, kAudioDevicePropertyDeviceUID) != nil
    }

    // MARK: volume

    private var volAddr: AudioObjectPropertyAddress {
        addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
    }

    func volume(of d: AudioDeviceID) -> Float? {
        if let v: Float32 = get(d, volAddr, 0) { return v }
        let vals = [0, 1, 2].compactMap { el -> Float32? in
            get(d, addr(kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, AudioObjectPropertyElement(el)), 0)
        }
        // shortcut: element 0 wins if present, else first channel; fine for stereo devices
        return vals.first
    }

    private func settable(_ d: AudioDeviceID, _ a: AudioObjectPropertyAddress) -> Bool {
        var a = a
        guard AudioObjectHasProperty(d, &a) else { return false }
        var s: DarwinBoolean = false
        return AudioObjectIsPropertySettable(d, &a, &s) == noErr && s.boolValue
    }

    func canSetVolume(of d: AudioDeviceID) -> Bool {
        if settable(d, volAddr) { return true }
        return [0, 1, 2].contains { settable(d, addr(kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, AudioObjectPropertyElement($0))) }
    }

    func setVolume(_ v: Float, of d: AudioDeviceID) {
        let c = min(max(v, 0), 1)
        if settable(d, volAddr) { _ = set(d, volAddr, Float32(c)); return }
        for el in [0, 1, 2] {
            let a = addr(kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, AudioObjectPropertyElement(el))
            if settable(d, a) { _ = set(d, a, Float32(c)) }
        }
    }
}
