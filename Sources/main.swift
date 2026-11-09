import AppKit
import Foundation
import IOKit.pwr_mgt

// MARK: - Model

struct Heart { var x: CGFloat; var age: CGFloat }

final class PetState {
    static let shared = PetState()
    private let defaults = UserDefaults.standard

    // World (positions are fractions of the canvas width, 0...1)
    var x: CGFloat = 0.36
    var ball: CGFloat = 0.78
    var ballVelocity: CGFloat = 0     // fraction of canvas width per second
    var ballSpin: CGFloat = 0
    var ballDragging = false
    var chasingBall = false
    var snack: CGFloat?
    var poop: [CGFloat] = []
    var sleeping = false
    var direction: CGFloat = 1
    var tick: CGFloat = 0

    // Counters (persisted)
    var pets = UserDefaults.standard.integer(forKey: "pets")
    var feeds = UserDefaults.standard.integer(forKey: "feeds")
    var cleans = UserDefaults.standard.integer(forKey: "cleans")
    var games = UserDefaults.standard.integer(forKey: "games")

    // Timing
    var lastTap: [Date] = []
    var lastPoop = Date()
    var lastUpdate = Date()
    var recentActivity = Date()
    var nextWander = Date().addingTimeInterval(3)
    var walkTarget: CGFloat?
    var lounging = false
    var loungeUntil = Date.distantPast
    var nextLounge = Date().addingTimeInterval(12)

    // Kept at rest: Blob Kitty does not hop when petted.
    let jump: CGFloat = 0
    let landing: CGFloat = 0
    var hearts: [Heart] = []
    var pettingUntil = Date.distantPast

    // Blob Kitty needs: 0...10. Updated with elapsed real time.
    var hunger: CGFloat = 10
    var company: CGFloat = 10

    var views = NSHashTable<NSView>.weakObjects()

    func pet() {
        pets += 1; defaults.set(pets, forKey: "pets")
        let now = Date()
        lastTap = lastTap.filter { now.timeIntervalSince($0) < 1.3 }
        lastTap.append(now)
        sleeping = false; lounging = false; recentActivity = now
        walkTarget = nil
        company = min(10, company + 2)
        pettingUntil = now.addingTimeInterval(1.3)
        // Blob Kitty stays on the ground when petted (no hopping).
        hearts.append(Heart(x: CGFloat.random(in: -8...8), age: 0))
        if hearts.count > 5 { hearts.removeFirst() }
    }

    func addSnack(_ p: CGFloat) { snack = p; lounging = false; sleeping = false; recentActivity = Date() }

    func clean(_ index: Int) {
        guard poop.indices.contains(index) else { return }
        poop.remove(at: index)
        cleans += 1; defaults.set(cleans, forKey: "cleans")
        recentActivity = Date()
    }

    func startBallDrag(at p: CGFloat) {
        ballDragging = true
        ballVelocity = 0
        lounging = false
        chasingBall = false
        moveBall(to: p)
        games += 1
        defaults.set(games, forKey: "games")
    }

    func moveBall(to p: CGFloat) {
        ball = max(0.02, min(0.98, p))
        sleeping = false
        recentActivity = Date()
    }

    func finishBallDrag(velocity: CGFloat) {
        guard ballDragging else { return }
        ballDragging = false
        ballVelocity = max(-0.20, min(0.20, velocity))
        chasingBall = true
        sleeping = false
        recentActivity = Date()
    }

    /// Advances the simulation. Uses real elapsed time so speed is frame-rate independent.
    func update() {
        let now = Date()
        let elapsed = CGFloat(max(0, now.timeIntervalSince(lastUpdate)))
        let dt = min(elapsed, 0.1)
        hunger = max(0, hunger - min(elapsed, 60) / 18)
        company = max(0, company - min(elapsed, 60) / 22)
        lastUpdate = now
        tick += dt * 1.6

        if now.timeIntervalSince(lastPoop) > 1100 {
            if poop.count < 3 { poop.append(CGFloat.random(in: 0.7...0.93)) }
            lastPoop = now
        }

        for i in hearts.indices { hearts[i].age += dt * 1.1 }
        hearts.removeAll { $0.age >= 1 }
        // Release momentum, friction and rebounds match the browser Blob Kitty.
        if !ballDragging {
            ball += ballVelocity * dt
            ballSpin += ballVelocity * dt * 8
            ballVelocity *= exp(-1.45 * dt)
            if ball < 0.02 || ball > 0.98 {
                ball = max(0.02, min(0.98, ball))
                ballVelocity *= -0.55
            }
            if abs(ballVelocity) < 0.003 { ballVelocity = 0 }
        }

        if lounging && now >= loungeUntil {
            lounging = false
            nextLounge = now.addingTimeInterval(Double.random(in: 14...24))
        }
        if let food = snack {
            direction = food > x ? 1 : -1
            x += max(-0.040 * dt, min(0.040 * dt, food - x))
            if abs(food - x) < 0.022 {
                snack = nil; feeds += 1
                hunger = min(10, hunger + 4)
                defaults.set(feeds, forKey: "feeds")
                recentActivity = now
            }
        } else if chasingBall {
            direction = ball >= x ? 1 : -1
            let delta = ball - x
            x += max(-0.055 * dt, min(0.055 * dt, delta))
            if abs(delta) < 0.02 && !ballDragging {
                if abs(ballVelocity) < 0.03 {
                    ballVelocity += direction * 0.075
                    chasingBall = false
                }
            }
        } else if lounging {
            walkTarget = nil
        } else if now >= nextLounge && !ballDragging {
            lounging = true
            loungeUntil = now.addingTimeInterval(Double.random(in: 3...6))
            walkTarget = nil
        } else if now.timeIntervalSince(recentActivity) > 40 {
            sleeping = true; walkTarget = nil
        } else if !sleeping {
            if let target = walkTarget {
                direction = target > x ? 1 : -1
                x += direction * 0.025 * dt
                if abs(target - x) < 0.004 {
                    walkTarget = nil
                    nextWander = now.addingTimeInterval(Double.random(in: 2...6))
                }
            } else if now >= nextWander {
                walkTarget = CGFloat.random(in: 0.12...0.88)
            }
        }
        x = max(0.05, min(0.95, x))

        for view in views.allObjects { view.needsDisplay = true }
    }
}

// MARK: - View

final class PetCanvas: NSView {
    static let size = NSSize(width: 1085, height: 30)
    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    let state = PetState.shared
    private var draggingBall = false
    private var lastBallPosition: CGFloat = 0
    private var lastBallTime: TimeInterval = 0
    private var releaseVelocity: CGFloat = 0
    private var touchIdentity: (NSCopying & NSObjectProtocol)?
    private var lastTouchTime: TimeInterval = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.direct]
        state.views.add(self)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }
    override var intrinsicContentSize: NSSize { PetCanvas.size }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Drawing helpers

    private func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
        c.setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
    }
    private func rectangle(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
        c.setFill(); NSRect(x: x, y: y, width: w, height: h).fill()
    }

    /// Kawaii kitten: unmistakable pointed ears, whiskers, muzzle and curved cat tail.
    private func drawCat(t: CGFloat, blink: Bool) {
        let fur = NSColor(red: 0.80, green: 0.65, blue: 0.52, alpha: 1)
        let cream = NSColor(red: 1.0, green: 0.97, blue: 0.91, alpha: 1)
        let earPink = NSColor(red: 1.0, green: 0.67, blue: 0.72, alpha: 1)
        let blue = NSColor(red: 0.17, green: 0.58, blue: 0.98, alpha: 1)
        let pupil = NSColor(red: 0.07, green: 0.28, blue: 0.58, alpha: 1)
        let ink = NSColor(red: 0.39, green: 0.27, blue: 0.30, alpha: 1)
        let beingPetted = Date() < state.pettingUntil
        let bob = sin(t * (beingPetted ? 4.5 : 1.3)) * (beingPetted ? 1.1 : 0.4)
        let sad = state.hunger <= 3 || state.company <= 3

        // Tail curls upward like a question mark, behind the body.
        let tail = NSBezierPath()
        tail.lineWidth = 8
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 25, y: 14))
        tail.curve(to: NSPoint(x: 38, y: 37 + sin(t * 0.8) * 2),
                   controlPoint1: NSPoint(x: 45, y: 8),
                   controlPoint2: NSPoint(x: 48, y: 30))
        fur.setStroke(); tail.stroke()

        // Tiny rounded paws and a chubby, compact kitten silhouette.
        oval(-25, 0, 19, 11, fur)
        oval(6, 0, 19, 11, fur)
        oval(-30, 8 + bob, 60, 48, fur)

        // Pointed triangular ears with slightly curled tips (not round monkey ears).
        for side in [-1.0 as CGFloat, 1.0] {
            let ear = NSBezierPath()
            ear.move(to: NSPoint(x: side * 12, y: 46 + bob))
            ear.line(to: NSPoint(x: side * 22, y: 72 + bob))
            ear.line(to: NSPoint(x: side * 29, y: 66 + bob))
            ear.line(to: NSPoint(x: side * 31, y: 44 + bob))
            ear.close()
            fur.setFill(); ear.fill()
            let inner = NSBezierPath()
            inner.move(to: NSPoint(x: side * 18, y: 49 + bob))
            inner.line(to: NSPoint(x: side * 23, y: 64 + bob))
            inner.line(to: NSPoint(x: side * 27, y: 49 + bob))
            inner.close()
            earPink.setFill(); inner.fill()
        }

        // Only two little white markings, not a pale monkey-like face mask.
        oval(-16, 9 + bob, 25, 13, cream)
        oval(15, 48 + bob, 10, 7, cream)

        // Blue eyes on the fur, a small cream muzzle with the cat's W-shaped mouth.
        if blink || beingPetted {
            oval(-18, 34 + bob, 14, 2.5, pupil)
            oval(4, 34 + bob, 14, 2.5, pupil)
        } else {
            oval(-18, 28 + bob, 14, 18, blue)
            oval(4, 28 + bob, 14, 18, blue)
            oval(-14, 30 + bob, 7, 13, pupil)
            oval(8, 30 + bob, 7, 13, pupil)
            oval(-15, 38 + bob, 5, 6, .white)
            oval(7, 38 + bob, 5, 6, .white)
        }
        oval(-15, 20 + bob, 15, 9, cream)
        oval(0, 20 + bob, 15, 9, cream)

        // Small inverted pink triangle clearly reads as a cat nose.
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: -5, y: 26 + bob))
        nose.line(to: NSPoint(x: 5, y: 26 + bob))
        nose.line(to: NSPoint(x: 0, y: 21 + bob))
        nose.close(); earPink.setFill(); nose.fill()

        let mouth = NSBezierPath()
        mouth.lineWidth = 1.5
        mouth.lineCapStyle = .round
        mouth.move(to: NSPoint(x: 0, y: 21 + bob))
        mouth.line(to: NSPoint(x: 0, y: 17 + bob))
        mouth.move(to: NSPoint(x: -6, y: sad ? 15 : 17 + bob))
        mouth.curve(to: NSPoint(x: 0, y: sad ? 17 : 15 + bob),
                    controlPoint1: NSPoint(x: -5, y: sad ? 18 : 13 + bob),
                    controlPoint2: NSPoint(x: -2, y: sad ? 18 : 13 + bob))
        mouth.curve(to: NSPoint(x: 6, y: sad ? 15 : 17 + bob),
                    controlPoint1: NSPoint(x: 2, y: sad ? 18 : 13 + bob),
                    controlPoint2: NSPoint(x: 5, y: sad ? 18 : 13 + bob))
        ink.setStroke(); mouth.stroke()

        // Three short whiskers on each side.
        let whiskers = NSBezierPath()
        whiskers.lineWidth = 1
        whiskers.lineCapStyle = .round
        for side in [-1.0 as CGFloat, 1.0] {
            for offset in [-5.0 as CGFloat, 0.0, 5.0] {
                whiskers.move(to: NSPoint(x: side * 15, y: 21 + bob + offset * 0.35))
                whiskers.line(to: NSPoint(x: side * 28, y: 21 + bob + offset))
            }
        }
        ink.withAlphaComponent(0.65).setStroke(); whiskers.stroke()
        oval(-26, 23 + bob, 7, 4, earPink.withAlphaComponent(0.65))
        oval(19, 23 + bob, 7, 4, earPink.withAlphaComponent(0.65))
    }

    private func drawLoungingKitty(t: CGFloat) {
        let fur = NSColor(red: 0.80, green: 0.65, blue: 0.52, alpha: 1)
        let cream = NSColor(red: 1, green: 0.97, blue: 0.91, alpha: 1)
        let pink = NSColor(red: 1, green: 0.67, blue: 0.72, alpha: 1)
        let blue = NSColor(red: 0.17, green: 0.58, blue: 0.98, alpha: 1)
        let wiggle = sin(t * 2) * 1.1
        // Belly-up pose still has visible triangular ears and kitten whiskers.
        let tail = NSBezierPath()
        tail.lineWidth = 7
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 24, y: 11))
        tail.curve(to: NSPoint(x: 35, y: 31),
                   controlPoint1: NSPoint(x: 45, y: 5),
                   controlPoint2: NSPoint(x: 43, y: 24))
        fur.setStroke(); tail.stroke()
        oval(-31, 5, 62, 42, fur)
        oval(-22, 9, 44, 29, cream)
        for side in [-1.0 as CGFloat, 1.0] {
            let ear = NSBezierPath()
            ear.move(to: NSPoint(x: side * 12, y: 36))
            ear.line(to: NSPoint(x: side * 22, y: 51))
            ear.line(to: NSPoint(x: side * 28, y: 35))
            ear.close(); fur.setFill(); ear.fill()
            oval(side * 21 - 3, 37, 6, 7, pink)
        }
        oval(-25, 31 + wiggle, 14, 13, fur)
        oval(11, 31 - wiggle, 14, 13, fur)
        oval(-22, 36 + wiggle, 7, 4, pink)
        oval(15, 36 - wiggle, 7, 4, pink)
        oval(-18, 19, 9, 9, blue)
        oval(9, 19, 9, 9, blue)
        oval(-16, 23, 3, 4, .white)
        oval(11, 23, 3, 4, .white)
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: -4, y: 15))
        nose.line(to: NSPoint(x: 4, y: 15))
        nose.line(to: NSPoint(x: 0, y: 11))
        nose.close(); pink.setFill(); nose.fill()
        oval(-23, 12, 7, 3, pink)
        oval(16, 12, 7, 3, pink)
    }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width, h = bounds.height
        guard w > 0 && h > 0 else { return }
        let now = Date()
        let top = NSColor(red: 0.23, green: 0.61, blue: 0.98, alpha: 1)
        let bottom = NSColor(red: 0.58, green: 0.84, blue: 1, alpha: 1)
        NSGradient(starting: top, ending: bottom)?.draw(in: bounds, angle: -90)
        let t = state.tick
        let textColor = NSColor(red: 0.16, green: 0.29, blue: 0.40, alpha: 1)
        let groundY = h * 0.075

        // Minimal pastel-blue background with only a few faint small clouds.
        for i in 0..<3 {
            let xx = (CGFloat(i) * 0.32 + 0.10) * w + sin(t * 0.1 + CGFloat(i)) * 4
            oval(xx, h * 0.70, h * 0.40, h * 0.10, NSColor.white.withAlphaComponent(0.45))
        }
        rectangle(0, 0, w, groundY, NSColor(red: 0.62, green: 0.78, blue: 0.74, alpha: 1))
        (PetCanvas.clock.string(from: now) as NSString).draw(
            at: NSPoint(x: w - 42, y: h - 13),
            withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                             .foregroundColor: textColor])

        for px in state.poop {
            oval(px * w - 4, groundY, 9, h * 0.14, .brown)
            oval(px * w - 2, groundY + h * 0.08, 5, h * 0.1, .brown)
        }
        if let food = state.snack {
            for dx in [-4.0, 0.0, 4.0] { oval(food * w + CGFloat(dx), groundY, 3.5, 3.5, .orange) }
        }
        // Matte pink ball, without highlights or shine.
        oval(state.ball * w - 6, groundY - 1, 12, 12, .systemPink)

        // Cat
        let cx = state.x * w
        let hopPx = state.jump * 5
        let shadowW = 18 * (1 - 0.35 * state.jump)
        oval(cx - shadowW / 2, groundY - 1.5, shadowW, 3, NSColor(white: 0, alpha: 0.2))

        // The cat is ~30 units tall in local space; scale it so it (and a hop) fit the 30pt bar.
        let base: CGFloat = 0.37
        let sy = base * (1 + 0.10 * state.jump - 0.12 * state.landing)
        let sx = base * (1 - 0.06 * state.jump + 0.10 * state.landing)
        NSGraphicsContext.saveGraphicsState()
        let xf = NSAffineTransform()
        xf.translateX(by: cx, yBy: groundY + 0.6 + hopPx)
        xf.scaleX(by: sx, yBy: sy)
        xf.concat()
        if state.lounging { drawLoungingKitty(t: t) }
        else { drawCat(t: t, blink: Int(t * 3) % 37 == 0) }
        NSGraphicsContext.restoreGraphicsState()

        // Hearts and zZ are drawn unscaled so they stay crisp.
        for heart in state.hearts {
            ("+" as NSString).draw(
                at: NSPoint(x: cx + heart.x - 4, y: groundY + 14 + heart.age * 8),
                withAttributes: [.font: NSFont.systemFont(ofSize: 9),
                                 .foregroundColor: NSColor.systemPink.withAlphaComponent(1 - heart.age)])
        }

        let line = "HUNGER \(Int(state.hunger.rounded()))/10  COMPANY \(Int(state.company.rounded()))/10"
        (line as NSString).draw(
            at: NSPoint(x: w * 0.24, y: h - 10),
            withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .medium),
                             .foregroundColor: textColor])
    }

    // MARK: Interaction

    private func handleDown(_ fraction: CGFloat) {
        let w = max(1, bounds.width)
        let f = max(0, min(1, fraction))
        let px = f * w

        enum Hit { case poop(Int), ball, cat }
        var best: (hit: Hit, score: CGFloat)?
        func consider(_ hit: Hit, center: CGFloat, radius: CGFloat) {
            let score = abs(center * w - px) / radius       // 0 = dead centre, 1 = edge
            if score <= 1, score < (best?.score ?? .infinity) { best = (hit, score) }
        }
        for (i, p) in state.poop.enumerated() { consider(.poop(i), center: p, radius: 18) }
        consider(.ball, center: state.ball, radius: 16)
        // Finger-sized hit target is wider than the small visual sprite.
        consider(.cat, center: state.x, radius: 40)

        draggingBall = false
        switch best?.hit {
        case .poop(let i)?: state.clean(i)
        case .ball?:
            draggingBall = true
            lastBallPosition = f
            lastBallTime = ProcessInfo.processInfo.systemUptime
            releaseVelocity = 0
            state.startBallDrag(at: f)
        case .cat?: state.pet()
        case nil: state.addSnack(f)
        }
        needsDisplay = true
    }

    private func handleMove(_ fraction: CGFloat) {
        guard draggingBall else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0.016, now - lastBallTime)
        releaseVelocity = max(-0.20, min(0.20,
            (fraction - lastBallPosition) / CGFloat(elapsed)))
        lastBallPosition = fraction
        lastBallTime = now
        state.moveBall(to: fraction)
        needsDisplay = true
    }

    private func endDrag() {
        if draggingBall {
            let elapsed = ProcessInfo.processInfo.systemUptime - lastBallTime
            state.finishBallDrag(velocity: elapsed < 0.15 ? releaseVelocity : 0)
        }
        draggingBall = false
    }
    private func endTouch() { endDrag(); touchIdentity = nil }

    // Touch Bar touches. AppKit may *also* synthesize mouse events for the same tap, so
    // mouse handlers below ignore events that closely follow a touch (no double counting).
    override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .began, in: self).first else { return }
        lastTouchTime = ProcessInfo.processInfo.systemUptime
        touchIdentity = touch.identity
        handleDown(touch.location(in: self).x / max(1, bounds.width))
    }
    override func touchesMoved(with event: NSEvent) {
        lastTouchTime = ProcessInfo.processInfo.systemUptime
        guard draggingBall, let id = touchIdentity else { return }
        for touch in event.touches(matching: .moved, in: self) where touch.identity.isEqual(id) {
            handleMove(touch.location(in: self).x / max(1, bounds.width))
            break
        }
    }
    override func touchesEnded(with event: NSEvent) {
        lastTouchTime = ProcessInfo.processInfo.systemUptime
        endTouch()
    }
    override func touchesCancelled(with event: NSEvent) { endTouch() }

    private var mouseIsEchoOfTouch: Bool {
        ProcessInfo.processInfo.systemUptime - lastTouchTime < 0.35
    }
    override func mouseDown(with event: NSEvent) {
        guard !mouseIsEchoOfTouch else { return }
        handleDown(convert(event.locationInWindow, from: nil).x / max(1, bounds.width))
    }
    override func mouseDragged(with event: NSEvent) {
        guard !mouseIsEchoOfTouch else { return }
        handleMove(convert(event.locationInWindow, from: nil).x / max(1, bounds.width))
    }
    override func mouseUp(with event: NSEvent) {
        if !mouseIsEchoOfTouch { endDrag() }
    }
}

// MARK: - App

final class PetApp: NSObject, NSApplicationDelegate, NSTouchBarDelegate {
    static let canvasID = NSTouchBarItem.Identifier("touchbarpet.canvas")
    static let trayID = NSTouchBarItem.Identifier("touchbarpet.tray")

    private let defaults = UserDefaults.standard
    private var bar: NSTouchBar?
    private var trayItem: NSCustomTouchBarItem?
    private var statusItem: NSStatusItem?
    private var previewWindow: NSPanel?
    // Preserve the normal macOS Touch Bar unless the user explicitly opts in.
    private let touchBarRequested = ProcessInfo.processInfo.arguments.contains("--touchbar")
    private var pinItem: NSMenuItem?
    private var awakeItem: NSMenuItem?
    private var frameTimer: Timer?
    private var watchdog: Timer?
    private var activity: NSObjectProtocol?
    private var displayAssertion: IOPMAssertionID = 0

    /// false after the user chose "Hide cat" -> nothing may bring the bar back.
    private var wantVisible = false
    /// nil = not yet known; true = NSTouchBar.isVisible works for system-modal bars.
    private var visibilityReliable: Bool?

    /// Pinned: no close button, and the bar is restored automatically if the system drops it.
    private var pinned: Bool {
        get { (defaults.object(forKey: "pinned") as? Bool) ?? false }
        set { defaults.set(newValue, forKey: "pinned") }
    }
    private var keepAwake: Bool {
        get { defaults.bool(forKey: "keepAwake") }
        set { defaults.set(newValue, forKey: "keepAwake") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Without this macOS "App Nap"s a windowless background app and the animation stalls.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "TouchBarPET Touch Bar animation")
        ProcessInfo.processInfo.disableAutomaticTermination("TouchBarPET")
        ProcessInfo.processInfo.disableSuddenTermination()

        buildMenu()
        if touchBarRequested { showTouchBar() }

        // .common so the pet keeps animating while the menu-bar menu is open.
        let t = Timer(timeInterval: 1.0 / 20.0, repeats: true) { _ in PetState.shared.update() }
        t.tolerance = 0.01
        RunLoop.main.add(t, forMode: .common)
        frameTimer = t

        let w = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self, self.pinned else { return }
            self.ensureVisible(onlyIfKnown: true)
        }
        RunLoop.main.add(w, forMode: .common)
        watchdog = w

        // On-screen preview is the default, without taking over the hardware bar.
        if !touchBarRequested { showPreview() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let b = bar { TouchPETDismissBar(b) }
        TouchPETRemoveTrayItem(PetApp.trayID.rawValue)
        setKeepAwake(false, save: false)
        if let a = activity { ProcessInfo.processInfo.endActivity(a) }
    }

    // MARK: Setup

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "PET"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show preview", action: #selector(showPreview), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show on Touch Bar (opt in)", action: #selector(showTouchBar), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Pet Kitty", action: #selector(petKitty), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Restore normal Touch Bar", action: #selector(restoreNormalTouchBar), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide cat", action: #selector(hide), keyEquivalent: ""))
        menu.addItem(.separator())
        let pin = NSMenuItem(title: "Pin to Touch Bar (no close button, auto-restore)",
                             action: #selector(togglePin(_:)), keyEquivalent: "")
        pin.state = pinned ? .on : .off
        menu.addItem(pin); pinItem = pin
        let awake = NSMenuItem(title: "Keep display awake (Touch Bar stays on)",
                               action: #selector(toggleAwake(_:)), keyEquivalent: "")
        awake.state = keepAwake ? .on : .off
        menu.addItem(awake); awakeItem = awake
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TouchBarPET", action: #selector(quit), keyEquivalent: "q"))
        for m in menu.items { m.target = self }
        item.menu = menu
        statusItem = item
    }

    private func buildBar() {
        let b = NSTouchBar()
        b.delegate = self
        b.defaultItemIdentifiers = [PetApp.canvasID]
        b.principalItemIdentifier = PetApp.canvasID
        bar = b

        // Control Strip button exists only during explicit hardware opt-in.
        let tray = NSCustomTouchBarItem(identifier: PetApp.trayID)
        tray.view = NSButton(title: "PET", target: self, action: #selector(show))
        TouchPETInstallTrayItem(tray, PetApp.trayID.rawValue)
        trayItem = tray
    }

    private func observeSystemEvents() {
        let ws = NSWorkspace.shared.notificationCenter
        // After sleep / lock the system drops the modal bar; the hardware needs a moment to wake.
        let wakeNames: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ]
        for name in wakeNames {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.restore(after: [1.2, 4.0], onlyIfKnown: false)
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.restore(after: [1.0, 3.5], onlyIfKnown: false) }

        // Other system-modal bars (Siri, screenshots, ...) or display changes can replace ours.
        ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) {
            [weak self] _ in self?.restore(after: [0.4], onlyIfKnown: true)
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.restore(after: [0.8], onlyIfKnown: true) }
    }

    // MARK: Presenting

    private func restore(after delays: [TimeInterval], onlyIfKnown: Bool) {
        for d in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { [weak self] in
                self?.ensureVisible(onlyIfKnown: onlyIfKnown)
            }
        }
    }

    /// Re-presents the bar when it is gone. If `isVisible` can't be trusted on this macOS
    /// version we only re-present for events that definitely dismiss it (wake/unlock),
    /// never on a timer, so the pet doesn't flicker.
    private func ensureVisible(onlyIfKnown: Bool) {
        guard wantVisible, let b = bar else { return }
        if visibilityReliable == true {
            if !b.isVisible && (pinned || !onlyIfKnown) { present() }
        } else if !onlyIfKnown {
            present()
        }
    }

    private func present() {
        guard let b = bar else { return }
        TouchPETSetCloseBoxVisible(!pinned)
        let ok = TouchPETPresentBar(b, PetApp.trayID.rawValue)
        statusItem?.button?.title = ok ? "PET" : "PET!"
        if !ok { NSLog("TouchBarPET: no system-modal Touch Bar API available on this macOS version") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, let b = self.bar else { return }
            if b.isVisible { self.visibilityReliable = true }
            else if self.visibilityReliable == nil { self.visibilityReliable = false }
        }
    }

    // MARK: Actions

    @objc func petKitty() { PetState.shared.pet() }

    @objc func showTouchBar() {
        if bar == nil { buildBar(); observeSystemEvents() }
        wantVisible = true
        if keepAwake { setKeepAwake(true, save: false) }
        present()
    }

    @objc func restoreNormalTouchBar() {
        wantVisible = false
        if let b = bar { TouchPETDismissBar(b) }
        TouchPETRemoveTrayItem(PetApp.trayID.rawValue)
        trayItem = nil
        bar = nil
        setKeepAwake(false, save: false)
        statusItem?.button?.title = "PET"
    }

    @objc func show() { showTouchBar() }
    @objc func hide() {
        restoreNormalTouchBar()
        previewWindow?.orderOut(nil)
    }

    /// Uses the exact same PetCanvas and PetState as the hardware Touch Bar.
    /// This is an interactive preview, not an emulation of macOS's private Touch Bar APIs.
    @objc func showPreview() {
        if previewWindow == nil {
            let rect = NSRect(origin: .zero, size: PetCanvas.size)
            let panel = NSPanel(
                contentRect: rect,
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false)
            panel.title = "TouchBarPET — On-screen preview"
            panel.contentView = PetCanvas(frame: rect)
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces]
            panel.center()
            previewWindow = panel
        }
        previewWindow?.orderFrontRegardless()
    }

    @objc func quit() { NSApp.terminate(nil) }

    @objc func togglePin(_ sender: NSMenuItem) {
        pinned.toggle()
        sender.state = pinned ? .on : .off
        if wantVisible { present() }   // re-present only while opted in
    }

    @objc func toggleAwake(_ sender: NSMenuItem) {
        setKeepAwake(!keepAwake && wantVisible)
        sender.state = keepAwake ? .on : .off
    }

    private func setKeepAwake(_ on: Bool, save: Bool = true) {
        if on, displayAssertion == 0 {
            var id: IOPMAssertionID = 0
            let r = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "TouchBarPET keeps the Touch Bar on" as CFString, &id)
            if r == kIOReturnSuccess { displayAssertion = id }
        } else if !on, displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
        if save { keepAwake = on }
    }

    // MARK: NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == PetApp.canvasID else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let canvas = PetCanvas(frame: NSRect(origin: .zero, size: PetCanvas.size))
        canvas.setContentHuggingPriority(.defaultLow, for: .horizontal)
        canvas.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        item.view = canvas
        item.visibilityPriority = .high
        return item
    }
}

let app = NSApplication.shared
let delegate = PetApp()
app.delegate = delegate
app.run()
