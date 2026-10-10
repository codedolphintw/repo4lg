// SCENES: controls
// AppKit controls at every NSControl.ControlSize (mini, small, regular, large,
// extraLarge) in a fixed grid: rows = control, columns = size. The JSON carries
// each control's frame, intrinsic size and alignment insets; the PNG is measured
// for the visible extent (tools/measure_lg_macos.py).
import AppKit

struct CtlRow {
    let name: String
    let width: CGFloat?
    let make: @MainActor () -> NSView
}

@MainActor
func ctlSetSize(_ v: NSView, _ cs: NSControl.ControlSize) {
    if let c = v as? NSControl {
        c.controlSize = cs
    } else if let p = v as? NSProgressIndicator {
        p.controlSize = cs
    }
}

@MainActor
func ctlRowsA() -> [CtlRow] {
    [
        CtlRow(name: "push", width: nil) {
            let b = NSButton(title: "Button", target: nil, action: nil)
            b.bezelStyle = .rounded
            return b
        },
        CtlRow(name: "push-tinted", width: nil) {
            let b = NSButton(title: "Button", target: nil, action: nil)
            b.bezelStyle = .rounded
            b.bezelColor = .controlAccentColor
            return b
        },
        CtlRow(name: "checkbox-on", width: nil) {
            let b = NSButton(checkboxWithTitle: "Check", target: nil, action: nil)
            b.state = .on
            return b
        },
        CtlRow(name: "checkbox-off", width: nil) {
            let b = NSButton(checkboxWithTitle: "Check", target: nil, action: nil)
            b.state = .off
            return b
        },
        CtlRow(name: "radio-on", width: nil) {
            let b = NSButton(radioButtonWithTitle: "Radio", target: nil, action: nil)
            b.state = .on
            return b
        },
        CtlRow(name: "radio-off", width: nil) {
            let b = NSButton(radioButtonWithTitle: "Radio", target: nil, action: nil)
            b.state = .off
            return b
        },
        CtlRow(name: "switch-on", width: nil) {
            let s = NSSwitch()
            s.state = .on
            return s
        },
        CtlRow(name: "switch-off", width: nil) {
            let s = NSSwitch()
            s.state = .off
            return s
        },
    ]
}

@MainActor
func ctlRowsB() -> [CtlRow] {
    [
        CtlRow(name: "segmented", width: nil) {
            let s = NSSegmentedControl(labels: ["One", "Two"], trackingMode: .selectOne, target: nil, action: nil)
            s.selectedSegment = 1
            return s
        },
        CtlRow(name: "slider", width: 140) {
            NSSlider(value: 0.4, minValue: 0, maxValue: 1, target: nil, action: nil)
        },
        CtlRow(name: "slider-ticks", width: 140) {
            let s = NSSlider(value: 0.4, minValue: 0, maxValue: 1, target: nil, action: nil)
            s.numberOfTickMarks = 5
            return s
        },
        CtlRow(name: "stepper", width: nil) {
            let s = NSStepper()
            s.minValue = 0
            s.maxValue = 10
            s.doubleValue = 3
            return s
        },
        CtlRow(name: "textfield", width: 140) {
            let t = NSTextField(frame: .zero)
            t.stringValue = "Text"
            t.isBezeled = true
            t.bezelStyle = .roundedBezel
            t.isEditable = true
            return t
        },
        CtlRow(name: "searchfield", width: 140) {
            let t = NSSearchField(frame: .zero)
            t.stringValue = "Search"
            return t
        },
        CtlRow(name: "popup", width: nil) {
            let p = NSPopUpButton(frame: .zero, pullsDown: false)
            p.addItems(withTitles: ["Option 1", "Option 2", "Option 3"])
            return p
        },
        CtlRow(name: "progress", width: 140) {
            let p = NSProgressIndicator(frame: .zero)
            p.style = .bar
            p.isIndeterminate = false
            p.minValue = 0
            p.maxValue = 100
            p.doubleValue = 60
            return p
        },
    ]
}

@MainActor
func ctlBuildPage(_ w: NSWindow, rows: [CtlRow], sizes: [(String, NSControl.ControlSize)]) -> [(String, String, NSView)] {
    let content = DrawView(frame: NSRect(x: 0, y: 0, width: 1000, height: 552)) { r in
        NSColor.windowBackgroundColor.setFill()
        r.fill()
    }
    w.contentView = content
    var made: [(String, String, NSView)] = []
    for (ri, row) in rows.enumerated() {
        let rowY = CGFloat(20 + ri * 64)
        let label = NSTextField(labelWithString: row.name)
        label.frame = NSRect(x: 10, y: rowY + 24, width: 130, height: 17)
        content.addSubview(label)
        for (ci, sz) in sizes.enumerated() {
            let v = row.make()
            ctlSetSize(v, sz.1)
            var s = v.intrinsicContentSize
            if let fw = row.width { s.width = fw }
            if s.width < 0 { s.width = 100 }
            if s.height < 0 { s.height = 22 }
            v.frame = NSRect(x: CGFloat(150 + ci * 170), y: rowY + ((64 - s.height) / 2).rounded(), width: s.width, height: s.height)
            content.addSubview(v)
            made.append((row.name, sz.0, v))
        }
    }
    return made
}

@MainActor
func ctlRecord(_ made: [(String, String, NSView)]) -> [[String: Any]] {
    var cells: [[String: Any]] = []
    for (name, size, v) in made {
        var d: [String: Any] = ["row": name, "size": size, "frame": viewFrame(v), "class": String(describing: type(of: v))]
        let ic = v.intrinsicContentSize
        d["intrinsic"] = [Double(ic.width), Double(ic.height)]
        let fs = v.fittingSize
        d["fitting"] = [Double(fs.width), Double(fs.height)]
        let ai = v.alignmentRectInsets
        d["insets"] = [Double(ai.top), Double(ai.left), Double(ai.bottom), Double(ai.right)]
        if let c = v as? NSControl {
            d["controlSize"] = Int(c.controlSize.rawValue)
            if let f = c.font { d["font"] = Double(f.pointSize) }
        }
        cells.append(d)
    }
    return cells
}

@MainActor
func scene_controls(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    let sizes: [(String, NSControl.ControlSize)] = [
        ("mini", .mini), ("small", .small), ("regular", .regular), ("large", .large), ("extraLarge", .extraLarge),
    ]
    let w = ctx.titled("Controls", 12, 36, 1000, 592)
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    let a = ctlBuildPage(w, rows: ctlRowsA(), sizes: sizes)
    await ctx.pause(1.2)
    ctx.notes["cells-A"] = ctlRecord(a)
    ctx.shot("page-a", windows: [("Controls", w)])
    let b = ctlBuildPage(w, rows: ctlRowsB(), sizes: sizes)
    await ctx.pause(1.2)
    ctx.notes["cells-B"] = ctlRecord(b)
    ctx.shot("page-b", windows: [("Controls", w)])
}
