// SCENES: states
// Control states on a flat window: rest, pressed (highlight), disabled, focus ring
// (first responder walked across the controls), selected text, pointer hover (the
// cursor is warped and a synthetic move posted; the JSON counts the move events
// that arrived), and the semantic system colors of the current appearance and
// accent. Run per accent with variant "accent-<n>" (run.sh sets AppleAccentColor)
// and with "fka" (Full Keyboard Access, which makes buttons show a focus ring).
import AppKit

@MainActor
final class MoveCounter {
    var moved = 0
    var entered = 0
}

@MainActor
func scene_states(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    let w = ctx.titled("States", 12, 40, 920, 380)
    w.acceptsMouseMovedEvents = true
    let content = DrawView(frame: NSRect(x: 0, y: 0, width: 920, height: 340)) { r in
        NSColor.windowBackgroundColor.setFill()
        r.fill()
    }
    w.contentView = content
    var views: [String: NSView] = [:]
    func add(_ name: String, _ v: NSView, _ x: CGFloat, _ y: CGFloat, width: CGFloat? = nil) {
        let ic = v.intrinsicContentSize
        let wd = width ?? (ic.width > 0 ? ic.width : 100)
        let h = ic.height > 0 ? ic.height : 22
        v.frame = NSRect(x: x, y: y, width: wd, height: h)
        content.addSubview(v)
        views[name] = v
    }
    func textField(_ s: String) -> NSTextField {
        let t = NSTextField(frame: .zero)
        t.stringValue = s
        t.isBezeled = true
        t.bezelStyle = .roundedBezel
        t.isEditable = true
        return t
    }
    func push(_ title: String) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }

    add("text", textField("Text"), 30, 30, width: 200)
    let search = NSSearchField(frame: .zero)
    search.stringValue = "Search"
    add("search", search, 260, 30, width: 200)
    let tdis = textField("Disabled")
    tdis.isEnabled = false
    add("text-disabled", tdis, 490, 30, width: 200)

    add("push", push("Button"), 30, 90)
    let pressed = push("Pressed")
    pressed.highlight(true)
    add("push-pressed", pressed, 150, 90)
    let pdis = push("Disabled")
    pdis.isEnabled = false
    add("push-disabled", pdis, 280, 90)
    let ptint = push("Tinted")
    ptint.bezelColor = .controlAccentColor
    add("push-tinted", ptint, 410, 90)
    let con = NSButton(checkboxWithTitle: "On", target: nil, action: nil)
    con.state = .on
    add("check-on", con, 520, 90)
    let coff = NSButton(checkboxWithTitle: "Off", target: nil, action: nil)
    add("check-off", coff, 600, 90)
    let cdis = NSButton(checkboxWithTitle: "Disabled", target: nil, action: nil)
    cdis.state = .on
    cdis.isEnabled = false
    add("check-disabled", cdis, 680, 90)

    let ron = NSButton(radioButtonWithTitle: "On", target: nil, action: nil)
    ron.state = .on
    add("radio-on", ron, 30, 150)
    let rdis = NSButton(radioButtonWithTitle: "Disabled", target: nil, action: nil)
    rdis.state = .on
    rdis.isEnabled = false
    add("radio-disabled", rdis, 110, 150)
    let son = NSSwitch()
    son.state = .on
    add("switch-on", son, 230, 150)
    let sdis = NSSwitch()
    sdis.state = .on
    sdis.isEnabled = false
    add("switch-disabled", sdis, 300, 150)
    let sl = NSSlider(value: 0.4, minValue: 0, maxValue: 1, target: nil, action: nil)
    add("slider", sl, 380, 150, width: 140)
    let sld = NSSlider(value: 0.4, minValue: 0, maxValue: 1, target: nil, action: nil)
    sld.isEnabled = false
    add("slider-disabled", sld, 550, 150, width: 140)

    let seg = NSSegmentedControl(labels: ["One", "Two", "Three"], trackingMode: .selectOne, target: nil, action: nil)
    seg.selectedSegment = 1
    add("segmented", seg, 30, 210)
    let pop = NSPopUpButton(frame: .zero, pullsDown: false)
    pop.addItems(withTitles: ["Option 1", "Option 2"])
    add("popup", pop, 250, 210)
    let popd = NSPopUpButton(frame: .zero, pullsDown: false)
    popd.addItems(withTitles: ["Disabled"])
    popd.isEnabled = false
    add("popup-disabled", popd, 400, 210)
    add("stepper", NSStepper(), 550, 210)
    let prog = NSProgressIndicator(frame: .zero)
    prog.style = .bar
    prog.isIndeterminate = false
    prog.doubleValue = 60
    add("progress", prog, 610, 210, width: 140)
    let lab = NSTextField(labelWithString: "Label text (selected text sample below)")
    add("label", lab, 30, 270, width: 300)

    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(1.5)
    w.makeFirstResponder(nil)
    await ctx.pause(0.5)
    var frames: [String: Any] = [:]
    for (n, v) in views { frames[n] = viewFrame(v) }
    ctx.notes["views"] = frames
    ctx.notes["colors"] = ctx.colorTable()
    ctx.shot("base")

    // Accent runs only need the base page, one focus ring and the selection.
    let short = ctx.variant.hasPrefix("accent")
    // Focus ring: first responder walked over the controls.
    for n in (short ? ["text"] : ["text", "search", "push", "check-on", "popup", "segmented", "slider"]) {
        guard let v = views[n] else { continue }
        w.makeFirstResponder(v)
        await ctx.pause(0.7)
        ctx.shot("focus-\(n)")
    }
    if let t = views["text"] as? NSTextField {
        w.makeFirstResponder(t)
        t.selectText(nil)
        await ctx.pause(0.7)
        ctx.shot("selected")
    }
    w.makeFirstResponder(nil)

    if short { return }
    // Hover.
    let counter = MoveCounter()
    ctx.keep.append(counter)
    let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered]) { e in
        MainActor.assumeIsolated {
            if e.type == .mouseMoved { counter.moved += 1 } else { counter.entered += 1 }
        }
        return e
    }
    if let m = monitor { ctx.keep.append(m as AnyObject) }
    var hover: [String: Any] = [:]
    for n in ["push", "check-on", "segmented", "popup", "slider"] {
        guard let v = views[n] else { continue }
        let p = v.convert(NSPoint(x: v.bounds.midX, y: v.bounds.midY), to: nil)
        let s = w.convertPoint(toScreen: p)
        let cg = CGPoint(x: s.x, y: screenHeight() - s.y)
        CGWarpMouseCursorPosition(cg)
        for dx in [0.0, 2.0, 0.0] {
            let pt = CGPoint(x: cg.x + CGFloat(dx), y: cg.y)
            if let ev = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pt, mouseButton: .left) {
                ev.post(tap: .cghidEventTap)
            }
            await ctx.pause(0.2)
        }
        await ctx.pause(0.6)
        let loc = NSEvent.mouseLocation
        var h: [String: Any] = [:]
        h["asked"] = ["x": Double(cg.x), "y": Double(cg.y)]
        h["got"] = ["x": Double(loc.x), "y": Double(screenHeight() - loc.y)]
        h["moved"] = counter.moved
        h["entered"] = counter.entered
        hover[n] = h
        ctx.shot("hover-\(n)")
    }
    ctx.notes["hover"] = hover
}
