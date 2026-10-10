// SCENES: glass glasstime
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
    static let adaptNames = ["flat128", "stripes12_duty50", "stripes12_duty25", "stripes12_duty75", "stripes3_duty50",
                             "stripes48_duty50", "checker12", "gradient_x", "gradient_y", "white_dots_on_black"]
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

/// Ten backdrops of the same mean brightness family (see GL.adaptNames), one per tile,
/// to find out what the regular glass adapts to.
struct AdaptPattern: View {
    let kind: Int
    var body: some View {
        Canvas { c, size in
            func fill(_ r: CGRect, _ v: Double) {
                c.fill(Path(r), with: .color(Color(.sRGB, white: v, opacity: 1)))
            }
            func stripes(_ period: CGFloat, _ black: CGFloat) {
                fill(CGRect(origin: .zero, size: size), 1.0)
                var x: CGFloat = 0
                while x < size.width {
                    fill(CGRect(x: x, y: 0, width: min(black, size.width - x), height: size.height), 0.0)
                    x += period
                }
            }
            switch kind {
            case 0:
                fill(CGRect(origin: .zero, size: size), 128.0 / 255)
            case 1: stripes(24, 12)
            case 2: stripes(24, 6)
            case 3: stripes(24, 18)
            case 4: stripes(6, 3)
            case 5: stripes(96, 48)
            case 6:
                fill(CGRect(origin: .zero, size: size), 1.0)
                var y: CGFloat = 0
                var row = 0
                while y < size.height {
                    var x: CGFloat = 0
                    var col = 0
                    while x < size.width {
                        if (row + col) % 2 == 0 { fill(CGRect(x: x, y: y, width: 12, height: 12), 0.0) }
                        x += 12
                        col += 1
                    }
                    y += 12
                    row += 1
                }
            case 7:
                var x: CGFloat = 0
                while x < size.width {
                    fill(CGRect(x: x, y: 0, width: 1, height: size.height), Double(x / (size.width - 1)))
                    x += 1
                }
            case 8:
                var y: CGFloat = 0
                while y < size.height {
                    fill(CGRect(x: 0, y: y, width: size.width, height: 1), Double(y / (size.height - 1)))
                    y += 1
                }
            default:
                fill(CGRect(origin: .zero, size: size), 0.0)
                var y: CGFloat = 6
                while y < size.height {
                    var x: CGFloat = 6
                    while x < size.width {
                        c.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                               with: .color(Color(.sRGB, white: 1.0, opacity: 1)))
                        x += 12
                    }
                    y += 12
                }
            }
        }
        .frame(width: GL.tileW, height: GL.tileH)
        .clipped()
    }
}

struct AdaptTiles: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<10, id: \.self) { i in
                AdaptPattern(kind: i)
                    .offset(x: GL.tile(i / 5, i % 5).minX, y: GL.tile(i / 5, i % 5).minY)
            }
        }
    }
}

struct AdaptGlass: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<10, id: \.self) { i in
                glassBox(GL.glassRect(i / 5, i % 5), Glass.regular, GL.gr)
            }
        }
    }
}

/// Page "ctx": does the regular glass look beyond what is under it? Top row: 120 x 64 glass
/// over stripes that exist only in a patch around it (margin 0 ... 80 px); bottom band:
/// full-width stripes with the same glass alone, next to a second regular glass, next to clear.
enum CX {
    static let margins: [CGFloat] = [0, 10, 20, 40, 80]
    static func patch(_ i: Int) -> CGRect {
        var x: CGFloat = 20
        for j in 0..<i { x += 120 + 2 * margins[j] + 20 }
        let m = margins[i]
        return CGRect(x: x, y: 150 - 32 - m, width: 120 + 2 * m, height: 64 + 2 * m)
    }
    static func glass(_ i: Int) -> CGRect {
        let p = patch(i)
        let m = margins[i]
        return CGRect(x: p.minX + m, y: p.minY + m, width: 120, height: 64)
    }
    static let band = CGRect(x: 0, y: 300, width: 1000, height: 300)
    static let lower: [(String, CGRect, Bool)] = [
        ("band_alone", CGRect(x: 60, y: 420, width: 120, height: 64), false),
        ("band_pair_a", CGRect(x: 240, y: 420, width: 120, height: 64), false),
        ("band_pair_b", CGRect(x: 380, y: 420, width: 120, height: 64), false),
        ("band_regular_next_to_clear", CGRect(x: 560, y: 420, width: 120, height: 64), false),
        ("band_clear_next_to_regular", CGRect(x: 700, y: 420, width: 120, height: 64), true),
    ]
}

struct CtxTiles: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<5, id: \.self) { i in
                BWStripes().frame(width: CX.patch(i).width, height: CX.patch(i).height).clipped()
                    .offset(x: CX.patch(i).minX, y: CX.patch(i).minY)
            }
            BWStripes().frame(width: CX.band.width, height: CX.band.height).clipped()
                .offset(x: CX.band.minX, y: CX.band.minY)
        }
    }
}

struct CtxGlass: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<5, id: \.self) { i in
                glassBox(CX.glass(i), Glass.regular, 20)
            }
            glassBox(CX.lower[0].1, Glass.regular, 20)
            glassBox(CX.lower[1].1, Glass.regular, 20)
            glassBox(CX.lower[2].1, Glass.regular, 20)
            glassBox(CX.lower[3].1, Glass.regular, 20)
            glassBox(CX.lower[4].1, Glass.clear, 20)
        }
    }
}

/// Page "bisect": variants of the `sizes` page (see macos.md 3.9) that remove one difference at a
/// time: no clear shapes, one shape alone, another position, equal sizes, stripes only in a band,
/// stripes only in patches. Variant 0 is the sizes page itself (the control).
enum BX {
    static let count = 7
    static func shapes(_ v: Int) -> [(CGRect, CGFloat, Bool)] {
        var res: [(CGRect, CGFloat, Bool)] = []
        let sizesRegular = (0..<5).map { (GL.sizeRect($0, clear: false), GL.sizeSpecs[$0].2, false) }
        switch v {
        case 0:
            res = sizesRegular
            for i in 0..<5 { res.append((GL.sizeRect(i, clear: true), GL.sizeSpecs[i].2, true)) }
        case 2:
            res = [sizesRegular[2]]
        case 3:
            res = [(CGRect(x: 225, y: 38, width: 120, height: 64), 20, false)]
        case 4:
            for i in 0..<5 { res.append((CGRect(x: 30 + 160 * CGFloat(i), y: 70, width: 120, height: 64), 20, false)) }
        default:
            res = sizesRegular
        }
        return res
    }
    static func stripeRects(_ v: Int) -> [CGRect] {
        switch v {
        case 5: return [CGRect(x: 0, y: 0, width: 1000, height: 300)]
        case 6: return shapes(v).map { $0.0.insetBy(dx: -40, dy: -40) }
        default: return [CGRect(x: 0, y: 0, width: 1000, height: 600)]
        }
    }
}

struct BisectTiles: View {
    let v: Int
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(BX.stripeRects(v).enumerated()), id: \.offset) { _, r in
                BWStripes().frame(width: r.width, height: r.height).clipped().offset(x: r.minX, y: r.minY)
            }
        }
    }
}

struct BisectGlass: View {
    let v: Int
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(BX.shapes(v).enumerated()), id: \.offset) { _, sp in
                glassBox(sp.0, sp.2 ? Glass.clear : Glass.regular, sp.1)
            }
        }
    }
}

struct GlassPage: View {
    let kind: String
    let panels: Bool
    let glass: Bool
    var v: Int = 0
    var body: some View {
        ZStack(alignment: .topLeading) {
            if panels {
                if kind == "grid" { GridTiles() } else if kind == "sizes" { SizesTiles() } else if kind == "adapt" { AdaptTiles() } else if kind == "ctx" { CtxTiles() } else if kind == "bisect" { BisectTiles(v: v) } else { MiscPanels() }
            }
            if glass {
                if kind == "grid" { GridGlass() } else if kind == "sizes" { SizesGlass() } else if kind == "adapt" { AdaptGlass() } else if kind == "ctx" { CtxGlass() } else if kind == "bisect" { BisectGlass(v: v) } else { MiscGlass() }
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
    var adapt: [[String: Any]] = []
    for i in 0..<10 {
        var d: [String: Any] = ["name": GL.adaptNames[i]]
        d["tile"] = rj(GL.tile(i / 5, i % 5))
        d["glass"] = rj(GL.glassRect(i / 5, i % 5))
        adapt.append(d)
    }
    L["adapt"] = adapt
    var ctx: [[String: Any]] = []
    for i in 0..<5 {
        var d: [String: Any] = ["name": "patch_margin_\(Int(CX.margins[i]))"]
        d["glass"] = rj(CX.glass(i))
        d["patch"] = rj(CX.patch(i))
        ctx.append(d)
    }
    for (n, r, clear) in CX.lower {
        var d: [String: Any] = ["name": n, "kind": clear ? "clear" : "regular"]
        d["glass"] = rj(r)
        ctx.append(d)
    }
    L["ctx"] = ctx
    var bisect: [[String: Any]] = []
    for v in 0..<BX.count {
        var shapes: [[String: Any]] = []
        for (r, radius, clear) in BX.shapes(v) {
            var d: [String: Any] = ["kind": clear ? "clear" : "regular", "radius": Double(radius)]
            d["rect"] = rj(r)
            shapes.append(d)
        }
        var d: [String: Any] = ["v": v, "shapes": shapes]
        d["stripes"] = BX.stripeRects(v).map { rj($0) }
        bisect.append(d)
    }
    L["bisect"] = bisect
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
    host.rootView = GlassPage(kind: "adapt", panels: true, glass: true)
    await ctx.pause(2.0)
    ctx.shot("in-adapt")
    host.rootView = GlassPage(kind: "ctx", panels: true, glass: true)
    await ctx.pause(2.0)
    ctx.shot("in-ctx")
    for v in 0..<BX.count {
        host.rootView = GlassPage(kind: "bisect", panels: true, glass: true, v: v)
        await ctx.pause(2.0)
        ctx.shot("in-bisect\(v)")
    }
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
    ovHost.rootView = GlassPage(kind: "adapt", panels: false, glass: false)
    bdHost.rootView = GlassPage(kind: "adapt", panels: true, glass: false)
    await ctx.pause(1.5)
    ctx.shot("ctl-adapt")
    ovHost.rootView = GlassPage(kind: "ctx", panels: false, glass: false)
    bdHost.rootView = GlassPage(kind: "ctx", panels: true, glass: false)
    await ctx.pause(1.5)
    ctx.shot("ctl-ctx")
    for v in 0..<BX.count {
        ovHost.rootView = GlassPage(kind: "bisect", panels: false, glass: false, v: v)
        bdHost.rootView = GlassPage(kind: "bisect", panels: true, glass: false, v: v)
        await ctx.pause(1.5)
        ctx.shot("ctl-bisect\(v)")
    }
}


/// Is the regular glass's tone over full-window stripes a function of TIME or of history? One
/// page (the lone 120 x 64 of bisect variant 2) is captured at several delays after it appears,
/// first in a fresh process, then after a flat page, then again; the shot names carry the delay.
@MainActor
func scene_glasstime(_ ctx: Ctx) async {
    ctx.notes["layout"] = glassLayout()
    ctx.notes["origin"] = ["x": 12.0, "y": 44.0]
    let inw = ctx.borderless("inwindow", 12, 44, 1000, 600, opaque: true)
    inw.backgroundColor = gray(60)
    let host = NSHostingView(rootView: GlassPage(kind: "bisect", panels: true, glass: true, v: 2))
    inw.contentView = host
    inw.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    var clock: [String: Any] = [:]
    func series(_ tag: String) async {
        let start = Date()
        for delay in [0.2, 0.6, 1.2, 2.5, 5.0, 9.0] {
            let wait = delay - Date().timeIntervalSince(start)
            if wait > 0 { await ctx.pause(wait) }
            let name = "\(tag)-\(Int(delay * 10))"
            ctx.shot(name)
            clock[name] = Date().timeIntervalSince(start)
        }
    }
    await series("fresh")
    host.rootView = GlassPage(kind: "adapt", panels: true, glass: true)
    await ctx.pause(3.0)
    ctx.shot("flat-page")
    host.rootView = GlassPage(kind: "bisect", panels: true, glass: true, v: 2)
    await series("again")
    host.rootView = GlassPage(kind: "bisect", panels: true, glass: true, v: 1)
    await series("v1")
    ctx.notes["clock"] = clock
}
