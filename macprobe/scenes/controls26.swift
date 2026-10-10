// SCENES: controls26
// AppKit APIs that only exist in the macOS 26 SDK: NSButton glass bezel at every
// control size, and NSGlassEffectView (regular and clear, with and without tint)
// over striped content. Kept in its own file because these are the calls most
// likely to need a correction after the first compile.
import AppKit

@MainActor
func scene_controls26(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    let w = ctx.titled("Controls26", 12, 40, 1000, 420)
    let content = DrawView(frame: NSRect(x: 0, y: 0, width: 1000, height: 380)) { r in
        paintStripes(r, width: 12, colors: [gray(0), gray(255)])
    }
    w.contentView = content
    let sizes: [(String, NSControl.ControlSize)] = [
        ("mini", .mini), ("small", .small), ("regular", .regular), ("large", .large), ("extraLarge", .extraLarge),
    ]
    var cells: [[String: Any]] = []
    for (ci, sz) in sizes.enumerated() {
        let b = NSButton(title: "Glass", target: nil, action: nil)
        b.bezelStyle = .glass
        b.controlSize = sz.1
        let ic = b.intrinsicContentSize
        b.frame = NSRect(x: CGFloat(30 + ci * 190), y: 30, width: max(ic.width, 60), height: max(ic.height, 20))
        content.addSubview(b)
        let p = NSButton(title: "Prominent", target: nil, action: nil)
        p.bezelStyle = .glass
        p.bezelColor = .controlAccentColor
        p.controlSize = sz.1
        let pc = p.intrinsicContentSize
        p.frame = NSRect(x: CGFloat(30 + ci * 190), y: 110, width: max(pc.width, 60), height: max(pc.height, 20))
        content.addSubview(p)
        cells.append(["row": "glass", "size": sz.0, "view": b, "intrinsic": [Double(ic.width), Double(ic.height)]])
        cells.append(["row": "glass-prominent", "size": sz.0, "view": p, "intrinsic": [Double(pc.width), Double(pc.height)]])
    }
    // NSGlassEffectView: regular, clear, regular tinted.
    let styles: [(String, NSGlassEffectView.Style, NSColor?)] = [
        ("regular", .regular, nil), ("clear", .clear, nil), ("tinted", .regular, NSColor.systemBlue),
    ]
    var glassViews: [(String, NSView)] = []
    for (i, s) in styles.enumerated() {
        let g = NSGlassEffectView(frame: NSRect(x: CGFloat(30 + i * 200), y: 200, width: 120, height: 64))
        g.cornerRadius = 20
        g.style = s.1
        g.tintColor = s.2
        content.addSubview(g)
        glassViews.append((s.0, g))
    }
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.5)
    var out: [[String: Any]] = []
    for c in cells {
        var d: [String: Any] = ["row": c["row"] ?? "", "size": c["size"] ?? "", "intrinsic": c["intrinsic"] ?? []]
        if let v = c["view"] as? NSView { d["frame"] = viewFrame(v) }
        out.append(d)
    }
    ctx.notes["cells"] = out
    var gv: [String: Any] = [:]
    for (n, v) in glassViews { gv[n] = viewFrame(v) }
    ctx.notes["glassViews"] = gv
    ctx.shot("page", windows: [("Controls26", w)])
}
