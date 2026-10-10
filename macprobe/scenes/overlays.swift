// SCENES: overlays
// Menus, pop-up button menu, popover, tooltip, sheet and alert (sheet and modal).
// Menu tracking blocks the calling code, so the capture is scheduled first with
// ctx.later and cancels the tracking when done. Window frames of menus, popovers
// and tooltips come from the window server list written by Ctx.shot ("cg").
import AppKit

@MainActor
final class MenuTarget: NSObject {
    @objc func noop(_ sender: Any?) {}
}

@MainActor
func ovItem(_ t: MenuTarget, _ title: String, key: String = "", symbol: String? = nil,
            enabled: Bool = true, state: NSControl.StateValue = .off) -> NSMenuItem {
    let it = NSMenuItem(title: title, action: #selector(MenuTarget.noop(_:)), keyEquivalent: key)
    it.target = t
    it.isEnabled = enabled
    it.state = state
    if let s = symbol { it.image = NSImage(systemSymbolName: s, accessibilityDescription: nil) }
    return it
}

@MainActor
func ovMakeMenu(_ t: MenuTarget) -> NSMenu {
    let m = NSMenu(title: "Context")
    m.autoenablesItems = false
    m.addItem(ovItem(t, "New", key: "n", symbol: "doc"))
    m.addItem(ovItem(t, "Open", key: "o", symbol: "folder"))
    m.addItem(NSMenuItem.separator())
    let share = ovItem(t, "Share", symbol: "square.and.arrow.up")
    let sub = NSMenu(title: "Share")
    sub.autoenablesItems = false
    sub.addItem(ovItem(t, "Mail"))
    sub.addItem(ovItem(t, "Messages"))
    share.submenu = sub
    m.addItem(share)
    m.addItem(ovItem(t, "Checked", state: .on))
    m.addItem(ovItem(t, "Disabled", enabled: false))
    m.addItem(NSMenuItem.separator())
    m.addItem(ovItem(t, "Delete", symbol: "trash"))
    return m
}

@MainActor
func ovLabel(_ s: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, bold: Bool = false) -> NSTextField {
    let l = NSTextField(labelWithString: s)
    l.frame = NSRect(x: x, y: y, width: w, height: 17)
    if bold { l.font = NSFont.boldSystemFont(ofSize: 13) }
    return l
}

@MainActor
func ovPanelContent(_ w: CGFloat, _ h: CGFloat, _ title: String) -> NSView {
    let v = DrawView(frame: NSRect(x: 0, y: 0, width: w, height: h)) { _ in }
    v.addSubview(ovLabel(title, 20, 20, w - 40, bold: true))
    v.addSubview(ovLabel("Some explanatory text.", 20, 46, w - 40))
    let c = NSButton(checkboxWithTitle: "Option", target: nil, action: nil)
    c.frame = NSRect(x: 20, y: 76, width: 120, height: 18)
    v.addSubview(c)
    let b1 = NSButton(title: "Cancel", target: nil, action: nil)
    b1.frame = NSRect(x: w - 180, y: h - 48, width: 76, height: 28)
    let b2 = NSButton(title: "OK", target: nil, action: nil)
    b2.frame = NSRect(x: w - 96, y: h - 48, width: 76, height: 28)
    b2.keyEquivalent = "\r"
    v.addSubview(b1)
    v.addSubview(b2)
    return v
}

@MainActor
func scene_overlays(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    let t = MenuTarget()
    ctx.keep.append(t)
    let host = ctx.titled("host", 40, 70, 720, 460)
    let content = DrawView(frame: NSRect(x: 0, y: 0, width: 720, height: 420)) { r in
        NSColor.windowBackgroundColor.setFill()
        r.fill()
    }
    host.contentView = content
    let btn = NSButton(title: "Button", target: nil, action: nil)
    btn.frame = NSRect(x: 40, y: 40, width: 100, height: 28)
    btn.toolTip = "Tooltip text for the button"
    let popup = NSPopUpButton(frame: NSRect(x: 180, y: 40, width: 140, height: 28), pullsDown: false)
    popup.addItems(withTitles: ["Option 1", "Option 2", "Option 3"])
    let field = NSTextField(frame: NSRect(x: 360, y: 42, width: 200, height: 24))
    field.stringValue = "Text"
    content.addSubview(btn)
    content.addSubview(popup)
    content.addSubview(field)
    host.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(1.5)
    ctx.shot("host")

    // 1. Context menu.
    let m = ovMakeMenu(t)
    ctx.later(1.3) {
        ctx.shot("menu")
        m.cancelTracking()
    }
    m.popUp(positioning: nil, at: NSPoint(x: 60, y: 140), in: content)
    await ctx.pause(0.8)

    // 2. Pop-up button's own menu.
    ctx.later(1.3) {
        ctx.shot("popup-open")
        popup.menu?.cancelTracking()
    }
    popup.performClick(nil)
    await ctx.pause(0.8)

    // 3. Popover.
    let pop = NSPopover()
    pop.behavior = .applicationDefined
    pop.animates = false
    let pvc = NSViewController()
    pvc.view = ovPanelContent(260, 150, "Popover title")
    pop.contentViewController = pvc
    pop.contentSize = NSSize(width: 260, height: 150)
    pop.show(relativeTo: btn.bounds, of: btn, preferredEdge: .maxY)
    await ctx.pause(1.5)
    ctx.shot("popover")
    pop.close()
    await ctx.pause(0.8)

    // 4. Sheet.
    let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    sheet.isReleasedWhenClosed = false
    sheet.contentView = ovPanelContent(420, 200, "Sheet title")
    ctx.track("sheet", sheet)
    host.beginSheet(sheet, completionHandler: nil)
    await ctx.pause(1.5)
    ctx.shot("sheet", windows: [("sheet", sheet)])
    host.endSheet(sheet)
    sheet.orderOut(nil)
    await ctx.pause(1.0)

    // 5. Alert as a sheet.
    let alert = NSAlert()
    alert.messageText = "Alert title"
    alert.informativeText = "Informative text of the alert."
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning
    ctx.track("alert", alert.window)
    alert.beginSheetModal(for: host, completionHandler: nil)
    await ctx.pause(1.5)
    ctx.shot("alert-sheet", windows: [("alert", alert.window)])
    host.endSheet(alert.window)
    alert.window.orderOut(nil)
    await ctx.pause(1.0)

    // 6. Alert as an app-modal window.
    let a2 = NSAlert()
    a2.messageText = "Alert title"
    a2.informativeText = "Informative text of the alert."
    a2.addButton(withTitle: "OK")
    a2.addButton(withTitle: "Cancel")
    ctx.track("alert-modal", a2.window)
    ctx.later(1.5) {
        ctx.shot("alert-modal", windows: [("alert-modal", a2.window)])
        NSApp.abortModal()
    }
    _ = a2.runModal()
    await ctx.pause(1.0)

    // 7. Tooltip: needs the pointer over the button. Warping the cursor and posting a
    //    synthetic move is tried; the JSON records where the pointer ended up.
    host.makeKeyAndOrderFront(nil)
    await ctx.pause(0.5)
    let inWindow = btn.convert(NSPoint(x: 50, y: 14), to: nil)
    let onScreen = host.convertPoint(toScreen: inWindow)
    let cg = CGPoint(x: onScreen.x, y: screenHeight() - onScreen.y)
    CGWarpMouseCursorPosition(cg)
    if let ev = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: cg, mouseButton: .left) {
        ev.post(tap: .cghidEventTap)
    }
    await ctx.pause(0.3)
    let cg2 = CGPoint(x: cg.x + 2, y: cg.y + 1)
    if let ev = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: cg2, mouseButton: .left) {
        ev.post(tap: .cghidEventTap)
    }
    await ctx.pause(3.0)
    let loc = NSEvent.mouseLocation
    var mouse: [String: Any] = [:]
    mouse["asked"] = ["x": Double(cg.x), "y": Double(cg.y)]
    mouse["got"] = ["x": Double(loc.x), "y": Double(screenHeight() - loc.y)]
    ctx.notes["mouse"] = mouse
    ctx.shot("tooltip")
}
