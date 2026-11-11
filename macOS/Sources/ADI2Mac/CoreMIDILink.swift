import Foundation
import CoreMIDI
import ADI2Core

struct MIDIDevice: Identifiable, Equatable {
    let id: Int32
    let name: String
    let model: DeviceModel
    let destination: MIDIEndpointRef
    let source: MIDIEndpointRef
}

struct MIDIError: LocalizedError {
    let operation: String
    let status: OSStatus
    var errorDescription: String? { "\(operation) failed (CoreMIDI \(status)). Reconnect the USB cable and enable MIDI Control on the ADI-2." }
}

@MainActor protocol MIDIConnection: AnyObject {
    var onDevicesChanged: (() -> Void)? { get set }
    var onMessage: (([UInt8]) -> Void)? { get set }
    func devices() -> [MIDIDevice]
    func connect(_ device: MIDIDevice) throws
    func send(_ bytes: [UInt8]) throws
    func disconnect()
}

/// Uses CoreMIDI only; no direct USB access, drivers, helpers or shell commands.
@MainActor final class CoreMIDILink: MIDIConnection {
    var onDevicesChanged: (() -> Void)?
    var onMessage: (([UInt8]) -> Void)?
    private var client: MIDIClientRef = 0
    private var input: MIDIPortRef = 0
    private var output: MIDIPortRef = 0
    private var current: MIDIDevice?
    private var framer = SysExFramer()
    private var generation: UInt64 = 0

    init() {
        let result = MIDIClientCreateWithBlock("ADI-2 Companion" as CFString, &client) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onDevicesChanged?() }
        }
        if result != noErr { client = 0 }
    }

    func devices() -> [MIDIDevice] {
        var devices: [MIDIDevice] = []
        for index in 0..<MIDIGetNumberOfDestinations() {
            let destination = MIDIGetDestination(index)
            let name = string(destination, kMIDIPropertyDisplayName)
            guard name.localizedCaseInsensitiveContains("ADI-2"), !name.localizedCaseInsensitiveContains("MIDI 2") else { continue }
            var entity: MIDIEntityRef = 0
            guard MIDIEndpointGetEntity(destination, &entity) == noErr, entity != 0 else { continue }
            // Pair by the same CoreMIDI entity, never just by matching names.
            let sources = (0..<MIDIEntityGetNumberOfSources(entity)).map { MIDIEntityGetSource(entity, $0) }
                .filter { !string($0, kMIDIPropertyDisplayName).localizedCaseInsensitiveContains("MIDI 2") }
            guard sources.count == 1, let source = sources.first else { continue }
            var uniqueID: Int32 = 0
            guard MIDIObjectGetIntegerProperty(destination, kMIDIPropertyUniqueID, &uniqueID) == noErr else { continue }
            let model: DeviceModel = name.localizedCaseInsensitiveContains("2/4") ? .pro24 : name.localizedCaseInsensitiveContains("Pro") ? .pro : .dac
            devices.append(MIDIDevice(id: uniqueID, name: name, model: model, destination: destination, source: source))
        }
        return devices
    }

    func connect(_ device: MIDIDevice) throws {
        disconnect()
        guard client != 0 else { throw MIDIError(operation: "Create MIDI client", status: -1) }
        try check(MIDIOutputPortCreate(client, "ADI-2 output" as CFString, &output), "Create output")
        do {
            let session = generation
            try check(MIDIInputPortCreateWithBlock(client, "ADI-2 input" as CFString, &input) { [weak self] packets, _ in
                var bytes: [UInt8] = []
                // Keep the packet pointer inside the original variable-length list.
                let offset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
                var packet = UnsafeRawPointer(packets).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self)
                for _ in 0..<packets.pointee.numPackets {
                    let count = Int(packet.pointee.length)
                    let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!
                    let data = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
                    bytes.append(contentsOf: UnsafeBufferPointer(start: data, count: count))
                    packet = UnsafePointer(MIDIPacketNext(packet))
                }
                let received = bytes
                Task { @MainActor [weak self] in guard let self, self.generation == session else { return }; self.receive(received) }
            }, "Create input")
            try check(MIDIPortConnectSource(input, device.source, nil), "Connect input")
            current = device
        } catch { disconnect(); throw error }
    }

    func send(_ bytes: [UInt8]) throws {
        guard let device = current, output != 0 else { throw MIDIError(operation: "No connected MIDI output", status: -1) }
        guard bytes.count <= 256 else { throw MIDIError(operation: "MIDI message exceeds 256 bytes", status: -1) }
        var list = MIDIPacketList()
        let result: OSStatus = withUnsafeMutablePointer(to: &list) { pointer in
            let packet = MIDIPacketListInit(pointer)
            return bytes.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return -1 }
                _ = MIDIPacketListAdd(pointer, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, base)
                return MIDISend(output, device.destination, pointer)
            }
        }
        try check(result, "Send MIDI")
    }

    func disconnect() {
        generation &+= 1
        if let device = current, input != 0 { MIDIPortDisconnectSource(input, device.source) }
        if input != 0 { MIDIPortDispose(input); input = 0 }
        if output != 0 { MIDIPortDispose(output); output = 0 }
        current = nil
        framer = SysExFramer()
    }

    private func receive(_ bytes: [UInt8]) {
        for message in framer.append(bytes) { onMessage?(message) }
    }
    private func check(_ status: OSStatus, _ operation: String) throws {
        if status != noErr { throw MIDIError(operation: operation, status: status) }
    }
    private func string(_ object: MIDIObjectRef, _ property: CFString) -> String {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(object, property, &value) == noErr else { return "" }
        return value?.takeRetainedValue() as String? ?? ""
    }
    deinit {
        if input != 0 { MIDIPortDispose(input) }
        if output != 0 { MIDIPortDispose(output) }
        if client != 0 { MIDIClientDispose(client) }
    }
}
