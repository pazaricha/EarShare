import Foundation
import IOBluetooth

struct PairedAudioDevice: Identifiable, Hashable {
    let id: String // address
    let name: String
    let isConnected: Bool
}

enum Bluetooth {
    static func pairedAudioDevices() -> [PairedAudioDevice] {
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return devices.filter { $0.deviceClassMajor == 0x04 }.compactMap { d in
            guard let addr = d.addressString else { return nil }
            return PairedAudioDevice(id: addr, name: d.name ?? addr, isConnected: d.isConnected())
        }
    }

    /// Blocks; call off the main thread.
    static func connect(address: String) -> Bool {
        IOBluetoothDevice(addressString: address)?.openConnection() == kIOReturnSuccess
    }
}
