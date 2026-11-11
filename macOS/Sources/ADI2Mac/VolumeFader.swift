import SwiftUI
import AppKit
import QuartzCore

/// The binding contains the device's authoritative value. Animation never writes it.
struct VolumeFader: NSViewRepresentable {
    var value: Double
    var bounds: ClosedRange<Double>
    var step: Double
    var enabled: Bool
    var reduceMotion: Bool
    var context: String
    var onChange: (Double) -> Void

    func makeNSView(context: Context) -> VolumeFaderControl {
        let control = VolumeFaderControl(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        update(control)
        return control
    }

    func updateNSView(_ control: VolumeFaderControl, context: Context) { update(control) }

    private func update(_ control: VolumeFaderControl) {
        control.onChange = onChange
        control.configure(value: value, bounds: bounds, step: step, enabled: enabled, reduceMotion: reduceMotion, context: context)
    }
}

/// Native keyboard/focus/accessibility behavior with an explicitly animated renderer.
/// Device updates set model-layer endpoints, then retarget from current presentation.
final class VolumeFaderControl: NSSlider {
    var onChange: ((Double) -> Void)?
    var step: Double = 0.1
    var reduceMotion = false {
        didSet { if reduceMotion { render(animated: false) } }
    }
    private(set) var targetValue: Double = -114.5
    let knobLayer = CALayer()
    let fillLayer = CALayer()
    private let trackLayer = CALayer()
    private var isTrackingDrag = false
    private var currentContext: String?
    private var previousLayoutBounds = NSRect.zero
    private let knobDiameter: CGFloat = 16
    private let trackThickness: CGFloat = 4
    var trackStartX: CGFloat { bounds.minX + knobDiameter / 2 + 2 }
    var trackEndX: CGFloat { max(trackStartX, bounds.maxX - knobDiameter / 2 - 2) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        minValue = -114.5
        maxValue = 6
        doubleValue = targetValue
        isContinuous = true
        numberOfTickMarks = 0
        focusRingType = .exterior
        wantsLayer = true
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
        layer?.addSublayer(knobLayer)
        target = self
        action = #selector(nativeValueChanged(_:))
        setAccessibilityLabel("Output volume")
        setAccessibilityHelp("Use the arrow keys to adjust volume in 0.1 decibel steps.")
        updateColors()
        render(animated: false)
    }

    required init?(coder: NSCoder) { return nil }
    override var acceptsFirstResponder: Bool { isEnabled }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 28) }
    override var isEnabled: Bool {
        didSet {
            if !isEnabled { render(animated: false) }
            updateColors()
        }
    }

    func configure(value: Double, bounds: ClosedRange<Double>, step: Double, enabled: Bool, reduceMotion: Bool, context: String) {
        guard value.isFinite, bounds.lowerBound.isFinite, bounds.upperBound.isFinite,
              bounds.lowerBound < bounds.upperBound, step.isFinite, step > 0 else { return }
        let reset = currentContext != context || minValue != bounds.lowerBound || maxValue != bounds.upperBound
        currentContext = context
        if minValue != bounds.lowerBound { minValue = bounds.lowerBound }
        if maxValue != bounds.upperBound { maxValue = bounds.upperBound }
        self.step = step
        if self.isEnabled != enabled { self.isEnabled = enabled }
        if self.reduceMotion != reduceMotion { self.reduceMotion = reduceMotion }
        setVolume(value, animated: !reset)
    }

    func setVolume(_ value: Double, animated: Bool) {
        guard value.isFinite, minValue.isFinite, maxValue.isFinite, minValue < maxValue else { return }
        let next = min(maxValue, max(minValue, value))
        let changed = next != targetValue
        targetValue = next
        super.doubleValue = next
        // An unchanged SwiftUI update must not restart a running follow animation.
        if changed || !animated { render(animated: animated && isEnabled && !reduceMotion && !isTrackingDrag && window != nil) }
        if changed { NSAccessibility.post(element: self, notification: .valueChanged) }
    }

    /// Pointer mapping is separate from dispatch, so rendering cannot create MIDI.
    func value(at point: NSPoint) -> Double {
        let fraction = min(1, max(0, (point.x - trackStartX) / max(1, trackEndX - trackStartX)))
        return minValue + Double(fraction) * (maxValue - minValue)
    }

    /// A grabbed knob moves relative to the actual volume at mouse-down,
    /// never relative to a lagging animation frame. Track clicks remain absolute.
    func dragValue(from startValue: Double, deltaX: CGFloat) -> Double {
        guard startValue.isFinite, deltaX.isFinite else { return targetValue }
        let delta = Double(deltaX / max(1, trackEndX - trackStartX)) * (maxValue - minValue)
        return min(maxValue, max(minValue, startValue + delta))
    }

    func userSetValue(_ value: Double) {
        guard isEnabled, value.isFinite, step.isFinite, step > 0 else { return }
        let quantized = min(maxValue, max(minValue, (value / step).rounded(.toNearestOrEven) * step))
        let changed = abs(quantized - targetValue) > step * 0.000001
        setVolume(quantized, animated: false)
        if changed { onChange?(quantized) }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let window else { return }
        window.makeFirstResponder(self)
        let start = convert(event.locationInWindow, from: nil)
        let visualX = knobLayer.presentation()?.position.x ?? knobLayer.position.x
        let grabbedKnob = abs(start.x - visualX) <= knobDiameter / 2 + 3
        let dragStartValue = targetValue
        isTrackingDrag = true
        defer { isTrackingDrag = false; render(animated: false) }
        if !grabbedKnob { userSetValue(value(at: start)) }
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            let point = convert(next.locationInWindow, from: nil)
            // Clicking the knob without dragging is not a volume change.
            if next.type == .leftMouseDragged {
                let nextValue = grabbedKnob
                    ? dragValue(from: dragStartValue, deltaX: point.x - start.x)
                    : value(at: point)
                userSetValue(nextValue)
            }
            if next.type == .leftMouseUp { break }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        switch event.keyCode {
        case 123, 125: userSetValue(targetValue - step)
        case 124, 126: userSetValue(targetValue + step)
        default: super.keyDown(with: event)
        }
    }

    @objc private func nativeValueChanged(_ sender: NSSlider) { userSetValue(sender.doubleValue) }

    override func accessibilityValue() -> Any? { NSNumber(value: targetValue) }
    override func accessibilityValueDescription() -> String? {
        "\(targetValue.formatted(.number.precision(.fractionLength(1)))) decibels"
    }
    override func accessibilityMinValue() -> Any? { NSNumber(value: minValue) }
    override func accessibilityMaxValue() -> Any? { NSNumber(value: maxValue) }
    override func setAccessibilityValue(_ accessibilityValue: Any?) {
        if let value = accessibilityValue as? NSNumber { userSetValue(value.doubleValue) }
    }
    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        userSetValue(targetValue + step)
        return true
    }
    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        userSetValue(targetValue - step)
        return true
    }

    override func layout() {
        super.layout()
        if previousLayoutBounds != bounds {
            previousLayoutBounds = bounds
            render(animated: false)
        }
    }
    // The CALayers own the entire fader; no default cell segments or ticks show.
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { updateColors() }
    override func draw(_ dirtyRect: NSRect) {}
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateColors() }
    override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 1, dy: 3) }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 10, yRadius: 10).fill()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            trackLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(0.16).cgColor
            fillLayer.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.49, blue: 0.83, alpha: isEnabled ? 1 : 0.35).cgColor
            knobLayer.backgroundColor = NSColor.controlColor.cgColor
            knobLayer.borderColor = NSColor.labelColor.withAlphaComponent(isEnabled ? 0.22 : 0.1).cgColor
            knobLayer.borderWidth = 0.5
            knobLayer.shadowColor = NSColor.black.cgColor
            knobLayer.shadowOpacity = isEnabled ? 0.18 : 0.05
            knobLayer.shadowRadius = 1.5
            knobLayer.shadowOffset = CGSize(width: 0, height: -1)
            CATransaction.commit()
        }
    }

    private func render(animated: Bool) {
        guard layer != nil, minValue < maxValue else { return }
        let oldX = knobLayer.presentation()?.position.x ?? knobLayer.position.x
        let oldWidth = fillLayer.presentation()?.bounds.width ?? fillLayer.bounds.width
        let fraction = min(1, max(0, (targetValue - minValue) / (maxValue - minValue)))
        let width = (trackEndX - trackStartX) * CGFloat(fraction)
        let x = trackStartX + width
        let centerY = bounds.midY
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = CGRect(x: trackStartX, y: centerY - trackThickness / 2, width: trackEndX - trackStartX, height: trackThickness)
        trackLayer.cornerRadius = trackThickness / 2
        fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.position = CGPoint(x: trackStartX, y: centerY)
        fillLayer.bounds = CGRect(x: 0, y: 0, width: width, height: trackThickness)
        fillLayer.cornerRadius = trackThickness / 2
        knobLayer.bounds = CGRect(x: 0, y: 0, width: knobDiameter, height: knobDiameter)
        knobLayer.position = CGPoint(x: x, y: centerY)
        knobLayer.cornerRadius = knobDiameter / 2
        knobLayer.removeAnimation(forKey: "volume.position")
        fillLayer.removeAnimation(forKey: "volume.fill")
        CATransaction.commit()
        if animated && abs(oldX - x) > 0.01 {
            let position = CABasicAnimation(keyPath: "position.x")
            position.fromValue = oldX
            position.toValue = x
            position.duration = 0.18
            position.timingFunction = CAMediaTimingFunction(name: .easeOut)
            knobLayer.add(position, forKey: "volume.position")
            let fill = CABasicAnimation(keyPath: "bounds.size.width")
            fill.fromValue = oldWidth
            fill.toValue = width
            fill.duration = position.duration
            fill.timingFunction = position.timingFunction
            fillLayer.add(fill, forKey: "volume.fill")
        }
    }
}
