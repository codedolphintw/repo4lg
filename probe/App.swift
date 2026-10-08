// Liquid Glass probe. One page per launch, chosen with `-page <name>`.
// Each control is tagged with probe(id); its frame (points, window space) is
// written with the effective appearance and accessibility flags to
// Documents/frames.json, so the capture script can confirm what was rendered.
import SwiftUI
import UIKit

@main
struct ProbeApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// Frames go to one store instead of a PreferenceKey: sheet and alert content
// live in a separate hierarchy, which preferences do not cross.
@MainActor
final class FrameStore {
    static var frames: [String: CGRect] = [:]
}

extension View {
    func probe(_ id: String) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { FrameStore.frames[id] = $0 }
    }
}

struct RootView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var insets = EdgeInsets()
    let page = UserDefaults.standard.string(forKey: "page") ?? "buttons"

    var body: some View {
        content
            .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
            .task {
                // Sheets and alerts animate in; 3 s is past every presentation.
                try? await Task.sleep(for: .seconds(3))
                write()
            }
    }

    @ViewBuilder private var content: some View {
        switch page {
        case "buttons": ButtonsPage()
        case "inputs": InputsPage()
        case "list": ListPage()
        case "tabs": TabsPage()
        case "sheet": SheetPage()
        case "alert": AlertPage()
        case "glass": GlassPage()
        case "swatch-regular": SwatchPage(clear: false)
        case "swatch-clear": SwatchPage(clear: true)
        case "edges": EdgesPage()
        case "showcase": ShowcasePage()
        case "tabswitch": TabSwitchPage()
        case "tabdrag": TabSwitchPage(auto: false)
        case "toggle": ToggleMotionPage()
        case "morph": MorphPage()
        case "press": PressPage()
        case let p where p.hasPrefix("merge-"): MergePage(gap: Double(p.dropFirst(6)) ?? 0)
        default: Text("unknown page \(page)")
        }
    }

    private func write() {
        var bounds: [String: [String: Double]] = [:]
        for (k, r) in FrameStore.frames {
            bounds[k] = ["x": r.minX, "y": r.minY, "w": r.width, "h": r.height]
        }
        let doc: [String: Any] = [
            "page": page,
            "scale": Double(UITraitCollection.current.displayScale),
            "scheme": scheme == .dark ? "dark" : "light",
            "contrast": contrast == .increased ? "increased" : "standard",
            "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
            "darkerSystemColors": UIAccessibility.isDarkerSystemColorsEnabled,
            "safeArea": ["top": insets.top, "bottom": insets.bottom,
                         "leading": insets.leading, "trailing": insets.trailing],
            "bounds": bounds,
        ]
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("frames.json"))
        }
    }
}

// MARK: - Backgrounds

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

// 1 pt black lines every 8 pt on white: shows lens displacement near edges.
struct Grid: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var x: CGFloat = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(.black))
                x += 8
            }
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black))
                y += 8
            }
        }
    }
}

// Colourful scrolling content, so bars and sheets have something to refract.
struct ColorRows: View {
    var body: some View {
        ForEach(0..<24, id: \.self) { i in
            Rectangle()
                .fill(Color(hue: Double(i) / 24, saturation: 0.7, brightness: 0.9))
                .frame(height: 44)
                .overlay(Text("Row \(i)").foregroundStyle(.white))
        }
    }
}

// MARK: - Pages

struct ButtonsPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Button("Glass") {}.buttonStyle(.glass).probe("button.glass")
                    Button("Prominent") {}.buttonStyle(.glassProminent).probe("button.glassProminent")
                    Button("Red") {}.buttonStyle(.glassProminent).tint(.red).probe("button.glassProminent.red")
                }
                HStack(spacing: 12) {
                    Button("Bordered") {}.buttonStyle(.bordered).probe("button.bordered")
                    Button("Filled") {}.buttonStyle(.borderedProminent).probe("button.borderedProminent")
                    Button("Plain") {}.buttonStyle(.borderless).probe("button.borderless")
                }
                HStack(spacing: 8) {
                    Button("Mini") {}.controlSize(.mini).probe("glass.mini")
                    Button("Small") {}.controlSize(.small).probe("glass.small")
                    Button("Regular") {}.controlSize(.regular).probe("glass.regular")
                }
                .buttonStyle(.glass)
                HStack(spacing: 8) {
                    Button("Large") {}.controlSize(.large).probe("glass.large")
                    Button("XLarge") {}.controlSize(.extraLarge).probe("glass.extraLarge")
                }
                .buttonStyle(.glass)
                HStack(spacing: 8) {
                    Button("Mini") {}.controlSize(.mini).probe("glassProminent.mini")
                    Button("Small") {}.controlSize(.small).probe("glassProminent.small")
                    Button("Large") {}.controlSize(.large).probe("glassProminent.large")
                    Button("XL") {}.controlSize(.extraLarge).probe("glassProminent.extraLarge")
                }
                .buttonStyle(.glassProminent)
                HStack(spacing: 12) {
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(.glass).buttonBorderShape(.circle).probe("icon.glass.circle")
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(.glassProminent).buttonBorderShape(.circle).probe("icon.glassProminent.circle")
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.large).probe("icon.glass.circle.large")
                    Button("Rounded") {}
                        .buttonStyle(.glass).buttonBorderShape(.roundedRectangle).probe("button.glass.roundedRectangle")
                    Button("Off") {}.buttonStyle(.glass).disabled(true).probe("button.glass.disabled")
                }
                Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.glass).probe("button.glass.label")
            }
            .padding()
        }
    }
}

struct InputsPage: View {
    @State private var on = true
    @State private var off = false
    @State private var value = 0.4
    @State private var count = 3
    @State private var segment = 1
    @State private var text = "Text"
    @State private var empty = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("Toggle on", isOn: $on).probe("toggle.on")
            Toggle("Toggle off", isOn: $off).probe("toggle.off")
            Slider(value: $value).probe("slider")
            Stepper("Stepper \(count)", value: $count).probe("stepper")
            Picker("Segment", selection: $segment) {
                Text("One").tag(0)
                Text("Two").tag(1)
                Text("Three").tag(2)
            }
            .pickerStyle(.segmented).probe("segmented")
            TextField("Placeholder", text: $text).textFieldStyle(.roundedBorder).probe("textfield.filled")
            TextField("Placeholder", text: $empty).textFieldStyle(.roundedBorder).probe("textfield.empty")
            ProgressView(value: 0.6).probe("progress.linear")
            HStack(spacing: 24) {
                ProgressView().probe("progress.circular")
                ProgressView().controlSize(.large).probe("progress.circular.large")
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct ListPage: View {
    @State private var on = true

    var body: some View {
        NavigationStack {
            List {
                Section("Section") {
                    Toggle("Wi-Fi", isOn: $on).probe("list.toggle")
                    NavigationLink("General") { Text("General") }.probe("list.link")
                    LabeledContent("Version", value: "26.0").probe("list.value")
                }
                Section {
                    Button("Sign Out", role: .destructive) {}.probe("list.destructive")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {} label: { Image(systemName: "chevron.left") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {}
                }
            }
        }
    }
}

struct TabsPage: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    ScrollView { VStack(spacing: 0) { ColorRows() } }
                        .navigationTitle("Home")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {} label: { Image(systemName: "ellipsis") }
                            }
                        }
                }
            }
            Tab("Search", systemImage: "magnifyingglass") { Text("Search") }
            Tab("Library", systemImage: "books.vertical") { Text("Library") }
            Tab("Settings", systemImage: "gear") { Text("Settings") }
        }
    }
}

struct SheetPage: View {
    var body: some View {
        ScrollView { VStack(spacing: 0) { ColorRows() } }
            .sheet(isPresented: .constant(true)) {
                VStack(spacing: 16) {
                    Text("Sheet").font(.headline).probe("sheet.title")
                    Button("Action") {}.buttonStyle(.glassProminent).probe("sheet.button")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 24)
                .presentationDetents([.medium])
            }
    }
}

struct AlertPage: View {
    var body: some View {
        ScrollView { VStack(spacing: 0) { ColorRows() } }
            .alert("Alert Title", isPresented: .constant(true)) {
                Button("Cancel", role: .cancel) {}
                Button("OK") {}
            } message: {
                Text("A short message.")
            }
    }
}

// Measurement page: empty glass shapes over known flat colours and a grid.
struct GlassPage: View {
    var body: some View {
        VStack(spacing: 0) {
            band("white", Color.white)
            band("black", Color.black)
            band("gray", Color(white: 0.5))
            band("red", Color(red: 1, green: 0, blue: 0))
            ZStack {
                Grid()
                HStack(spacing: 16) {
                    Color.clear.frame(width: 120, height: 64)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20)).probe("grid.regular")
                    GlassEffectContainer(spacing: 24) {
                        HStack(spacing: 8) {
                            Color.clear.frame(width: 56, height: 56).glassEffect().probe("grid.merge.a")
                            Color.clear.frame(width: 56, height: 56).glassEffect().probe("grid.merge.b")
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func band(_ name: String, _ color: Color) -> some View {
        ZStack {
            color
            HStack(spacing: 16) {
                Color.clear.frame(width: 120, height: 64)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20)).probe("\(name).regular")
                Color.clear.frame(width: 120, height: 64)
                    .glassEffect(.clear, in: .rect(cornerRadius: 20)).probe("\(name).clear")
                Color.clear.frame(width: 64, height: 64)
                    .glassEffect(.regular.tint(.blue)).probe("\(name).tint")
            }
        }
    }
}

// MARK: - Measurement pages

// Glass over flat swatches. Cell id = background hex, so the output colour can
// be fitted against a known input. 3 columns x 7 rows of 134 x 112 pt cells,
// each holding a 94 x 48 pt glass rectangle (corner 12), 20+ pt from any other
// colour so the blur cannot reach a neighbouring cell.
struct SwatchPage: View {
    let clear: Bool
    static let colors: [(Double, Double, Double)] = [
        (0, 0, 0), (0.1, 0.1, 0.1), (0.2, 0.2, 0.2), (0.3, 0.3, 0.3), (0.4, 0.4, 0.4),
        (0.5, 0.5, 0.5), (0.6, 0.6, 0.6), (0.7, 0.7, 0.7), (0.8, 0.8, 0.8), (0.9, 0.9, 0.9),
        (1, 1, 1), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0, 1, 1), (1, 0, 1), (1, 1, 0),
        (1, 0.5, 0), (0.5, 0.25, 0.75), (0.2, 0.6, 0.4), (0.9, 0.75, 0.6),
    ]

    var body: some View {
        let rows = stride(from: 0, to: Self.colors.count, by: 3).map { Array(Self.colors[$0..<min($0 + 3, Self.colors.count)]) }
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        let col = rows[r][c]
                        ZStack {
                            Color(.sRGB, red: col.0, green: col.1, blue: col.2)
                            Color.clear.frame(width: 94, height: 48)
                                .glassEffect(clear ? .clear : .regular, in: .rect(cornerRadius: 12))
                                .probe("sw." + hex(col.0, col.1, col.2))
                        }
                        .frame(width: 134, height: 112)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
    String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
}

// Black|white step edge (blur kernel), grid (refraction), white field (shadow).
struct EdgesPage: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 0) { Color.black; Color.white }
                Color.clear.frame(width: 300, height: 96)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24)).probe("edge.regular")
            }
            .frame(height: 170)
            ZStack {
                HStack(spacing: 0) { Color.black; Color.white }
                Color.clear.frame(width: 300, height: 96)
                    .glassEffect(.clear, in: .rect(cornerRadius: 24)).probe("edge.clear")
            }
            .frame(height: 170)
            ZStack {
                Grid()
                Color.clear.frame(width: 300, height: 96)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24)).probe("grid.regular")
            }
            .frame(height: 170)
            ZStack {
                Color.white
                Color.clear.frame(width: 200, height: 96)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24)).probe("shadow.regular")
            }
            .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

// The comparison page (see SHOWCASE_SPEC.md in the consuming project): every
// compared control on the system background, plus glass samples on stripes.
struct ShowcasePage: View {
    @State private var on = true
    @State private var off = false
    @State private var value = 0.4
    @State private var count = 3
    @State private var segment = 1
    @State private var text = "Text"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Button("Glass") {}.buttonStyle(.glass).probe("btn-glass")
                Button("Prominent") {}.buttonStyle(.glassProminent).probe("btn-prominent")
                Button("Bordered") {}.buttonStyle(.bordered).probe("btn-bordered")
            }
            HStack(spacing: 16) {
                Button("Filled") {}.buttonStyle(.borderedProminent).probe("btn-filled")
                Button("Plain") {}.buttonStyle(.borderless).probe("btn-plain")
                Button("Off") {}.buttonStyle(.glass).disabled(true).probe("btn-disabled")
            }
            HStack(spacing: 16) {
                Button("Small") {}.buttonStyle(.glass).controlSize(.small).probe("btn-glass-small")
                Button("Large") {}.buttonStyle(.glass).controlSize(.large).probe("btn-glass-large")
                Button {} label: { Image(systemName: "plus") }
                    .buttonStyle(.glass).buttonBorderShape(.circle).probe("icon-glass")
                Button {} label: { Image(systemName: "plus") }
                    .buttonStyle(.glassProminent).buttonBorderShape(.circle).probe("icon-prominent")
            }
            HStack(spacing: 24) {
                Toggle("On", isOn: $on).labelsHidden().probe("toggle-on")
                Toggle("Off", isOn: $off).labelsHidden().probe("toggle-off")
                Stepper("Stepper", value: $count).labelsHidden().probe("stepper")
            }
            Slider(value: $value).frame(width: 240).probe("slider")
            Picker("Segment", selection: $segment) {
                Text("One").tag(0)
                Text("Two").tag(1)
                Text("Three").tag(2)
            }
            .pickerStyle(.segmented).frame(width: 280).probe("segmented")
            TextField("Placeholder", text: $text).textFieldStyle(.roundedBorder)
                .frame(width: 280).probe("textfield")
            ProgressView(value: 0.6).frame(width: 240).probe("progress")
            ZStack {
                Stripes()
                HStack(spacing: 16) {
                    Color.clear.frame(width: 120, height: 64)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20)).probe("glass-regular")
                    Color.clear.frame(width: 120, height: 64)
                        .glassEffect(.clear, in: .rect(cornerRadius: 20)).probe("glass-clear")
                    Color.clear.frame(width: 64, height: 64)
                        .glassEffect(.regular.tint(.blue)).probe("glass-tint")
                }
            }
            .frame(width: 370, height: 112)
            .probe("stripes")
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Motion pages
// Each animates on a timer from t = 4 s (after frames.json is written), every
// 2 s, so a screen recording started at ~3 s sees several cycles.

func everyTwoSeconds(_ step: @escaping @MainActor () -> Void) async {
    try? await Task.sleep(for: .seconds(4))
    while !Task.isCancelled {
        await MainActor.run { withAnimation { step() } }
        try? await Task.sleep(for: .seconds(2))
    }
}

// Static: two 64 pt glass circles in one GlassEffectContainer(spacing: 40),
// `gap` pt apart, over a gradient -- the merge bridge as a function of gap.
struct MergePage: View {
    let gap: Double
    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange, .pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            GlassEffectContainer(spacing: 40) {
                HStack(spacing: gap) {
                    Color.clear.frame(width: 64, height: 64).glassEffect().probe("merge.a")
                    Color.clear.frame(width: 64, height: 64).glassEffect().probe("merge.b")
                }
            }
        }
    }
}

struct TabSwitchPage: View {
    var auto = true
    @State private var sel = 0
    var body: some View {
        TabView(selection: $sel) {
            Tab("Home", systemImage: "house", value: 0) { ScrollView { VStack(spacing: 0) { ColorRows() } } }
            Tab("Search", systemImage: "magnifyingglass", value: 1) { ScrollView { VStack(spacing: 0) { ColorRows() } } }
            Tab("Library", systemImage: "books.vertical", value: 2) { ScrollView { VStack(spacing: 0) { ColorRows() } } }
            Tab("Settings", systemImage: "gear", value: 3) { ScrollView { VStack(spacing: 0) { ColorRows() } } }
        }
        .task { if auto { await everyTwoSeconds { sel = sel == 0 ? 2 : 0 } } }
    }
}

struct ToggleMotionPage: View {
    @State private var on = false
    var body: some View {
        VStack {
            Toggle("Toggle", isOn: $on).labelsHidden().probe("toggle")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await everyTwoSeconds { on.toggle() } }
    }
}

// The common iOS 26 pattern: one glass circle that expands into a row of
// glass buttons, matched with glassEffectID in one container.
struct MorphPage: View {
    @Namespace private var ns
    @State private var open = false
    var body: some View {
        ZStack {
            Stripes().ignoresSafeArea()
            GlassEffectContainer(spacing: 20) {
                HStack(spacing: 12) {
                    if open {
                        ForEach(["pencil", "trash", "paperplane"], id: \.self) { icon in
                            Image(systemName: icon).frame(width: 56, height: 56)
                                .glassEffect().glassEffectID(icon, in: ns)
                        }
                    }
                    Image(systemName: open ? "xmark" : "plus").frame(width: 56, height: 56)
                        .glassEffect().glassEffectID("main", in: ns)
                }
            }
            .probe("morph")
        }
        .task { await everyTwoSeconds { open.toggle() } }
    }
}

// Pressed by the capture script (idb) while recording: an interactive glass
// shape and a glass button, both over stripes so the lens shows.
struct PressPage: View {
    var body: some View {
        ZStack {
            Stripes().ignoresSafeArea()
            VStack(spacing: 60) {
                Color.clear.frame(width: 200, height: 72)
                    .glassEffect(.regular.interactive(), in: .capsule).probe("press.interactive")
                Button("Glass Button") {}.buttonStyle(.glass).controlSize(.large).probe("press.button")
            }
        }
    }
}
