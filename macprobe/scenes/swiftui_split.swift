// SCENES: sidebar_swiftui
// SwiftUI NavigationSplitView + .toolbar in a titled window: the sidebar, toolbar
// and detail the way a SwiftUI app gets them on macOS 26 (floating glass sidebar,
// glass toolbar items). The detail is striped so the glass has something to blur.
import SwiftUI
import AppKit

struct SplitStripes: View {
    var body: some View {
        Canvas { c, size in
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                c.fill(Path(CGRect(x: x, y: 0, width: 16, height: size.height)), with: .color(colors[i % colors.count]))
                x += 16
                i += 1
            }
        }
    }
}

struct SplitDemo: View {
    @State private var sel: String? = "Today"
    let names = ["Inbox", "Today", "Favorites", "Archive", "Trash"]
    var body: some View {
        NavigationSplitView {
            List(names, id: \.self, selection: $sel) { n in
                Label(n, systemImage: "tray")
            }
        } detail: {
            ZStack {
                SplitStripes().ignoresSafeArea()
                Text("Detail").padding(20).glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }
        .toolbar {
            ToolbarItem { Button("Add", systemImage: "plus") {} }
            ToolbarItem { Button("Share", systemImage: "square.and.arrow.up") {} }
        }
    }
}

@MainActor
func scene_sidebar_swiftui(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    let host = NSHostingController(rootView: SplitDemo())
    let w = NSWindow(contentViewController: host)
    w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    w.title = "SwiftUI split"
    w.isReleasedWhenClosed = false
    ctx.track("split-swiftui", w)
    w.setFrame(appKitRect(40, 60, 860, 560), display: true)
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.5)
    ctx.shot("split", windows: [("split-swiftui", w)])
    if let frame = w.contentView?.superview { ctx.notes["tree-split"] = ctx.dump(frame, maxDepth: 6) }
}
