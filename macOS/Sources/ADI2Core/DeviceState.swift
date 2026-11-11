import Foundation

public struct ParameterAddress: Hashable, Sendable {
    public let address: Int
    public let index: Int
    public init(address: Int, index: Int) { self.address = address; self.index = index }
}
/// A newly constructed accumulator starts empty for each hardware sync.
/// Write readiness requires an entire selected output state, not one reply packet.
public struct DeviceStateAccumulator: Sendable {
    public let output: Output
    public private(set) var values: [ParameterAddress:Int] = [:]
    public init(output: Output, values: [ParameterAddress:Int] = [:]) { self.output = output; self.values = values }
    public static func requiredKeys(output: Output) -> Set<ParameterAddress> {
        var keys: Set<ParameterAddress> = [ParameterAddress(address:output.channel,index:12),ParameterAddress(address:output.channel,index:20)]
        for address in [output.left,output.right] {
            for index in [2,20] { keys.insert(ParameterAddress(address:address,index:index)) }
            for layout in EQProfile.layout {
                for index in [layout.gain,layout.frequency,layout.q] { keys.insert(ParameterAddress(address:address,index:index)) }
                if let type = layout.type { keys.insert(ParameterAddress(address:address,index:type)) }
            }
        }
        return keys
    }
    public var isComplete: Bool { Self.requiredKeys(output:output).allSatisfy {values[$0] != nil} }
    public mutating func receive(_ parameters:[ParameterValue]) {
        for parameter in parameters {
            guard (0...14).contains(parameter.address), (0...(parameter.address == 12 ? 63 : 31)).contains(parameter.index) else {continue}
            values[ParameterAddress(address:parameter.address,index:parameter.index)] = parameter.raw
        }
    }
    /// Hydrates only observed values. No defaults or enum clamping can hide invalid hardware data.
    public func profile(right: Bool = false) throws -> EQProfile {
        guard isComplete else { throw ADI2Error.invalid("The selected output has not returned a complete EQ and volume state.") }
        let address = right ? output.right : output.left
        func raw(_ index: Int, address override: Int? = nil) throws -> Int {
            guard let raw = values[ParameterAddress(address:override ?? address,index:index)] else { throw ADI2Error.invalid("The hardware state is missing parameter \(index).") }
            return raw
        }
        func flag(_ index: Int, address override: Int? = nil) throws -> Bool {
            let v = try raw(index,address:override)
            guard v == 0 || v == 1 else { throw ADI2Error.invalid("The hardware returned an invalid switch value.") }
            return v == 1
        }
        let bands = try EQProfile.layout.enumerated().map { i,layout -> Band in
            let types = Band.types(for:i)
            let type: String
            if let index = layout.type {
                let v = try raw(index)
                guard types.indices.contains(v) else { throw ADI2Error.invalid("The hardware returned an unsupported type for band \(i+1).") }
                type = types[v]
            } else { type = "Peak" }
            return Band(type:type,gainDB:Double(try raw(layout.gain)) * 0.5,frequency:Double(try raw(layout.frequency)),q:Double(try raw(layout.q)) / 10)
        }
        let profile = EQProfile(name:"Hardware EQ",output:output,bands:bands,eqEnabled:try flag(2),bassTrebleEnabled:try flag(20),loudnessEnabled:try flag(20,address:output.channel))
        try profile.validate()
        let volume = try raw(12,address:output.channel)
        guard (-1145...60).contains(volume) else { throw ADI2Error.invalid("The hardware returned an invalid output volume.") }
        return profile
    }
    /// Validates recognized parameters while retaining forward-compatible unknown entries.
    public func validate(device: DeviceModel) throws {
        _ = try profile()
        _ = try profile(right:true)
        for (key,raw) in values {
            let definitions: [ParameterDefinition]
            if key.address == 12 { definitions = ParameterRegistry.device(for:device) }
            else if key.address == 0 { definitions = ParameterRegistry.input(for:device) }
            else if let output = Output.allCases.first(where: {$0.channel == key.address}) {
                if device == .dac && output == .phones34 {continue}
                definitions = ParameterRegistry.output(for:device,output:output)
            } else if ADI2Protocol.frequencyAddresses.contains(key.address) {
                if device == .dac && [1,2,10,11].contains(key.address) {continue}
                definitions = ParameterRegistry.eq
            } else {continue}
            guard let p = definitions.first(where: {$0.index == key.index}) else {continue}
            let real = p.kind == "freq" ? Double(raw) : Double(raw) * p.increment
            guard (p.minimum...p.maximum).contains(real) else { throw ADI2Error.invalid("The hardware returned an invalid value for \(p.name). Sync again before making changes.") }
        }
    }

}
