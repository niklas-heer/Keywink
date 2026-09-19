#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let assetRoot = repositoryRoot
    .appendingPathComponent("Leader Key/Assets.xcassets")

private let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16px-16pt@1x.png", 16),
    ("icon_32px-16pt@2x.png", 32),
    ("icon_32px-32pt@1x.png", 32),
    ("icon_64px-32pt@2x.png", 64),
    ("icon_128px-128pt@1x.png", 128),
    ("icon_256px-128pt@2x.png", 256),
    ("icon_256px-128pt@2x 1.png", 256),
    ("icon_512px-256pt@2x.png", 512),
    ("icon_512px-512pt@1x.png", 512),
    ("icon_1024.png", 1024),
]

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func strokeCurve(
    in context: CGContext,
    from start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    to end: CGPoint,
    width: CGFloat,
    color: CGColor
) {
    context.beginPath()
    context.move(to: start)
    context.addCurve(to: end, control1: control1, control2: control2)
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.strokePath()
}

private func curvePath(
    from start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    to end: CGPoint
) -> CGPath {
    let path = CGMutablePath()
    path.move(to: start)
    path.addCurve(to: end, control1: control1, control2: control2)
    return path
}

private func drawAppIcon(in context: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let tile = CGRect(x: 72, y: 72, width: 880, height: 880)
    let tilePath = roundedRect(tile, radius: 210)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -30), blur: 54, color: color(0.06, 0.02, 0.16, 0.46))
    context.addPath(tilePath)
    context.setFillColor(color(0.18, 0.08, 0.42))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0.42, 0.13, 0.70), color(0.08, 0.57, 0.58)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 170, y: 900),
        end: CGPoint(x: 890, y: 120),
        options: []
    )

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0.66, 0.35, 0.91, 0.54), color(0.66, 0.35, 0.91, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 250, y: 780),
        startRadius: 0,
        endCenter: CGPoint(x: 250, y: 780),
        endRadius: 560,
        options: []
    )
    context.restoreGState()

    context.addPath(tilePath)
    context.setStrokeColor(color(1, 1, 1, 0.20))
    context.setLineWidth(8)
    context.strokePath()

    let keyBase = CGRect(x: 184, y: 205, width: 656, height: 594)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -26), blur: 36, color: color(0.06, 0.02, 0.20, 0.48))
    context.addPath(roundedRect(keyBase, radius: 148))
    context.setFillColor(color(0.18, 0.09, 0.35, 0.88))
    context.fillPath()
    context.restoreGState()

    let keyTop = CGRect(x: 184, y: 250, width: 656, height: 568)
    let keyTopPath = roundedRect(keyTop, radius: 148)
    context.saveGState()
    context.addPath(keyTopPath)
    context.clip()
    let keyGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(1, 1, 1), color(0.85, 0.90, 1)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        keyGradient,
        start: CGPoint(x: 512, y: 818),
        end: CGPoint(x: 512, y: 250),
        options: []
    )
    context.restoreGState()

    context.addPath(keyTopPath)
    context.setStrokeColor(color(1, 1, 1, 0.74))
    context.setLineWidth(10)
    context.strokePath()

    let ink = color(0.24, 0.11, 0.48)
    context.addEllipse(in: CGRect(x: 323, y: 518, width: 74, height: 92))
    context.setFillColor(ink)
    context.fillPath()

    strokeCurve(
        in: context,
        from: CGPoint(x: 563, y: 574),
        control1: CGPoint(x: 608, y: 616),
        control2: CGPoint(x: 670, y: 586),
        to: CGPoint(x: 704, y: 536),
        width: 38,
        color: ink
    )
    strokeCurve(
        in: context,
        from: CGPoint(x: 340, y: 428),
        control1: CGPoint(x: 418, y: 322),
        control2: CGPoint(x: 604, y: 306),
        to: CGPoint(x: 690, y: 420),
        width: 38,
        color: ink
    )
}

private func writePNG(size: Int, to url: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }
    drawAppIcon(in: context, pixels: size)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "IconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "IconGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not write \(url.path)"])
    }
}

private func drawStatusItem(in context: CGContext, filled: Bool) {
    let ink = color(0, 0, 0)
    let body = roundedRect(CGRect(x: 1.5, y: 2.3, width: 15, height: 13.4), radius: 3.4)
    let lip = CGPath(roundedRect: CGRect(x: 4.2, y: 1.1, width: 9.6, height: 3.2), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil)

    if filled {
        context.addPath(lip)
        context.setFillColor(ink)
        context.fillPath()

        let wink = curvePath(
            from: CGPoint(x: 9.7, y: 10.6),
            control1: CGPoint(x: 10.7, y: 11.5),
            control2: CGPoint(x: 12.1, y: 11.0),
            to: CGPoint(x: 12.8, y: 9.9)
        )
        let smile = curvePath(
            from: CGPoint(x: 5.2, y: 7.0),
            control1: CGPoint(x: 7.1, y: 4.6),
            control2: CGPoint(x: 11.2, y: 4.5),
            to: CGPoint(x: 13.0, y: 6.9)
        )
        let cutout = CGMutablePath()
        cutout.addPath(body)
        cutout.addEllipse(in: CGRect(x: 5.0, y: 9.2, width: 1.8, height: 2.2))
        cutout.addPath(wink.copy(strokingWithWidth: 1.15, lineCap: .round, lineJoin: .round, miterLimit: 10))
        cutout.addPath(smile.copy(strokingWithWidth: 1.15, lineCap: .round, lineJoin: .round, miterLimit: 10))
        context.addPath(cutout)
        context.drawPath(using: .eoFill)
    } else {
        context.addPath(lip)
        context.setFillColor(ink)
        context.fillPath()
        context.addPath(body)
        context.setStrokeColor(ink)
        context.setLineWidth(1.5)
        context.strokePath()
        context.addEllipse(in: CGRect(x: 5.0, y: 9.2, width: 1.8, height: 2.2))
        context.fillPath()
        strokeCurve(
            in: context,
            from: CGPoint(x: 9.7, y: 10.6),
            control1: CGPoint(x: 10.7, y: 11.5),
            control2: CGPoint(x: 12.1, y: 11.0),
            to: CGPoint(x: 12.8, y: 9.9),
            width: 1.15,
            color: ink
        )
        strokeCurve(
            in: context,
            from: CGPoint(x: 5.2, y: 7.0),
            control1: CGPoint(x: 7.1, y: 4.6),
            control2: CGPoint(x: 11.2, y: 4.5),
            to: CGPoint(x: 13.0, y: 6.9),
            width: 1.15,
            color: ink
        )
    }
}

private func writeStatusPDF(filled: Bool, to url: URL) throws {
    var mediaBox = CGRect(x: 0, y: 0, width: 18, height: 18)
    let fixedDate = Date(timeIntervalSince1970: 0)
    let metadata: CFDictionary = [
        kCGPDFContextCreator: "Keywink icon generator",
        "CreationDate" as CFString: fixedDate,
        "ModDate" as CFString: fixedDate,
    ] as CFDictionary
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, metadata) else {
        throw NSError(domain: "IconGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create PDF context"])
    }
    context.beginPDFPage(nil)
    drawStatusItem(in: context, filled: filled)
    context.endPDFPage()
    context.closePDF()
}

do {
    let appIconDirectory = assetRoot.appendingPathComponent("AppIcon.appiconset")
    for icon in iconFiles {
        try writePNG(size: icon.pixels, to: appIconDirectory.appendingPathComponent(icon.name))
    }

    try writeStatusPDF(
        filled: false,
        to: assetRoot.appendingPathComponent("StatusItem.imageset/StatusItem Copy.pdf")
    )
    try writeStatusPDF(
        filled: true,
        to: assetRoot.appendingPathComponent("StatusItem-filled.imageset/StatusItem-filled.pdf")
    )
    print("Generated Keywink app and status-item icons in \(assetRoot.path)")
} catch {
    fputs("Icon generation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
