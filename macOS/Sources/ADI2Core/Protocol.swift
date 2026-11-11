import Foundation

public enum ADI2Error: Error, LocalizedError, Equatable {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

public enum DeviceModel: String, CaseIterable, Codable, Sendable {
    case dac, pro, pro24
    public var deviceID: UInt8 { switch self { case .dac: return 0x71; case .pro: return 0x72; case .pro24: return 0x73 } }
    public var title: String { switch self { case .dac: return "ADI-2 DAC"; case .pro: return "ADI-2 Pro"; case .pro24: return "ADI-2/4 Pro SE" } }
}
public enum Output: String, CaseIterable, Codable, Sendable {
    case line, phones, phones34
    public var channel: Int { switch self { case .line: return 3; case .phones: return 6; case .phones34: return 9 } }
    public var left: Int { channel + 1 }
    public var right: Int { channel + 2 }
    public var title: String { switch self { case .line: return "Line Out"; case .phones: return "Phones 1/2"; case .phones34: return "Phones 3/4" } }
}
public struct Message: Equatable, Sendable {
    public let device: UInt8
    public let command: UInt8
    public let payload: [UInt8]
}
public struct ParameterValue: Equatable, Sendable {
    public let address: Int
    public let index: Int
    public let raw: Int
    public init(address: Int, index: Int, raw: Int) { self.address = address; self.index = index; self.raw = raw }
}
public enum ADI2Protocol {
    public static let frequencyAddresses: Set<Int> = [1,2,4,5,7,8,10,11,13,14]
    public static let frequencyIndices: Set<Int> = [5,8,11,14,18,22,25]
    public static func encode(address: Int, index: Int, raw: Int) throws -> [UInt8] {
        guard (0...15).contains(address), (0...31).contains(index), (-2048...2047).contains(raw) else { throw ADI2Error.invalid("Parameter is outside its MIDI container range.") }
        let v = raw & 0xfff
        return [UInt8((address << 3) | (index >> 2)), UInt8(((index & 3) << 5) | ((v >> 7) & 31)), UInt8(v & 127)]
    }
    public static func encodeFrequency(address: Int, index: Int, hz: Double) throws -> [UInt8] {
        guard (0...15).contains(address), (0...31).contains(index), hz.isFinite, (0...20470).contains(hz) else { throw ADI2Error.invalid("Frequency is outside its MIDI container range.") }
        let factor = hz > 2047
        let raw = Int((factor ? hz / 10 : hz).rounded(.toNearestOrEven))
        guard raw <= 2047 else { throw ADI2Error.invalid("Frequency cannot be represented.") }
        return [UInt8((address << 3) | (index >> 2)), UInt8(((index & 3) << 5) | (factor ? 16 : 0) | ((raw >> 7) & 15)), UInt8(raw & 127)]
    }
    public static func encodeDevice(index: Int, raw: Int) throws -> [UInt8] {
        guard (0...63).contains(index), (0...2047).contains(raw) else { throw ADI2Error.invalid("Device parameter is outside its MIDI container range.") }
        return [UInt8(96 | (index >> 3)), UInt8(((index & 7) << 4) | ((raw >> 7) & 15)), UInt8(raw & 127)]
    }
    public static func message(device: UInt8, command: UInt8, payload: [UInt8] = []) -> [UInt8] { [0xf0,0,0x20,0x0d,device,command] + payload + [0xf7] }
    public static func parameters(device: UInt8, containers: [[UInt8]]) -> [UInt8] { message(device: device, command: 2, payload: containers.flatMap { $0 }) }
    public static func requestAll(device: UInt8) -> [UInt8] { message(device: device, command: 3, payload: [9]) }
    public static func requestEQPreset(device: UInt8, slot: Int) throws -> [UInt8] {
        guard (0..<20).contains(slot) else { throw ADI2Error.invalid("EQ preset must be between 1 and 20.") }
        return message(device: device, command: 3, payload: [UInt8(10 + slot)])
    }
    public static func setup(device: UInt8, slot: Int, save: Bool) throws -> [UInt8] {
        guard (1...9).contains(slot) else { throw ADI2Error.invalid("Setup must be between 1 and 9.") }
        return message(device: device, command: 4, payload: [UInt8(slot + (save ? 9 : 0))])
    }
    public static func name(device: UInt8, firstByte: UInt8, name: String) throws -> [UInt8] {
        guard firstByte < 128 else { throw ADI2Error.invalid("Invalid name address.") }
        let chars = Array(name.unicodeScalars.prefix(14)).map { $0.value >= 32 && $0.value < 127 ? UInt8($0.value) : UInt8(63) }
        return message(device: device, command: 6, payload: [firstByte] + Array(repeating: 32, count: 14 - chars.count) + chars + [0,0])
    }
    public static func parse(_ bytes: [UInt8]) -> Message? {
        guard bytes.count >= 7, Array(bytes.prefix(4)) == [0xf0,0,0x20,0x0d], bytes.last == 0xf7, bytes.dropFirst().dropLast().allSatisfy({ $0 < 128 }), DeviceModel.allCases.contains(where: { $0.deviceID == bytes[4] }) else { return nil }
        return Message(device: bytes[4], command: bytes[5], payload: Array(bytes[6..<(bytes.count - 1)]))
    }
    public static func parseParameters(_ bytes: [UInt8]) throws -> [ParameterValue] {
        guard bytes.count % 3 == 0, bytes.allSatisfy({$0 < 128}) else { throw ADI2Error.invalid("Incomplete or invalid MIDI parameter payload.") }
        return stride(from: 0, to: bytes.count, by: 3).map { p in
            let a = Int(bytes[p]), b = Int(bytes[p + 1]), c = Int(bytes[p + 2])
            let address = (a >> 3) & 15
            if address == 12 { return ParameterValue(address: address, index: ((a & 7) << 3) | ((b >> 4) & 7), raw: ((b & 15) << 7) | c) }
            let index = ((a & 7) << 2) | ((b >> 5) & 3)
            var raw = ((b & 31) << 7) | c
            if frequencyAddresses.contains(address), frequencyIndices.contains(index) { raw = (((b & 15) << 7) | c) * ((b & 16) != 0 ? 10 : 1) }
            else if raw > 2047 { raw -= 4096 }
            return ParameterValue(address: address, index: index, raw: raw)
        }
    }
}

/// Stateful MIDI 1.0 SysEx framing across CoreMIDI packet boundaries.
/// Realtime events may occur anywhere; status bytes abort an incomplete frame.
public struct SysExFramer: Sendable {
    private var current: [UInt8]? = nil
    public let maximumLength: Int
    public init(maximumLength: Int = 65536) { self.maximumLength = max(7, maximumLength) }
    public mutating func append(_ bytes: [UInt8]) -> [[UInt8]] {
        var messages: [[UInt8]] = []
        for byte in bytes {
            if byte >= 0xf8 { continue }
            if byte == 0xf0 { current = [byte]; continue }
            guard current != nil else { continue }
            if byte == 0xf7 { current!.append(byte); messages.append(current!); current = nil }
            else if byte >= 0x80 || current!.count >= maximumLength - 1 { current = nil }
            else { current!.append(byte) }
        }
        return messages
    }
}
