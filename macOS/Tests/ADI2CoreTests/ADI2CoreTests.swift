#if canImport(XCTest)
import XCTest
#else
import Foundation
private var assertionCount = 0
private var failureCount = 0
class XCTestCase {}
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, _ message:String = "", file:StaticString=#filePath,line:UInt=#line) { assertionCount += 1; do { if try !value() {failureCount += 1; print("FAIL \(file):\(line) \(message)")} } catch {failureCount += 1;print("FAIL \(file):\(line) \(error)")} }
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, _ message:String = "", file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(try !value(),message,file:file,line:line) }
func XCTAssertEqual<T:Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message:String = "", file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(try a() == b(),message,file:file,line:line) }
func XCTAssertEqual(_ a:Double,_ b:Double,accuracy:Double,file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(abs(a-b)<=accuracy,file:file,line:line) }
func XCTAssertNil<T>(_ value:T?,file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(value == nil,file:file,line:line) }
func XCTAssertThrowsError<T>(_ value: @autoclosure () throws -> T,_ message:String = "",file:StaticString=#filePath,line:UInt=#line) { do {_ = try value();XCTAssertTrue(false,message,file:file,line:line)} catch {assertionCount += 1} }
func XCTAssertNoThrow<T>(_ value: @autoclosure () throws -> T,_ message:String = "",file:StaticString=#filePath,line:UInt=#line) { do {_ = try value();assertionCount += 1} catch {XCTAssertTrue(false,"\(message) \(error)",file:file,line:line)} }
func XCTUnwrap<T>(_ value:T?,file:StaticString=#filePath,line:UInt=#line) throws -> T { guard let value else {XCTAssertTrue(false,file:file,line:line);throw ADI2Error.invalid("Missing value")};return value }
#endif
@testable import ADI2Core

final class ADI2CoreTests: XCTestCase {
    func hex(_ string:String) -> [UInt8] { string.split(separator:" ").map {UInt8($0,radix:16)!} }
    func testOfficialVolumeOracle() throws {
        XCTAssertEqual(ADI2Protocol.parameters(device:0x73,containers:[try ADI2Protocol.encode(address:9,index:12,raw:-100)]),hex("F0 00 20 0D 73 02 4B 1F 1C F7"))
    }
    func testOfficialInputAndRequestOracles() throws {
        XCTAssertEqual(ADI2Protocol.parameters(device:0x73,containers:[try ADI2Protocol.encode(address:0,index:1,raw:2)]),hex("F0 00 20 0D 73 02 00 20 02 F7"))
        XCTAssertEqual(ADI2Protocol.requestAll(device:0x73),hex("F0 00 20 0D 73 03 09 F7"))
        XCTAssertEqual(try ADI2Protocol.requestEQPreset(device:0x73,slot:1),hex("F0 00 20 0D 73 03 0B F7"))
    }
    func testOfficialFrequencyOracle() throws {
        XCTAssertEqual(try ADI2Protocol.encodeFrequency(address:14,index:18,hz:10000),hex("74 57 68"))
        XCTAssertEqual(try ADI2Protocol.parseParameters(hex("74 57 68")),[ParameterValue(address:14,index:18,raw:10000)])
        XCTAssertEqual(try ADI2Protocol.parseParameters(hex("09 20 64 0A 03 74 4B 1F 1C")),[ParameterValue(address:1,index:5,raw:100),ParameterValue(address:1,index:8,raw:500),ParameterValue(address:9,index:12,raw:-100)])
    }
    func testSignedAndDevicePackingBoundaries() throws {
        for raw in [-2048,-100,-3,0,13,2047] { XCTAssertEqual(try ADI2Protocol.parseParameters(ADI2Protocol.encode(address:7,index:4,raw:raw)).first?.raw,raw) }
        for (index,raw) in [(1,3),(25,2),(63,2047)] { XCTAssertEqual(try ADI2Protocol.parseParameters(ADI2Protocol.encodeDevice(index:index,raw:raw)),[ParameterValue(address:12,index:index,raw:raw)]) }
    }
    func testEncoderRejectsInvalidInputsWithoutTrapping() {
        XCTAssertThrowsError(try ADI2Protocol.encode(address:16,index:1,raw:0))
        XCTAssertThrowsError(try ADI2Protocol.encode(address:1,index:-1,raw:0))
        XCTAssertThrowsError(try ADI2Protocol.encode(address:1,index:1,raw:2048))
        XCTAssertThrowsError(try ADI2Protocol.encodeFrequency(address:-1,index:1,hz:1000))
        XCTAssertThrowsError(try ADI2Protocol.encodeFrequency(address:1,index:1,hz:.nan))
        XCTAssertThrowsError(try ADI2Protocol.encodeFrequency(address:1,index:1,hz:1e300))
        XCTAssertThrowsError(try ADI2Protocol.encodeDevice(index:64,raw:0))
        XCTAssertThrowsError(try ADI2Protocol.requestEQPreset(device:0x71,slot:20))
        XCTAssertThrowsError(try ADI2Protocol.setup(device:0x71,slot:0,save:false))
    }
    func testNameAndSetupMessages() throws {
        let bytes=try ADI2Protocol.name(device:0x73,firstByte:0x21,name:"Setup 1")
        XCTAssertEqual(bytes.count,24)
        XCTAssertEqual(String(bytes:bytes[7..<21],encoding:.ascii),"       Setup 1")
        XCTAssertEqual(Array(bytes[21..<23]),[0,0])
        XCTAssertEqual(try ADI2Protocol.setup(device:0x71,slot:9,save:true),hex("F0 00 20 0D 71 04 12 F7"))
    }
    func testFramerAcrossPacketsAndRealtime() {
        var framer=SysExFramer()
        XCTAssertEqual(framer.append(hex("90 7F F0 00 20 F8")),[])
        XCTAssertEqual(framer.append(hex("0D 71 03 FA 09 F7")),[hex("F0 00 20 0D 71 03 09 F7")])
    }
    func testFramerRecoversFromCorruptAndOversizeFrames() {
        var framer=SysExFramer(maximumLength:8)
        XCTAssertEqual(framer.append(hex("F0 00 20 0D 71 03 09 00 F7")),[])
        XCTAssertEqual(framer.append(hex("F0 00 91 00 F7")),[])
        XCTAssertEqual(framer.append(hex("F0 00 F0 00 20 0D 71 03 09 F7")),[hex("F0 00 20 0D 71 03 09 F7")])
    }
    func testParserRejectsForeignAndMalformedMessages() throws {
        XCTAssertNil(ADI2Protocol.parse(hex("F0 01 20 0D 71 03 09 F7")))
        XCTAssertNil(ADI2Protocol.parse(hex("F0 00 20 0D 70 03 09 F7")))
        XCTAssertNil(ADI2Protocol.parse(hex("F0 00 20 0D 71 03 89 F7")))
        XCTAssertThrowsError(try ADI2Protocol.parseParameters([0,0]))
        XCTAssertThrowsError(try ADI2Protocol.parseParameters([0,0,0x80]))
    }
    func testProfileJSONMatchesLinuxKeysAndRoundTrips() throws {
        let profile=EQProfile.dt1990
        let data=try JSONEncoder().encode(profile)
        let text=String(decoding:data,as:UTF8.self)
        XCTAssertTrue(text.contains("freq_hz")); XCTAssertTrue(text.contains("gain_db")); XCTAssertTrue(text.contains("eq_enable"))
        XCTAssertEqual(try JSONDecoder().decode(EQProfile.self,from:data),profile)
    }
    func testProfileWireBothChannelsAndSwitches() throws {
        let values=try ADI2Protocol.parseParameters(EQProfile.dt1990.containers().flatMap {$0})
        for address in [7,8] {
            XCTAssertEqual(values.first {$0.address == address && $0.index == 4}?.raw,13)
            XCTAssertEqual(values.first {$0.address == address && $0.index == 18}?.raw,10000)
            XCTAssertEqual(values.first {$0.address == address && $0.index == 20}?.raw,0)
        }
        XCTAssertFalse(values.contains {$0.index == 12 && $0.address == 6}) // profile never changes volume
    }
    func testProfileRejectsUnsupportedBandsAndNonFinite() {
        var p=EQProfile.flat;p.bands[1].type="Shelf";XCTAssertThrowsError(try p.containers())
        p = .flat;p.bands[3].frequency=100;XCTAssertThrowsError(try p.containers())
        p = .flat;p.bands[0].gainDB = .infinity;XCTAssertThrowsError(try p.containers())
        p.bands=[];XCTAssertThrowsError(try p.containers())
    }
    let apo="""
    Preamp: -6.5 dB
    Filter 1: ON LSC Fc 105 Hz Gain 6.5 dB Q 0.70
    Filter 2: ON PK Fc 150 Hz Gain -2.0 dB Q 0.50
    Filter 3: ON PK Fc 4200 Hz Gain 4.5 dB Q 3.50
    Filter 4: ON PK Fc 7400 Hz Gain -3.0 dB Q 3.40
    Filter 5: ON HSC Fc 10000 Hz Gain -7.5 dB Q 0.70
    """
    func testAPOImportMatchesHardwareVerifiedProfileAndWarnsPreamp() throws {
        let r=try EQImporter.parse(text:apo,name:"Reference",output:.line)
        XCTAssertEqual(r.profile.bands,EQProfile.dt1990.bands)
        XCTAssertEqual(r.profile.output,.line);XCTAssertEqual(r.preampDB,-6.5)
        XCTAssertTrue(r.warnings.contains {$0.contains("Preamp")})
    }
    func testTenBandReductionKeepsStrongestAndReportsDropped() throws {
        let text=(1...10).map {"Filter \($0): ON PK Fc \($0 * 1000) Hz Gain \($0) dB Q 1"}.joined(separator:"\n")
        let r=try EQImporter.parse(text:text)
        XCTAssertEqual(r.profile.bands.map(\.gainDB),[6,7,8,9,10])
        XCTAssertTrue(r.warnings.contains {$0.contains("Dropped 5")})
    }
    func testCSVQuotedHeaderCRLFAndJSONAliases() throws {
        let csv="\"frequency\",gain_db,q,type\r\n105,6.5,0.7,LS\r\n4200,4.5,3.5,PK\r\n10000,-7.5,0.7,HS\r\n"
        let r=try EQImporter.parse(text:csv)
        XCTAssertEqual(r.profile.bands[0].type,"Shelf");XCTAssertEqual(r.profile.bands[4].frequency,10000)
        let json=#"{"name":"Test","filters":[{"type":"LOW_SHELF","frequency":105,"gain":6.5,"q":0.7},{"type":"PEAKING","fc":4200,"gain_db":4.5,"q":3.5}]}"#
        let j=try EQImporter.parse(text:json)
        XCTAssertEqual(j.profile.name,"Test");XCTAssertEqual(j.profile.bands[1].gainDB,4.5)
    }
    func testOwnProfileImportPreservesContentAndSelectsOutput() throws {
        let text=String(decoding:try JSONEncoder().encode(EQProfile.dt1990),as:UTF8.self)
        let r=try EQImporter.parse(text:text,output:.line)
        XCTAssertEqual(r.profile.bands,EQProfile.dt1990.bands);XCTAssertEqual(r.profile.output,.line);XCTAssertEqual(r.warnings,[])
    }
    func testImportClampsAndReportsInvalidFilters() throws {
        let r=try EQImporter.parse(text:"Filter 1: ON LSC Fc 10 Hz Gain 15 dB Q 0.2\nFilter 2: ON LSC Fc 80 Hz Gain 3 dB Q 0.7\nFilter 3: ON PK Fc 24000 Hz Gain -14 dB Q 12")
        XCTAssertEqual(r.profile.bands[0].frequency,20);XCTAssertEqual(r.profile.bands[0].gainDB,12);XCTAssertEqual(r.profile.bands[0].q,0.5)
        XCTAssertTrue(r.warnings.contains {$0.contains("extra low shelf")})
        XCTAssertTrue(r.warnings.contains {$0.contains("20000")})
    }
    func testMalformedAndNonFiniteImportsRejectSafely() {
        for text in ["", "not an eq file", "{broken", #"{"filters":[]}"#, "frequency,gain\nnan,3", "frequency,gain\ninf,3", "\"unterminated"] { XCTAssertThrowsError(try EQImporter.parse(text:text),text) }
        XCTAssertNoThrow(try EQImporter.parse(text:"frequency,gain\n1e300,3"))
    }
    func testEQResponseSanity() {
        XCTAssertEqual(EQResponse.decibels(profile:.flat,frequency:1000),0,accuracy:1e-9)
        var p=EQProfile.flat;p.bands[2].gainDB=6
        XCTAssertEqual(EQResponse.decibels(profile:p,frequency:1000),6,accuracy:0.001)
        p.eqEnabled=false;XCTAssertEqual(EQResponse.decibels(profile:p,frequency:1000),0)
    }
    func testRegistryDeviceFilteringAndWireUnits() throws {
        XCTAssertEqual(ParameterRegistry.input(for:.dac).count,0)
        XCTAssertEqual(ParameterRegistry.output(for:.dac,output:.line).first {$0.index == 2}?.labels,["-5 dBu","+1 dBu","+7 dBu","+13 dBu"])
        let volume=try XCTUnwrap(ParameterRegistry.output(for:.dac,output:.phones).first {$0.index == 12})
        XCTAssertEqual(try volume.raw(-10),-100)
        XCTAssertTrue(ParameterRegistry.device(for:.dac).contains {$0.index == 16 && $0.isReadOnly})
        XCTAssertEqual(Set(ParameterRegistry.eq.map(\.index)).count,ParameterRegistry.eq.count)
    }
}

extension ADI2CoreTests {
    func testSyncRequiresEveryRequiredValueFromFreshRequest() throws {
        let keys=DeviceStateAccumulator.requiredKeys(output:.phones).sorted { ($0.address,$0.index) < ($1.address,$1.index) }
        var state=DeviceStateAccumulator(output:.phones)
        XCTAssertFalse(state.isComplete)
        let first=Array(keys.dropLast()).map {ParameterValue(address:$0.address,index:$0.index,raw:0)}
        state.receive(first)
        XCTAssertFalse(state.isComplete)
        let last=try XCTUnwrap(keys.last)
        state.receive([ParameterValue(address:last.address,index:last.index,raw:0)])
        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(DeviceStateAccumulator(output:.phones).isComplete)
        var other=DeviceStateAccumulator(output:.line);other.receive(first)
        XCTAssertFalse(other.isComplete)
    }
    func testSyncRequiresRightChannelAndObservedVolume() {
        var state=DeviceStateAccumulator(output:.phones)
        let keys=DeviceStateAccumulator.requiredKeys(output:.phones)
        state.receive(keys.filter {$0.address != Output.phones.right}.map {ParameterValue(address:$0.address,index:$0.index,raw:0)})
        XCTAssertFalse(state.isComplete)
        state.receive(keys.filter {$0.address == Output.phones.right}.map {ParameterValue(address:$0.address,index:$0.index,raw:0)})
        XCTAssertTrue(state.isComplete)
        var noVolume=DeviceStateAccumulator(output:.phones)
        noVolume.receive(keys.filter {!($0.address == 6 && $0.index == 12)}.map {ParameterValue(address:$0.address,index:$0.index,raw:0)})
        XCTAssertFalse(noVolume.isComplete)
    }
}

extension ADI2CoreTests {
    func validState() throws -> [ParameterAddress:Int] {
        var state: [ParameterAddress:Int] = [:]
        for p in try ADI2Protocol.parseParameters(EQProfile.dt1990.containers().flatMap {$0}) { state[ParameterAddress(address:p.address,index:p.index)] = p.raw }
        state[ParameterAddress(address:6,index:12)] = -100
        return state
    }
    func testValidatedHardwareProfileMatchesBothChannels() throws {
        let state=DeviceStateAccumulator(output:.phones,values:try validState())
        XCTAssertEqual(try state.profile().bands,EQProfile.dt1990.bands)
        XCTAssertEqual(try state.profile(right:true).bands,EQProfile.dt1990.bands)
        XCTAssertNoThrow(try state.validate(device:.dac))
    }
    func testIncompleteAndInvalidHardwareCannotHydrateReadyState() throws {
        XCTAssertThrowsError(try DeviceStateAccumulator(output:.phones).profile())
        for (key,value) in [(ParameterAddress(address:7,index:3),99),(ParameterAddress(address:7,index:4),25),(ParameterAddress(address:8,index:6),0),(ParameterAddress(address:8,index:14),199),(ParameterAddress(address:6,index:12),1000),(ParameterAddress(address:8,index:2),2)] {
            var values=try validState();values[key]=value
            let state=DeviceStateAccumulator(output:.phones,values:values)
            XCTAssertThrowsError(try state.validate(device:.dac))
        }
    }
    func testKnownParametersValidateAndUnknownRemainForwardCompatible() throws {
        var values=try validState()
        values[ParameterAddress(address:12,index:63)] = 1000
        XCTAssertNoThrow(try DeviceStateAccumulator(output:.phones,values:values).validate(device:.dac))
        values[ParameterAddress(address:12,index:2)] = 999
        XCTAssertThrowsError(try DeviceStateAccumulator(output:.phones,values:values).validate(device:.dac))
    }
}

extension ADI2CoreTests {
    func testPresetSaveMatchesLinuxWireOracleAndSeparateCommit() throws {
        let messages=try EQProfile.dt1990.presetMessages(device:0x71,slot:2,name:"Studio")
        // The explicit fixture below is generated by the Linux app's encoding,
        // including exactly 17 band containers per preset channel.
        let actualOracle=hex("F0 00 20 0D 71 02 68 60 01 69 00 0D 69 20 69 69 40 07 69 7F 7C 6A 01 16 6A 20 05 6A 40 09 6A 73 24 6B 00 23 6B 3F 7A 6B 55 64 6B 60 22 6C 00 01 6C 3F 71 6C 57 68 6C 60 07 70 60 01 71 00 0D 71 20 69 71 40 07 71 7F 7C 72 01 16 72 20 05 72 40 09 72 73 24 73 00 23 73 3F 7A 73 55 64 73 60 22 74 00 01 74 3F 71 74 57 68 74 60 07 F7")
        XCTAssertEqual(messages.count,3)
        XCTAssertEqual(messages[0],actualOracle)
        XCTAssertEqual(messages[0].count,109)
        XCTAssertEqual(messages[1],hex("F0 00 20 0D 71 02 68 40 10 F7"))
        XCTAssertEqual(messages[2],hex("F0 00 20 0D 71 06 02 20 20 20 20 20 20 20 20 53 74 75 64 69 6F 00 00 F7"))
        let parameters=try ADI2Protocol.parseParameters(ADI2Protocol.parse(messages[0])!.payload)
        XCTAssertEqual(parameters.count,34)
        XCTAssertFalse(parameters.contains {$0.index == 2 || $0.index == 20},"Preset staging faithfully sends bands only; no invented enable/Bass/Treble fields.")
    }
    func testPresetBoundsNamesAndPairedLoadSelector() throws {
        XCTAssertEqual(try ADI2Protocol.loadEQPreset(device:0x71,output:.phones,slot:20),hex("F0 00 20 0D 71 02 3F 00 15 47 00 15 F7"))
        XCTAssertEqual(try EQProfile.flat.presetMessages(device:0x73,slot:1).count,2)
        for slot in [0,21] {
            XCTAssertThrowsError(try EQProfile.flat.presetMessages(device:0x71,slot:slot))
            XCTAssertThrowsError(try ADI2Protocol.loadEQPreset(device:0x71,output:.phones,slot:slot))
        }
        XCTAssertThrowsError(try EQProfile.flat.presetMessages(device:0x70,slot:1))
        XCTAssertThrowsError(try ADI2Protocol.loadEQPreset(device:0x71,output:.phones34,slot:1))
        XCTAssertThrowsError(try EQProfile.flat.presetMessages(device:0x71,slot:1,name:"123456789012345"))
        XCTAssertThrowsError(try EQProfile.flat.presetMessages(device:0x71,slot:1,name:"Héllo"))
        XCTAssertThrowsError(try EQProfile.flat.presetMessages(device:0x71,slot:1,name:"Bad\nName"))
        var bad=EQProfile.flat;bad.bands=[]
        XCTAssertThrowsError(try bad.presetMessages(device:0x71,slot:1))
    }
    func testLocalLibraryRoundTripUniqueNamesAndRemoval() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let library=FileProfileLibrary(directory:root)
        var profile=EQProfile.dt1990;profile.name="../../A profile / with a path"
        let first=try library.save(profile),second=try library.save(profile)
        XCTAssertFalse(first.id == second.id)
        XCTAssertTrue(UUID(uuidString:first.id) != nil)
        XCTAssertEqual(try library.list().profiles.count,2)
        XCTAssertEqual(try library.list().profiles.first?.profile,profile)
        let file=root.appendingPathComponent(first.id + ".json")
        let text=try String(contentsOf:file,encoding:.utf8)
        XCTAssertTrue(text.contains("freq_hz"));XCTAssertTrue(text.contains("eq_enable"))
        XCTAssertEqual(try EQImporter.parse(text:text).profile.bands,profile.bands)
        try library.remove(id:first.id)
        XCTAssertEqual(try library.list().profiles.map(\.id),[second.id])
        XCTAssertThrowsError(try library.remove(id:"../outside"))
    }
    func testLocalLibraryListsHealthyProfilesAlongsideCorruptFiles() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let library=FileProfileLibrary(directory:root)
        var z=EQProfile.flat;z.name="Zulu"
        var a=EQProfile.flat;a.name="Alpha"
        _ = try library.save(z);_ = try library.save(a)
        try Data("{broken".utf8).write(to:root.appendingPathComponent(UUID().uuidString + ".json"))
        let outside=root.appendingPathComponent("target.txt")
        try Data("private unrelated file".utf8).write(to:outside)
        let linkID=UUID().uuidString
        try FileManager.default.createSymbolicLink(at:root.appendingPathComponent(linkID + ".json"),withDestinationURL:outside)
        let listing=try library.list()
        XCTAssertEqual(listing.profiles.map { $0.profile.name },["Alpha","Zulu"])
        XCTAssertEqual(listing.warnings.count,2)
        XCTAssertThrowsError(try library.remove(id:linkID))
        XCTAssertTrue(FileManager.default.fileExists(atPath:outside.path))
        var invalid=EQProfile.flat;invalid.bands[0].gainDB=100
        XCTAssertThrowsError(try library.save(invalid))
    }
}

extension ADI2CoreTests {
    func testPresetBufferCommitFlagIsNotValidatedAsLiveEQEnable() throws {
        var values=try validState()
        values[ParameterAddress(address:13,index:2)] = 19 << 4
        values[ParameterAddress(address:14,index:2)] = 19 << 4
        XCTAssertNoThrow(try DeviceStateAccumulator(output:.phones,values:values).validate(device:.dac))
        values[ParameterAddress(address:8,index:2)] = 19 << 4
        XCTAssertThrowsError(try DeviceStateAccumulator(output:.phones,values:values).validate(device:.dac))
    }
}

#if !canImport(XCTest)
@main struct CoreTestRunner {
 static func main() throws {
 let tests=ADI2CoreTests()
 try tests.testOfficialVolumeOracle()
 try tests.testOfficialInputAndRequestOracles()
 try tests.testOfficialFrequencyOracle()
 try tests.testSignedAndDevicePackingBoundaries()
 tests.testEncoderRejectsInvalidInputsWithoutTrapping()
 try tests.testNameAndSetupMessages()
 tests.testFramerAcrossPacketsAndRealtime()
 tests.testFramerRecoversFromCorruptAndOversizeFrames()
 try tests.testParserRejectsForeignAndMalformedMessages()
 try tests.testProfileJSONMatchesLinuxKeysAndRoundTrips()
 try tests.testProfileWireBothChannelsAndSwitches()
 tests.testProfileRejectsUnsupportedBandsAndNonFinite()
 try tests.testAPOImportMatchesHardwareVerifiedProfileAndWarnsPreamp()
 try tests.testTenBandReductionKeepsStrongestAndReportsDropped()
 try tests.testCSVQuotedHeaderCRLFAndJSONAliases()
 try tests.testOwnProfileImportPreservesContentAndSelectsOutput()
 try tests.testImportClampsAndReportsInvalidFilters()
 tests.testMalformedAndNonFiniteImportsRejectSafely()
 tests.testEQResponseSanity()
 try tests.testRegistryDeviceFilteringAndWireUnits()
 try tests.testSyncRequiresEveryRequiredValueFromFreshRequest()
 tests.testSyncRequiresRightChannelAndObservedVolume()
 try tests.testValidatedHardwareProfileMatchesBothChannels()
 try tests.testIncompleteAndInvalidHardwareCannotHydrateReadyState()
 try tests.testKnownParametersValidateAndUnknownRemainForwardCompatible()
 try tests.testPresetSaveMatchesLinuxWireOracleAndSeparateCommit()
 try tests.testPresetBoundsNamesAndPairedLoadSelector()
 try tests.testLocalLibraryRoundTripUniqueNamesAndRemoval()
 try tests.testLocalLibraryListsHealthyProfilesAlongsideCorruptFiles()
 try tests.testPresetBufferCommitFlagIsNotValidatedAsLiveEQEnable()
 print("ADI2Core: 30 cases, \(assertionCount) assertions, \(failureCount) failures")
 if failureCount > 0 {exit(1)}
 }
}
#endif
