// macOS Liquid Glass feasibility probe (PLAN 0.4): can a window screenshot on a
// hosted runner contain the real glass (blur of what is behind it)?
//
// Two windows: "Backdrop" is a stripe pattern; "Glass" overlaps it and has a
// SwiftUI toolbar plus glass panels. Glass over the Backdrop window is the
// behind-window case (needs the window server), glass over in-window stripes is
// the case an in-process render could also see.
import SwiftUI
import AppKit

struct Stripes: View {
    var body: some View {
        Canvas { ctx, size in
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]
            let w: CGFloat = 16
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                         with: .color(colors[i % colors.count]))
                x += w
                i += 1
            }
        }
    }
}

struct GlassContent: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Stripes().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Glass panel over window content")
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                HStack(spacing: 12) {
                    Button("Glass") {}.buttonStyle(.glass)
                    Button("Prominent") {}.buttonStyle(.glassProminent)
                }
            }
            .padding(24)
            .padding(.top, 40)
        }
        .toolbar {
            ToolbarItem { Button("Add", systemImage: "plus") {} }
            ToolbarItem { Button("Share", systemImage: "square.and.arrow.up") {} }
        }
    }
}

typealias WindowListImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

func savePNG(_ image: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

// Borderless, non-opaque window holding only a glass panel: whatever the panel shows
// of the Backdrop window is glass sampling content from ANOTHER window.
struct ClearContent: View {
    var body: some View {
        Text("Glass over another window")
            .padding(24)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(8)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var backdrop: NSWindow!
    var glass: NSWindow!
    var clear: NSWindow!
    let out = ProcessInfo.processInfo.environment["OUT"] ?? "."

    func applicationDidFinishLaunching(_ n: Notification) {
        let vis = NSScreen.main!.visibleFrame
        backdrop = NSWindow(contentRect: NSRect(x: vis.minX + 40, y: vis.minY + 60, width: 520, height: 420),
                            styleMask: [.titled], backing: .buffered, defer: false)
        backdrop.title = "Backdrop"
        backdrop.contentView = NSHostingView(rootView: Stripes())
        backdrop.makeKeyAndOrderFront(nil)

        let host = NSHostingController(rootView: GlassContent())
        glass = NSWindow(contentViewController: host)
        glass.title = "Glass"
        glass.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        glass.setFrame(NSRect(x: vis.minX + 300, y: vis.minY + 120, width: 520, height: 420), display: true)
        glass.titlebarAppearsTransparent = true
        glass.makeKeyAndOrderFront(nil)

        clear = NSWindow(contentRect: NSRect(x: vis.minX + 56, y: vis.minY + 80, width: 230, height: 110),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        clear.title = "Clear"
        clear.isOpaque = false
        clear.backgroundColor = .clear
        clear.hasShadow = true
        clear.contentView = NSHostingView(rootView: ClearContent())
        clear.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.capture() }
    }

    func capture() {
        print("screen frame \(NSScreen.main!.frame) scale \(NSScreen.main!.backingScaleFactor)")
        for w in [backdrop!, glass!, clear!] {
            print("WINDOW \(w.title) \(w.windowNumber) frame \(w.frame)")
        }
        // CGWindowListCreateImage is obsoleted in the macOS 26 SDK, so look it up
        // at run time instead of linking it.
        let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage")
        if let sym {
            let fn = unsafeBitCast(sym, to: WindowListImage.self)
            let kIncluding: UInt32 = 1 << 3   // kCGWindowListOptionIncludingWindow
            let kBoundsIgnoreFraming: UInt32 = 1 << 0
            for w in [backdrop!, glass!, clear!] {
                if let img = fn(.null, kIncluding, UInt32(w.windowNumber), kBoundsIgnoreFraming)?.takeRetainedValue() {
                    savePNG(img, "\(out)/self-\(w.title).png")
                    print("self capture \(w.title): \(img.width)x\(img.height)")
                } else {
                    print("self capture \(w.title): nil")
                }
            }
        } else {
            print("CGWindowListCreateImage: symbol not found")
        }
        fflush(stdout)
        FileManager.default.createFile(atPath: "\(out)/ready", contents: Data())
    }
}

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let d = AppDelegate()
        app.delegate = d
        app.run()
    }
}
