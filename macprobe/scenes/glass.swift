// SCENES: glass
// The glass material on macOS 26 over known backdrops, in the two situations that
// exist on a desktop:
//   in-window     glass over content of the SAME window (SwiftUI .glassEffect)
//   behind-window glass in a transparent window over ANOTHER window
// Backdrops are the iOS probe's: flat grey swatches, 12 px black/white stripes, a
// black|white step, white (shadow), mid grey, saturated swatches. Layout constants
// live in `GL` and are written to the JSON, so the measuring script reads them.
import SwiftUI
import AppKit

enum GL {
    static let levels = [0, 51, 77, 102, 128, 153, 178, 204, 229, 255]
    static let tileW: CGFloat = 190
    static let tileH: CGFloat = 140
    static let gw: CGFloat = 120
    static let gh: CGFloat = 64
    static let gr: CGFloat = 20

    static func tile(_ row: Int, _ col: Int) -> CGRect {
        CGRect(x: CGFloat(col) * tileW, y: CGFloat(row) * tileH, width: tileW, height: tileH)
    }
    static func glassRect(_ row: Int, _ col: Int) -> CGRect {
        let t = tile(row, col)
        return CGRect(x: t.midX - gw / 2, y: t.midY - gh / 2, width: gw, height: gh)
    }
    static func level(_ row: Int, _ col: Int) -> Int { levels[(row % 2) * 5 + col] }

    static let stripes = CGRect(x: 20, y: 20, width: 370, height: 112)
    static let stripeRegular = CGRect(x: 37, y: 44, width: 120, height: 64)
    static let stripeClear = CGRect(x: 173, y: 44, width: 120, height: 64)
    static let stripeTint = CGRect(x: 309, y: 44, width: 64, height: 64)
    static let stepR = CGRect(x: 420, y: 20, width: 400, height: 112)
    static let stepC = CGRect(x: 420, y: 150, width: 400, height: 112)
    static let stepGlassR = CGRect(x: 560, y: 44, width: 120, height: 64)
    static let stepGlassC = CGRect(x: 560, y: 174, width: 120, height: 64)
    static let shadowPanel = CGRect(x: 20, y: 150, width: 370, height: 210)
    static let shadowBig = CGRect(x: 105, y: 207, width: 200, height: 96)
    static let shadowPanel2 = CGRect(x: 420, y: 280, width: 260, height: 170)
    static let shadowSmall = CGRect(x: 490, y: 333, width: 120, height: 64)
    static let greyPanel = CGRect(x: 700, y: 280, width: 280, height: 170)
    static let greyTint = CGRect(x: 720, y: 300, width: 64, height: 64)
    static let greyClear = CGRect(x: 720, y: 380, width: 120, height: 64)
    static let btnGlass = CGPoint(x: 810, y: 305)
    static let btnProminent = CGPoint(x: 810, y: 355)
    // Page "sizes": the same glass at five sizes (w, h, corner radius), regular in the
    // top row and clear in the bottom row, over full-window 12 px stripes.
    static let sizeSpecs: [(CGFloat, CGFloat, CGFloat)] = [
        (48, 48, 24), (64, 64, 32), (120, 64, 20), (200, 96, 28), (360, 160, 32),
    ]
    static let sizeX: [CGFloat] = [30, 100, 190, 340, 580]
    static func sizeRect(_ i: Int, clear: Bool) -> CGRect {
        let spec = sizeSpecs[i]
        let top: CGFloat = clear ? 340 : 70
        return CGRect(x: sizeX[i], y: top, width: spec.0, height: spec.1)
    }
    static let satColors: [(Int, Int, Int)] = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)]
    static func satSwatch(_ i: Int) -> CGRect { CGRect(x: 20 + CGFloat(i) * 92, y: 380, width: 92, height: 140) }
    static func satGlass(_ i: Int) -> CGRect {
        let s = satSwatch(i)
        return CGRect(x: s.midX - 35, y: s.midY - 22, width: 70, height: 44)
    }
}

@MainActor
func fillRect(_ r: CGRect, _ c: Color) -> some View {
    Rectangle().fill(c).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
}

@MainActor
func glassBox(_ r: CGRect, _ g: Glass, _ radius: CGFloat) -> some View {
    Color.clear.frame(width: r.width, height: r.height)
        .glassEffect(g, in: .rect(cornerRadius: radius))
        .offset(x: r.minX, y: r.minY)
}

@MainActor
func tintCircle(_ r: CGRect) -> some View {
    Color.clear.frame(width: r.width, height: r.height)
        .glassEffect(.regular.tint(.blue), in: .circle)
        .offset(x: r.minX, y: r.minY)
}

struct BWStripes: View {
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

struct GridTiles: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { row in
                ForEach(0..<5, id: \.self) { col in
                    fillRect(GL.tile(row, col), Color(.sRGB, white: Double(GL.level(row, col)) / 255, opacity: 1))
                }
            }
        }
    }
}

struct GridGlass: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { row in
                ForEach(0..<5, id: \.self) { col in
                    glassBox(GL.glassRect(row, col), row < 2 ? Glass.regular : Glass.clear, GL.gr)
                }
            }
        }
    }
}

struct MiscPanels: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            BWStripes()
                .frame(width: GL.stripes.width, height: GL.stripes.height)
                .clipped()
                .offset(x: GL.stripes.minX, y: GL.stripes.minY)
            fillRect(CGRect(x: GL.stepR.minX, y: GL.stepR.minY, width: 200, height: 112), Color.black)
            fillRect(CGRect(x: GL.stepR.minX + 200, y: GL.stepR.minY, width: 200, height: 112), Color.white)
            fillRect(CGRect(x: GL.stepC.minX, y: GL.stepC.minY, width: 200, height: 112), Color.black)
            fillRect(CGRect(x: GL.stepC.minX + 200, y: GL.stepC.minY, width: 200, height: 112), Color.white)
            fillRect(GL.shadowPanel, Color.white)
            fillRect(GL.shadowPanel2, Color.white)
            fillRect(GL.greyPanel, Color(.sRGB, white: 128.0 / 255, opacity: 1))
            ForEach(0..<4, id: \.self) { i in
                fillRect(GL.satSwatch(i), Color(.sRGB, red: Double(GL.satColors[i].0) / 255,
                                                green: Double(GL.satColors[i].1) / 255,
                                                blue: Double(GL.satColors[i].2) / 255, opacity: 1))
            }
        }
    }
}

struct MiscGlass: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            glassBox(GL.stripeRegular, Glass.regular, 20)
            glassBox(GL.stripeClear, Glass.clear, 20)
            tintCircle(GL.stripeTint)
            glassBox(GL.stepGlassR, Glass.regular, 20)
            glassBox(GL.stepGlassC, Glass.clear, 20)
            glassBox(GL.shadowSmall, Glass.regular, 20)
            glassBox(GL.shadowBig, Glass.regular, 28)
            tintCircle(GL.greyTint)
            glassBox(GL.greyClear, Glass.clear, 20)
            Button("Glass") {}
                .buttonStyle(.glass)
                .fixedSize()
                .offset(x: GL.btnGlass.x, y: GL.btnGlass.y)
            Button("Prominent") {}
                .buttonStyle(.glassProminent)
                .fixedSize()
                .offset(x: GL.btnProminent.x, y: GL.btnProminent.y)
            ForEach(0..<4, id: \.self) { i in
                glassBox(GL.satGlass(i), Glass.regular, 16)
            }
        }
    }
}

struct SizesTiles: View {
    var body: some View {
        BWStripes().frame(width: 1000, height: 600).clipped()
    }
}

struct SizesGlass: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<5, id: \.self) { i in
                glassBox(GL.sizeRect(i, clear: false), Glass.regular, GL.sizeSpecs[i].2)
                glassBox(GL.sizeRect(i, clear: true), Glass.clear, GL.sizeSpecs[i].2)
            }
        }
    }
}

struct GlassPage: View {
    let kind: String
    let panels: Bool
    let glass: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            if panels {
                if kind == "grid" { GridTiles() } else if kind == "sizes" { SizesTiles() } else { MiscPanels() }
            }
            if glass {
                if kind == "grid" { GridGlass() } else if kind == "sizes" { SizesGlass() } else { MiscGlass() }
            }
        }
        .frame(width: 1000, height: 600, alignment: .topLeading)
    }
}

@MainActor
func glassLayout() -> [String: Any] {
    func rj(_ r: CGRect) -> [String: Double] {
        ["x": q(r.minX), "y": q(r.minY), "w": q(r.width), "h": q(r.height)]
    }
    var tiles: [[String: Any]] = []
    for row in 0..<4 {
        for col in 0..<5 {
            var d: [String: Any] = ["row": row, "col": col, "level": GL.level(row, col), "kind": row < 2 ? "regular" : "clear"]
            d["tile"] = rj(GL.tile(row, col))
            d["glass"] = rj(GL.glassRect(row, col))
            tiles.append(d)
        }
    }
    var sat: [[String: Any]] = []
    for i in 0..<4 {
        var d: [String: Any] = ["rgb": [GL.satColors[i].0, GL.satColors[i].1, GL.satColors[i].2]]
        d["swatch"] = rj(GL.satSwatch(i))
        d["glass"] = rj(GL.satGlass(i))
        sat.append(d)
    }
    var L: [String: Any] = ["tiles": tiles, "sat": sat, "radius": Double(GL.gr), "levels": GL.levels]
    L["stripes"] = rj(GL.stripes)
    L["stripeRegular"] = rj(GL.stripeRegular)
    L["stripeClear"] = rj(GL.stripeClear)
    L["stripeTint"] = rj(GL.stripeTint)
    L["stepR"] = rj(GL.stepR)
    L["stepC"] = rj(GL.stepC)
    L["stepGlassR"] = rj(GL.stepGlassR)
    L["stepGlassC"] = rj(GL.stepGlassC)
    L["shadowPanel"] = rj(GL.shadowPanel)
    L["shadowPanel2"] = rj(GL.shadowPanel2)
    L["shadowSmall"] = rj(GL.shadowSmall)
    L["shadowBig"] = rj(GL.shadowBig)
    L["greyPanel"] = rj(GL.greyPanel)
    L["greyTint"] = rj(GL.greyTint)
    L["greyClear"] = rj(GL.greyClear)
    L["btnGlassOrigin"] = ["x": q(GL.btnGlass.x), "y": q(GL.btnGlass.y)]
    L["btnProminentOrigin"] = ["x": q(GL.btnProminent.x), "y": q(GL.btnProminent.y)]
    L["stripeWidth"] = 12
    var sizes: [[String: Any]] = []
    for i in 0..<5 {
        for clear in [false, true] {
            var d: [String: Any] = ["kind": clear ? "clear" : "regular", "radius": Double(GL.sizeSpecs[i].2)]
            d["rect"] = rj(GL.sizeRect(i, clear: clear))
            sizes.append(d)
        }
    }
    L["sizes"] = sizes
    return L
}

@MainActor
func scene_glass(_ ctx: Ctx) async {
    ctx.notes["layout"] = glassLayout()
    // The two windows below sit at the same frame: window coordinates = layout coordinates.
    let fx: CGFloat = 12, fy: CGFloat = 44
    ctx.notes["origin"] = ["x": Double(fx), "y": Double(fy)]

    // 1. In-window glass: backdrop and glass in one SwiftUI view.
    let inw = ctx.borderless("inwindow", fx, fy, 1000, 600, opaque: true)
    inw.backgroundColor = gray(60)
    let host = NSHostingView(rootView: GlassPage(kind: "grid", panels: true, glass: true))
    inw.contentView = host
    inw.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    await ctx.pause(2.5)
    ctx.shot("in-grid", windows: [("inwindow", inw)])
    host.rootView = GlassPage(kind: "misc", panels: true, glass: true)
    await ctx.pause(2.0)
    ctx.shot("in-misc", windows: [("inwindow", inw)])
    host.rootView = GlassPage(kind: "sizes", panels: true, glass: true)
    await ctx.pause(2.0)
    ctx.shot("in-sizes")
    inw.orderOut(nil)

    // 2. Behind-window glass: the backdrop is its own window; the glass lives in a
    //    transparent window above it.
    let bd = ctx.borderless("backdrop", fx, fy, 1000, 600, opaque: true)
    bd.backgroundColor = gray(60)
    let bdHost = NSHostingView(rootView: GlassPage(kind: "grid", panels: true, glass: false))
    bd.contentView = bdHost
    bd.orderFront(nil)
    let ov = ctx.borderless("overlay", fx, fy, 1000, 600, opaque: false)
    let ovHost = NSHostingView(rootView: GlassPage(kind: "grid", panels: false, glass: false))
    ov.contentView = ovHost
    ov.makeKeyAndOrderFront(nil)
    await ctx.pause(1.5)
    ctx.shot("ctl-grid")
    ovHost.rootView = GlassPage(kind: "grid", panels: false, glass: true)
    await ctx.pause(2.5)
    ctx.shot("bh-grid")
    ovHost.rootView = GlassPage(kind: "misc", panels: false, glass: false)
    bdHost.rootView = GlassPage(kind: "misc", panels: true, glass: false)
    await ctx.pause(1.5)
    ctx.shot("ctl-misc")
    ovHost.rootView = GlassPage(kind: "misc", panels: false, glass: true)
    await ctx.pause(2.5)
    ctx.shot("bh-misc")
    ovHost.rootView = GlassPage(kind: "sizes", panels: false, glass: false)
    bdHost.rootView = GlassPage(kind: "sizes", panels: true, glass: false)
    await ctx.pause(1.5)
    ctx.shot("ctl-sizes")
    ovHost.rootView = GlassPage(kind: "sizes", panels: false, glass: true)
    await ctx.pause(2.5)
    ctx.shot("bh-sizes")
}
