#!/usr/bin/env swift

import AppKit

let arguments = CommandLine.arguments
let outputPath: String
if arguments.count > 1 {
    outputPath = arguments[1]
} else {
    outputPath = FileManager.default.currentDirectoryPath
}

let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)

func scaled(_ value: CGFloat, scale: CGFloat) -> CGFloat {
    return value * scale / 512.0
}

func createGradient(colors: [NSColor], locations: [CGFloat]) -> CGGradient {
    let cgColors = colors.map { $0.cgColor } as CFArray
    return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: locations)!
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to create graphics context")
    }

    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Background rounded square with gradient
    let bgRect = CGRect(x: scaled(48, scale: size),
                        y: scaled(48, scale: size),
                        width: scaled(416, scale: size),
                        height: scaled(416, scale: size))
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: scaled(96, scale: size), cornerHeight: scaled(96, scale: size), transform: nil)
    let bgGradient = createGradient(colors: [
        NSColor(calibratedRed: 0.424, green: 0.388, blue: 1.0, alpha: 1.0),
        NSColor(calibratedRed: 0.545, green: 0.361, blue: 1.0, alpha: 1.0),
        NSColor(calibratedRed: 1.0, green: 0.396, blue: 0.518, alpha: 1.0)
    ], locations: [0.0, 0.5, 1.0])
    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(bgGradient,
                               start: CGPoint(x: bgRect.minX, y: bgRect.maxY),
                               end: CGPoint(x: bgRect.maxX, y: bgRect.minY),
                               options: [])
    context.restoreGState()

    // Screen rectangle with gradient
    let screenRect = CGRect(x: scaled(132, scale: size),
                            y: scaled(148, scale: size),
                            width: scaled(248, scale: size),
                            height: scaled(176, scale: size))
    let screenPath = CGPath(roundedRect: screenRect, cornerWidth: scaled(36, scale: size), cornerHeight: scaled(36, scale: size), transform: nil)
    let screenGradient = createGradient(colors: [
        NSColor(calibratedRed: 0.184, green: 0.145, blue: 0.416, alpha: 1.0),
        NSColor(calibratedRed: 0.106, green: 0.071, blue: 0.243, alpha: 1.0)
    ], locations: [0.0, 1.0])
    context.saveGState()
    context.addPath(screenPath)
    context.clip()
    context.drawLinearGradient(screenGradient,
                               start: CGPoint(x: screenRect.minX, y: screenRect.maxY),
                               end: CGPoint(x: screenRect.maxX, y: screenRect.minY),
                               options: [])
    context.restoreGState()

    context.setStrokeColor(NSColor(calibratedRed: 0.836, green: 0.784, blue: 1.0, alpha: 0.4).cgColor)
    context.setLineWidth(scaled(6, scale: size))
    context.addPath(screenPath)
    context.strokePath()

    // Wave path representing signal
    let wavePath = CGMutablePath()
    wavePath.move(to: CGPoint(x: scaled(168, scale: size), y: scaled(208, scale: size)))
    wavePath.addCurve(to: CGPoint(x: scaled(286, scale: size), y: scaled(210, scale: size)),
                      control1: CGPoint(x: scaled(208, scale: size), y: scaled(188, scale: size)),
                      control2: CGPoint(x: scaled(246, scale: size), y: scaled(188, scale: size)))
    wavePath.addCurve(to: CGPoint(x: scaled(374, scale: size), y: scaled(204, scale: size)),
                      control1: CGPoint(x: scaled(316, scale: size), y: scaled(226, scale: size)),
                      control2: CGPoint(x: scaled(342, scale: size), y: scaled(224, scale: size)))

    context.addPath(wavePath)
    context.setStrokeColor(NSColor(calibratedRed: 0.548, green: 0.482, blue: 1.0, alpha: 0.65).cgColor)
    context.setLineWidth(scaled(12, scale: size))
    context.setLineCap(.round)
    context.strokePath()

    // Soft glow ellipse
    context.saveGState()
    let glowRect = CGRect(x: scaled(166, scale: size),
                          y: scaled(166, scale: size),
                          width: scaled(180, scale: size),
                          height: scaled(144, scale: size))
    context.translateBy(x: glowRect.midX, y: glowRect.midY)
    context.scaleBy(x: glowRect.width / 2, y: glowRect.height / 2)
    let glowGradient = createGradient(colors: [
        NSColor(calibratedRed: 0.637, green: 0.535, blue: 1.0, alpha: 0.9),
        NSColor(calibratedRed: 0.637, green: 0.535, blue: 1.0, alpha: 0.0)
    ], locations: [0.0, 1.0])
    context.drawRadialGradient(glowGradient,
                               startCenter: CGPoint.zero,
                               startRadius: 0,
                               endCenter: CGPoint.zero,
                               endRadius: 1,
                               options: [])
    context.restoreGState()

    // Camera lens shadow
    let shadowCircle = CGRect(x: scaled(320, scale: size),
                              y: scaled(312, scale: size),
                              width: scaled(136, scale: size),
                              height: scaled(136, scale: size))
    context.setFillColor(NSColor(calibratedRed: 0.066, green: 0.036, blue: 0.165, alpha: 0.56).cgColor)
    context.fillEllipse(in: shadowCircle)

    // Camera lens outer circle
    let lensOuter = shadowCircle.insetBy(dx: scaled(4, scale: size), dy: scaled(4, scale: size))
    let lensGradient = createGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.9),
        NSColor(calibratedRed: 0.725, green: 0.706, blue: 1.0, alpha: 0.75),
        NSColor(calibratedRed: 0.373, green: 0.251, blue: 1.0, alpha: 1.0)
    ], locations: [0.0, 0.45, 1.0])
    context.saveGState()
    context.addEllipse(in: lensOuter)
    context.clip()
    context.drawLinearGradient(lensGradient,
                               start: CGPoint(x: lensOuter.minX, y: lensOuter.maxY),
                               end: CGPoint(x: lensOuter.maxX, y: lensOuter.minY),
                               options: [])
    context.restoreGState()

    // Lens inner highlight
    let lensInner = CGRect(x: lensOuter.midX - scaled(36, scale: size),
                           y: lensOuter.midY - scaled(36, scale: size),
                           width: scaled(72, scale: size),
                           height: scaled(72, scale: size))
    let lensCore = createGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.95),
        NSColor(calibratedRed: 0.235, green: 0.165, blue: 1.0, alpha: 0.15)
    ], locations: [0.0, 1.0])
    context.saveGState()
    context.addEllipse(in: lensInner)
    context.clip()
    context.drawRadialGradient(lensCore,
                               startCenter: CGPoint(x: lensInner.midX, y: lensInner.midY),
                               startRadius: 0,
                               endCenter: CGPoint(x: lensInner.midX, y: lensInner.midY),
                               endRadius: lensInner.width / 2,
                               options: [])
    context.restoreGState()

    // Specular highlights
    context.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.45).cgColor)
    let topHighlight = CGRect(x: scaled(224, scale: size) - scaled(16, scale: size),
                              y: scaled(184, scale: size) - scaled(16, scale: size),
                              width: scaled(32, scale: size),
                              height: scaled(32, scale: size))
    context.fillEllipse(in: topHighlight)

    context.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.75).cgColor)
    let lensHighlight = CGRect(x: lensOuter.midX + scaled(12, scale: size) - scaled(12, scale: size),
                               y: lensOuter.midY + scaled(24, scale: size) - scaled(12, scale: size),
                               width: scaled(24, scale: size),
                               height: scaled(24, scale: size))
    context.fillEllipse(in: lensHighlight)

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }
    try pngData.write(to: url)
}

let iconOutputs: [(size: CGFloat, filename: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for entry in iconOutputs {
    let image = drawIcon(size: CGFloat(entry.size))
    let destination = outputURL.appendingPathComponent(entry.filename)
    do {
        try savePNG(image: image, to: destination)
        print("Saved \(entry.filename)")
    } catch {
        fputs("Failed to write \(entry.filename): \(error)\n", stderr)
        exit(1)
    }
}

print("Icon generation complete at \(outputURL.path)")
