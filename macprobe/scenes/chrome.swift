// SCENES: chrome sidebar
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
    }
    let defs: [Def] = [
        Def(name: "plain", style: nil, full: false),
        Def(name: "unified", style: .unified, full: false),
        Def(name: "expanded", style: .expanded, full: false),
        Def(name: "unifiedCompact", style: .unifiedCompact, full: false),
        Def(name: "preference", style: .preference, full: false),
        Def(name: "fullsize", style: .unified, full: true),
    ]
    let colX: [CGFloat] = [12, 362, 712]
    let rowY: [CGFloat] = [48, 372]
    var wins: [(String, NSWindow)] = []
    for (i, d) in defs.enumerated() {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if d.full { style.insert(.fullSizeContentView) }
        let w = ctx.titled(d.name, colX[i % 3], rowY[i / 3], 300, 270, style: style)
        let full = d.full
        w.contentView = DrawView(frame: NSRect(x: 0, y: 0, width: 300, height: 240)) { r in
            if full {
                paintStripes(r, width: 16, colors: rainbow)
            } else {
                NSColor.windowBackgroundColor.setFill()
                r.fill()
            }
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
        w.orderFront(nil)
        wins.append((d.name, w))
    }
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.0)
    for (name, w) in wins {
        w.makeKeyAndOrderFront(nil)
        await ctx.pause(1.0)
        ctx.shot("w-\(name)", windows: [(name, w)])
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
func scene_sidebar(_ ctx: Ctx) async {
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
        paintStripes(r, width: 16, colors: rainbow)
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
    // Collapsed sidebar: shows how the toolbar and content reflow.
    sideItem.isCollapsed = true
    await ctx.pause(1.5)
    ctx.shot("split-collapsed", windows: [("split", w)])
}
