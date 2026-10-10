// SCENES: showcase
// SwiftUI's own controls on macOS 26: the reference page for a later stack
// comparison (see SHOWCASE_SPEC.md). Page "a": button styles, toggles, pickers,
// slider, stepper, text field, progress, menu button and the stripes panel with
// glass; pages "b1" and "b2": the same kinds at every ControlSize. Every control
// carries .probe(name); the frames (relative to the hosting view, top-left) are
// written to the JSON together with the hosting view's screen frame.
import SwiftUI
import AppKit

struct ProbeKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

final class FrameStore {
    static var frames: [String: CGRect] = [:]
}

extension View {
    func probe(_ name: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: ProbeKey.self, value: [name: g.frame(in: .named("page"))])
        })
    }
}

struct ShowStripes: View {
    var body: some View {
        Canvas { c, size in
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                c.fill(Path(CGRect(x: x, y: 0, width: 12, height: size.height)),
                       with: .color(i % 2 == 0 ? Color.black : Color.white))
                x += 12
                i += 1
            }
        }
    }
}

@MainActor
func showGlass(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ g: Glass, circle: Bool, tint: Bool, name: String) -> some View {
    Group {
        if circle {
            Color.clear.frame(width: w, height: h).glassEffect(.regular.tint(.blue), in: .circle)
        } else {
            Color.clear.frame(width: w, height: h).glassEffect(g, in: .rect(cornerRadius: 20))
        }
    }
    .probe(name)
    .offset(x: x, y: y)
}

struct PageA: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Button("Bordered") {}.buttonStyle(.bordered).probe("btn-bordered")
                Button("Prominent") {}.buttonStyle(.borderedProminent).probe("btn-prominent")
                Button("Glass") {}.buttonStyle(.glass).probe("btn-glass")
                Button("Prominent") {}.buttonStyle(.glassProminent).probe("btn-glass-prominent")
                Button("Plain") {}.buttonStyle(.plain).probe("btn-plain")
                Button("Borderless") {}.buttonStyle(.borderless).probe("btn-borderless")
                Button("Off") {}.buttonStyle(.glass).disabled(true).probe("btn-disabled")
            }
            HStack(spacing: 14) {
                Button { } label: { Image(systemName: "plus") }
                    .buttonStyle(.glass).buttonBorderShape(.circle).probe("icon-glass")
                Button { } label: { Image(systemName: "plus") }
                    .buttonStyle(.glassProminent).buttonBorderShape(.circle).probe("icon-prominent")
                Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden().probe("switch-on")
                Toggle("", isOn: .constant(false)).toggleStyle(.switch).labelsHidden().probe("switch-off")
                Toggle("Check", isOn: .constant(true)).toggleStyle(.checkbox).probe("checkbox-on")
                Toggle("Check", isOn: .constant(false)).toggleStyle(.checkbox).probe("checkbox-off")
            }
            HStack(alignment: .top, spacing: 24) {
                Picker("", selection: .constant(1)) {
                    Text("One").tag(0)
                    Text("Two").tag(1)
                }
                .pickerStyle(.radioGroup).labelsHidden().probe("radio-group")
                Picker("", selection: .constant(1)) {
                    Text("One").tag(0)
                    Text("Two").tag(1)
                    Text("Three").tag(2)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 280).probe("segmented")
                Picker("", selection: .constant(1)) {
                    Text("One").tag(0)
                    Text("Two").tag(1)
                }
                .pickerStyle(.menu).labelsHidden().probe("picker-menu")
                Menu("Menu") { Button("One") {} }.probe("menu-button")
            }
            HStack(spacing: 24) {
                Slider(value: .constant(0.4)).frame(width: 240).probe("slider")
                Slider(value: .constant(3), in: 0...10, step: 1).frame(width: 240).probe("slider-steps")
                Stepper("", value: .constant(3)).labelsHidden().probe("stepper")
            }
            HStack(spacing: 24) {
                TextField("", text: .constant("Text")).textFieldStyle(.roundedBorder).frame(width: 280).probe("textfield")
                ProgressView(value: 0.6).frame(width: 240).probe("progress")
                ProgressView().controlSize(.small).probe("spinner-small")
                ProgressView().probe("spinner")
            }
            ZStack(alignment: .topLeading) {
                ShowStripes().frame(width: 370, height: 112).clipped()
                showGlass(17, 24, 120, 64, Glass.regular, circle: false, tint: false, name: "glass-regular")
                showGlass(153, 24, 120, 64, Glass.clear, circle: false, tint: false, name: "glass-clear")
                showGlass(289, 24, 64, 64, Glass.regular, circle: true, tint: true, name: "glass-tint")
            }
            .frame(width: 370, height: 112, alignment: .topLeading)
            .probe("stripes")
        }
        .padding(24)
        .frame(width: 1000, height: 620, alignment: .topLeading)
    }
}

let sizeList: [(String, ControlSize)] = [
    ("mini", .mini), ("small", .small), ("regular", .regular), ("large", .large), ("extraLarge", .extraLarge),
]

struct SizeRow<C: View>: View {
    let label: String
    let make: () -> C
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Text(label).frame(width: 110, alignment: .leading)
            ForEach(sizeList, id: \.0) { item in
                make().controlSize(item.1).probe("\(label)-\(item.0)")
            }
        }
    }
}

struct PageB1: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SizeRow(label: "bordered") { Button("Button") {}.buttonStyle(.bordered) }
            SizeRow(label: "prominent") { Button("Button") {}.buttonStyle(.borderedProminent) }
            SizeRow(label: "glass") { Button("Button") {}.buttonStyle(.glass) }
            SizeRow(label: "glassProminent") { Button("Button") {}.buttonStyle(.glassProminent) }
            SizeRow(label: "switch") { Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden() }
            SizeRow(label: "checkbox") { Toggle("Check", isOn: .constant(true)).toggleStyle(.checkbox) }
        }
        .padding(16)
        .frame(width: 1000, height: 620, alignment: .topLeading)
    }
}

struct PageB2: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SizeRow(label: "segmented") {
                Picker("", selection: .constant(1)) {
                    Text("One").tag(0)
                    Text("Two").tag(1)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 130)
            }
            SizeRow(label: "textfield") { TextField("", text: .constant("Text")).textFieldStyle(.roundedBorder).frame(width: 110) }
            SizeRow(label: "slider") { Slider(value: .constant(0.4)).frame(width: 110) }
            SizeRow(label: "stepper") { Stepper("", value: .constant(3)).labelsHidden() }
            SizeRow(label: "progress") { ProgressView(value: 0.6).frame(width: 110) }
            SizeRow(label: "menu") {
                Picker("", selection: .constant(1)) {
                    Text("One").tag(0)
                    Text("Two").tag(1)
                }
                .pickerStyle(.menu).labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 1000, height: 620, alignment: .topLeading)
    }
}

struct ShowRoot: View {
    let page: String
    var body: some View {
        Group {
            if page == "a" {
                PageA()
            } else if page == "b1" {
                PageB1()
            } else {
                PageB2()
            }
        }
        .coordinateSpace(name: "page")
        .onPreferenceChange(ProbeKey.self) { FrameStore.frames = $0 }
    }
}

@MainActor
func scene_showcase(_ ctx: Ctx) async {
    ctx.backdrop(gray: 192)
    let w = ctx.titled("Showcase", 12, 40, 1000, 660)
    let host = NSHostingView(rootView: ShowRoot(page: "a"))
    w.contentView = host
    w.setContentSize(NSSize(width: 1000, height: 620))
    w.setFrameTopLeftPoint(NSPoint(x: 12, y: screenHeight() - 40))
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    for page in ["a", "b1", "b2"] {
        FrameStore.frames = [:]
        host.rootView = ShowRoot(page: page)
        await ctx.pause(2.0)
        var probes: [String: Any] = [:]
        for (k, r) in FrameStore.frames {
            probes[k] = ["x": q(r.minX), "y": q(r.minY), "w": q(r.width), "h": q(r.height)]
        }
        var info: [String: Any] = [:]
        info["probes"] = probes
        info["host"] = viewFrame(host)
        ctx.notes["page-\(page)"] = info
        ctx.shot("page-\(page)", windows: [("Showcase", w)])
    }
}
