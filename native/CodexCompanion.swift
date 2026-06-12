import Cocoa

enum PetState: String, CaseIterable {
    case idle
    case codexRunning = "codex_running"
    case commandRunning = "command_running"
    case thinking
    case waitingUser = "waiting_user"
    case success
    case error
    case longRunning = "long_running"
}

struct CompanionConfig: Codable {
    struct WindowConfig: Codable {
        var x: Double
        var y: Double
        var scale: Double
        var opacity: Double
        var alwaysOnTop: Bool
    }

    struct BehaviorConfig: Codable {
        var idleAnimation: Bool
        var bubbleEnabled: Bool
        var launchAtLogin: Bool
    }

    var version: Int
    var window: WindowConfig
    var behavior: BehaviorConfig
}

struct CodexStateFile: Decodable {
    struct Codex: Decodable {
        var detected: Bool
        var state: String
        var taskStartedAt: String?
        var transientUntil: String?
        var nextState: String?
    }

    var updatedAt: String
    var codex: Codex
}

final class PetView: NSView {
    weak var appDelegate: AppDelegate?
    private var dragStartInWindow: NSPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStartInWindow = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let currentScreenPoint = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: currentScreenPoint.x - dragStartInWindow.x,
            y: currentScreenPoint.y - dragStartInWindow.y
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        appDelegate?.saveWindowFrame()
    }

    override func rightMouseDown(with event: NSEvent) {
        appDelegate?.showContextMenu(event: event)
    }
}

final class StageReflectionView: NSView {
    var sparklePhase: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    private let sparkleOffsets: [CGPoint] = [
        CGPoint(x: -0.42, y: 0.60),
        CGPoint(x: -0.32, y: 0.70),
        CGPoint(x: -0.18, y: 0.55),
        CGPoint(x: -0.06, y: 0.82),
        CGPoint(x: 0.08, y: 0.64),
        CGPoint(x: 0.22, y: 0.74),
        CGPoint(x: 0.35, y: 0.58),
        CGPoint(x: 0.46, y: 0.68),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)
        drawStageReflectionLayer()
        drawSoftReflectionLayer()
        drawFallingSparkleLayer()
    }

    private func drawStageReflectionLayer() {
        // Stage Reflection Layer
        let stageRect = bounds.insetBy(dx: bounds.width * 0.03, dy: bounds.height * 0.30)
        let stagePath = NSBezierPath()
        stagePath.move(to: CGPoint(x: stageRect.minX, y: stageRect.midY))
        stagePath.curve(
            to: CGPoint(x: stageRect.maxX, y: stageRect.midY + sin(sparklePhase) * 2),
            controlPoint1: CGPoint(x: stageRect.minX + stageRect.width * 0.22, y: stageRect.maxY + 12),
            controlPoint2: CGPoint(x: stageRect.minX + stageRect.width * 0.78, y: stageRect.maxY + 7)
        )
        stagePath.curve(
            to: CGPoint(x: stageRect.minX, y: stageRect.midY),
            controlPoint1: CGPoint(x: stageRect.minX + stageRect.width * 0.78, y: stageRect.minY - 10),
            controlPoint2: CGPoint(x: stageRect.minX + stageRect.width * 0.20, y: stageRect.minY - 6)
        )
        stagePath.close()
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.72, green: 0.93, blue: 1.0, alpha: 0.00),
            NSColor(calibratedRed: 0.66, green: 0.88, blue: 1.0, alpha: 0.15),
            NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.0, alpha: 0.28),
            NSColor(calibratedRed: 0.72, green: 0.93, blue: 1.0, alpha: 0.00),
        ])
        gradient?.draw(in: stagePath, angle: 0)

        for index in 0..<7 {
            let waveY = stageRect.midY + CGFloat(index - 3) * 5 + sin(sparklePhase + CGFloat(index) * 0.9) * 2
            let wave = NSBezierPath()
            wave.move(to: CGPoint(x: stageRect.minX + 22, y: waveY))
            wave.curve(
                to: CGPoint(x: stageRect.maxX - 22, y: waveY + sin(sparklePhase * 0.8 + CGFloat(index)) * 3),
                controlPoint1: CGPoint(x: stageRect.minX + stageRect.width * 0.36, y: waveY + 8),
                controlPoint2: CGPoint(x: stageRect.minX + stageRect.width * 0.64, y: waveY - 7)
            )
            NSColor(calibratedRed: 0.88, green: 0.97, blue: 1.0, alpha: 0.09 + CGFloat(index % 2) * 0.04).setStroke()
            wave.lineWidth = index == 3 ? 1.5 : 0.9
            wave.stroke()
        }
    }

    private func drawSoftReflectionLayer() {
        // Soft Reflection Layer
        let reflectionColor = NSColor(calibratedRed: 0.86, green: 0.96, blue: 1.0, alpha: 0.16)
        reflectionColor.setStroke()

        for index in 0..<5 {
            let insetX = bounds.width * (0.20 + CGFloat(index) * 0.045)
            let y = bounds.midY - CGFloat(index) * 4 + sin(sparklePhase * 0.7 + CGFloat(index)) * 1.6
            let path = NSBezierPath()
            path.move(to: CGPoint(x: insetX, y: y))
            path.curve(
                to: CGPoint(x: bounds.width - insetX, y: y + 1),
                controlPoint1: CGPoint(x: bounds.width * 0.38, y: y + 7),
                controlPoint2: CGPoint(x: bounds.width * 0.62, y: y - 5)
            )
            path.lineWidth = max(0.7, 1.4 - CGFloat(index) * 0.18)
            path.stroke()
        }
    }

    private func drawFallingSparkleLayer() {
        // Falling Sparkle Layer
        for (index, offset) in sparkleOffsets.enumerated() {
            let fall = CGFloat(index % 4) * 0.08 + (sparklePhase * 0.06).truncatingRemainder(dividingBy: 0.42)
            let flicker = 0.42 + 0.34 * (sin(sparklePhase * 1.7 + CGFloat(index)) + 1) / 2
            let center = CGPoint(
                x: bounds.midX + offset.x * bounds.width + sin(sparklePhase + CGFloat(index)) * 6,
                y: bounds.minY + max(0.22, offset.y - fall) * bounds.height
            )
            let radius = CGFloat(1.6 + Double(index % 3) * 0.7)
            let sparkleRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let sparklePath = NSBezierPath(ovalIn: sparkleRect)
            NSColor(calibratedRed: 0.92, green: 0.98, blue: 1.0, alpha: flicker).setFill()
            sparklePath.fill()
        }
    }
}

final class StatusAccentView: NSView {
    var state: PetState = .idle {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        switch state {
        case .codexRunning:
            break
        case .commandRunning:
            drawTerminalAccent()
        case .thinking:
            drawThinkingAccent()
        case .longRunning:
            drawCoffeeAccent()
        case .waitingUser:
            drawWaitingAccent()
        case .success:
            drawSuccessAccent()
        case .error:
            drawMagnifierAccent()
        case .idle:
            break
        }
    }

    private func drawTerminalAccent() {
        let rect = NSRect(x: bounds.minX + bounds.width * 0.14, y: bounds.height * 0.42, width: 92, height: 56)
        let panel = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedRed: 0.60, green: 0.86, blue: 1.0, alpha: 0.16).setFill()
        panel.fill()
        NSColor(calibratedRed: 0.86, green: 0.96, blue: 1.0, alpha: 0.48).setStroke()
        panel.lineWidth = 1.2
        panel.stroke()

        NSColor(calibratedRed: 0.92, green: 0.98, blue: 1.0, alpha: 0.62).setStroke()
        for index in 0..<3 {
            let y = rect.maxY - 18 - CGFloat(index) * 11
            let line = NSBezierPath()
            line.move(to: CGPoint(x: rect.minX + 16, y: y))
            line.line(to: CGPoint(x: rect.minX + 38 + CGFloat(index) * 12, y: y))
            line.lineWidth = 1.4
            line.stroke()
        }
    }

    private func drawThinkingAccent() {
        NSColor(calibratedRed: 0.90, green: 0.98, blue: 1.0, alpha: 0.62).setFill()
        for index in 0..<5 {
            let angle = CGFloat(index) / 5 * 2 * .pi
            let center = CGPoint(
                x: bounds.midX + bounds.width * 0.23 + cos(angle) * 22,
                y: bounds.height * 0.66 + sin(angle) * 16
            )
            NSBezierPath(ovalIn: NSRect(x: center.x - 2.4, y: center.y - 2.4, width: 4.8, height: 4.8)).fill()
        }
    }

    private func drawCoffeeAccent() {
        let cup = NSRect(x: bounds.midX + bounds.width * 0.22, y: bounds.height * 0.26, width: 34, height: 30)
        let cupPath = NSBezierPath(roundedRect: cup, xRadius: 7, yRadius: 7)
        NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.0, alpha: 0.25).setFill()
        cupPath.fill()
        NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.0, alpha: 0.58).setStroke()
        cupPath.lineWidth = 1.2
        cupPath.stroke()

        let handle = NSBezierPath(ovalIn: NSRect(x: cup.maxX - 4, y: cup.midY - 6, width: 14, height: 12))
        handle.lineWidth = 1.2
        handle.stroke()

        for index in 0..<2 {
            let steam = NSBezierPath()
            steam.move(to: CGPoint(x: cup.minX + 11 + CGFloat(index) * 10, y: cup.maxY + 4))
            steam.curve(
                to: CGPoint(x: cup.minX + 13 + CGFloat(index) * 10, y: cup.maxY + 21),
                controlPoint1: CGPoint(x: cup.minX + 6 + CGFloat(index) * 10, y: cup.maxY + 9),
                controlPoint2: CGPoint(x: cup.minX + 18 + CGFloat(index) * 10, y: cup.maxY + 14)
            )
            steam.lineWidth = 1
            steam.stroke()
        }
    }

    private func drawWaitingAccent() {
        NSColor(calibratedRed: 0.92, green: 0.98, blue: 1.0, alpha: 0.58).setStroke()
        for index in 0..<3 {
            let arc = NSBezierPath()
            let radius = CGFloat(10 + index * 8)
            arc.appendArc(
                withCenter: CGPoint(x: bounds.midX + bounds.width * 0.25, y: bounds.height * 0.58),
                radius: radius,
                startAngle: -25,
                endAngle: 42
            )
            arc.lineWidth = 1.2
            arc.stroke()
        }
    }

    private func drawSuccessAccent() {
        NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.0, alpha: 0.70).setFill()
        for index in 0..<7 {
            let x = bounds.midX - 90 + CGFloat(index) * 30
            let y = bounds.height * 0.72 + CGFloat(index % 2) * 18
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 5, height: 5)).fill()
        }
    }

    private func drawMagnifierAccent() {
        let center = CGPoint(x: bounds.minX + bounds.width * 0.22, y: bounds.height * 0.44)
        let lens = NSBezierPath(ovalIn: NSRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32))
        NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.0, alpha: 0.18).setFill()
        lens.fill()
        NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.0, alpha: 0.62).setStroke()
        lens.lineWidth = 1.6
        lens.stroke()

        let handle = NSBezierPath()
        handle.move(to: CGPoint(x: center.x + 11, y: center.y - 11))
        handle.line(to: CGPoint(x: center.x + 29, y: center.y - 29))
        handle.lineWidth = 2
        handle.stroke()
    }
}

final class DancerRigView: NSView {
    private let rootLayer = CALayer()
    private let leftArmLayer = CAShapeLayer()
    private let rightArmLayer = CAShapeLayer()
    private let headLayer = CAShapeLayer()
    private let torsoLayer = CAShapeLayer()
    private let legsLayer = CAShapeLayer()
    private let skirtLayer = CALayer()
    private var skirtPanelLayers: [CAShapeLayer] = []
    private var sparkleLayers: [CALayer] = []
    private var animatedState: PetState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupRig()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRig()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rootLayer.frame = bounds
        layoutRig()
        CATransaction.commit()
    }

    func applyState(_ state: PetState, paused: Bool) {
        if paused {
            removeRigAnimations()
            animatedState = nil
            return
        }

        guard animatedState != state || leftArmLayer.animation(forKey: "codex.rig.leftArm") == nil else {
            return
        }

        animatedState = state
        removeRigAnimations()
        layoutRig()
        animateRig(for: state)
    }

    private func setupRig() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        rootLayer.masksToBounds = false
        layer?.addSublayer(rootLayer)

        skirtLayer.masksToBounds = false
        rootLayer.addSublayer(skirtLayer)

        for index in 0..<7 {
            let panel = CAShapeLayer()
            panel.name = "skirtPanelLayers.\(index)"
            panel.fillColor = NSColor(calibratedRed: 0.82, green: 0.94, blue: 1, alpha: 0.24).cgColor
            panel.strokeColor = NSColor(calibratedRed: 0.92, green: 0.98, blue: 1, alpha: 0.58).cgColor
            panel.lineJoin = .round
            panel.shadowColor = NSColor(calibratedRed: 0.72, green: 0.92, blue: 1, alpha: 1).cgColor
            panel.shadowOpacity = 0.65
            panel.shadowRadius = 9
            panel.shadowOffset = .zero
            skirtPanelLayers.append(panel)
            skirtLayer.addSublayer(panel)
        }

        configureLine(leftArmLayer, width: 7, alpha: 0.86)
        configureLine(rightArmLayer, width: 7, alpha: 0.86)
        configureLine(legsLayer, width: 6, alpha: 0.74)
        configureFilled(headLayer, fillAlpha: 0.36, strokeAlpha: 0.78, width: 3)
        configureFilled(torsoLayer, fillAlpha: 0.28, strokeAlpha: 0.74, width: 3)

        rootLayer.addSublayer(legsLayer)
        rootLayer.addSublayer(torsoLayer)
        rootLayer.addSublayer(leftArmLayer)
        rootLayer.addSublayer(rightArmLayer)
        rootLayer.addSublayer(headLayer)

        for index in 0..<14 {
            let sparkle = CALayer()
            sparkle.name = "sparkleLayers.\(index)"
            sparkle.backgroundColor = NSColor.white.withAlphaComponent(0.75).cgColor
            sparkle.cornerRadius = 2
            sparkle.shadowColor = NSColor(calibratedRed: 0.74, green: 0.93, blue: 1, alpha: 1).cgColor
            sparkle.shadowOpacity = 0.9
            sparkle.shadowRadius = 6
            sparkle.shadowOffset = .zero
            sparkleLayers.append(sparkle)
            rootLayer.addSublayer(sparkle)
        }
    }

    private func configureLine(_ layer: CAShapeLayer, width: CGFloat, alpha: CGFloat) {
        layer.fillColor = NSColor.clear.cgColor
        layer.strokeColor = NSColor(calibratedRed: 0.93, green: 0.98, blue: 1, alpha: alpha).cgColor
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.lineWidth = width
        layer.shadowColor = NSColor(calibratedRed: 0.72, green: 0.92, blue: 1, alpha: 1).cgColor
        layer.shadowOpacity = 0.82
        layer.shadowRadius = 10
        layer.shadowOffset = .zero
    }

    private func configureFilled(_ layer: CAShapeLayer, fillAlpha: CGFloat, strokeAlpha: CGFloat, width: CGFloat) {
        layer.fillColor = NSColor(calibratedRed: 0.86, green: 0.96, blue: 1, alpha: fillAlpha).cgColor
        layer.strokeColor = NSColor(calibratedRed: 0.96, green: 0.99, blue: 1, alpha: strokeAlpha).cgColor
        layer.lineWidth = width
        layer.shadowColor = NSColor(calibratedRed: 0.74, green: 0.93, blue: 1, alpha: 1).cgColor
        layer.shadowOpacity = 0.8
        layer.shadowRadius = 13
        layer.shadowOffset = .zero
    }

    private func layoutRig() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let layerBounds = NSRect(origin: .zero, size: bounds.size)
        skirtLayer.frame = layerBounds

        for layer in [leftArmLayer, rightArmLayer, headLayer, torsoLayer, legsLayer] {
            layer.frame = layerBounds
        }
        for panel in skirtPanelLayers {
            panel.frame = layerBounds
            panel.lineWidth = scaled(1.8)
        }

        leftArmLayer.lineWidth = scaled(7)
        rightArmLayer.lineWidth = scaled(7)
        legsLayer.lineWidth = scaled(6)
        torsoLayer.lineWidth = scaled(3)
        headLayer.lineWidth = scaled(3)

        leftArmLayer.path = leftArmPath(lift: 0).cgPath
        rightArmLayer.path = rightArmPath(lift: 0).cgPath
        headLayer.path = headPath(tilt: 0).cgPath
        torsoLayer.path = torsoPath(sway: 0).cgPath
        legsLayer.path = legsPath(step: 0).cgPath

        for (index, panel) in skirtPanelLayers.enumerated() {
            panel.path = skirtPanelPath(index: index, wave: 0).cgPath
        }

        for (index, sparkle) in sparkleLayers.enumerated() {
            let point = sparklePoint(index: index, wave: 0)
            sparkle.frame = NSRect(x: point.x, y: point.y, width: scaled(4), height: scaled(4))
            sparkle.cornerRadius = scaled(2)
        }
    }

    private struct RigMotion {
        var armLift: CGFloat
        var skirtWave: CGFloat
        var headTilt: CGFloat
        var torsoSway: CGFloat
        var step: CGFloat
        var duration: TimeInterval
    }

    private func motion(for state: PetState) -> RigMotion {
        switch state {
        case .idle:
            return RigMotion(armLift: 0.28, skirtWave: 0.24, headTilt: 0.16, torsoSway: 0.12, step: 0.10, duration: 2.2)
        case .codexRunning:
            return RigMotion(armLift: 0.38, skirtWave: 0.34, headTilt: 0.22, torsoSway: 0.18, step: 0.16, duration: 1.55)
        case .commandRunning:
            return RigMotion(armLift: 0.66, skirtWave: 0.58, headTilt: 0.34, torsoSway: 0.28, step: 0.34, duration: 0.92)
        case .thinking:
            return RigMotion(armLift: 0.42, skirtWave: 0.30, headTilt: 0.38, torsoSway: 0.18, step: 0.12, duration: 1.45)
        case .waitingUser:
            return RigMotion(armLift: 0.82, skirtWave: 0.48, headTilt: 0.44, torsoSway: 0.24, step: 0.18, duration: 1.05)
        case .success:
            return RigMotion(armLift: 1.00, skirtWave: 0.72, headTilt: 0.34, torsoSway: 0.32, step: 0.42, duration: 0.82)
        case .error:
            return RigMotion(armLift: 0.50, skirtWave: 0.36, headTilt: 0.50, torsoSway: 0.36, step: 0.20, duration: 0.70)
        case .longRunning:
            return RigMotion(armLift: 0.22, skirtWave: 0.22, headTilt: 0.12, torsoSway: 0.10, step: 0.08, duration: 2.6)
        }
    }

    private func animateRig(for state: PetState) {
        let motion = motion(for: state)
        addPathAnimation(
            to: leftArmLayer,
            key: "codex.rig.leftArm",
            values: [-motion.armLift, motion.armLift, -motion.armLift].map { leftArmPath(lift: $0).cgPath },
            duration: motion.duration
        )
        addPathAnimation(
            to: rightArmLayer,
            key: "codex.rig.rightArm",
            values: [motion.armLift, -motion.armLift, motion.armLift].map { rightArmPath(lift: $0).cgPath },
            duration: motion.duration
        )
        addPathAnimation(
            to: headLayer,
            key: "codex.rig.head",
            values: [-motion.headTilt, motion.headTilt, -motion.headTilt].map { headPath(tilt: $0).cgPath },
            duration: motion.duration * 1.15
        )
        addPathAnimation(
            to: torsoLayer,
            key: "codex.rig.torso",
            values: [-motion.torsoSway, motion.torsoSway, -motion.torsoSway].map { torsoPath(sway: $0).cgPath },
            duration: motion.duration
        )
        addPathAnimation(
            to: legsLayer,
            key: "codex.rig.legs",
            values: [-motion.step, motion.step, -motion.step].map { legsPath(step: $0).cgPath },
            duration: motion.duration
        )

        for (index, panel) in skirtPanelLayers.enumerated() {
            addPathAnimation(
                to: panel,
                key: "codex.rig.skirt.\(index)",
                values: [-motion.skirtWave, motion.skirtWave, -motion.skirtWave].map {
                    skirtPanelPath(index: index, wave: $0).cgPath
                },
                duration: motion.duration * (0.92 + Double(index) * 0.035)
            )
        }

        for (index, sparkle) in sparkleLayers.enumerated() {
            addSparkleAnimation(to: sparkle, index: index, motion: motion)
        }
    }

    private func addPathAnimation(to layer: CAShapeLayer, key: String, values: [CGPath], duration: TimeInterval) {
        let animation = CAKeyframeAnimation(keyPath: "path")
        animation.values = values
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.calculationMode = .cubic
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: key)
    }

    private func addSparkleAnimation(to layer: CALayer, index: Int, motion: RigMotion) {
        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = [
            sparklePoint(index: index, wave: -motion.skirtWave),
            sparklePoint(index: index, wave: motion.skirtWave),
            sparklePoint(index: index, wave: -motion.skirtWave),
        ]
        position.keyTimes = [0, 0.5, 1]
        position.duration = motion.duration * (1.15 + Double(index % 5) * 0.08)
        position.repeatCount = .infinity
        position.calculationMode = .cubic
        position.isRemovedOnCompletion = false
        layer.add(position, forKey: "codex.rig.sparkle.position.\(index)")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.18, 0.9, 0.24]
        opacity.keyTimes = [0, 0.45, 1]
        opacity.duration = position.duration
        opacity.repeatCount = .infinity
        opacity.beginTime = CACurrentMediaTime() + Double(index % 4) * 0.18
        opacity.isRemovedOnCompletion = false
        layer.add(opacity, forKey: "codex.rig.sparkle.opacity.\(index)")
    }

    private func removeRigAnimations() {
        for layer in [leftArmLayer, rightArmLayer, headLayer, torsoLayer, legsLayer] {
            layer.removeAllAnimations()
        }
        for panel in skirtPanelLayers {
            panel.removeAllAnimations()
        }
        for sparkle in sparkleLayers {
            sparkle.removeAllAnimations()
        }
    }

    private func leftArmPath(lift: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: p(142, 235))
        path.curve(
            to: p(76 - lift * 16, 308 + lift * 34),
            controlPoint1: p(122 - lift * 6, 260 + lift * 12),
            controlPoint2: p(98 - lift * 18, 286 + lift * 30)
        )
        path.curve(
            to: p(62 - lift * 22, 335 + lift * 20),
            controlPoint1: p(72 - lift * 26, 318 + lift * 16),
            controlPoint2: p(66 - lift * 24, 328 + lift * 22)
        )
        return path
    }

    private func rightArmPath(lift: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: p(178, 235))
        path.curve(
            to: p(244 + lift * 16, 308 + lift * 34),
            controlPoint1: p(198 + lift * 6, 260 + lift * 12),
            controlPoint2: p(222 + lift * 18, 286 + lift * 30)
        )
        path.curve(
            to: p(258 + lift * 22, 335 + lift * 20),
            controlPoint1: p(248 + lift * 26, 318 + lift * 16),
            controlPoint2: p(254 + lift * 24, 328 + lift * 22)
        )
        return path
    }

    private func headPath(tilt: CGFloat) -> NSBezierPath {
        let x = 152 + tilt * 4
        let y = 260 + abs(tilt) * 5
        let path = NSBezierPath(ovalIn: r(x, y, 42, 52))
        let bun = NSBezierPath(ovalIn: r(x - 24 - tilt * 4, y + 12, 20, 20))
        path.append(bun)
        return path
    }

    private func torsoPath(sway: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: p(160 + sway * 8, 254))
        path.curve(to: p(136 + sway * 12, 164), controlPoint1: p(142 + sway * 14, 232), controlPoint2: p(130 + sway * 10, 190))
        path.curve(to: p(184 + sway * 12, 164), controlPoint1: p(148 + sway * 12, 145), controlPoint2: p(172 + sway * 12, 145))
        path.curve(to: p(160 + sway * 8, 254), controlPoint1: p(190 + sway * 10, 190), controlPoint2: p(178 + sway * 14, 232))
        path.close()
        return path
    }

    private func legsPath(step: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: p(149, 152))
        path.curve(to: p(140 - step * 8, 70), controlPoint1: p(146 - step * 6, 126), controlPoint2: p(142 - step * 10, 96))
        path.move(to: p(171, 152))
        path.curve(to: p(182 + step * 8, 70), controlPoint1: p(174 + step * 6, 126), controlPoint2: p(178 + step * 10, 96))
        return path
    }

    private func skirtPanelPath(index: Int, wave: CGFloat) -> NSBezierPath {
        let center = CGFloat(index - 3)
        let topX = 160 + center * 8
        let leftX = 104 + center * 27 - wave * center * 12
        let rightX = 216 + center * 27 + wave * (4 - abs(center)) * 8
        let bottomY = 74 + abs(center) * 10
        let path = NSBezierPath()
        path.move(to: p(topX, 166))
        path.curve(to: p(leftX, bottomY), controlPoint1: p(topX - 18 - wave * 12, 136), controlPoint2: p(leftX - 18, 100 + wave * 12))
        path.curve(to: p(rightX, bottomY + 4), controlPoint1: p(leftX + 24, bottomY - 14 - wave * 10), controlPoint2: p(rightX - 22, bottomY - 10 + wave * 10))
        path.curve(to: p(topX, 166), controlPoint1: p(rightX + 8, 108), controlPoint2: p(topX + 20 + wave * 10, 138))
        path.close()
        return path
    }

    private func sparklePoint(index: Int, wave: CGFloat) -> CGPoint {
        let angle = CGFloat(index) / CGFloat(max(sparkleLayers.count, 1)) * 2 * .pi
        let radiusX = scaled(122 + CGFloat(index % 3) * 12)
        let radiusY = scaled(45 + CGFloat(index % 4) * 6)
        let center = p(160, 92)
        return CGPoint(
            x: center.x + cos(angle + wave * 0.8) * radiusX,
            y: center.y + sin(angle * 1.15 + wave) * radiusY
        )
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x / 320 * bounds.width, y: y / 370 * bounds.height)
    }

    private func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x / 320 * bounds.width, y: y / 370 * bounds.height, width: width / 320 * bounds.width, height: height / 370 * bounds.height)
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * min(bounds.width / 320, bounds.height / 370)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let canvasSize = NSSize(width: 720, height: 820)
    private let basePetHeight: CGFloat = 620
    private let appSupportURL: URL
    private let configURL: URL
    private let stateURL: URL
    private var config: CompanionConfig
    private var window: NSWindow!
    private var petView: PetView!
    private var stageReflectionView: StageReflectionView!
    private var dancerImageView: NSImageView!
    private var statusAccentView: StatusAccentView!
    private var bubbleLabel: NSTextField!
    private var stateTimer: Timer?
    private var frameTimer: Timer?
    private var displayLinkTimer: Timer?
    private var currentFrameInterval: TimeInterval = 0.24
    private var cachedCodexProcessDetected = false
    private var processDetectionCacheUntil = Date.distantPast
    private var dancerFrames: [NSImage] = []
    private var actionClips: [PetState: [NSImage]] = [:]
    private var dancerFrameIndex = 0
    private var currentState: PetState = .idle
    private var renderedState: PetState?
    private var demoOverrideState: PetState?
    private var previousBaseState: PetState = .idle
    private var transientUntil = Date.distantPast
    private var activeStateHoldUntil = Date.distantPast
    private let minimumVisibleActiveDuration: TimeInterval = 6
    private let processDetectionInterval: TimeInterval = 15
    private let stageEffectInterval: TimeInterval = 0.25
    private let maxGlobalImageTravel: CGFloat = 4
    private let maxGlobalRotationDegrees: CGFloat = 1.2
    private let maxCachedActionClips = 3
    private var actionClipCacheOrder: [PetState] = []
    private var animationPaused = false

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexCompanion", isDirectory: true)
        appSupportURL = support
        configURL = support.appendingPathComponent("config.json")
        stateURL = support.appendingPathComponent("state.json")
        config = Self.loadConfig(from: configURL)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        createWindow()
        updateState()
        startTimers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowFrame()
    }

    private func createWindow() {
        window = NSWindow(
            contentRect: defaultFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = config.window.alwaysOnTop ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.alphaValue = config.window.opacity

        petView = PetView(frame: NSRect(origin: .zero, size: canvasSize))
        petView.appDelegate = self
        petView.wantsLayer = true
        petView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = petView

        stageReflectionView = StageReflectionView(frame: stageReflectionFrame())
        petView.addSubview(stageReflectionView)

        dancerFrames = loadDancerFrames()
        actionClips = [:]
        dancerImageView = NSImageView(frame: dancerFrame())
        dancerImageView.image = framesForCurrentState().first ?? loadPetImage()
        dancerImageView.imageScaling = .scaleProportionallyUpOrDown
        dancerImageView.alphaValue = 0.98
        dancerImageView.wantsLayer = true
        dancerImageView.layer?.shadowColor = NSColor(calibratedRed: 0.74, green: 0.92, blue: 1, alpha: 1).cgColor
        dancerImageView.layer?.shadowOpacity = 0.86
        dancerImageView.layer?.shadowRadius = 22
        dancerImageView.layer?.shadowOffset = .zero
        petView.addSubview(dancerImageView)

        statusAccentView = StatusAccentView(frame: NSRect(origin: .zero, size: canvasSize))
        statusAccentView.state = currentState
        petView.addSubview(statusAccentView)

        bubbleLabel = NSTextField(labelWithString: "")
        bubbleLabel.isHidden = true
        bubbleLabel.alignment = .center
        bubbleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        bubbleLabel.textColor = NSColor(calibratedRed: 0.13, green: 0.10, blue: 0.19, alpha: 1)
        bubbleLabel.backgroundColor = NSColor.white.withAlphaComponent(0.92)
        bubbleLabel.wantsLayer = true
        bubbleLabel.layer?.cornerRadius = 8
        bubbleLabel.layer?.borderWidth = 1
        bubbleLabel.layer?.borderColor = NSColor(calibratedWhite: 0.62, alpha: 0.28).cgColor
        bubbleLabel.frame = NSRect(x: 430, y: 520, width: 148, height: 38)
        petView.addSubview(bubbleLabel)

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        writeDebugLog("window=\(window.frame) dancerFrames=\(dancerFrames.count) actionClips=\(actionClips.keys.count)")
    }

    private func loadDancerFrames() -> [NSImage] {
        (0..<8).compactMap { index in
            Bundle.main
                .url(forResource: "dancer-frame-\(index)", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
        }
    }

    private func actionClipId(for state: PetState) -> String {
        switch state {
        case .idle, .codexRunning, .commandRunning, .thinking, .longRunning, .waitingUser, .success, .error: return "codex-running"
        }
    }

    private func framesForCurrentState() -> [NSImage] {
        if let frames = cachedActionClip(for: currentState) {
            return frames
        }

        let frames = loadActionClip(for: currentState)
        if !frames.isEmpty {
            cacheActionClip(frames, for: currentState)
            return frames
        }

        if currentState != .codexRunning, let frames = cachedActionClip(for: .codexRunning) {
            return frames
        }

        if currentState != .codexRunning {
            let fallbackFrames = loadActionClip(for: .codexRunning)
            if !fallbackFrames.isEmpty {
                cacheActionClip(fallbackFrames, for: .codexRunning)
                return fallbackFrames
            }
        }

        return dancerFrames
    }

    private func cachedActionClip(for state: PetState) -> [NSImage]? {
        guard let frames = actionClips[state], !frames.isEmpty else { return nil }
        actionClipCacheOrder.removeAll { $0 == state }
        actionClipCacheOrder.append(state)
        return frames
    }

    private func cacheActionClip(_ frames: [NSImage], for state: PetState) {
        actionClips[state] = frames
        actionClipCacheOrder.removeAll { $0 == state }
        actionClipCacheOrder.append(state)

        while actionClipCacheOrder.count > maxCachedActionClips {
            let evicted = actionClipCacheOrder.removeFirst()
            actionClips.removeValue(forKey: evicted)
        }
    }

    private func loadActionClip(for state: PetState) -> [NSImage] {
        var frames: [NSImage] = []
        let clipId = actionClipId(for: state)

        for index in 0..<24 {
            guard let url = Bundle.main.url(
                forResource: "frame-\(index)",
                withExtension: "png",
                subdirectory: "dancer-actions/\(clipId)"
            ), let image = NSImage(contentsOf: url) else {
                break
            }

            frames.append(image)
        }

        return frames
    }

    private func loadPetImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "pet-placeholder", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        return NSImage(named: "pet-placeholder")
    }

    private func defaultFrame() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let preferredX = config.window.x >= 0 ? config.window.x : screenFrame.maxX - canvasSize.width - 48
        let preferredY = config.window.y >= 0 ? config.window.y : screenFrame.minY + 80
        let x = min(max(preferredX, screenFrame.minX), screenFrame.maxX - canvasSize.width)
        let y = min(max(preferredY, screenFrame.minY), screenFrame.maxY - canvasSize.height)
        return NSRect(x: x, y: y, width: canvasSize.width, height: canvasSize.height)
    }

    private func dancerFrame() -> NSRect {
        let height = min(760, max(500, basePetHeight * CGFloat(config.window.scale)))
        let width = min(canvasSize.width * 0.96, height * 1.03)
        return NSRect(
            x: (canvasSize.width - width) / 2,
            y: max(38, canvasSize.height - height - 24),
            width: width,
            height: height
        )
    }

    private func stageReflectionFrame() -> NSRect {
        let width = min(canvasSize.width * 0.92, 620 * CGFloat(config.window.scale))
        let height = min(132, 122 * CGFloat(config.window.scale))

        return NSRect(
            x: (canvasSize.width - width) / 2,
            y: 36,
            width: width,
            height: height
        )
    }

    private func startTimers() {
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateState()
        }
        stateTimer?.tolerance = 0.35
        scheduleFrameTimer()
        animateStageEffects()
    }

    private func scheduleFrameTimer() {
        frameTimer?.invalidate()
        let interval = activeFrameInterval()
        currentFrameInterval = interval
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateDancerFrame()
        }
        frameTimer?.tolerance = min(interval * 0.30, 0.12)
    }

    private func animateStageEffects() {
        displayLinkTimer?.invalidate()
        displayLinkTimer = Timer.scheduledTimer(withTimeInterval: stageEffectInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.animationPaused else { return }
            guard self.shouldAnimateStageEffects() else { return }
            self.stageReflectionView.sparklePhase += self.stageSparkleStep()
        }
        displayLinkTimer?.tolerance = stageEffectInterval * 0.40
    }

    private func updateState() {
        if let demoOverrideState {
            currentState = demoOverrideState
            renderState()
            return
        }

        let stateFile = readStateFile()
        let processDetected = needsProcessDetection(stateFile) ? detectCodexProcessCached() : false
        let normalizedState = normalize(stateFile: stateFile, processDetected: processDetected)
        let now = Date()
        var displayState = normalizedState

        if isActiveCodexState(normalizedState) {
            activeStateHoldUntil = now.addingTimeInterval(minimumVisibleActiveDuration)
        } else if normalizedState == .waitingUser,
                  isActiveCodexState(currentState),
                  activeStateHoldUntil > now {
            displayState = currentState
        }

        if displayState != .success && displayState != .error {
            previousBaseState = displayState
        }

        if (displayState == .success || displayState == .error) && displayState != currentState {
            transientUntil = now.addingTimeInterval(4)
        }

        currentState = transientUntil > now ? displayState : previousBaseState
        renderState()
    }

    private func readStateFile() -> CodexStateFile? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(CodexStateFile.self, from: data)
    }

    private func normalize(stateFile: CodexStateFile?, processDetected: Bool) -> PetState {
        guard let stateFile, isFresh(stateFile.updatedAt) else {
            return fallbackState(processDetected: processDetected)
        }

        if let state = PetState(rawValue: stateFile.codex.state) {
            if isExpiredTransient(state, stateFile.codex.transientUntil) {
                return nextState(from: stateFile.codex.nextState, processDetected: processDetected)
            }

            if state == .commandRunning, isLongRunning(stateFile.codex.taskStartedAt) {
                return .longRunning
            }

            return state
        }

        return fallbackState(processDetected: stateFile.codex.detected || processDetected)
    }

    private func isFresh(_ updatedAt: String) -> Bool {
        guard let date = parseISODate(updatedAt) else { return false }
        return Date().timeIntervalSince(date) <= 30
    }

    private func needsProcessDetection(_ stateFile: CodexStateFile?) -> Bool {
        guard let stateFile else { return true }
        guard isFresh(stateFile.updatedAt) else { return true }
        guard let state = PetState(rawValue: stateFile.codex.state) else { return true }

        if isExpiredTransient(state, stateFile.codex.transientUntil), stateFile.codex.nextState == nil {
            return true
        }

        return false
    }

    private func isLongRunning(_ taskStartedAt: String?) -> Bool {
        guard let taskStartedAt else { return false }
        guard let date = parseISODate(taskStartedAt) else { return false }
        return Date().timeIntervalSince(date) >= 90
    }

    private func isExpiredTransient(_ state: PetState, _ transientUntil: String?) -> Bool {
        guard state == .success || state == .error, let transientUntil else { return false }
        guard let date = parseISODate(transientUntil) else { return false }
        return Date() >= date
    }

    private func parseISODate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func nextState(from rawValue: String?, processDetected: Bool) -> PetState {
        if let rawValue, let state = PetState(rawValue: rawValue), state != .success, state != .error {
            return state
        }

        return fallbackState(processDetected: processDetected)
    }

    private func fallbackState(processDetected: Bool) -> PetState {
        return processDetected ? .waitingUser : .idle
    }

    private func isActiveCodexState(_ state: PetState) -> Bool {
        switch state {
        case .codexRunning, .commandRunning, .thinking, .longRunning:
            return true
        default:
            return false
        }
    }

    private func detectCodexProcess() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-fl", "/Applications/Codex.app/Contents/Resources/codex"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func detectCodexProcessCached() -> Bool {
        let now = Date()
        guard processDetectionCacheUntil <= now else {
            return cachedCodexProcessDetected
        }

        cachedCodexProcessDetected = detectCodexProcess()
        processDetectionCacheUntil = now.addingTimeInterval(processDetectionInterval)
        return cachedCodexProcessDetected
    }

    private func renderState(force: Bool = false) {
        let stateChanged = renderedState != currentState
        if stateChanged {
            dancerFrameIndex = 0
            renderedState = currentState
            applyImageMotion(for: currentState)
        }

        if force || stateChanged {
            stageReflectionView.frame = stageReflectionFrame()
            dancerImageView.frame = dancerFrame()
            statusAccentView.frame = NSRect(origin: .zero, size: canvasSize)
            statusAccentView.state = currentState
            updateDancerFrame(force: true)
        }

        window.alphaValue = config.window.opacity
        window.level = config.window.alwaysOnTop ? .floating : .normal

        let activeBubbleText = config.behavior.bubbleEnabled ? bubbleText(for: currentState) : nil
        if let text = activeBubbleText {
            if bubbleLabel.stringValue != text {
                bubbleLabel.stringValue = text
            }
            bubbleLabel.isHidden = false
        } else {
            bubbleLabel.isHidden = true
        }

        if activeBubbleText == nil {
            bubbleLabel.stringValue = ""
        }

        if abs(currentFrameInterval - activeFrameInterval()) > 0.001 {
            scheduleFrameTimer()
        }
    }

    private func updateDancerFrame(force: Bool = false) {
        let frames = framesForCurrentState()
        guard !frames.isEmpty else { return }
        guard force || !animationPaused else { return }

        dancerImageView.image = frames[dancerFrameIndex % frames.count]
        dancerFrameIndex = (dancerFrameIndex + frameStep(for: currentState)) % frames.count
    }

    private func activeFrameInterval() -> TimeInterval {
        switch currentState {
        case .idle:
            return 1.20
        case .codexRunning:
            return 0.42
        case .commandRunning:
            return 0.38
        case .thinking:
            return 0.72
        case .longRunning:
            return 1.00
        case .waitingUser:
            return 0.70
        case .success:
            return 0.30
        case .error:
            return 0.72
        }
    }

    private func shouldAnimateStageEffects() -> Bool {
        switch currentState {
        case .idle:
            return false
        default:
            return true
        }
    }

    private func stageSparkleStep() -> CGFloat {
        switch currentState {
        case .success:
            return 0.13
        case .commandRunning, .codexRunning:
            return 0.10
        case .waitingUser, .thinking, .error:
            return 0.08
        case .longRunning:
            return 0.05
        case .idle:
            return 0
        }
    }

    private func applyImageMotion(for state: PetState) {
        guard let layer = dancerImageView.layer else { return }
        layer.removeAnimation(forKey: "codex.pet.action.position")
        layer.removeAnimation(forKey: "codex.pet.action.rotation")
        layer.removeAnimation(forKey: "codex.pet.action.scale")

        if animationPaused {
            return
        }

        let profile = actionMotion(for: state)
        let position = CAKeyframeAnimation(keyPath: "position.y")
        position.values = profile.yValues
        position.keyTimes = profile.keyTimes
        position.duration = profile.duration
        position.repeatCount = .infinity
        position.isAdditive = true
        position.calculationMode = .cubic
        position.isRemovedOnCompletion = false
        layer.add(position, forKey: "codex.pet.action.position")

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = profile.rotationValues.map { $0 * .pi / 180 }
        rotation.keyTimes = profile.keyTimes
        rotation.duration = profile.duration
        rotation.repeatCount = .infinity
        rotation.isAdditive = true
        rotation.calculationMode = .cubic
        rotation.isRemovedOnCompletion = false
        layer.add(rotation, forKey: "codex.pet.action.rotation")

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = profile.scaleValues
        scale.keyTimes = profile.keyTimes
        scale.duration = profile.duration
        scale.repeatCount = .infinity
        scale.calculationMode = .cubic
        scale.isRemovedOnCompletion = false
        layer.add(scale, forKey: "codex.pet.action.scale")
    }

    private struct ActionMotion {
        var duration: TimeInterval
        var yValues: [CGFloat]
        var rotationValues: [CGFloat]
        var scaleValues: [CGFloat]
        var keyTimes: [NSNumber]
    }

    private func actionMotion(for state: PetState) -> ActionMotion {
        switch state {
        case .idle:
            return subtleDanceMotion(duration: 4.2, yValues: [0, 2, 0], rotationValues: [-0.35, 0.35, -0.35], scaleValues: [0.998, 1.002, 0.998], keyTimes: [0, 0.5, 1])
        case .codexRunning:
            return subtleDanceMotion(duration: 2.1, yValues: [0, 3, -1, 0], rotationValues: [-0.7, 0.9, -0.5, -0.7], scaleValues: [1.0, 1.006, 1.0, 1.0], keyTimes: [0, 0.34, 0.72, 1])
        case .commandRunning:
            return subtleDanceMotion(duration: 1.8, yValues: [0, 2, 0], rotationValues: [-0.8, 0.2, -0.8], scaleValues: [1.002, 1.008, 1.002], keyTimes: [0, 0.5, 1])
        case .thinking:
            return subtleDanceMotion(duration: 3.2, yValues: [0, 2, 0], rotationValues: [-0.6, 0.7, -0.6], scaleValues: [1.0, 1.004, 1.0], keyTimes: [0, 0.5, 1])
        case .longRunning:
            return subtleDanceMotion(duration: 4.6, yValues: [0, 2, -1, 0], rotationValues: [-0.45, 0.5, -0.25, -0.45], scaleValues: [0.998, 1.003, 1.0, 0.998], keyTimes: [0, 0.40, 0.72, 1])
        case .waitingUser:
            return subtleDanceMotion(duration: 2.0, yValues: [0, 3, 1, 3, 0], rotationValues: [-0.8, 1.0, -0.4, 0.9, -0.8], scaleValues: [1.0, 1.006, 1.0, 1.006, 1.0], keyTimes: [0, 0.25, 0.5, 0.75, 1])
        case .success:
            return subtleDanceMotion(duration: 1.2, yValues: [0, 4, 1, 0], rotationValues: [-0.9, 1.2, -0.4, -0.9], scaleValues: [1.0, 1.010, 1.004, 1.0], keyTimes: [0, 0.38, 0.72, 1])
        case .error:
            return subtleDanceMotion(duration: 2.4, yValues: [0, 1, 0], rotationValues: [-1.0, -0.4, -1.0], scaleValues: [1.0, 0.998, 1.0], keyTimes: [0, 0.5, 1])
        }
    }

    private func subtleDanceMotion(
        duration: TimeInterval,
        yValues: [CGFloat],
        rotationValues: [CGFloat],
        scaleValues: [CGFloat],
        keyTimes: [NSNumber]
    ) -> ActionMotion {
        ActionMotion(
            duration: duration,
            yValues: yValues.map { min(max($0, -maxGlobalImageTravel), maxGlobalImageTravel) },
            rotationValues: rotationValues.map { min(max($0, -maxGlobalRotationDegrees), maxGlobalRotationDegrees) },
            scaleValues: scaleValues,
            keyTimes: keyTimes
        )
    }

    private func frameStep(for state: PetState) -> Int {
        switch state {
        case .success, .commandRunning, .waitingUser:
            return 1
        case .error:
            return 2
        default:
            return 1
        }
    }

    private func bubbleText(for state: PetState) -> String? {
        switch state {
        case .waitingUser:
            return "等你回复"
        case .success:
            return "通过啦"
        case .error:
            return "这里好像出错了"
        case .longRunning:
            return "还在跑..."
        default:
            return nil
        }
    }

    func showContextMenu(event: NSEvent) {
        let menu = NSMenu()
        let status = NSMenuItem(title: "状态：\(currentState.rawValue)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "大小 90%", action: #selector(setScale90), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "大小 110%", action: #selector(setScale110), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "大小 130%", action: #selector(setScale130), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "透明度 70%", action: #selector(setOpacity70), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "透明度 85%", action: #selector(setOpacity85), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "透明度 100%", action: #selector(setOpacity100), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: config.window.alwaysOnTop ? "取消总在最前" : "总在最前", action: #selector(toggleAlwaysOnTop), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: animationPaused ? "继续动画" : "暂停动画", action: #selector(togglePause), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(actionDemoMenuItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: petView)
    }

    private func actionDemoMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "动作演示", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "动作演示")
        submenu.addItem(demoMenuItem(title: "恢复自动状态", action: #selector(clearDemoOverride), state: demoOverrideState == nil))
        submenu.addItem(.separator())
        submenu.addItem(demoMenuItem(title: "待机", action: #selector(demoIdle), state: demoOverrideState == .idle))
        submenu.addItem(demoMenuItem(title: "跳舞运行", action: #selector(demoCodexRunning), state: demoOverrideState == .codexRunning))
        submenu.addItem(demoMenuItem(title: "执行命令", action: #selector(demoCommandRunning), state: demoOverrideState == .commandRunning))
        submenu.addItem(demoMenuItem(title: "思考", action: #selector(demoThinking), state: demoOverrideState == .thinking))
        submenu.addItem(demoMenuItem(title: "长时间运行", action: #selector(demoLongRunning), state: demoOverrideState == .longRunning))
        submenu.addItem(demoMenuItem(title: "等待输入", action: #selector(demoWaitingUser), state: demoOverrideState == .waitingUser))
        submenu.addItem(demoMenuItem(title: "成功", action: #selector(demoSuccess), state: demoOverrideState == .success))
        submenu.addItem(demoMenuItem(title: "错误", action: #selector(demoError), state: demoOverrideState == .error))
        item.submenu = submenu
        return item
    }

    private func demoMenuItem(title: String, action: Selector, state selected: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = selected ? .on : .off
        return item
    }

    @objc private func setScale90() { setScale(0.9) }
    @objc private func setScale110() { setScale(1.1) }
    @objc private func setScale130() { setScale(1.3) }
    @objc private func setOpacity70() { setOpacity(0.70) }
    @objc private func setOpacity85() { setOpacity(0.85) }
    @objc private func setOpacity100() { setOpacity(1.0) }
    @objc private func clearDemoOverride() {
        demoOverrideState = nil
        transientUntil = .distantPast
        updateState()
    }
    @objc private func demoIdle() { setDemoState(.idle) }
    @objc private func demoCodexRunning() { setDemoState(.codexRunning) }
    @objc private func demoCommandRunning() { setDemoState(.commandRunning) }
    @objc private func demoThinking() { setDemoState(.thinking) }
    @objc private func demoLongRunning() { setDemoState(.longRunning) }
    @objc private func demoWaitingUser() { setDemoState(.waitingUser) }
    @objc private func demoSuccess() { setDemoState(.success) }
    @objc private func demoError() { setDemoState(.error) }
    @objc private func toggleAlwaysOnTop() {
        config.window.alwaysOnTop.toggle()
        saveConfig()
        renderState(force: true)
    }
    @objc private func togglePause() {
        animationPaused.toggle()
        if !animationPaused {
            applyImageMotion(for: currentState)
            updateDancerFrame(force: true)
        } else {
            dancerImageView.layer?.removeAllAnimations()
        }
    }
    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setScale(_ value: Double) {
        config.window.scale = min(1.3, max(0.9, value))
        saveConfig()
        renderState(force: true)
    }

    private func setOpacity(_ value: Double) {
        config.window.opacity = min(1.0, max(0.7, value))
        saveConfig()
        renderState(force: true)
    }

    private func setDemoState(_ state: PetState) {
        demoOverrideState = state
        currentState = state
        transientUntil = .distantPast
        renderState(force: true)
    }

    func saveWindowFrame() {
        guard let window else { return }
        config.window.x = window.frame.origin.x
        config.window.y = window.frame.origin.y
        saveConfig()
    }

    private func saveConfig() {
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configURL, options: .atomic)
        }
    }

    private func writeDebugLog(_ message: String) {
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        let line = "\(Date()) \(message)\n"
        let logURL = appSupportURL.appendingPathComponent("debug.log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    private static func loadConfig(from url: URL) -> CompanionConfig {
        let defaultConfig = CompanionConfig(
            version: 1,
            window: .init(x: -1, y: -1, scale: 1, opacity: 1, alwaysOnTop: true),
            behavior: .init(idleAnimation: true, bubbleEnabled: true, launchAtLogin: false)
        )

        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CompanionConfig.self, from: data),
              decoded.version == 1
        else {
            return defaultConfig
        }

        return CompanionConfig(
            version: 1,
            window: .init(
                x: decoded.window.x,
                y: decoded.window.y,
                scale: min(1.3, max(0.9, decoded.window.scale)),
                opacity: min(1.0, max(0.7, decoded.window.opacity)),
                alwaysOnTop: decoded.window.alwaysOnTop
            ),
            behavior: decoded.behavior
        )
    }
}
