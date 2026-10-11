import AppKit
import Foundation

final class PetState {
    static let shared = PetState()
    var x: CGFloat = 0.36
    var ball: CGFloat = 0.78
    var snack: CGFloat?
    var poop: [CGFloat] = []
    var sleeping = false
    var shelter = false
    var direction: CGFloat = 1
    var tick: CGFloat = 0
    var lastTap: [Date] = []
    var lastPoop = Date()
    var lastWeather = Date()
    var weather = 0
    var pets = UserDefaults.standard.integer(forKey: "pets")
    var feeds = UserDefaults.standard.integer(forKey: "feeds")
    var cleans = UserDefaults.standard.integer(forKey: "cleans")
    var games = UserDefaults.standard.integer(forKey: "games")
    var recentActivity = Date()
    var views = NSHashTable<NSView>.weakObjects()
    func pet() {
        pets += 1; UserDefaults.standard.set(pets, forKey: "pets")
        let now = Date()
        lastTap = lastTap.filter { now.timeIntervalSince($0) < 1.3 }
        lastTap.append(now)
        if lastTap.count >= 3 { shelter.toggle(); lastTap.removeAll() }
        sleeping = false; recentActivity = now
    }
    func addSnack(_ p: CGFloat) { snack = p; sleeping = false; recentActivity = Date() }
    func clean(_ index: Int) {
        guard poop.indices.contains(index) else { return }
        poop.remove(at: index)
        cleans += 1; UserDefaults.standard.set(cleans, forKey: "cleans")
    }
    func ballMoved(_ p: CGFloat, newGame: Bool) {
        ball = max(0.03, min(0.97, p))
        if newGame { games += 1; UserDefaults.standard.set(games, forKey: "games") }
        sleeping = false; recentActivity = Date()
    }
    func update() {
        tick += 0.08
        let now = Date()
        if now.timeIntervalSince(lastWeather) > 65 {
            weather = (weather + 1) % 3; lastWeather = now
        }
        if now.timeIntervalSince(lastPoop) > 1100 {
            if poop.count < 3 { poop.append(CGFloat.random(in: 0.7...0.93)) }
            lastPoop = now
        }
        if let food = snack {
            direction = food > x ? 1 : -1
            x += max(-0.006, min(0.006, food - x))
            if abs(food - x) < 0.022 {
                snack = nil; feeds += 1
                UserDefaults.standard.set(feeds, forKey: "feeds")
                recentActivity = now
            }
        } else if now.timeIntervalSince(recentActivity) > 18 {
            sleeping = true
        } else if !sleeping && Int(tick * 10) % 7 == 0 {
            x += direction * 0.002
            if x < 0.1 || x > 0.9 { direction *= -1 }
        }
        for view in views.allObjects { view.needsDisplay = true }
    }
}

final class PetCanvas: NSView {
    let state = PetState.shared
    private var draggingBall = false
    private var touchIdentity: AnyHashable?
    override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.direct]
        state.views.add(self)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override var acceptsFirstResponder: Bool { true }

    func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
        c.setFill()
        NSBezierPath(ovalIn: NSRect(x:x,y:y,width:w,height:h)).fill()
    }
    func rectangle(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
        c.setFill(); NSRect(x:x,y:y,width:w,height:h).fill()
    }
    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width, h = bounds.height
        guard w > 0 && h > 0 else { return }
        let hr = Calendar.current.component(.hour, from: Date())
        let morning = (6..<11).contains(hr), day = (11..<17).contains(hr)
        let sunset = (17..<21).contains(hr), night = !morning && !day && !sunset
        let top: NSColor = night ? NSColor(red:0.03,green:0.06,blue:0.16,alpha:1) :
            sunset ? NSColor(red:0.45,green:0.22,blue:0.55,alpha:1) :
            morning ? NSColor(red:0.59,green:0.79,blue:0.95,alpha:1) :
            NSColor(red:0.3,green:0.65,blue:0.98,alpha:1)
        let bottom: NSColor = night ? NSColor(red:0.12,green:0.16,blue:0.33,alpha:1) :
            sunset ? NSColor(red:1,green:0.55,blue:0.32,alpha:1) :
            morning ? NSColor(red:0.97,green:0.84,blue:0.65,alpha:1) :
            NSColor(red:0.63,green:0.87,blue:1,alpha:1)
        NSGradient(starting: top, ending: bottom)?.draw(in: bounds, angle: -90)
        let t = state.tick
        if night {
            for i in 0..<12 {
                let px = CGFloat((i*71+17)%100)/100*w
                let py = h*(0.46 + CGFloat((i*23)%40)/100)
                oval(px,py,1.5,1.5,.white)
            }
        }
        if state.weather != 2 {
            oval(w*0.14, h*0.55, h*0.28, h*0.28, night ? .white : .systemYellow)
        }
        if state.weather > 0 {
            for i in 0..<4 {
                let xx = (CGFloat(i)*0.23+0.11)*w + sin(t*0.2+CGFloat(i))*6
                oval(xx,h*0.72,h*0.38,h*0.13,.white)
                oval(xx+h*0.08,h*0.75,h*0.2,h*0.15,.white)
                if state.weather == 2 {
                    for n in 0..<3 {
                        rectangle(xx+CGFloat(n)*h*0.1,h*0.43+CGFloat(Int(t*15)%9),1.4,h*0.13,.systemBlue)
                    }
                }
            }
        }
        rectangle(0,0,w,h*0.18,NSColor(red:0.28,green:0.6,blue:0.36,alpha:1))
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        (fmt.string(from: Date()) as NSString).draw(at:NSPoint(x:w-42,y:h-13),
            withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:10,weight:.medium),
                            .foregroundColor:night ? NSColor.white : NSColor.black])
        for px in state.poop {
            oval(px*w-4,h*0.18,9,h*0.14,NSColor.brown)
            oval(px*w-2,h*0.26,5,h*0.1,NSColor.brown)
        }
        if let food = state.snack {
            for dx in [-4.0,0.0,4.0] { oval(food*w+CGFloat(dx),h*0.18,3.5,3.5,.orange) }
        }
        oval(state.ball*w-5,h*0.18,10,10,.systemPink)
        let cx = state.x*w, cy = h*0.2
        let fur = NSColor.white, outline = NSColor(white:0.80,alpha:1)
        if state.shelter {
            rectangle(cx-22,cy,4,h*0.6,.brown)
            rectangle(cx+18,cy,4,h*0.6,.brown)
            let roof = NSBezierPath()
            roof.move(to:NSPoint(x:cx-26,y:cy+h*0.58))
            roof.line(to:NSPoint(x:cx,y:cy+h*0.9))
            roof.line(to:NSPoint(x:cx+26,y:cy+h*0.58))
            roof.close(); NSColor.brown.setFill(); roof.fill()
        }
        for i in 0..<6 {
            let shift = CGFloat(i)
            oval(cx-state.direction*(15+shift*3.2),cy+8+sin(t+shift*0.2)*2+sin(shift*0.45)*9,11,9,i%2==0 ? fur : outline)
        }
        oval(cx-13,cy,27,state.sleeping ? 13 : 18,fur)
        let hx = cx+state.direction*7
        oval(hx-10,cy+9,19,16,fur)
        for side in [-1.0,1.0] {
            let ear = NSBezierPath()
            ear.move(to:NSPoint(x:hx+CGFloat(side)*3,y:cy+19))
            ear.line(to:NSPoint(x:hx+CGFloat(side)*8,y:cy+30))
            ear.line(to:NSPoint(x:hx+CGFloat(side)*9,y:cy+16))
            ear.close(); fur.setFill(); ear.fill()
            oval(hx+CGFloat(side)*4-2,cy+24,4,4,.systemPink)
            if state.sleeping {
                rectangle(hx+CGFloat(side)*4-3,cy+17,6,1.2,.darkGray)
            } else {
                oval(hx+CGFloat(side)*4-1,cy+16,2.3,3.5,.darkGray)
            }
        }
        oval(hx-1,cy+12,3,2,.systemPink)
        if state.sleeping {
            ("zZ" as NSString).draw(at:NSPoint(x:hx+14,y:cy+22),
                 withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.white])
        }
        let status = "PET \(state.pets)  FED \(state.feeds)  PLAY \(state.games)  CLEAN \(state.cleans)"
        (status as NSString).draw(at:NSPoint(x:w*0.24,y:h*0.77),
             withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:7,weight:.medium),
                             .foregroundColor:night ? NSColor.white : NSColor.black])
    }
    func handleDown(_ fraction: CGFloat) {
        let f = max(0,min(1,fraction))
        draggingBall = false
        // Hit test from left to right; poop and ball have priority.
        if let i = state.poop.firstIndex(where:{abs($0-f)<0.045}) {
            state.clean(i)
        } else if abs(state.ball-f)<0.04 {
            draggingBall = true; state.ballMoved(f,newGame:true)
        } else if abs(state.x-f)<0.075 {
            state.pet()
        } else {
            state.addSnack(f)
        }
        needsDisplay = true
    }
    func handleMove(_ fraction: CGFloat) {
        if draggingBall { state.ballMoved(fraction,newGame:false); needsDisplay = true }
    }
    func xFraction(_ event: NSEvent, _ phase: NSTouch.Phase) -> CGFloat? {
        // For direct Touch Bar touches, location(in:) is in local view coordinates.
        guard let touch = event.touches(matching: phase, in: self).first else { return nil }
        return touch.location(in:self).x / max(1,bounds.width)
    }
    override func touchesBegan(with event: NSEvent) {
        if let x = xFraction(event,.began) { handleDown(x) }
    }
    override func touchesMoved(with event: NSEvent) {
        if let x = xFraction(event,.moved) { handleMove(x) }
    }
    override func touchesEnded(with event: NSEvent) { draggingBall = false }
    override func touchesCancelled(with event: NSEvent) { draggingBall = false }
    override func mouseDown(with event: NSEvent) {
        handleDown(convert(event.locationInWindow,from:nil).x / max(1,bounds.width))
    }
    override func mouseDragged(with event: NSEvent) {
        handleMove(convert(event.locationInWindow,from:nil).x / max(1,bounds.width))
    }
    override func mouseUp(with event: NSEvent) { draggingBall = false }
}
final class PetApp: NSObject, NSApplicationDelegate, NSTouchBarDelegate {
    var bar: NSTouchBar?
    var status: NSStatusItem?
    var timer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        status?.button?.title = "CAT"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title:"Show cat",action:#selector(show),keyEquivalent:""))
        menu.addItem(NSMenuItem(title:"Quit TouchPET",action:#selector(quit),keyEquivalent:"q"))
        for item in menu.items { item.target = self }
        status?.menu = menu
        let b = NSTouchBar()
        b.delegate = self
        b.defaultItemIdentifiers = [NSTouchBarItem.Identifier("touchpet.canvas")]
        b.principalItemIdentifier = NSTouchBarItem.Identifier("touchpet.canvas")
        bar = b
        show()
        timer = Timer.scheduledTimer(withTimeInterval:1.0/20.0,repeats:true) { _ in
            PetState.shared.update()
        }
    }
    func touchBar(_ touchBar:NSTouchBar,makeItemForIdentifier id:NSTouchBarItem.Identifier)->NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier:id)
        item.view = PetCanvas(frame:NSRect(x:0,y:0,width:610,height:30))
        return item
    }
    @objc func show() { if let b = bar { _ = TouchPETPresentBar(b) } }
    @objc func quit() { if let b = bar { TouchPETDismissBar(b) }; NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = PetApp()
app.delegate = delegate
app.run()
