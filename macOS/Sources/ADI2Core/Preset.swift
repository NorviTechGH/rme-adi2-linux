import Foundation

extension EQProfile {
    /// Writes the five EQ bands into preset staging addresses 13/14, commits the
    /// slot, then optionally names it. Bass/Treble and Loudness are not included:
    /// this follows the Linux app's published-MIDITable implementation exactly.
    /// Each returned frame must be sent in order; these commands are not atomic.
    public func presetMessages(device: UInt8, slot: Int, name: String = "") throws -> [[UInt8]] {
        guard DeviceModel.allCases.contains(where: {$0.deviceID == device}) else { throw ADI2Error.invalid("Choose a supported ADI-2 device model.") }
        guard (1...20).contains(slot) else { throw ADI2Error.invalid("EQ preset slot must be between 1 and 20.") }
        try validate()
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard name.utf8.count <= 14, name.unicodeScalars.allSatisfy({(32...126).contains($0.value)}) else { throw ADI2Error.invalid("Device preset names use up to 14 printable ASCII characters.") }
        var containers: [[UInt8]] = []
        for address in [13,14] {
            for (i,band) in bands.enumerated() {
                let indices = Self.layout[i]
                if let index = indices.type {
                    containers.append(try ADI2Protocol.encode(address:address,index:index,raw:Band.types(for:i).firstIndex(of:band.type)!))
                }
                containers.append(try ADI2Protocol.encode(address:address,index:indices.gain,raw:Int((band.gainDB / 0.5).rounded(.toNearestOrEven))))
                containers.append(try ADI2Protocol.encodeFrequency(address:address,index:indices.frequency,hz:band.frequency))
                containers.append(try ADI2Protocol.encode(address:address,index:indices.q,raw:Int((band.q / 0.1).rounded(.toNearestOrEven))))
            }
        }
        let commit = try ADI2Protocol.encode(address:13,index:2,raw:(slot-1) << 4)
        var messages = [ADI2Protocol.parameters(device:device,containers:containers),ADI2Protocol.parameters(device:device,containers:[commit])]
        if !name.isEmpty { messages.append(try ADI2Protocol.name(device:device,firstByte:UInt8(slot),name:name)) }
        return messages
    }
}
extension ADI2Protocol {
    /// Manual = 0, Temp = 1, preset N = N+1. The output-wide selector exists
    /// only in the left EQ block, matching the Linux controller and device dump.
    public static func loadEQPreset(device: UInt8, output: Output, slot: Int) throws -> [UInt8] {
        guard DeviceModel.allCases.contains(where: {$0.deviceID == device}) else { throw ADI2Error.invalid("Choose a supported ADI-2 device model.") }
        guard (1...20).contains(slot) else { throw ADI2Error.invalid("EQ preset slot must be between 1 and 20.") }
        if device == DeviceModel.dac.deviceID && output == .phones34 { throw ADI2Error.invalid("Phones 3/4 is available on ADI-2 Pro models.") }
        let containers = [try encode(address:output.left,index:28,raw:slot+1)]
        return parameters(device:device,containers:containers)
    }
}
