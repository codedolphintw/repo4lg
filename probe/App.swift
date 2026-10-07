// Liquid Glass probe: renders a few glass controls over known backgrounds and
// records each control's frame (in points) to Documents/frames.json.
import SwiftUI
import UIKit

@main
struct ProbeApp: App {
    var body: some Scene {
        WindowGroup { ProbeView() }
    }
}

struct FrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func probe(_ id: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: FrameKey.self, value: [id: g.frame(in: .global)])
        })
    }
}

// 12 pt black/white vertical stripes: shows blur radius and edge refraction.
struct Stripes: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 12, height: size.height)),
                         with: .color(i % 2 == 0 ? .black : .white))
                x += 12
                i += 1
            }
        }
    }
}

struct Controls: View {
    let prefix: String
    var body: some View {
        VStack(spacing: 20) {
            Button("Glass") {}.buttonStyle(.glass).probe("\(prefix).button.glass")
            Button("Prominent") {}.buttonStyle(.glassProminent).probe("\(prefix).button.glassProminent")
            Text("glassEffect").padding().glassEffect().probe("\(prefix).text.glassEffect")
            Text("rect16").padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 16)).probe("\(prefix).text.rect16")
            Text("clear").padding().glassEffect(.clear).probe("\(prefix).text.clear")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProbeView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var frames: [String: CGRect] = [:]

    var body: some View {
        VStack(spacing: 0) {
            Controls(prefix: "stripes").background(Stripes().ignoresSafeArea())
            Controls(prefix: "gradient").background(
                LinearGradient(colors: [.red, .yellow, .green, .blue],
                               startPoint: .leading, endPoint: .trailing).ignoresSafeArea())
        }
        .onPreferenceChange(FrameKey.self) { frames = $0 }
        .task {
            try? await Task.sleep(for: .seconds(2))
            write()
        }
    }

    private func write() {
        var bounds: [String: [String: Double]] = [:]
        for (k, r) in frames {
            bounds[k] = ["x": r.minX, "y": r.minY, "w": r.width, "h": r.height]
        }
        let doc: [String: Any] = [
            "scale": Double(UITraitCollection.current.displayScale),
            "scheme": scheme == .dark ? "dark" : "light",
            "bounds": bounds,
        ]
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("frames.json"))
        }
    }
}
