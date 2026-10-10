// SCENES: chrome sidebar toolbarglass
// Window chrome of macOS 26 (AppKit): titled window with and without a toolbar in
// each toolbar style, traffic lights, window shadow (per-window captures keep the
// alpha), and a split view with a sidebar. Run once normally and once with
// UIDesignRequiresCompatibility (variant "compat") for the pre-26 look.
import AppKit

@MainActor
final class TBDelegate: NSObject, NSToolbarDelegate {
    let ids: [NSToolbarItem.Identifier]
    init(_ ids: [NSToolbarItem.Identifier]) {
        self.ids = ids
        super.init()
    }
    @objc func noop(_ sender: Any?) {}
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { ids }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { ids }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier.rawValue == "search" {
            return NSSearchToolbarItem(itemIdentifier: itemIdentifier)
        }
        let symbols: [String: String] = ["add": "plus", "share": "square.and.arrow.up", "more": "ellipsis.circle", "tag": "tag"]
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.image = NSImage(systemSymbolName: symbols[itemIdentifier.rawValue] ?? "circle", accessibilityDescription: nil)
        item.label = itemIdentifier.rawValue.capitalized
        item.target = self
        item.action = #selector(noop(_:))
        return item
    }
}

@MainActor
func tbid(_ s: String) -> NSToolbarItem.Identifier { NSToolbarItem.Identifier(rawValue: s) }

@MainActor
func scene_chrome(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    struct Def {
        let name: String
        let style: NSWindow.ToolbarStyle?
        let full: Bool
        let width: CGFloat
        let x: CGFloat
        let top: CGFloat
    }
    // Wide enough that the toolbar items do not collapse into the overflow menu; no two
    // windows overlap, so every full-screen capture shows the key window unobscured.
    let defs: [Def] = [
        Def(name: "plain", style: nil, full: false, width: 330, x: 10, top: 40),
        Def(name: "expanded", style: .expanded, full: false, width: 330, x: 350, top: 40),
        Def(name: "preference", style: .preference, full: false, width: 330, x: 690, top: 40),
        Def(name: "unified", style: .unified, full: false, width: 480, x: 10, top: 270),
        Def(name: "fullsize", style: .unified, full: true, width: 480, x: 520, top: 270),
        Def(name: "unifiedCompact", style: .unifiedCompact, full: false, width: 480, x: 10, top: 500),
    ]
    var wins: [(String, NSWindow)] = []
    for d in defs {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if d.full { style.insert(.fullSizeContentView) }
        let w = ctx.titledContent(d.name, d.width, 150, style: style)
        let full = d.full
        w.contentView = DrawView(frame: NSRect(x: 0, y: 0, width: d.width, height: 150)) { r in
            if full {
                rgb(255, 149, 0).setFill()
            } else {
                NSColor.windowBackgroundColor.setFill()
            }
            r.fill()
        }
        if let st = d.style {
            let ids: [NSToolbarItem.Identifier] = [tbid("add"), tbid("share"), .space, tbid("more"), .flexibleSpace, tbid("search")]
            let del = TBDelegate(ids)
            ctx.keep.append(del)
            let tb = NSToolbar(identifier: "tb-\(d.name)")
            tb.delegate = del
            tb.displayMode = .iconOnly
            w.toolbar = tb
            w.toolbarStyle = st
        }
        w.setFrameTopLeftPoint(NSPoint(x: d.x, y: screenHeight() - d.top))
        w.orderFront(nil)
        wins.append((d.name, w))
    }
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.0)
    for (name, w) in wins {
        w.makeKeyAndOrderFront(nil)
        await ctx.pause(1.0)
        ctx.shot("w-\(name)", windows: [(name, w)])
        if name == "unified", let close = w.standardWindowButton(.closeButton) {
            // The pointer over the traffic lights makes their glyphs appear.
            pointerMove(to: centerOf(close))
            await ctx.pause(0.3)
            pointerMove(to: CGPoint(x: centerOf(close).x + 1, y: centerOf(close).y))
            await ctx.pause(0.8)
            ctx.shot("w-unified-hover-lights", windows: [(name, w)])
            pointerMove(to: CGPoint(x: 1000, y: 700))
        }
    }
    // The first window again, now that another window is key.
    ctx.shot("w-plain-inactive", windows: [wins[0]])
    for (name, w) in wins {
        if let frame = w.contentView?.superview { ctx.notes["tree-\(name)"] = ctx.dump(frame, maxDepth: 5) }
    }
}

@MainActor
final class SideData: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let items = ["Inbox", "Today", "Favorites", "Archive", "Trash"]
    let symbols = ["tray", "calendar", "star", "archivebox", "trash"]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: 180, height: 28))
        let iv = NSImageView(frame: NSRect(x: 6, y: 5, width: 18, height: 18))
        iv.image = NSImage(systemSymbolName: symbols[row], accessibilityDescription: nil)
        let tf = NSTextField(labelWithString: items[row])
        tf.frame = NSRect(x: 30, y: 5, width: 120, height: 17)
        cell.addSubview(iv)
        cell.addSubview(tf)
        cell.imageView = iv
        cell.textField = tf
        return cell
    }
}

@MainActor
final class FillBox {
    var stripes = true
}

@MainActor
func scene_sidebar(_ ctx: Ctx) async {
    let box = FillBox()
    ctx.keep.append(box)
    ctx.backdrop(gray: 192)
    let data = SideData()
    ctx.keep.append(data)
    let table = NSTableView()
    table.style = .sourceList
    table.headerView = nil
    let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
    col.width = 180
    table.addTableColumn(col)
    table.dataSource = data
    table.delegate = data
    table.reloadData()
    table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
    let scroll = NSScrollView()
    scroll.documentView = table
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = false
    let sideVC = NSViewController()
    sideVC.view = scroll
    let sideItem = NSSplitViewItem(sidebarWithViewController: sideVC)
    let mainVC = NSViewController()
    mainVC.view = DrawView(frame: NSRect(x: 0, y: 0, width: 600, height: 500)) { r in
        if box.stripes {
            paintStripes(r, width: 16, colors: rainbow)
        } else {
            rgb(255, 149, 0).setFill()
            r.fill()
        }
    }
    let mainItem = NSSplitViewItem(viewController: mainVC)
    let split = NSSplitViewController()
    split.addSplitViewItem(sideItem)
    split.addSplitViewItem(mainItem)
    let w = ctx.titled("split", 40, 60, 860, 560, style: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
    w.contentViewController = split
    let ids: [NSToolbarItem.Identifier] = [.toggleSidebar, .sidebarTrackingSeparator, tbid("add"), tbid("share"), .flexibleSpace, tbid("search")]
    let del = TBDelegate(ids)
    ctx.keep.append(del)
    let tb = NSToolbar(identifier: "tb-split")
    tb.delegate = del
    tb.displayMode = .iconOnly
    w.toolbar = tb
    w.setFrame(appKitRect(40, 60, 860, 560), display: true)
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.5)
    var rows: [[String: Double]] = []
    for r in 0..<data.items.count { rows.append(screenFrame(of: table.rect(ofRow: r), in: table)) }
    var side: [String: Any] = [:]
    side["min"] = Double(sideItem.minimumThickness)
    side["max"] = Double(sideItem.maximumThickness)
    side["view"] = viewFrame(sideVC.view)
    side["content"] = viewFrame(mainVC.view)
    side["rows"] = rows
    side["rowHeight"] = Double(table.rowHeight)
    ctx.notes["sidebar"] = side
    ctx.shot("split", windows: [("split", w)])
    if let frame = w.contentView?.superview { ctx.notes["tree-split"] = ctx.dump(frame, maxDepth: 6) }
    // Flat content: the sidebar's and toolbar's own outlines are easy to measure on it.
    box.stripes = false
    mainVC.view.needsDisplay = true
    await ctx.pause(1.2)
    ctx.shot("split-flat", windows: [("split", w)])
    box.stripes = true
    mainVC.view.needsDisplay = true
    // Collapsed sidebar: shows how the toolbar and content reflow.
    sideItem.isCollapsed = true
    await ctx.pause(1.5)
    ctx.shot("split-collapsed", windows: [("split", w)])
}

/// Toolbar glass (the platters behind the toolbar items) over four known backdrops that run
/// under the toolbar: 12 px black/white stripes and flat black, grey 128 and white.
@MainActor
func scene_toolbarglass(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    struct Spec {
        let name: String
        let level: Int
        let x: CGFloat
        let top: CGFloat
    }
    let specs: [Spec] = [
        Spec(name: "stripes", level: -1, x: 10, top: 40), Spec(name: "g000", level: 0, x: 520, top: 40),
        Spec(name: "g128", level: 128, x: 10, top: 250), Spec(name: "g255", level: 255, x: 520, top: 250),
    ]
    var wins: [(String, NSWindow)] = []
    for sp in specs {
        let w = ctx.titledContent(sp.name, 480, 150, style: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        let level = sp.level
        w.contentView = DrawView(frame: NSRect(x: 0, y: 0, width: 480, height: 150)) { r in
            if level < 0 {
                paintStripes(r, width: 12, colors: [gray(0), gray(255)])
            } else {
                gray(level).setFill()
                r.fill()
            }
        }
        let ids: [NSToolbarItem.Identifier] = [tbid("add"), tbid("share"), .space, tbid("more"), .flexibleSpace, tbid("search")]
        let del = TBDelegate(ids)
        ctx.keep.append(del)
        let tb = NSToolbar(identifier: "tb-\(sp.name)")
        tb.delegate = del
        tb.displayMode = .iconOnly
        w.toolbar = tb
        w.toolbarStyle = .unified
        w.setFrameTopLeftPoint(NSPoint(x: sp.x, y: screenHeight() - sp.top))
        w.orderFront(nil)
        wins.append((sp.name, w))
    }
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.0)
    for (name, w) in wins {
        w.makeKeyAndOrderFront(nil)
        await ctx.pause(1.0)
        ctx.shot("tb-\(name)", windows: [(name, w)])
        if let frame = w.contentView?.superview { ctx.notes["tree-\(name)"] = ctx.dump(frame, maxDepth: 6) }
    }
}
