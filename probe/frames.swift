// Extract frames from a simulator screen recording: frames <video> <outdir> <fps> <scale>
// Writes outdir/f0000.png ... at `fps`, scaled by `scale`, and prints the count.
import AppKit
import AVFoundation

let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let outDir = a[2]
let fps = Double(a[3]) ?? 30
let scale = Double(a[4]) ?? 1.0 / 3
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.appliesPreferredTrackTransform = true
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let duration = CMTimeGetSeconds(asset.duration)
var i = 0
while Double(i) / fps < duration {
    let t = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)
    if let cg = try? gen.copyCGImage(at: t, actualTime: nil) {
        let w = Int(Double(cg.width) * scale), h = Int(Double(cg.height) * scale)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try? rep.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: String(format: "%@/f%04d.png", outDir, i)))
    }
    i += 1
}
print("frames \(i) duration \(duration)")
