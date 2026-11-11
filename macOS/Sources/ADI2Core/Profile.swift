import Foundation

public struct Band: Codable, Equatable, Sendable {
    public var type: String
    public var gainDB: Double
    public var frequency: Double
    public var q: Double
    public init(type: String = "Peak", gainDB: Double = 0, frequency: Double = 1000, q: Double = 1) { self.type = type; self.gainDB = gainDB; self.frequency = frequency; self.q = q }
    enum CodingKeys: String, CodingKey { case type, gainDB = "gain_db", frequency = "freq_hz", q }
    public static func types(for index: Int) -> [String] { index == 0 ? ["Peak", "Shelf", "High Pass", "High Cut"] : index == 4 ? ["Peak", "Shelf", "High Cut"] : ["Peak"] }
    public func validate(index: Int) throws {
        guard (0..<5).contains(index), Self.types(for: index).contains(type), gainDB.isFinite, frequency.isFinite, q.isFinite, (-12...12).contains(gainDB), ((index >= 3 ? 200.0 : 20.0)...20000).contains(frequency), (0.5...(index >= 3 ? 5.0 : 9.9)).contains(q) else { throw ADI2Error.invalid("Band \(index + 1) is outside the ADI-2's supported type, gain, frequency or Q range.") }
    }
}
public struct EQProfile: Codable, Equatable, Sendable {
    public var name: String
    public var output: Output
    public var bands: [Band]
    public var eqEnabled: Bool
    public var bassTrebleEnabled: Bool
    public var loudnessEnabled: Bool
    public init(name: String = "Untitled", output: Output = .phones, bands: [Band] = Array(repeating: Band(), count: 5), eqEnabled: Bool = true, bassTrebleEnabled: Bool = false, loudnessEnabled: Bool = false) { self.name = name; self.output = output; self.bands = bands; self.eqEnabled = eqEnabled; self.bassTrebleEnabled = bassTrebleEnabled; self.loudnessEnabled = loudnessEnabled }
    enum CodingKeys: String, CodingKey { case name, output, bands, eqEnabled = "eq_enable", bassTrebleEnabled = "bass_treble_enable", loudnessEnabled = "loudness_enable" }
    public static var flat: EQProfile { EQProfile(name: "Flat", bands: [100.0,500,1000,4000,10000].map { Band(frequency: $0) }) }
    public static var dt1990: EQProfile { EQProfile(name: "DT 1990 Pro (analytic) — studio reference", bands: [Band(type:"Shelf",gainDB:6.5,frequency:105,q:0.7),Band(gainDB:-2,frequency:150,q:0.5),Band(gainDB:4.5,frequency:4200,q:3.5),Band(gainDB:-3,frequency:7400,q:3.4),Band(type:"Shelf",gainDB:-7.5,frequency:10000,q:0.7)]) }
    public func validate() throws { guard bands.count == 5 else { throw ADI2Error.invalid("An ADI-2 profile requires exactly five bands.") }; for (i,b) in bands.enumerated() { try b.validate(index:i) } }
    public static let layout: [(type: Int?, gain: Int, frequency: Int, q: Int)] = [(3,4,5,6),(nil,7,8,9),(nil,10,11,12),(nil,13,14,15),(16,17,18,19)]
    public func containers() throws -> [[UInt8]] {
        try validate()
        var boxes: [[UInt8]] = []
        for address in [output.left, output.right] {
            boxes.append(try ADI2Protocol.encode(address: address, index: 2, raw: eqEnabled ? 1 : 0))
            boxes.append(try ADI2Protocol.encode(address: address, index: 20, raw: bassTrebleEnabled ? 1 : 0))
            for (i,b) in bands.enumerated() {
                let l = Self.layout[i]
                if let t = l.type { boxes.append(try ADI2Protocol.encode(address: address, index: t, raw: Band.types(for:i).firstIndex(of:b.type)!)) }
                boxes.append(try ADI2Protocol.encode(address:address,index:l.gain,raw:Int((b.gainDB / 0.5).rounded(.toNearestOrEven))))
                boxes.append(try ADI2Protocol.encodeFrequency(address:address,index:l.frequency,hz:b.frequency))
                boxes.append(try ADI2Protocol.encode(address:address,index:l.q,raw:Int((b.q / 0.1).rounded(.toNearestOrEven))))
            }
        }
        boxes.append(try ADI2Protocol.encode(address:output.channel,index:20,raw:loudnessEnabled ? 1 : 0))
        return boxes
    }
}
