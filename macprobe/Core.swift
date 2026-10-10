// Shared plumbing of the macOS Liquid Glass probe (AppKit + Foundation only, no SwiftUI).
//
// One process = one scene in one appearance (see run.sh). A scene is an async
// function `scene_<name>(_ ctx: Ctx)` in scenes/<file>.swift; the file's first
// line `// SCENES: a b` lists the scene names it defines (build.sh generates the
// entry point per file, so a scene file that does not compile only loses itself).
//
// Coordinates written to JSON are SCREEN pixels with the origin at the top-left
// (the hosted runner's screen is 1024 x 768 at scale 1.0, so 1 pt = 1 px), the
// same convention as the PNGs from `screencapture`.
import AppKit
import Foundation

typealias SceneFn = @MainActor (Ctx) async -> Void
var sceneRegistry: [String: SceneFn] = [:]

/// Borderless windows cannot become key by default; glass in a window that is not
/// key can look different, so the probe's windows opt in.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// A view that paints itself with a closure (flipped by default: origin top-left).
final class DrawView: NSView {
    private let painter: (NSRect) -> Void
    private let flip: Bool
    init(frame: NSRect, flipped: Bool = true, painter: @escaping (NSRect) -> Void) {
        self.painter = painter
        self.flip = flipped
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override var isFlipped: Bool { flip }
    override func draw(_ dirtyRect: NSRect) { painter(bounds) }
}

func gray(_ v: Int) -> NSColor {
    let c = CGFloat(v) / 255
    return NSColor(srgbRed: c, green: c, blue: c, alpha: 1)
}

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}

func q(_ v: CGFloat) -> Double { (Double(v) * 100).rounded() / 100 }

/// Turn anything into JSON-safe Foundation values.
func sanitize(_ v: Any) -> Any {
    switch v {
    case let d as [String: Any]: return d.mapValues { sanitize($0) }
    case let a as [Any]: return a.map { sanitize($0) }
    case let s as String: return s
    case let b as Bool: return b
    case let i as Int: return i
    case let i as Int32: return Int(i)
    case let f as CGFloat: return f.isFinite ? Double(f) : 0.0
    case let d as Double: return d.isFinite ? d : 0.0
    default: return String(describing: v)
    }
}

@MainActor func screenHeight() -> CGFloat { NSScreen.screens[0].frame.height }

/// Rect from top-left screen pixels to AppKit (bottom-left origin) screen coordinates.
@MainActor func appKitRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: screenHeight() - y - h, width: w, height: h)
}

/// AppKit screen rect to the JSON form {x, y, w, h} (top-left origin).
@MainActor func topLeft(_ r: NSRect) -> [String: Double] {
    ["x": q(r.minX), "y": q(screenHeight() - r.maxY), "w": q(r.width), "h": q(r.height)]
}

@MainActor func screenRect(of v: NSView) -> NSRect {
    guard let w = v.window else { return .zero }
    return w.convertToScreen(v.convert(v.bounds, to: nil))
}

@MainActor func viewFrame(_ v: NSView) -> [String: Double] { topLeft(screenRect(of: v)) }

/// Vertical stripes of `width` px cycling through `colors`, starting at r.minX.
func paintStripes(_ r: NSRect, width: CGFloat, colors: [NSColor]) {
    var x = r.minX
    var i = 0
    while x < r.maxX {
        colors[i % colors.count].setFill()
        NSRect(x: x, y: r.minY, width: min(width, r.maxX - x), height: r.height).fill()
        x += width
        i += 1
    }
}

let rainbow: [NSColor] = [
    rgb(255, 59, 48), rgb(255, 149, 0), rgb(255, 204, 0), rgb(52, 199, 89),
    rgb(0, 122, 255), rgb(175, 82, 222), rgb(255, 45, 85), rgb(0, 199, 190),
]

@MainActor func screenFrame(of rect: NSRect, in v: NSView) -> [String: Double] {
    guard let w = v.window else { return [:] }
    return topLeft(w.convertToScreen(v.convert(rect, to: nil)))
}

@discardableResult
func runTool(_ path: String, _ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    do { try p.run() } catch { return -1 }
    p.waitUntilExit()
    return p.terminationStatus
}

/// Window-server list restricted to this process (no actor state: callable anywhere).
func cgWindowsOfProcess() -> [[String: Any]] {
    let pid = Int(ProcessInfo.processInfo.processIdentifier)
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
    var res: [[String: Any]] = []
    for w in list {
        guard let opid = (w["kCGWindowOwnerPID"] as? NSNumber)?.intValue, opid == pid else { continue }
        var d: [String: Any] = [:]
        d["number"] = (w["kCGWindowNumber"] as? NSNumber)?.intValue ?? -1
        d["layer"] = (w["kCGWindowLayer"] as? NSNumber)?.intValue ?? -1
        d["alpha"] = (w["kCGWindowAlpha"] as? NSNumber)?.doubleValue ?? -1.0
        d["name"] = (w["kCGWindowName"] as? String) ?? ""
        if let b = w["kCGWindowBounds"] as? NSDictionary, let r = CGRect(dictionaryRepresentation: b as CFDictionary) {
            d["bounds"] = ["x": q(r.minX), "y": q(r.minY), "w": q(r.width), "h": q(r.height)]
        }
        res.append(d)
    }
    return res
}

/// Menu tracking, modal alerts and similar calls block until the user dismisses
/// them. Called from inside the scene's own task they would block the main queue
/// that is running it (blocks scheduled with ctx.later then never run), so the
/// blocking call is made from a run-loop timer instead: the task is suspended while
/// it blocks and the main queue stays free. Returns after the blocking call returns.
@MainActor
func runBlocking(_ body: @escaping @MainActor () -> Void) async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        let t = Timer(timeInterval: 0.05, repeats: false) { _ in
            MainActor.assumeIsolated { body() }
            cont.resume()
        }
        RunLoop.main.add(t, forMode: .common)
    }
}

/// Synthetic pointer events (the runner lets the process post them).
@MainActor
func pointerMove(to p: CGPoint) {
    CGWarpMouseCursorPosition(p)
    if let ev = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left) {
        ev.post(tap: .cghidEventTap)
    }
}

@MainActor
func pointerButton(at p: CGPoint, down: Bool) {
    let type: CGEventType = down ? .leftMouseDown : .leftMouseUp
    if let ev = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left) {
        ev.setIntegerValueField(.mouseEventClickState, value: 1)
        ev.post(tap: .cghidEventTap)
    }
}

/// Screen centre (top-left origin, CGEvent coordinates) of a view.
@MainActor
func centerOf(_ v: NSView) -> CGPoint {
    let r = screenRect(of: v)
    return CGPoint(x: r.midX, y: screenHeight() - r.midY)
}

@MainActor
final class Ctx {
    let scene: String
    let appearance: String
    let variant: String
    let out: String
    var tag: String { "\(scene)-\(appearance)-\(variant)" }
    var shots: [[String: Any]] = []
    var notes: [String: Any] = [:]
    var tracked: [(String, NSWindow)] = []
    var keep: [AnyObject] = []

    init(scene: String, appearance: String, variant: String, out: String) {
        self.scene = scene
        self.appearance = appearance
        self.variant = variant
        self.out = out
    }

    // MARK: timing

    func pause(_ sec: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(sec * 1_000_000_000))
    }

    /// Run `f` on the main queue after `sec` (works while a menu is being tracked).
    func later(_ sec: Double, _ f: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + sec) {
            MainActor.assumeIsolated { f() }
        }
    }

    // MARK: windows

    func track(_ name: String, _ w: NSWindow) {
        tracked.removeAll { $0.0 == name }
        tracked.append((name, w))
        keep.append(w)
    }

    /// Full-screen opaque grey window under everything the scene shows.
    @discardableResult
    func backdrop(gray v: Int) -> NSWindow {
        let r = appKitRect(0, 0, 1024, 768)
        let w = NSWindow(contentRect: r, styleMask: [.borderless], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.hasShadow = false
        w.isOpaque = true
        w.backgroundColor = gray(v)
        w.setFrame(r, display: true)
        w.orderFront(nil)
        keep.append(w)
        return w
    }

    /// Titled window with the given OUTER frame in top-left screen pixels.
    func titled(_ name: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]) -> NSWindow {
        let win = NSWindow(contentRect: appKitRect(x, y, w, h), styleMask: style, backing: .buffered, defer: false)
        win.title = name
        win.isReleasedWhenClosed = false
        win.setFrame(appKitRect(x, y, w, h), display: false)
        track(name, win)
        return win
    }

    /// Titled window with the given CONTENT size; the caller positions it with
    /// setFrameTopLeftPoint after adding a toolbar (which makes the frame taller).
    func titledContent(_ name: String, _ cw: CGFloat, _ ch: CGFloat,
                       style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]) -> NSWindow {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: cw, height: ch), styleMask: style, backing: .buffered, defer: false)
        win.title = name
        win.isReleasedWhenClosed = false
        track(name, win)
        return win
    }

    /// Borderless key-capable window at the exact frame (top-left screen pixels).
    func borderless(_ name: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                    opaque: Bool, shadow: Bool = false) -> NSWindow {
        let r = appKitRect(x, y, w, h)
        let win = KeyWindow(contentRect: r, styleMask: [.borderless], backing: .buffered, defer: false)
        win.isReleasedWhenClosed = false
        win.hasShadow = shadow
        win.isOpaque = opaque
        if !opaque { win.backgroundColor = .clear }
        win.setFrame(r, display: false)
        track(name, win)
        return win
    }

    // MARK: description of windows and views

    func windowInfo(_ w: NSWindow) -> [String: Any] {
        var d: [String: Any] = [
            "number": w.windowNumber,
            "frame": topLeft(w.frame),
            "isKey": w.isKeyWindow,
            "isMain": w.isMainWindow,
            "level": w.level.rawValue,
            "title": w.title,
            "contentLayout": topLeft(w.convertToScreen(w.contentLayoutRect)),
        ]
        if let cv = w.contentView { d["contentView"] = viewFrame(cv) }
        let kinds: [(String, NSWindow.ButtonType)] = [("close", .closeButton), ("mini", .miniaturizeButton), ("zoom", .zoomButton)]
        for (n, t) in kinds {
            if let b = w.standardWindowButton(t) { d["btn_" + n] = viewFrame(b) }
        }
        return d
    }

    /// Class names and screen frames of a view tree (private AppKit classes included:
    /// that is the point, it shows what the system builds for a toolbar or sidebar).
    func dump(_ v: NSView, maxDepth: Int = 5, limit: Int = 400) -> [String: Any] {
        var count = 0
        func rec(_ v: NSView, _ depth: Int) -> [String: Any] {
            count += 1
            var d: [String: Any] = ["class": String(describing: type(of: v)), "frame": viewFrame(v), "hidden": v.isHidden]
            if depth < maxDepth {
                var kids: [[String: Any]] = []
                for s in v.subviews {
                    if count >= limit { break }
                    kids.append(rec(s, depth + 1))
                }
                if !kids.isEmpty { d["children"] = kids }
            }
            return d
        }
        return rec(v, 0)
    }

    /// Windows of this process as the window server sees them (menus, popovers,
    /// tooltips, sheets included): number, layer, bounds, alpha.
    func cgWindows() -> [[String: Any]] { cgWindowsOfProcess() }

    // MARK: capture

    /// Full-screen capture (+ optional per-window captures) and a record of every
    /// tracked window's frame at this moment.
    func shot(_ name: String, windows: [(String, NSWindow)] = [], extra: [String: Any] = [:]) {
        let base = "\(out)/\(tag)-\(name)"
        let status = runTool("/usr/sbin/screencapture", ["-x", base + ".png"])
        var rec: [String: Any] = ["name": name, "file": "\(tag)-\(name).png", "status": Int(status)]
        var wins: [String: Any] = [:]
        for (n, w) in tracked { wins[n] = windowInfo(w) }
        rec["windows"] = wins
        rec["cg"] = cgWindows()
        for (n, w) in windows {
            let st = runTool("/usr/sbin/screencapture", ["-x", "-l", "\(w.windowNumber)", base + "-win-\(n).png"])
            rec["win_\(n)"] = "\(tag)-\(name)-win-\(n).png"
            rec["win_\(n)_status"] = Int(st)
        }
        for (k, v) in extra { rec[k] = v }
        shots.append(rec)
        print("shot \(name) status \(status)")
        fflush(stdout)
        flush()
    }

    /// Write the JSON so far (a hang or crash later still leaves the shots taken).
    func flush() {
        var root: [String: Any] = [
            "schema_version": 1, "scene": scene, "appearance": appearance, "variant": variant,
            "shots": shots, "notes": notes,
        ]
        root["screens"] = screens()
        let obj = sanitize(root)
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "\(out)/\(tag).json"), options: .atomic)
        }
    }

    // MARK: environment

    func flags() -> [String: Any] {
        let ws = NSWorkspace.shared
        var d: [String: Any] = [
            "reduceTransparency": ws.accessibilityDisplayShouldReduceTransparency,
            "increaseContrast": ws.accessibilityDisplayShouldIncreaseContrast,
            "reduceMotion": ws.accessibilityDisplayShouldReduceMotion,
            "differentiateWithoutColor": ws.accessibilityDisplayShouldDifferentiateWithoutColor,
            "invertColors": ws.accessibilityDisplayShouldInvertColors,
            "effectiveAppearance": NSApp.effectiveAppearance.name.rawValue,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
        ]
        let ud = UserDefaults.standard
        d["AppleAccentColor"] = ud.object(forKey: "AppleAccentColor").map { String(describing: $0) } ?? "unset"
        d["AppleKeyboardUIMode"] = ud.object(forKey: "AppleKeyboardUIMode").map { String(describing: $0) } ?? "unset"
        d["UIDesignRequiresCompatibility"] = (Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool) ?? false
        return d
    }

    func screens() -> [[String: Any]] {
        NSScreen.screens.map { (s: NSScreen) -> [String: Any] in
            var d: [String: Any] = [:]
            d["frame"] = topLeft(s.frame)
            d["visibleFrame"] = topLeft(s.visibleFrame)
            d["scale"] = Double(s.backingScaleFactor)
            d["colorSpace"] = s.colorSpace?.localizedName ?? "unknown"
            return d
        }
    }

    /// Semantic system colors as sRGB hex in the current appearance.
    func colorTable() -> [String: String] {
        let list: [(String, NSColor)] = [
            ("controlAccentColor", .controlAccentColor),
            ("selectedContentBackgroundColor", .selectedContentBackgroundColor),
            ("unemphasizedSelectedContentBackgroundColor", .unemphasizedSelectedContentBackgroundColor),
            ("selectedTextBackgroundColor", .selectedTextBackgroundColor),
            ("keyboardFocusIndicatorColor", .keyboardFocusIndicatorColor),
            ("windowBackgroundColor", .windowBackgroundColor),
            ("controlBackgroundColor", .controlBackgroundColor),
            ("controlColor", .controlColor),
            ("textBackgroundColor", .textBackgroundColor),
            ("underPageBackgroundColor", .underPageBackgroundColor),
            ("labelColor", .labelColor),
            ("secondaryLabelColor", .secondaryLabelColor),
            ("tertiaryLabelColor", .tertiaryLabelColor),
            ("quaternaryLabelColor", .quaternaryLabelColor),
            ("placeholderTextColor", .placeholderTextColor),
            ("separatorColor", .separatorColor),
            ("gridColor", .gridColor),
            ("linkColor", .linkColor),
            ("systemRed", .systemRed), ("systemOrange", .systemOrange), ("systemYellow", .systemYellow),
            ("systemGreen", .systemGreen), ("systemMint", .systemMint), ("systemTeal", .systemTeal),
            ("systemCyan", .systemCyan), ("systemBlue", .systemBlue), ("systemIndigo", .systemIndigo),
            ("systemPurple", .systemPurple), ("systemPink", .systemPink), ("systemBrown", .systemBrown),
            ("systemGray", .systemGray),
        ]
        var res: [String: String] = [:]
        for (n, c) in list { res[n] = hex(c) }
        return res
    }

    func hex(_ c: NSColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            if let s = c.usingColorSpace(.sRGB) { s.getRed(&r, green: &g, blue: &b, alpha: &a) }
        }
        return String(format: "#%02X%02X%02X@%.2f", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()), Double(a))
    }

    // MARK: lifecycle

    func begin() async {
        // The watchdog must not depend on the main queue (a blocked menu loop would starve it).
        DispatchQueue.global().asyncAfter(deadline: .now() + 100) {
            fputs("watchdog: scene still running after 100 s
", stderr)
            exit(3)
        }
        await pause(1.5)
        notes["flags"] = flags()
        notes["screens"] = screens()
    }

    func finish() {
        flush()
        FileManager.default.createFile(atPath: "\(out)/\(tag).done", contents: Data())
        print("done \(tag)")
        fflush(stdout)
        exit(0)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let ctx: Ctx
    init(ctx: Ctx) {
        self.ctx = ctx
        super.init()
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.appearance = NSAppearance(named: ctx.appearance == "dark" ? .darkAqua : .aqua)
        NSApp.activate(ignoringOtherApps: true)
        let c = ctx
        Task { @MainActor in
            await c.begin()
            if let fn = sceneRegistry[c.scene] {
                await fn(c)
            } else {
                c.notes["error"] = "unknown scene \(c.scene)"
            }
            c.finish()
        }
    }
}

@MainActor
func runApp() {
    var scene = "none", appearance = "light", variant = "normal", out = "."
    let a = CommandLine.arguments
    var i = 1
    while i + 1 < a.count {
        switch a[i] {
        case "--scene": scene = a[i + 1]
        case "--appearance": appearance = a[i + 1]
        case "--variant": variant = a[i + 1]
        case "--out": out = a[i + 1]
        default: break
        }
        i += 2
    }
    let ctx = Ctx(scene: scene, appearance: appearance, variant: variant, out: out)
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let d = AppDelegate(ctx: ctx)
    app.delegate = d
    app.run()
}
