import Foundation
import CoreMIDI
import ADI2Core
#if canImport(ADI2Mac)
@testable import ADI2Mac
#endif
#if canImport(XCTest)
import XCTest
#else
private var assertionCount = 0
private var failureCount = 0
class XCTestCase {}
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, _ message:String = "", file:StaticString=#filePath,line:UInt=#line) { assertionCount += 1; do { if try !value() {failureCount += 1; print("FAIL \(file):\(line) \(message)")} } catch {failureCount += 1; print("FAIL \(file):\(line) \(error)")} }
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, _ message:String = "", file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(try !value(),message,file:file,line:line) }
func XCTAssertEqual<T:Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message:String = "", file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(try a() == b(),message,file:file,line:line) }
func XCTAssertNotNil<T>(_ value:T?,file:StaticString=#filePath,line:UInt=#line) { XCTAssertTrue(value != nil,file:file,line:line) }
func XCTUnwrap<T>(_ value:T?,file:StaticString=#filePath,line:UInt=#line) throws -> T { guard let value else {XCTAssertTrue(false,file:file,line:line);throw ADI2Error.invalid("Missing fixture value")};return value }
#endif

@MainActor private final class FakeMIDIConnection: MIDIConnection {
    var onDevicesChanged: (() -> Void)?
    var onMessage: (([UInt8]) -> Void)?
    var sent: [[UInt8]] = []
    var attempts: [[UInt8]] = []
    var failNextSend = false
    var connectedDevice: MIDIDevice?
    var available = [MIDIDevice(id:1,name:"ADI-2 DAC test fixture",model:.dac,destination:1,source:1)]
    func devices() -> [MIDIDevice] { available }
    func connect(_ device:MIDIDevice) throws { connectedDevice = device }
    func send(_ bytes:[UInt8]) throws {
        attempts.append(bytes)
        if failNextSend { failNextSend = false; throw ADI2Error.invalid("Injected MIDI send failure") }
        guard connectedDevice != nil else { throw ADI2Error.invalid("Fake MIDI is disconnected") }
        sent.append(bytes)
    }
    func disconnect() { connectedDevice = nil }
    func deliver(_ containers:[[UInt8]],device:UInt8 = 0x71) {
        onMessage?(ADI2Protocol.message(device:device,command:1,payload:containers.flatMap {$0}))
    }
}

@MainActor final class AppModelTests: XCTestCase {
    private func fixture(output:Output = .phones) throws -> [[UInt8]] {
        var p=EQProfile.flat;p.output=output
        return try p.containers() + [ADI2Protocol.encode(address:output.channel,index:12,raw:-300)]
    }
    private func ready(_ fake:FakeMIDIConnection,_ model:AppModel,output:Output = .phones) throws {
        model.connect();fake.deliver(try fixture(output:output))
        XCTAssertTrue(model.canWrite)
    }
    func testInitialConnectionRequiresWholeFreshStateBeforeWrites() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        model.connect()
        XCTAssertTrue(model.syncing);XCTAssertFalse(model.connected);XCTAssertFalse(model.canWrite)
        XCTAssertEqual(fake.sent,[ADI2Protocol.requestAll(device:0x71)])
        let volume=try XCTUnwrap(model.parameters.first {$0.index == 12})
        model.setParameter(volume,value:-20);model.applyProfile()
        XCTAssertEqual(fake.sent.count,1)
        let containers=try fixture()
        fake.deliver(Array(containers.prefix(20)))
        XCTAssertFalse(model.connected);XCTAssertFalse(model.canWrite)
        fake.deliver(Array(containers.dropFirst(20)))
        XCTAssertTrue(model.connected);XCTAssertTrue(model.canWrite)
        model.setParameter(volume,value:-20)
        XCTAssertEqual(fake.sent.count,2)
        let write=try XCTUnwrap(ADI2Protocol.parse(fake.sent.last!))
        XCTAssertEqual(write.command,2)
        XCTAssertEqual(try ADI2Protocol.parseParameters(write.payload),[ParameterValue(address:6,index:12,raw:-200)])
        model.sync()
        XCTAssertFalse(model.canWrite)
        fake.deliver(Array(containers.prefix(20)))
        XCTAssertFalse(model.canWrite,"A new sync cannot reuse values from its predecessor.")
        fake.deliver(Array(containers.dropFirst(20)))
        XCTAssertTrue(model.canWrite)
    }
    func testWrongDeviceRepliesCannotCompleteConnection() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        model.connect();fake.deliver(try fixture(),device:0x72)
        XCTAssertFalse(model.canWrite);XCTAssertFalse(model.connected)
        fake.deliver(try fixture())
        XCTAssertTrue(model.canWrite)
    }
    func testChangingOutputDuringInitialSyncStartsIndependentState() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        model.connect()
        fake.deliver(Array(try fixture().prefix(10)))
        model.selectOutput(.line)
        XCTAssertEqual(fake.sent.count,2)
        XCTAssertTrue(model.syncing);XCTAssertFalse(model.canWrite)
        fake.deliver(try fixture(output:.phones))
        XCTAssertFalse(model.canWrite,"The former output cannot establish readiness for the newly selected output.")
        fake.deliver(try fixture(output:.line))
        XCTAssertTrue(model.canWrite)
        XCTAssertEqual(model.profile.output,.line)
    }
    func testConnectedOutputSwitchWaitsForPreviouslyUnseenOutput() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        try ready(fake,model)
        model.selectOutput(.line)
        XCTAssertTrue(fake.connectedDevice != nil,"An uncached output must trigger a read without dropping the MIDI connection.")
        XCTAssertTrue(model.syncing);XCTAssertFalse(model.canWrite)
        XCTAssertEqual(fake.sent.count,2)
        fake.deliver(try fixture(output:.line))
        XCTAssertTrue(model.canWrite)
        XCTAssertEqual(model.profile.output,.line)
    }
    func testOfflineImportedDraftSurvivesConnectingAndSyncing() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        let imported=try EQImporter.parse(text:"Filter 1: ON PK Fc 100 Hz Gain 3 dB Q 1",output:.phones)
        model.profile=imported.profile
        model.updateBand(index:0,band:imported.profile.bands[0])
        let draft=model.profile
        XCTAssertTrue(model.hasDraft)
        try ready(fake,model)
        XCTAssertEqual(model.profile,draft)
        XCTAssertTrue(model.hasDraft)
        XCTAssertEqual(fake.sent.count,1,"Connecting and reading must not apply an offline draft.")
    }
    func testFailedProfileWriteDisconnectsAndPreservesDraft() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        try ready(fake,model)
        model.loadReference();let draft=model.profile
        fake.failNextSend=true
        model.applyProfile()
        XCTAssertFalse(model.canWrite);XCTAssertFalse(model.connected)
        XCTAssertTrue(model.hasDraft);XCTAssertEqual(model.profile,draft)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(fake.connectedDevice == nil)
        XCTAssertEqual(fake.attempts.count,2)
    }
    func testDisconnectedAndDemoControlsSendNoMIDI() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        let volume=try XCTUnwrap(model.parameters.first {$0.index == 12})
        model.loadReference();model.setParameter(volume,value:-30);model.applyProfile();model.sync()
        XCTAssertEqual(fake.attempts.count,0)
        model.startDemo()
        model.setParameter(volume,value:-40)
        model.loadReference();model.applyProfile();model.sync()
        let gain=try XCTUnwrap(ParameterRegistry.eq.first {$0.index == 4})
        model.setEQParameter(gain,value:2)
        XCTAssertTrue(model.demoMode);XCTAssertFalse(model.canWrite)
        XCTAssertEqual(fake.attempts.count,0)
        model.stopDemo();model.applyProfile()
        XCTAssertEqual(fake.attempts.count,0)
    }
    func testSampleRateDisplayCannotSendWrite() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        model.connect()
        fake.deliver(try fixture() + [ADI2Protocol.encodeDevice(index:16,raw:1)])
        XCTAssertTrue(model.canWrite)
        model.section="device"
        let rate=try XCTUnwrap(model.parameters.first {$0.index == 16})
        let count=fake.sent.count
        model.setParameter(rate,value:2)
        XCTAssertEqual(fake.sent.count,count)
        XCTAssertEqual(model.values[ParameterAddress(address:12,index:16)],1)
    }
    func testCompleteButInvalidStateDisconnectsBeforeAllowingWrites() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        model.connect()
        fake.deliver(try fixture() + [ADI2Protocol.encode(address:8,index:6,raw:0)])
        XCTAssertFalse(model.connected);XCTAssertFalse(model.canWrite)
        XCTAssertFalse(model.syncing);XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(fake.connectedDevice == nil)
        XCTAssertEqual(fake.sent.count,1)
    }
    func testInvalidLiveStateWhileEditingRevokesWrites() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        defer {model.disconnect()}
        try ready(fake,model)
        model.loadReference();let draft=model.profile
        fake.deliver([try ADI2Protocol.encode(address:8,index:6,raw:0)])
        XCTAssertFalse(model.canWrite);XCTAssertFalse(model.connected)
        XCTAssertTrue(model.hasDraft);XCTAssertEqual(model.profile,draft)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(fake.connectedDevice == nil)
    }
    func testDeviceRemovalRevokesWriteReadiness() async throws {
        let fake=FakeMIDIConnection(),model=AppModel(midi:fake)
        try ready(fake,model)
        fake.available=[];fake.onDevicesChanged?()
        XCTAssertFalse(model.connected);XCTAssertFalse(model.canWrite)
        XCTAssertTrue(fake.connectedDevice == nil)
        model.applyProfile()
        XCTAssertEqual(fake.sent.count,1)
    }
}

#if !canImport(XCTest)
@main struct AppModelTestRunner {
    @MainActor static func main() async throws {
        let tests=AppModelTests()
        try await tests.testInitialConnectionRequiresWholeFreshStateBeforeWrites()
        try await tests.testWrongDeviceRepliesCannotCompleteConnection()
        try await tests.testChangingOutputDuringInitialSyncStartsIndependentState()
        try await tests.testConnectedOutputSwitchWaitsForPreviouslyUnseenOutput()
        try await tests.testOfflineImportedDraftSurvivesConnectingAndSyncing()
        try await tests.testFailedProfileWriteDisconnectsAndPreservesDraft()
        try await tests.testDisconnectedAndDemoControlsSendNoMIDI()
        try await tests.testSampleRateDisplayCannotSendWrite()
        try await tests.testCompleteButInvalidStateDisconnectsBeforeAllowingWrites()
        try await tests.testInvalidLiveStateWhileEditingRevokesWrites()
        try await tests.testDeviceRemovalRevokesWriteReadiness()
        print("AppModel: 11 cases, \(assertionCount) assertions, \(failureCount) failures")
        if failureCount > 0 {exit(1)}
    }
}
#endif
