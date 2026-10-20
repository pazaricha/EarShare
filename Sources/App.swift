import SwiftUI
import CoreAudio

@MainActor
final class Model: ObservableObject {
    private static let key = "selectedUIDs"
    let engine = AudioEngine()
    @Published var devices: [OutputDevice] = []
    @Published var selected: Set<String> = Set(UserDefaults.standard.stringArray(forKey: Model.key) ?? [])
    @Published var volumes: [AudioDeviceID: Float] = [:]
    @Published var paired: [PairedAudioDevice] = []
    @Published var connecting: Set<String> = []
    @Published var running = false
    @Published var playingCount = 0
    @Published var error: String?

    init() {
        engine.onDevicesChanged { [weak self] in Task { @MainActor in self?.refresh() } }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.stopMultiOutput() }
        }
        refresh()
    }

    func refresh() {
        devices = engine.outputDevices()
        volumes = Dictionary(uniqueKeysWithValues: devices.compactMap { d in engine.volume(of: d.id).map { (d.id, $0) } })
        paired = Bluetooth.pairedAudioDevices().filter { !$0.isConnected }
        running = engine.isRunning
    }

    var selectedUIDs: [String] { devices.filter { selected.contains($0.uid) }.map(\.uid) }

    func toggle(_ uid: String, _ on: Bool) {
        if on { selected.insert(uid) } else { selected.remove(uid) }
        UserDefaults.standard.set(Array(selected), forKey: Model.key)
    }

    func setVolume(_ v: Float, _ d: OutputDevice) {
        volumes[d.id] = v
        engine.setVolume(v, of: d.id)
    }

    func start() {
        let uids = selectedUIDs
        do {
            try engine.startMultiOutput(uids: uids)
            playingCount = uids.count
            error = nil
        } catch { self.error = "\(error)" }
        running = engine.isRunning
    }

    func stop() { engine.stopMultiOutput(); running = engine.isRunning }

    func connect(_ d: PairedAudioDevice) {
        connecting.insert(d.id)
        Task {
            let ok = await Task.detached { Bluetooth.connect(address: d.id) }.value
            connecting.remove(d.id)
            if !ok { error = "Could not connect \(d.name)" }
            refresh()
        }
    }

    func quit() { engine.stopMultiOutput(); NSApp.terminate(nil) }
}

@main
struct DualAudioApp: App {
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra("DualAudio", systemImage: "headphones") {
            ContentView().environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Outputs").font(.headline)
            ForEach(model.devices) { d in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Toggle(isOn: Binding(get: { model.selected.contains(d.uid) }, set: { model.toggle(d.uid, $0) })) {
                            Text(d.name).lineLimit(1)
                        }
                        if d.isBluetooth {
                            Text("BT").font(.caption2).padding(.horizontal, 4)
                                .background(Color.blue.opacity(0.2), in: Capsule())
                        }
                    }
                    Slider(value: Binding(get: { Double(model.volumes[d.id] ?? 0) },
                                          set: { model.setVolume(Float($0), d) }), in: 0...1)
                        .disabled(!model.engine.canSetVolume(of: d.id))
                }
            }

            if model.running {
                HStack {
                    Text("▶︎ Playing on \(model.playingCount) devices")
                    Spacer()
                    Button("Stop") { model.stop() }
                }
            } else {
                Button("Play on selected (\(model.selectedUIDs.count))") { model.start() }
                    .disabled(model.selectedUIDs.count < 2)
            }
            if let e = model.error { Text(e).foregroundColor(.red).font(.caption) }

            if !model.paired.isEmpty {
                Divider()
                Text("Paired Bluetooth (not connected)").font(.headline)
                ForEach(model.paired) { p in
                    HStack {
                        Text(p.name).lineLimit(1)
                        Spacer()
                        if model.connecting.contains(p.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Connect") { model.connect(p) }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button("Refresh") { model.refresh() }
                Spacer()
                Button("Quit") { model.quit() }
            }
        }
        .padding(12)
        .frame(width: 320)
        .onAppear { model.refresh() }
    }
}
