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
    var snack: CGFloat?
    var poop: [CGFloat] = []
    var sleeping = false
    var shelter = false
    var direction: CGFloat = 1
    var tick: CGFloat = 0
    var weather = 0

    // Counters (persisted)
    var pets = UserDefaults.standard.integer(forKey: "pets")
    var feeds = UserDefaults.standard.integer(forKey: "feeds")
    var cleans = UserDefaults.standard.integer(forKey: "cleans")
    var games = UserDefaults.standard.integer(forKey: "games")

    // Timing
    var lastTap: [Date] = []
    var lastPoop = Date()
    var lastWeather = Date()
    var lastUpdate = Date()
    var recentActivity = Date()
    var nextWander = Date().addingTimeInterval(3)
    var walkTarget: CGFloat?

    // Hopping (when the cat is petted)
    static let hopDuration: CGFloat = 0.42
    static let maxQueuedHops = 6
    private(set) var isHopping = false
    var hopsLeft = 0
    private var hopT: CGFloat = 0
    private var hopFrom: CGFloat = 0
    private var hopTo: CGFloat = 0
    var jump: CGFloat = 0      // 0...1, height of the current hop arc
    var landing: CGFloat = 0   // 1 -> 0, landing squash
    var hearts: [Heart] = []

    var views = NSHashTable<NSView>.weakObjects()

    func pet() {
        pets += 1; defaults.set(pets, forKey: "pets")
        let now = Date()
        lastTap = lastTap.filter { now.timeIntervalSince($0) < 1.3 }
        lastTap.append(now)
        if lastTap.count >= 3 { shelter.toggle(); lastTap.removeAll() }
        sleeping = false; recentActivity = now
        walkTarget = nil
        queueHops(Int.random(in: 2...3))
        hearts.append(Heart(x: CGFloat.random(in: -8...8), age: 0))
        if hearts.count > 5 { hearts.removeFirst() }
    }

    /// Adds hops to the queue; rapid taps extend the sequence instead of restarting it.
    private func queueHops(_ n: Int) {
        hopsLeft = min(hopsLeft + n, PetState.maxQueuedHops)
        if !isHopping { beginHop() }
    }

    private func beginHop() {
        guard hopsLeft > 0 else { return }
        hopsLeft -= 1
        hopT = 0
        hopFrom = x
        var dist = CGFloat.random(in: 0.025...0.055) * (Bool.random() ? 1 : -1)
        if x + dist < 0.1 || x + dist > 0.9 { dist = -dist }   // bounce off the edges
        hopTo = max(0.1, min(0.9, x + dist))
        if abs(hopTo - x) > 0.003 { direction = hopTo > x ? 1 : -1 }
        isHopping = true
    }

    func addSnack(_ p: CGFloat) { snack = p; sleeping = false; recentActivity = Date() }

    func clean(_ index: Int) {
        guard poop.indices.contains(index) else { return }
        poop.remove(at: index)
        cleans += 1; defaults.set(cleans, forKey: "cleans")
        recentActivity = Date()
    }

    func ballMoved(_ p: CGFloat, newGame: Bool) {
        ball = max(0.03, min(0.97, p))
        if newGame { games += 1; defaults.set(games, forKey: "games") }
        sleeping = false; recentActivity = Date()
        if !isHopping && snack == nil { direction = ball >= x ? 1 : -1 }
    }

    /// Advances the simulation. Uses real elapsed time so speed is frame-rate independent.
    func update() {
        let now = Date()
        let dt = CGFloat(min(max(now.timeIntervalSince(lastUpdate), 0), 0.1))
        lastUpdate = now
        tick += dt * 1.6

        if now.timeIntervalSince(lastWeather) > 65 { weather = (weather + 1) % 3; lastWeather = now }
        if now.timeIntervalSince(lastPoop) > 1100 {
            if poop.count < 3 { poop.append(CGFloat.random(in: 0.7...0.93)) }
            lastPoop = now
        }

        for i in hearts.indices { hearts[i].age += dt * 1.1 }
        hearts.removeAll { $0.age >= 1 }
        landing = max(0, landing - dt * 5)

        if isHopping {
            hopT += dt / PetState.hopDuration
            let p = min(hopT, 1)
            x = hopFrom + (hopTo - hopFrom) * p
            jump = sin(p * .pi)
            if hopT >= 1 {
                x = hopTo; jump = 0; landing = 1
                isHopping = false
                if hopsLeft > 0 { beginHop() }
            }
        } else if let food = snack {
            direction = food > x ? 1 : -1
            x += max(-0.12 * dt, min(0.12 * dt, food - x))
            if abs(food - x) < 0.022 {
                snack = nil; feeds += 1
                defaults.set(feeds, forKey: "feeds")
                recentActivity = now
            }
        } else if now.timeIntervalSince(recentActivity) > 25 {
            sleeping = true; walkTarget = nil
        } else if !sleeping {
            if let target = walkTarget {
                direction = target > x ? 1 : -1
                x += direction * 0.035 * dt
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
    static let size = NSSize(width: 610, height: 30)
    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    let state = PetState.shared
    private var draggingBall = false
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

    /// Draws the cat with its feet at the local origin (0,0). The caller scales/translates.
    private func drawCat(t: CGFloat, blink: Bool) {
        let fur = NSColor.white, outline = NSColor(white: 0.80, alpha: 1)
        let d = state.direction
        for i in 0..<6 {
            let s = CGFloat(i)
            oval(-d * (15 + s * 3.2), 8 + sin(t * 2.2 + s * 0.35) * 2.5 + sin(s * 0.45) * 9,
                 11, 9, i % 2 == 0 ? fur : outline)
        }
        oval(-13, 0, 27, state.sleeping ? 13 : 18, fur)
        let hx = d * 7
        oval(hx - 10, 9, 19, 16, fur)
        for side in [-1.0 as CGFloat, 1.0] {
            let ear = NSBezierPath()
            ear.move(to: NSPoint(x: hx + side * 3, y: 19))
            ear.line(to: NSPoint(x: hx + side * 8, y: 30))
            ear.line(to: NSPoint(x: hx + side * 9, y: 16))
            ear.close(); fur.setFill(); ear.fill()
            oval(hx + side * 4 - 2, 24, 4, 4, .systemPink)
            if state.sleeping || blink {
                rectangle(hx + side * 4 - 3, 17, 6, 1.2, .darkGray)
            } else {
                oval(hx + side * 4 - 1, 16, 2.3, 3.5, .darkGray)
            }
        }
        oval(hx - 1, 12, 3, 2, .systemPink)
    }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width, h = bounds.height
        guard w > 0 && h > 0 else { return }
        let now = Date()
        let hr = Calendar.current.component(.hour, from: now)
        let morning = (6..<11).contains(hr), day = (11..<17).contains(hr)
        let sunset = (17..<21).contains(hr), night = !morning && !day && !sunset
        let top: NSColor = night ? NSColor(red: 0.03, green: 0.06, blue: 0.16, alpha: 1) :
            sunset ? NSColor(red: 0.45, green: 0.22, blue: 0.55, alpha: 1) :
            morning ? NSColor(red: 0.59, green: 0.79, blue: 0.95, alpha: 1) :
            NSColor(red: 0.3, green: 0.65, blue: 0.98, alpha: 1)
        let bottom: NSColor = night ? NSColor(red: 0.12, green: 0.16, blue: 0.33, alpha: 1) :
            sunset ? NSColor(red: 1, green: 0.55, blue: 0.32, alpha: 1) :
            morning ? NSColor(red: 0.97, green: 0.84, blue: 0.65, alpha: 1) :
            NSColor(red: 0.63, green: 0.87, blue: 1, alpha: 1)
        NSGradient(starting: top, ending: bottom)?.draw(in: bounds, angle: -90)
        let t = state.tick
        let textColor: NSColor = night ? .white : .black
        let groundY = h * 0.18

        if night {
            for i in 0..<12 {
                let px = CGFloat((i * 71 + 17) % 100) / 100 * w
                let py = h * (0.46 + CGFloat((i * 23) % 40) / 100)
                oval(px, py, 1.5, 1.5, .white)
            }
        }
        if state.weather != 2 {
            oval(w * 0.14, h * 0.52, h * 0.3, h * 0.3, night ? .white : .systemYellow)
        }
        if state.weather > 0 {
            let cloudY = h * 0.5
            let phase = CGFloat(Int(t * 15) % 9)
            for i in 0..<4 {
                let xx = (CGFloat(i) * 0.23 + 0.11) * w + sin(t * 0.2 + CGFloat(i)) * 6
                oval(xx, cloudY, h * 0.55, h * 0.14, .white)
                oval(xx + h * 0.1, cloudY + h * 0.04, h * 0.3, h * 0.16, .white)
                if state.weather == 2 {
                    for n in 0..<3 {   // rain falls downwards into the ground
                        rectangle(xx + CGFloat(n) * h * 0.18 + 2, cloudY - 2 - phase - CGFloat(n) * 2,
                                  1.4, h * 0.12, .systemBlue)
                    }
                }
            }
        }
        rectangle(0, 0, w, groundY, NSColor(red: 0.28, green: 0.6, blue: 0.36, alpha: 1))
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
        oval(state.ball * w - 5, groundY, 10, 10, .systemPink)

        // Cat
        let cx = state.x * w
        let hopPx = state.jump * 5
        let wood = NSColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1)
        if state.shelter {
            let eaves = groundY + 14
            rectangle(cx - 22, groundY, 3, 14, wood)
            rectangle(cx + 19, groundY, 3, 14, wood)
            let roof = NSBezierPath()
            roof.move(to: NSPoint(x: cx - 26, y: eaves))
            roof.line(to: NSPoint(x: cx, y: min(h - 1, eaves + 10)))
            roof.line(to: NSPoint(x: cx + 26, y: eaves))
            roof.close(); wood.setFill(); roof.fill()
        }
        let shadowW = 18 * (1 - 0.35 * state.jump)
        oval(cx - shadowW / 2, groundY - 1.5, shadowW, 3, NSColor(white: 0, alpha: 0.2))

        // The cat is ~30 units tall in local space; scale it so it (and a hop) fit the 30pt bar.
        let base: CGFloat = 0.58
        let sy = base * (1 + 0.10 * state.jump - 0.12 * state.landing)
        let sx = base * (1 - 0.06 * state.jump + 0.10 * state.landing)
        NSGraphicsContext.saveGraphicsState()
        let xf = NSAffineTransform()
        xf.translateX(by: cx, yBy: groundY + 0.6 + hopPx)
        xf.scaleX(by: sx, yBy: sy)
        xf.concat()
        drawCat(t: t, blink: Int(t * 3) % 11 == 0)
        NSGraphicsContext.restoreGraphicsState()

        // Hearts and zZ are drawn unscaled so they stay crisp.
        for heart in state.hearts {
            ("♥" as NSString).draw(
                at: NSPoint(x: cx + heart.x - 4, y: groundY + 14 + heart.age * 8),
                withAttributes: [.font: NSFont.systemFont(ofSize: 9),
                                 .foregroundColor: NSColor.systemPink.withAlphaComponent(1 - heart.age)])
        }
        if state.sleeping {
            ("zZ" as NSString).draw(
                at: NSPoint(x: cx + state.direction * 5 + 6, y: groundY + 12),
                withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.white])
        }

        let line = "PET \(state.pets)  FED \(state.feeds)  PLAY \(state.games)  CLEAN \(state.cleans)"
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
        consider(.cat, center: state.x, radius: 26)

        draggingBall = false
        switch best?.hit {
        case .poop(let i)?: state.clean(i)
        case .ball?: draggingBall = true; state.ballMoved(f, newGame: true)
        case .cat?: state.pet()
        case nil: state.addSnack(f)
        }
        needsDisplay = true
    }

    private func handleMove(_ fraction: CGFloat) {
        if draggingBall { state.ballMoved(fraction, newGame: false); needsDisplay = true }
    }

    private func endTouch() { draggingBall = false; touchIdentity = nil }

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
        if !mouseIsEchoOfTouch { draggingBall = false }
    }
}

// MARK: - App

final class PetApp: NSObject, NSApplicationDelegate, NSTouchBarDelegate {
    static let canvasID = NSTouchBarItem.Identifier("touchpet.canvas")
    static let trayID = NSTouchBarItem.Identifier("touchpet.tray")

    private let defaults = UserDefaults.standard
    private var bar: NSTouchBar?
    private var trayItem: NSCustomTouchBarItem?
    private var statusItem: NSStatusItem?
    private var pinItem: NSMenuItem?
    private var awakeItem: NSMenuItem?
    private var frameTimer: Timer?
    private var watchdog: Timer?
    private var activity: NSObjectProtocol?
    private var displayAssertion: IOPMAssertionID = 0

    /// false after the user chose "Hide cat" -> nothing may bring the bar back.
    private var wantVisible = true
    /// nil = not yet known; true = NSTouchBar.isVisible works for system-modal bars.
    private var visibilityReliable: Bool?

    /// Pinned: no close button, and the bar is restored automatically if the system drops it.
    private var pinned: Bool {
        get { (defaults.object(forKey: "pinned") as? Bool) ?? true }
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
            reason: "TouchPET Touch Bar animation")
        ProcessInfo.processInfo.disableAutomaticTermination("TouchPET")
        ProcessInfo.processInfo.disableSuddenTermination()

        buildMenu()
        buildBar()
        observeSystemEvents()

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

        if keepAwake { setKeepAwake(true) }
        show()
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
        item.button?.title = "🐱"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show cat", action: #selector(show), keyEquivalent: ""))
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
        menu.addItem(NSMenuItem(title: "Quit TouchPET", action: #selector(quit), keyEquivalent: "q"))
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

        // Control Strip button: one tap brings the pet back if it was dismissed.
        let tray = NSCustomTouchBarItem(identifier: PetApp.trayID)
        tray.view = NSButton(title: "🐱", target: self, action: #selector(show))
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
        statusItem?.button?.title = ok ? "🐱" : "🐱⚠︎"
        if !ok { NSLog("TouchPET: no system-modal Touch Bar API available on this macOS version") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, let b = self.bar else { return }
            if b.isVisible { self.visibilityReliable = true }
            else if self.visibilityReliable == nil { self.visibilityReliable = false }
        }
    }

    // MARK: Actions

    @objc func show() { wantVisible = true; present() }
    @objc func hide() { wantVisible = false; if let b = bar { TouchPETDismissBar(b) } }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func togglePin(_ sender: NSMenuItem) {
        pinned.toggle()
        sender.state = pinned ? .on : .off
        if wantVisible { present() }   // re-present to apply the close-button setting
    }

    @objc func toggleAwake(_ sender: NSMenuItem) {
        setKeepAwake(!keepAwake)
        sender.state = keepAwake ? .on : .off
    }

    private func setKeepAwake(_ on: Bool, save: Bool = true) {
        if on, displayAssertion == 0 {
            var id: IOPMAssertionID = 0
            let r = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "TouchPET keeps the Touch Bar on" as CFString, &id)
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
        item.view = PetCanvas(frame: NSRect(origin: .zero, size: PetCanvas.size))
        return item
    }
}

let app = NSApplication.shared
let delegate = PetApp()
app.delegate = delegate
app.run()
