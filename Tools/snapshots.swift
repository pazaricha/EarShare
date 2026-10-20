// Renders the menu panel in each demo state to PNG (no Screen Recording permission needed).
// Run via Tools/snapshots.sh, which compiles this with App.swift minus its @main.
import SwiftUI
import AppKit

@MainActor
func render(_ model: Model, dark: Bool, to path: String) {
    let host = NSHostingView(rootView: ContentView().environmentObject(model)
        .background(Color(nsColor: .windowBackgroundColor)))
    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    host.frame.size = host.fittingSize
    let win = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    win.contentView = host
    win.appearance = host.appearance
    // key + active so prominent buttons and checkboxes get the accent colour, as in the real popover
    win.setFrameOrigin(NSPoint(x: -10000, y: -10000))
    win.orderFrontRegardless(); win.makeKey()
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

@main
struct Snapshots {
    @MainActor static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        let out = CommandLine.arguments[1]
        let a = OutputDevice(id: 1, uid: "a", name: "Dana's AirPods Pro", isBluetooth: true)
        let b = OutputDevice(id: 2, uid: "b", name: "Alex's AirPods", isBluetooth: true)
        let mac = OutputDevice(id: 3, uid: "c", name: "MacBook Pro Speakers", isBluetooth: false)
        let pairedB = PairedAudioDevice(id: "b", name: "Alex's AirPods", isConnected: false)

        func model() -> Model {
            let m = Model(live: false)
            m.devices = [a, mac]; m.paired = [pairedB]
            m.volumes = [1: 0.5, 2: 0.5, 3: 0.4]; m.volumeSettable = [1, 2, 3]
            m.selected = []
            return m
        }
        var states: [(String, Model)] = []
        var m = model(); states.append(("1-connect", m))
        m = model(); m.connecting = ["b"]; states.append(("2-connecting", m))
        m = model(); m.paired = []; m.devices = [a, b, mac]; states.append(("3-connected", m))
        m = model(); m.paired = []; m.devices = [a, b, mac]; m.selected = ["a", "b"]; states.append(("4-ticked", m))
        m = model(); m.paired = []; m.devices = [a, b, mac]; m.selected = ["a", "b"]; m.running = true; m.playingCount = 2
        m.volumes = [1: 0.75, 2: 0.3, 3: 0.4]; states.append(("5-sharing", m))
        for (name, m) in states {
            for dark in [false, true] { render(m, dark: dark, to: "\(out)/\(name)\(dark ? "-dark" : "").png") }
        }
        print("rendered \(states.count * 2) snapshots to \(out)")
    }
}
