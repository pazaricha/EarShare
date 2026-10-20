import SwiftUI
import CoreAudio

@MainActor
final class Model: ObservableObject {
    private static let key = "selectedUIDs"
    let engine = AudioEngine()
    @Published var devices: [OutputDevice] = []
    @Published var selected: Set<String> = Set(UserDefaults.standard.stringArray(forKey: Model.key) ?? [])
    @Published var volumes: [AudioDeviceID: Float] = [:]
    @Published var volumeSettable: Set<AudioDeviceID> = []
    @Published var paired: [PairedAudioDevice] = []
    @Published var connecting: Set<String> = []
    @Published var running = false
    @Published var playingCount = 0
    @Published var error: String?

    /// live: false skips CoreAudio/Bluetooth so snapshot tooling can fill in demo state
    let live: Bool
    init(live: Bool = true) {
        self.live = live
        guard live else { return }
        engine.onDevicesChanged { [weak self] in Task { @MainActor in self?.refresh() } }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.engine.stopMultiOutput() }
        }
        refresh()
    }

    func refresh() {
        guard live else { return }
        devices = engine.outputDevices()
        volumes = Dictionary(uniqueKeysWithValues: devices.compactMap { d in engine.volume(of: d.id).map { (d.id, $0) } })
        volumeSettable = Set(devices.map(\.id).filter { engine.canSetVolume(of: $0) })
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
        } catch AudioEngineError.needAtLeastTwo {
            self.error = "Tick at least two outputs."
        } catch {
            self.error = "macOS refused to combine these outputs. Try reconnecting them. (\(error))"
        }
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
struct EarShareApp: App {
    // template image so macOS tints it for light/dark menu bars; SF Symbol fallback when run outside the bundle
    static let menuBarIcon: NSImage = {
        let img = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "headphones", accessibilityDescription: "EarShare")!
        img.isTemplate = true
        return img
    }()
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(model)
        } label: {
            Image(nsImage: Self.menuBarIcon).accessibilityLabel("EarShare")
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: Model
    // teal for steps and controls; green starts, red stops
    static let accent = Color(red: 0.13, green: 0.63, blue: 0.60)
    static let go = Color(red: 0.20, green: 0.66, blue: 0.33)
    static let stop = Color(red: 0.88, green: 0.27, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.running {
                step(1, "Connect headphones")
                if model.paired.isEmpty {
                    Label("All your paired headphones are connected.", systemImage: "checkmark.circle.fill")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(model.paired) { p in
                    HStack {
                        Image(systemName: "headphones").foregroundStyle(.secondary)
                        Text(p.name).lineLimit(1)
                        Spacer()
                        if model.connecting.contains(p.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Connect") { model.connect(p) }
                        }
                    }
                }
                Divider()
            }

            if model.running {
                Text("Listening now: set each volume").font(.headline)
            } else {
                step(2, "Tick who's listening")
            }
            // while sharing, only the active outputs are shown; ticks apply on the next Start
            ForEach(model.running ? model.devices.filter { model.selected.contains($0.uid) } : model.devices) { d in
                VStack(alignment: .leading, spacing: 4) {
                    let label = Label(d.name, systemImage: d.isBluetooth ? "headphones" : "speaker.wave.2").lineLimit(1)
                    if model.running {
                        label.padding(.leading, 20)
                    } else {
                        Toggle(isOn: Binding(get: { model.selected.contains(d.uid) }, set: { model.toggle(d.uid, $0) })) { label }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.secondary)
                        Slider(value: Binding(get: { Double(model.volumes[d.id] ?? 0) },
                                              set: { model.setVolume(Float($0), d) }), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 20)
                    .disabled(!model.volumeSettable.contains(d.id))
                }
            }

            Divider()
            if model.running {
                Label("Sharing sound with \(model.playingCount) outputs", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(Self.go)
                bigButton("Stop sharing", "stop.fill", Self.stop, enabled: true) { model.stop() }
            } else {
                step(3, "Start")
                bigButton(model.selectedUIDs.count < 2 ? "Share sound" : "Share sound with \(model.selectedUIDs.count) outputs",
                          "play.fill", Self.go, enabled: model.selectedUIDs.count >= 2) { model.start() }
                if model.selectedUIDs.count < 2 {
                    Text("Tick at least two outputs above.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let e = model.error { Text(e).foregroundColor(.red).font(.caption) }

            Divider()
            HStack {
                Button("Refresh") { model.refresh() }
                Spacer()
                Button("Quit") { model.quit() }
            }
        }
        .padding(14)
        .frame(width: 320)
        .tint(Self.accent)
        .onAppear { model.refresh() }
    }

    // explicit fill: keeps its colour even when the panel isn't the active window
    private func bigButton(_ title: String, _ icon: String, _ color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? Color.white : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(enabled ? color : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func step(_ n: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text("\(n)").font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 18, height: 18).background(Self.accent, in: Circle())
            Text(title).font(.headline)
        }
    }
}
