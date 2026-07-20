import AppKit
import CoreGraphics

// AgentBoard icon: three frosted kanban columns on deep charcoal,
// one accent-orange card lifted mid-drag. Full-bleed square; the OS
// applies the squircle mask on macOS 26 / iOS 26.

func draw(in ctx: CGContext, size: CGFloat) {
    let s = size / 1024.0
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        // y given from top in 1024-space; convert to CG bottom-origin
        CGRect(x: x * s, y: (1024 - y - h) * s, width: w * s, height: h * s)
    }
    func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius * s, cornerHeight: radius * s, transform: nil)
    }

    // Background: vertical gradient, deep charcoal with a faint blue cast
    let colors = [
        CGColor(red: 0.190, green: 0.195, blue: 0.225, alpha: 1),
        CGColor(red: 0.085, green: 0.085, blue: 0.105, alpha: 1),
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

    // Soft radial glow behind the glyph (upper center)
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [CGColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 0.10),
                                   CGColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 0.0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512 * s, y: 600 * s), startRadius: 0,
                           endCenter: CGPoint(x: 512 * s, y: 600 * s), endRadius: 520 * s, options: [])

    // Columns: top-aligned frosted bars, staggered heights
    let colW: CGFloat = 204
    let gap: CGFloat = 56
    let totalW = colW * 3 + gap * 2
    let x0 = (1024 - totalW) / 2
    let topY: CGFloat = 236
    let heights: [CGFloat] = [420, 552, 420]
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    for (i, h) in heights.enumerated() {
        let rect = r(x0 + CGFloat(i) * (colW + gap), topY, colW, h)
        ctx.addPath(rounded(rect, 52))
        ctx.fillPath()
    }

    // Cards inside columns (white, slightly translucent)
    let cardInset: CGFloat = 26
    let cardW = colW - cardInset * 2
    let cardH: CGFloat = 108
    let cardGap: CGFloat = 26
    let cardCounts = [2, 2, 1]
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.88))
    for (i, count) in cardCounts.enumerated() {
        let cx = x0 + CGFloat(i) * (colW + gap) + cardInset
        for j in 0..<count {
            // middle column: leave the top slot EMPTY (the orange card is lifted out of it)
            let slot = (i == 1) ? j + 1 : (i == 2 ? j + 1 : j)
            let cy = topY + cardInset + CGFloat(slot) * (cardH + cardGap)
            ctx.addPath(rounded(r(cx, cy, cardW, cardH), 30))
            ctx.fillPath()
        }
    }

    // Empty slot outline in middle column (where the orange card came from)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.28))
    ctx.setLineWidth(6 * s)
    ctx.setLineDash(phase: 0, lengths: [18 * s, 14 * s])
    let slotRect = r(x0 + colW + gap + cardInset, topY + cardInset, cardW, cardH)
    ctx.addPath(rounded(slotRect, 30))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    // The lifted accent card: larger, tilted, floating above the middle/right gap
    ctx.saveGState()
    let liftW: CGFloat = 248, liftH: CGFloat = 158
    let liftCX = (512 + 152) * s
    let liftCY = (1024 - 300) * s   // center y in CG coords (300 from top)
    ctx.translateBy(x: liftCX, y: liftCY)
    ctx.rotate(by: -8 * .pi / 180)
    let liftRect = CGRect(x: -liftW / 2 * s, y: -liftH / 2 * s, width: liftW * s, height: liftH * s)
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * s), blur: 44 * s,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.setFillColor(CGColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1))   // #FF9500
    ctx.addPath(CGPath(roundedRect: liftRect, cornerWidth: 36 * s, cornerHeight: 36 * s, transform: nil))
    ctx.fillPath()
    // subtle top highlight on the card
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.addPath(CGPath(roundedRect: CGRect(x: -liftW / 2 * s + 18 * s, y: liftH / 2 * s - 46 * s,
                                           width: (liftW - 36) * s, height: 26 * s),
                       cornerWidth: 13 * s, cornerHeight: 13 * s, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in sizes {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(in: ctx, size: CGFloat(px))
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("rendered \(sizes.count) files to \(outDir)")
