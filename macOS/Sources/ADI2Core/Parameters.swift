import Foundation

/// Registry ported from the Linux app's RME MIDITable v1.2 parameter definitions.
public struct ParameterDefinition: Identifiable, Sendable {
    public let index: Int
    public let name: String
    public let kind: String
    public let minimum: Double
    public let maximum: Double
    public let defaultValue: Double
    public let increment: Double
    public let unit: String
    public let labels: [String]
    public let devices: [DeviceModel]
    public var id: Int { index }
    public var isReadOnly: Bool { name == "Sample Rate (display)" }
    public func raw(_ real: Double) throws -> Int {
        guard real.isFinite, (minimum...maximum).contains(real) else { throw ADI2Error.invalid("\(name) is outside its supported range.") }
        return Int((real / increment).rounded(.toNearestOrEven))
    }
    public func real(_ raw: Int) -> Double { Double(raw) * increment }
}
public enum ParameterRegistry {
    private static let outputParameters: [ParameterDefinition] = [
        ParameterDefinition(index: 1, name: "Source", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Auto", "SPDIF coax", "Optical", "USB", "USB (Rec coax)", "USB (Rec opt.)"], devices: [.dac]),
        ParameterDefinition(index: 1, name: "Source", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Auto", "AES", "SPDIF", "Analog", "USB 1/2", "USB 3/4"], devices: [.pro, .pro24]),
        ParameterDefinition(index: 3, name: "Auto Ref Level", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 1.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 4, name: "Mono", kind: "enum", minimum: 0.0, maximum: 2.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "ON", "to Left"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 5, name: "Width", kind: "number", minimum: -1.0, maximum: 1.0, defaultValue: 1.0, increment: 0.01, unit: "", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 6, name: "M/S Processing", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 7, name: "Polarity", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "Both", "Left", "Right"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 8, name: "Crossfeed", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Off", "1", "2", "3", "4", "5"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 9, name: "DA Filter", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["SD Sharp", "SD Slow", "Sharp", "Slow", "NOS", "SD LD / Brickwall"], devices: [.dac]),
        ParameterDefinition(index: 9, name: "DA Filter", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["SD Sharp", "SD Slow", "Sharp", "Slow", "NOS", "SD LD"], devices: [.pro, .pro24]),
        ParameterDefinition(index: 10, name: "De-Emphasis", kind: "enum", minimum: 0.0, maximum: 2.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Auto", "ON", "OFF"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 11, name: "Dual EQ", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 12, name: "Volume", kind: "number", minimum: -114.5, maximum: 6.0, defaultValue: -10.0, increment: 0.1, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 13, name: "Lock Volume", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 14, name: "Balance", kind: "number", minimum: -1.0, maximum: 1.0, defaultValue: 0.0, increment: 0.01, unit: "", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 15, name: "Mute", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 16, name: "Dim", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 17, name: "Loopback to USB", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "pre FX", "post FX", "post -6 dB"], devices: [.dac]),
        ParameterDefinition(index: 18, name: "Digital DC Protection", kind: "enum", minimum: 0.0, maximum: 2.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "ON", "Filter"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 20, name: "Loudness Enable", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 21, name: "Loudness Bass Gain", kind: "number", minimum: 1.0, maximum: 10.0, defaultValue: 7.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 22, name: "Loudness Treble Gain", kind: "number", minimum: 1.0, maximum: 10.0, defaultValue: 7.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 23, name: "Loudness Low Vol Ref", kind: "number", minimum: -90.0, maximum: -20.0, defaultValue: -30.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24])
    ]
    private static let lineDAC: [ParameterDefinition] = [
        ParameterDefinition(index: 2, name: "Ref Level (Line)", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 2.0, increment: 1.0, unit: "", labels: ["-5 dBu", "+1 dBu", "+7 dBu", "+13 dBu"], devices: [.dac])
    ]
    private static let linePro: [ParameterDefinition] = [
        ParameterDefinition(index: 2, name: "Ref Level (Line)", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 2.0, increment: 1.0, unit: "", labels: ["+4 dBu", "+13 dBu", "+19 dBu", "+24 dBu"], devices: [.pro, .pro24])
    ]
    private static let phones: [ParameterDefinition] = [
        ParameterDefinition(index: 2, name: "Ref Level (Phones)", kind: "enum", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Lo-Power", "Hi-Power"], devices: [.dac, .pro, .pro24])
    ]
    private static let inputParameters: [ParameterDefinition] = [
        ParameterDefinition(index: 1, name: "Ref Level", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 2.0, increment: 1.0, unit: "", labels: ["+4 dBu", "+13 dBu", "+19 dBu", "+24 dBu"], devices: [.pro, .pro24]),
        ParameterDefinition(index: 2, name: "Auto Ref Level", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 3, name: "Trim Gain Left", kind: "number", minimum: 0.0, maximum: 6.0, defaultValue: 0.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 4, name: "Trim Gain Right", kind: "number", minimum: 0.0, maximum: 6.0, defaultValue: 0.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 5, name: "Phase Invert", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "Both", "Left", "Right"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 6, name: "M/S Processing", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 7, name: "AD Filter", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["SD Sharp", "SD Slow", "Sharp", "Slow"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 8, name: "Dual EQ", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 9, name: "AD Conversion", kind: "enum", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["PCM", "DSD"], devices: [.dac, .pro, .pro24])
    ]
    private static let deviceParameters: [ParameterDefinition] = [
        ParameterDefinition(index: 1, name: "Mute Line vs.", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 1.0, increment: 1.0, unit: "", labels: ["OFF", "vs. Phones", "Toggle Ph/Line", "Toggle plugged"], devices: [.dac]),
        ParameterDefinition(index: 2, name: "Auto Standby", kind: "enum", minimum: 0.0, maximum: 4.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "30 min", "1 h", "2 h", "4 h"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 3, name: "DSD Detection", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 1.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 4, name: "DSD Filter", kind: "enum", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["50 kHz", "150 kHz"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 5, name: "DSD Direct (Line)", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro]),
        ParameterDefinition(index: 6, name: "Basic Mode", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Auto", "AD/DA", "USB", "Preamp", "Dig Thru", "DAC"], devices: [.pro, .pro24]),
        ParameterDefinition(index: 8, name: "Dual Phones", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.pro, .pro24]),
        ParameterDefinition(index: 15, name: "Clock Source", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Auto", "INT", "SPDIF coax", "Optical"], devices: [.dac]),
        ParameterDefinition(index: 15, name: "Clock Source", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Auto", "INT", "AES", "SPDIF"], devices: [.pro, .pro24]),
        ParameterDefinition(index: 25, name: "Remap Keys", kind: "enum", minimum: 0.0, maximum: 2.0, defaultValue: 2.0, increment: 1.0, unit: "", labels: ["OFF", "ON", "IR Remote"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 16, name: "Sample Rate (display)", kind: "enum", minimum: 0.0, maximum: 9.0, defaultValue: 1.0, increment: 1.0, unit: "", labels: ["44.1 k", "48 k", "88.2 k", "96 k", "176.4 k", "192 k", "352.8 k", "384 k", "705.6 k", "768 k"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 32, name: "Display Mode", kind: "enum", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Default", "Dark"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 33, name: "Meter Color", kind: "enum", minimum: 0.0, maximum: 5.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Green", "Cyan", "Amber", "Monochrome", "Red", "Orange"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 34, name: "Horizontal Meter", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Post-FX", "Pre-FX", "Dual", "Post-FX dBu"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 35, name: "AutoDark Mode", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 36, name: "Show Volume Screen", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 1.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 37, name: "Lock UI", kind: "enum", minimum: 0.0, maximum: 3.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["OFF", "Remote", "Keys", "Keys + Remote"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 62, name: "Load Volume", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 26, name: "Key VOL (1)", kind: "enum", minimum: 0.0, maximum: 41.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Default", "Setup 1", "Setup 2", "Setup 3", "Setup 4", "Setup 5", "Setup 6", "Setup 7", "Setup 8", "Setup 9", "Mono", "Mono to L", "Mute", "Loudness", "EQ enable", "B/T enable", "EQ+B/T+Ld", "Toggle Ph/Line", "Polarity", "AutoDark", "Dim", "Toggle View", "Crossfeed 1", "Crossfeed 2", "Crossfeed 3", "Crossfeed 4", "Crossfeed 5", "DA SD Sharp", "DA SD Slow", "DA Sharp", "DA Slow", "DA NOS", "DA SD LD (Brickwall)", "EQ Preset 1", "EQ Preset 2", "EQ Preset 3", "EQ Preset 4", "EQ Preset 5", "EQ Preset 6", "EQ Preset 7", "EQ Preset 8", "EQ Preset 9"], devices: [.dac]),
        ParameterDefinition(index: 27, name: "Key I/O (2)", kind: "enum", minimum: 0.0, maximum: 41.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Default", "Setup 1", "Setup 2", "Setup 3", "Setup 4", "Setup 5", "Setup 6", "Setup 7", "Setup 8", "Setup 9", "Mono", "Mono to L", "Mute", "Loudness", "EQ enable", "B/T enable", "EQ+B/T+Ld", "Toggle Ph/Line", "Polarity", "AutoDark", "Dim", "Toggle View", "Crossfeed 1", "Crossfeed 2", "Crossfeed 3", "Crossfeed 4", "Crossfeed 5", "DA SD Sharp", "DA SD Slow", "DA Sharp", "DA Slow", "DA NOS", "DA SD LD (Brickwall)", "EQ Preset 1", "EQ Preset 2", "EQ Preset 3", "EQ Preset 4", "EQ Preset 5", "EQ Preset 6", "EQ Preset 7", "EQ Preset 8", "EQ Preset 9"], devices: [.dac]),
        ParameterDefinition(index: 28, name: "Key EQ (3)", kind: "enum", minimum: 0.0, maximum: 41.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Default", "Setup 1", "Setup 2", "Setup 3", "Setup 4", "Setup 5", "Setup 6", "Setup 7", "Setup 8", "Setup 9", "Mono", "Mono to L", "Mute", "Loudness", "EQ enable", "B/T enable", "EQ+B/T+Ld", "Toggle Ph/Line", "Polarity", "AutoDark", "Dim", "Toggle View", "Crossfeed 1", "Crossfeed 2", "Crossfeed 3", "Crossfeed 4", "Crossfeed 5", "DA SD Sharp", "DA SD Slow", "DA Sharp", "DA Slow", "DA NOS", "DA SD LD (Brickwall)", "EQ Preset 1", "EQ Preset 2", "EQ Preset 3", "EQ Preset 4", "EQ Preset 5", "EQ Preset 6", "EQ Preset 7", "EQ Preset 8", "EQ Preset 9"], devices: [.dac]),
        ParameterDefinition(index: 29, name: "Key SETUP (4)", kind: "enum", minimum: 0.0, maximum: 41.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Default", "Setup 1", "Setup 2", "Setup 3", "Setup 4", "Setup 5", "Setup 6", "Setup 7", "Setup 8", "Setup 9", "Mono", "Mono to L", "Mute", "Loudness", "EQ enable", "B/T enable", "EQ+B/T+Ld", "Toggle Ph/Line", "Polarity", "AutoDark", "Dim", "Toggle View", "Crossfeed 1", "Crossfeed 2", "Crossfeed 3", "Crossfeed 4", "Crossfeed 5", "DA SD Sharp", "DA SD Slow", "DA Sharp", "DA Slow", "DA NOS", "DA SD LD (Brickwall)", "EQ Preset 1", "EQ Preset 2", "EQ Preset 3", "EQ Preset 4", "EQ Preset 5", "EQ Preset 6", "EQ Preset 7", "EQ Preset 8", "EQ Preset 9"], devices: [.dac])
    ]
    private static let eqExtra: [ParameterDefinition] = [
        ParameterDefinition(index: 2, name: "EQ Enable", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 20, name: "Bass/Treble Enable", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 1.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 21, name: "Bass Gain", kind: "number", minimum: -12.0, maximum: 12.0, defaultValue: 0.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 22, name: "Bass Frequency", kind: "freq", minimum: 20.0, maximum: 150.0, defaultValue: 85.0, increment: 1.0, unit: "Hz", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 23, name: "Bass Q", kind: "number", minimum: 0.5, maximum: 1.5, defaultValue: 0.9, increment: 0.1, unit: "", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 24, name: "Treble Gain", kind: "number", minimum: -12.0, maximum: 12.0, defaultValue: 0.0, increment: 0.5, unit: "dB", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 25, name: "Treble Frequency", kind: "freq", minimum: 3000.0, maximum: 10000.0, defaultValue: 6500.0, increment: 1.0, unit: "Hz", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 26, name: "Treble Q", kind: "number", minimum: 0.5, maximum: 1.5, defaultValue: 0.7, increment: 0.1, unit: "", labels: [], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 27, name: "Load B/T with Preset", kind: "bool", minimum: 0.0, maximum: 1.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["off", "on"], devices: [.dac, .pro, .pro24]),
        ParameterDefinition(index: 28, name: "EQ Preset Select", kind: "enum", minimum: 0.0, maximum: 22.0, defaultValue: 0.0, increment: 1.0, unit: "", labels: ["Manual", "Temp", "Preset 1", "Preset 2", "Preset 3", "Preset 4", "Preset 5", "Preset 6", "Preset 7", "Preset 8", "Preset 9", "Preset 10", "Preset 11", "Preset 12", "Preset 13", "Preset 14", "Preset 15", "Preset 16", "Preset 17", "Preset 18", "Preset 19", "Preset 20", "Clear"], devices: [.dac, .pro, .pro24])
    ]
    public static func output(for device: DeviceModel, output: Output) -> [ParameterDefinition] {
        let reference = output == .line ? (device == .dac ? lineDAC : linePro) : phones
        return (outputParameters + reference).filter { $0.devices.contains(device) }.sorted { $0.index < $1.index }
    }
    public static func input(for device: DeviceModel) -> [ParameterDefinition] { device == .dac ? [] : inputParameters.filter { $0.devices.contains(device) } }
    public static func device(for device: DeviceModel) -> [ParameterDefinition] { deviceParameters.filter { $0.devices.contains(device) }.sorted { $0.index < $1.index } }
    public static let eq: [ParameterDefinition] = {
        var result = eqExtra
        for (i, layout) in EQProfile.layout.enumerated() {
            if let index = layout.type { result.append(ParameterDefinition(index: index, name: "Band \(i + 1) Type", kind: "enum", minimum: 0, maximum: Double(Band.types(for:i).count - 1), defaultValue: 0, increment: 1, unit: "", labels: Band.types(for:i), devices: DeviceModel.allCases)) }
            result.append(ParameterDefinition(index: layout.gain, name: "Band \(i + 1) Gain", kind: "number", minimum: -12, maximum: 12, defaultValue: 0, increment: 0.5, unit: "dB", labels: [], devices: DeviceModel.allCases))
            result.append(ParameterDefinition(index: layout.frequency, name: "Band \(i + 1) Frequency", kind: "freq", minimum: i >= 3 ? 200 : 20, maximum: 20000, defaultValue: 1000, increment: 1, unit: "Hz", labels: [], devices: DeviceModel.allCases))
            result.append(ParameterDefinition(index: layout.q, name: "Band \(i + 1) Q", kind: "number", minimum: 0.5, maximum: i >= 3 ? 5 : 9.9, defaultValue: 1, increment: 0.1, unit: "", labels: [], devices: DeviceModel.allCases))
        }
        return result.sorted { $0.index < $1.index }
    }()
}
