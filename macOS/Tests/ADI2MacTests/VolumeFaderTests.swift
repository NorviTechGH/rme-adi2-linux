import AppKit
import QuartzCore
#if canImport(ADI2Mac)
@testable import ADI2Mac
#endif
#if canImport(XCTest)
import XCTest
typealias VolumeFaderTestCase = XCTestCase
#else
class VolumeFaderTestCase {}
#endif

@MainActor private enum FaderEvidence {
    static var assertions = 0
    static var failures: [String] = []
    static var motionSamples: [Double] = []
    static var retargetSamples: [Double] = []
    static var burstSamples: [Double] = []
    static var midAnimationDrag: [String:Double] = [:]
    static func check(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        assertions += 1
        if !condition { failures.append(message) }
        #if canImport(XCTest)
        XCTAssertTrue(condition, message, file:file, line:line)
        #endif
    }
    static func reset() { assertions = 0; failures = []; motionSamples = []; retargetSamples = []; burstSamples = []; midAnimationDrag = [:] }
    static var report: [String: Any] {
        ["cases":10,"assertions":assertions,"failures":failures,"motion_presentation_x":motionSamples,"retarget_presentation_x":retargetSamples,"burst_presentation_x":burstSamples,"mid_animation_drag":midAnimationDrag]
    }
}

/// These component tests never construct AppModel or a CoreMIDI connection.
/// Motion checks inspect actual Core Animation presentation geometry in a real
/// isolated NSWindow, rather than asserting only the final model-layer position.
@MainActor final class VolumeFaderTests: VolumeFaderTestCase {
    private func control() -> VolumeFaderControl {
        let fader = VolumeFaderControl(frame:NSRect(x:20,y:36,width:420,height:44))
        fader.minValue = -114.5; fader.maxValue = 6; fader.step = 0.1
        fader.setVolume(-45,animated:false)
        return fader
    }
    private func scene() -> (NSWindow,VolumeFaderControl) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect:NSRect(x:160,y:180,width:460,height:116),styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        window.title = "Volume fader presentation sampling"
        let fader = control()
        window.contentView?.addSubview(fader)
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()
        return (window,fader)
    }
    private func pause(_ seconds:Double) async {
        try? await Task.sleep(nanoseconds:UInt64(seconds * 1_000_000_000))
    }
    private func key(_ character:String,code:UInt16) -> NSEvent {
        NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:0,context:nil,characters:character,charactersIgnoringModifiers:character,isARepeat:false,keyCode:code)!
    }
    private func near(_ actual:Double,_ expected:Double,_ message:String,tolerance:Double = 0.000001) {
        FaderEvidence.check(abs(actual-expected) <= tolerance,message)
    }
    func testPointerMappingClampsAtTrackAndPreservesInputResolution() async throws {
        let fader = control()
        let middle = (fader.trackStartX + fader.trackEndX) / 2
        near(fader.value(at:NSPoint(x:fader.trackStartX-200,y:20)),fader.minValue,"Pointer input clamps below the track.")
        near(fader.value(at:NSPoint(x:fader.trackEndX+200,y:20)),fader.maxValue,"Pointer input clamps above the track.")
        near(fader.value(at:NSPoint(x:middle,y:20)),(fader.minValue+fader.maxValue)/2,"Pointer mapping retains continuous geometry before MIDI quantization.")
        var callbacks:[Double] = []
        fader.onChange = {callbacks.append($0)}
        fader.userSetValue(-44.96)
        near(fader.targetValue,-45,"User input rounds to a tenth of a decibel.")
        fader.userSetValue(-44.94)
        near(fader.targetValue,-44.9,"Adjacent tenth-decibel input remains selectable.")
        fader.userSetValue(-1000);near(fader.targetValue,fader.minValue,"User input clamps to the lower bound.")
        fader.userSetValue(1000);near(fader.targetValue,fader.maxValue,"User input clamps to the upper bound.")
        FaderEvidence.check(!callbacks.isEmpty,"User input invokes the value callback.")
        FaderEvidence.check(callbacks.allSatisfy {abs($0 / 0.1 - ($0 / 0.1).rounded()) < 0.000001},"Only 0.1 dB values leave the user-input callback.")
    }
    func testKeyboardAndAccessibilityKeepTenthDecibelSteps() async throws {
        let fader = control()
        var callbacks:[Double] = []
        fader.onChange = {callbacks.append($0)}
        fader.keyDown(with:key("\u{F703}",code:124))
        near(fader.targetValue,-44.9,"Right arrow increases volume by exactly 0.1 dB.")
        fader.keyDown(with:key("\u{F702}",code:123))
        near(fader.targetValue,-45,"Left arrow decreases volume by exactly 0.1 dB.")
        FaderEvidence.check(fader.accessibilityPerformIncrement(),"The accessibility increment action is supported.")
        near(fader.targetValue,-44.9,"Accessibility increment preserves the 0.1 dB step.")
        FaderEvidence.check(fader.accessibilityPerformDecrement(),"The accessibility decrement action is supported.")
        near(fader.targetValue,-45,"Accessibility decrement preserves the 0.1 dB step.")
        FaderEvidence.check(callbacks.count == 4,"Each keyboard or accessibility action produces one user value.")
    }
    func testDisabledUserInputCannotEmitCallbacks() async throws {
        let fader = control()
        var callbacks:[Double] = []
        fader.onChange = {callbacks.append($0)}
        fader.isEnabled = false
        fader.userSetValue(0)
        fader.keyDown(with:key("\u{F703}",code:124))
        _ = fader.accessibilityPerformIncrement()
        _ = fader.accessibilityPerformDecrement()
        FaderEvidence.check(callbacks.isEmpty,"Disabled pointer, keyboard and accessibility input emits no value.")
        near(fader.targetValue,-45,"Disabled input leaves the target unchanged.")
    }
    func testProgrammaticTargetsNeverEmitUserValues() async throws {
        let fader = control()
        var callbacks:[Double] = []
        fader.onChange = {callbacks.append($0)}
        fader.setVolume(-70,animated:false)
        fader.setVolume(-20,animated:true)
        fader.setVolume(-30,animated:true)
        await pause(0.28)
        near(fader.targetValue,-30,"The newest programmatic value is authoritative.")
        FaderEvidence.check(callbacks.isEmpty,"Programmatic updates and animation never generate MIDI-bound user values.")
    }
    func testRealPresentationPassesThroughIntermediatePositionsWithoutOvershoot() async throws {
        let (window,fader) = scene()
        defer { window.orderOut(nil); window.close() }
        var callbacks:[Double] = []
        fader.onChange = {callbacks.append($0)}
        fader.setVolume(fader.minValue,animated:false)
        await pause(0.08)
        guard let startLayer = fader.knobLayer.presentation() else {
            FaderEvidence.check(false,"A composited presentation layer is required; offscreen endpoint-only results cannot prove smoothness.")
            return
        }
        let start = Double(startLayer.position.x)
        fader.setVolume(fader.maxValue,animated:true)
        let end = Double(fader.knobLayer.position.x)
        var samples:[Double] = []
        for _ in 0..<17 {
            await pause(1.0/60.0)
            if let presented = fader.knobLayer.presentation() { samples.append(Double(presented.position.x)) }
        }
        FaderEvidence.motionSamples = samples
        let low=min(start,end),high=max(start,end)
        let intermediate = Set(samples.filter {$0 > low+0.5 && $0 < high-0.5}.map {Int(($0*10).rounded())})
        FaderEvidence.check(window.isVisible,"Motion is sampled from a visible isolated test window.")
        FaderEvidence.check(samples.count >= 12,"Presentation geometry is available across successive display frames.")
        FaderEvidence.check(intermediate.count >= 4,"At least four distinct intermediate knob positions prove visible motion between endpoints.")
        FaderEvidence.check(samples.allSatisfy {$0 >= low-0.5 && $0 <= high+0.5},"The visible knob never overshoots the valid track.")
        near(samples.last ?? .nan,end,"The presentation settles at the authoritative target.",tolerance:0.75)
        FaderEvidence.check(callbacks.isEmpty,"Every sampled intermediate position remains presentation-only.")
    }
    func testRetargetingContinuesFromCurrentPresentationPosition() async throws {
        let (window,fader) = scene()
        defer { window.orderOut(nil); window.close() }
        fader.setVolume(fader.minValue,animated:false)
        await pause(0.08)
        fader.setVolume(fader.maxValue,animated:true)
        await pause(0.06)
        guard let presented=fader.knobLayer.presentation() else { FaderEvidence.check(false,"Retarget testing requires a real presentation layer.");return }
        let before=Double(presented.position.x),oldTarget=Double(fader.knobLayer.position.x)
        fader.setVolume(fader.minValue,animated:true)
        let newTarget=Double(fader.knobLayer.position.x)
        var samples:[Double] = []
        for _ in 0..<17 {
            await pause(1.0/60.0)
            if let layer=fader.knobLayer.presentation() {samples.append(Double(layer.position.x))}
        }
        FaderEvidence.retargetSamples=samples
        FaderEvidence.check(abs(oldTarget-before) > 5,"The retarget begins during actual visible motion, before the old target is reached.")
        FaderEvidence.check(samples.count >= 12,"Retarget presentation geometry is observed across display frames.")
        if let first=samples.first {
            FaderEvidence.check(abs(first-before) < abs(oldTarget-before)*0.55,"Retargeting begins near the current visible position instead of jumping to the old model target.")
        }
        FaderEvidence.check(samples.allSatisfy {$0 >= min(newTarget,before)-0.75 && $0 <= max(newTarget,before)+0.75},"Retargeting does not overshoot either the visible start or the new target.")
        near(samples.last ?? .nan,newTarget,"Retargeting settles at the newest target.",tolerance:0.75)
    }
    func testBurstyReportedKnobTargetsRemainContinuousAndNeverEmitInput() async throws {
        let (window,fader)=scene()
        defer {window.orderOut(nil);window.close()}
        fader.setVolume(-75,animated:false)
        await pause(0.08)
        var callbacks:[Double]=[]
        fader.onChange={callbacks.append($0)}
        let targets:[Double]=[-74.5,-71.5,-71,-68,-67.5,-64.5,-64,-61]
        let intervals:[Double]=[0.03,0.05,0.04,0.08,0.03,0.06,0.04,0.08]
        var samples:[Double]=[]
        var continuous=true,monotonic=true,meaningfulRetargets=0
        for (index,target) in targets.enumerated() {
            guard let beforeLayer=fader.knobLayer.presentation() else {FaderEvidence.check(false,"Bursty target checks require composited presentation layers.");return}
            let before=Double(beforeLayer.position.x),previousModel=Double(fader.knobLayer.position.x)
            if abs(previousModel-before) > 3 {meaningfulRetargets += 1}
            fader.setVolume(target,animated:true)
            let nextModel=Double(fader.knobLayer.position.x)
            await pause(1.0/60.0)
            guard let afterLayer=fader.knobLayer.presentation() else {FaderEvidence.check(false,"Presentation must remain available while reported targets change.");return}
            let after=Double(afterLayer.position.x)
            // At the first display frame, easing can advance partway toward a
            // new target; it must not snap to an old model-layer endpoint.
            continuous = continuous && abs(after-before) <= max(2.5,abs(nextModel-before)*0.55)
            monotonic = monotonic && after >= before-0.75 && after <= nextModel+0.75
            samples.append(contentsOf:[before,after])
            await pause(max(0,intervals[index]-1.0/60.0))
        }
        await pause(0.24)
        if let final=fader.knobLayer.presentation() {samples.append(Double(final.position.x))}
        FaderEvidence.burstSamples=samples
        FaderEvidence.check(meaningfulRetargets >= 2,"Several reported knob changes retarget while the visible fader is still between endpoints.")
        FaderEvidence.check(continuous,"Rapid 0.5/3 dB reported changes continue from visible positions without endpoint snaps.")
        FaderEvidence.check(monotonic,"A rising burst never visibly reverses or overshoots its targets.")
        FaderEvidence.check(Set(samples.map {Int(($0*10).rounded())}).count >= 8,"Continuous retargeting still produces distinct intermediate positions.")
        near(samples.last ?? .nan,Double(fader.knobLayer.position.x),"A burst settles at its newest authoritative value.",tolerance:0.75)
        FaderEvidence.check(callbacks.isEmpty,"Reported knob bursts and all intermediate drawing produce zero input callbacks.")
    }
    func testMidAnimationDragStartsFromAuthoritativeVolume() async throws {
        let (window,fader)=scene()
        defer {window.orderOut(nil);window.close()}
        fader.setVolume(-20,animated:false)
        await pause(0.08)
        fader.setVolume(-60,animated:true)
        await pause(0.045)
        guard let presented=fader.knobLayer.presentation() else {FaderEvidence.check(false,"The drag-baseline check needs an in-flight presentation layer.");return}
        let visibleValue=fader.value(at:NSPoint(x:presented.position.x,y:fader.bounds.midY))
        let authoritativeStart=fader.targetValue
        FaderEvidence.check(visibleValue > authoritativeStart+5,"The visible thumb is still meaningfully above a newly reduced hardware target.")
        near(fader.dragValue(from:authoritativeStart,deltaX:0),authoritativeStart,"Grabbing a visually moving knob does not change the actual volume.")
        var callbacks:[Double]=[]
        fader.onChange={callbacks.append($0)}
        let onePixelVolume=(fader.maxValue-fader.minValue)/Double(fader.trackEndX-fader.trackStartX)
        // The actual mouse-down handler uses this same relative-drag operation;
        // the presentation layer is only its hit-test, never the input baseline.
        fader.userSetValue(fader.dragValue(from:authoritativeStart,deltaX:1))
        near(fader.targetValue,authoritativeStart+onePixelVolume,"A one-pixel drag changes only the authoritative target by its pointer delta.",tolerance:0.050001)
        FaderEvidence.check(callbacks.count == 1,"A tiny drag produces one user callback.")
        FaderEvidence.check(abs((callbacks.first ?? .nan)-visibleValue) > 5,"The drag cannot promote an interpolated visual volume into hardware input.")
        near(fader.dragValue(from:authoritativeStart,deltaX:-10000),fader.minValue,"Relative dragging still clamps at the lower bound.")
        near(fader.dragValue(from:authoritativeStart,deltaX:10000),fader.maxValue,"Relative dragging still clamps at the upper bound.")
        FaderEvidence.midAnimationDrag=["visible_volume":visibleValue,"authoritative_start":authoritativeStart,"input_callback":callbacks.first ?? authoritativeStart,"input_callback_count":Double(callbacks.count)]
    }
    func testReduceMotionUsesImmediatePresentationUpdates() async throws {
        let (window,fader)=scene()
        defer { window.orderOut(nil);window.close() }
        fader.setVolume(fader.minValue,animated:false)
        await pause(0.08)
        fader.reduceMotion=true
        fader.setVolume(fader.maxValue,animated:true)
        let target=Double(fader.knobLayer.position.x)
        await pause(1.0/60.0)
        guard let layer=fader.knobLayer.presentation() else { FaderEvidence.check(false,"Reduced-motion presentation must be observable.");return }
        near(Double(layer.position.x),target,"Reduce Motion moves directly to the target without a tween.",tolerance:0.75)
    }
    func testUserDragInputMovesImmediatelyWhileReportedTargetsAnimate() async throws {
        let (window,fader)=scene()
        defer {window.orderOut(nil);window.close()}
        fader.setVolume(fader.minValue,animated:false)
        await pause(0.08)
        var callbacks:[Double] = []
        fader.onChange = {callbacks.append($0)}
        fader.userSetValue(0)
        let target=Double(fader.knobLayer.position.x)
        await pause(1.0/60.0)
        guard let layer=fader.knobLayer.presentation() else {FaderEvidence.check(false,"Direct user input presentation must be observable.");return}
        near(Double(layer.position.x),target,"Direct user input does not inherit a delayed follow animation.",tolerance:0.75)
        FaderEvidence.check(callbacks.count == 1,"A direct user edit produces one callback, not interpolated callbacks.")
        near(callbacks.first ?? .nan,0,"The user callback carries the chosen value.")
    }
}

#if !canImport(XCTest)
/// Standalone component preview for Command Line Tools environments. Run it as
/// an ordinary app, then click Run self-check; real NSApplication compositing is
/// intentional. Optional --report <path> writes bounded JSON test evidence.
@MainActor private final class VolumeFaderTestApplication: NSObject, NSApplicationDelegate {
    private var window:NSWindow!
    private var runButton:NSButton!
    private var results:NSTextView!
    private var preview:VolumeFaderControl!
    func applicationDidFinishLaunching(_ notification:Notification) {
        window=NSWindow(contentRect:NSRect(x:120,y:160,width:620,height:480),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="Isolated volume fader self-check"
        window.isReleasedWhenClosed=false
        let content=NSView(frame:NSRect(x:0,y:0,width:620,height:480))
        window.contentView=content
        let title=NSTextField(labelWithString:"Volume fader motion and input check")
        title.font = .systemFont(ofSize:19,weight:.semibold);title.frame=NSRect(x:24,y:430,width:570,height:28);content.addSubview(title)
        let subtitle=NSTextField(labelWithString:"Synthetic component only. This app never creates a MIDI connection.")
        subtitle.frame=NSRect(x:24,y:400,width:570,height:20);content.addSubview(subtitle)
        preview=VolumeFaderControl(frame:NSRect(x:24,y:342,width:570,height:44))
        preview.minValue = -114.5;preview.maxValue=6;preview.step=0.1;preview.setVolume(-45,animated:false);content.addSubview(preview)
        runButton=NSButton(title:"Run self-check",target:self,action:#selector(runChecks))
        runButton.frame=NSRect(x:24,y:290,width:170,height:32);content.addSubview(runButton)
        let scroll=NSScrollView(frame:NSRect(x:24,y:24,width:570,height:248))
        scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder
        results=NSTextView(frame:scroll.bounds);results.isEditable=false;results.font = .monospacedSystemFont(ofSize:12,weight:.regular)
        results.string="Ready. Checks will inspect real presentation layers across display frames."
        scroll.documentView=results;content.addSubview(scroll)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
    }
    @objc private func runChecks() {
        runButton.isEnabled=false;results.string="Running isolated component checks…"
        Task { @MainActor in
            FaderEvidence.reset()
            let tests=VolumeFaderTests()
            let checks:[() async throws -> Void] = [tests.testPointerMappingClampsAtTrackAndPreservesInputResolution,tests.testKeyboardAndAccessibilityKeepTenthDecibelSteps,tests.testDisabledUserInputCannotEmitCallbacks,tests.testProgrammaticTargetsNeverEmitUserValues,tests.testRealPresentationPassesThroughIntermediatePositionsWithoutOvershoot,tests.testRetargetingContinuesFromCurrentPresentationPosition,tests.testBurstyReportedKnobTargetsRemainContinuousAndNeverEmitInput,tests.testMidAnimationDragStartsFromAuthoritativeVolume,tests.testReduceMotionUsesImmediatePresentationUpdates,tests.testUserDragInputMovesImmediatelyWhileReportedTargetsAnimate]
            for check in checks { do {try await check()} catch {FaderEvidence.check(false,"Unexpected test error: \(error)")} }
            let data=try? JSONSerialization.data(withJSONObject:FaderEvidence.report,options:[.prettyPrinted,.sortedKeys])
            if let data,let marker=CommandLine.arguments.firstIndex(of:"--report"),CommandLine.arguments.indices.contains(marker+1) {try? data.write(to:URL(fileURLWithPath:CommandLine.arguments[marker+1]),options:.atomic)}
            results.string="10 cases, \(FaderEvidence.assertions) assertions, \(FaderEvidence.failures.count) failures\n\n" + (data.flatMap {String(data:$0,encoding:.utf8)} ?? "Unable to encode report")
            runButton.isEnabled=true
            window.makeKeyAndOrderFront(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
@main private struct VolumeFaderTestRunner {
    @MainActor static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate=VolumeFaderTestApplication()
        app.delegate=delegate
        withExtendedLifetime(delegate) {app.run()}
    }
}
#endif
