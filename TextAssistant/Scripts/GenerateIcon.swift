#!/usr/bin/env swift

import AppKit
import CoreGraphics

// Icon sizes needed for macOS
let iconSizes: [(Int, String)] = [
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

func createIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = CGFloat(size) / 1024.0

    // Background - dark gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0),
        CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        // Rounded rectangle background
        let cornerRadius = CGFloat(size) * 0.22
        let bgPath = CGPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        context.addPath(bgPath)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: 0, y: 0), options: [])
        context.resetClip()

        // Subtle border
        context.setStrokeColor(CGColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.5))
        context.setLineWidth(2 * scale)
        context.addPath(bgPath)
        context.strokePath()
    }

    // Chat bubble - main shape
    let bubbleWidth = CGFloat(size) * 0.6
    let bubbleHeight = CGFloat(size) * 0.45
    let bubbleX = (CGFloat(size) - bubbleWidth) / 2
    let bubbleY = CGFloat(size) * 0.35
    let bubbleRect = CGRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight)
    let bubbleRadius = bubbleHeight * 0.35

    // Bubble gradient (accent color - blue/purple)
    let bubbleGradientColors = [
        CGColor(red: 0.4, green: 0.5, blue: 0.95, alpha: 1.0),
        CGColor(red: 0.3, green: 0.35, blue: 0.85, alpha: 1.0)
    ] as CFArray

    if let bubbleGradient = CGGradient(colorsSpace: colorSpace, colors: bubbleGradientColors, locations: gradientLocations) {
        let bubblePath = CGPath(roundedRect: bubbleRect, cornerWidth: bubbleRadius, cornerHeight: bubbleRadius, transform: nil)

        context.saveGState()
        context.addPath(bubblePath)
        context.clip()
        context.drawLinearGradient(bubbleGradient, start: CGPoint(x: bubbleX, y: bubbleY + bubbleHeight), end: CGPoint(x: bubbleX, y: bubbleY), options: [])
        context.restoreGState()
    }

    // Chat bubble tail
    let tailSize = CGFloat(size) * 0.08
    let tailX = bubbleX + bubbleWidth * 0.2
    let tailY = bubbleY

    context.setFillColor(CGColor(red: 0.35, green: 0.42, blue: 0.9, alpha: 1.0))
    context.move(to: CGPoint(x: tailX, y: tailY))
    context.addLine(to: CGPoint(x: tailX + tailSize, y: tailY))
    context.addLine(to: CGPoint(x: tailX, y: tailY - tailSize * 0.8))
    context.closePath()
    context.fillPath()

    // Text lines inside bubble (representing text)
    let lineHeight = CGFloat(size) * 0.035
    let lineSpacing = CGFloat(size) * 0.055
    let lineStartX = bubbleX + bubbleWidth * 0.15
    let lineStartY = bubbleY + bubbleHeight * 0.65
    let lineWidths: [CGFloat] = [0.7, 0.5, 0.6]

    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))

    for (index, widthRatio) in lineWidths.enumerated() {
        let lineWidth = bubbleWidth * widthRatio * 0.7
        let lineY = lineStartY - CGFloat(index) * lineSpacing
        let lineRect = CGRect(x: lineStartX, y: lineY, width: lineWidth, height: lineHeight)
        let linePath = CGPath(roundedRect: lineRect, cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil)
        context.addPath(linePath)
        context.fillPath()
    }

    // Sparkle/AI indicator (small star)
    let starX = bubbleX + bubbleWidth * 0.85
    let starY = bubbleY + bubbleHeight * 0.85
    let starSize = CGFloat(size) * 0.08

    // Star gradient
    let starGradientColors = [
        CGColor(red: 0.95, green: 0.85, blue: 0.4, alpha: 1.0),
        CGColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
    ] as CFArray

    // Draw 4-point star
    context.saveGState()
    context.translateBy(x: starX, y: starY)

    let starPath = CGMutablePath()
    let points = 4
    let innerRadius = starSize * 0.3
    let outerRadius = starSize

    for i in 0..<(points * 2) {
        let radius = i % 2 == 0 ? outerRadius : innerRadius
        let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
        let x = cos(angle) * radius
        let y = sin(angle) * radius

        if i == 0 {
            starPath.move(to: CGPoint(x: x, y: y))
        } else {
            starPath.addLine(to: CGPoint(x: x, y: y))
        }
    }
    starPath.closeSubpath()

    context.addPath(starPath)
    context.setFillColor(CGColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 1.0))
    context.fillPath()

    context.restoreGState()

    image.unlockFocus()
    return image
}

// Create output directory
let outputDir = "TextAssistant/Resources/AppIcon.iconset"
let fileManager = FileManager.default

// Generate all icon sizes
for (size, filename) in iconSizes {
    let icon = createIcon(size: size)

    guard let tiffData = icon.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(filename)")
        continue
    }

    let outputPath = "\(outputDir)/\(filename)"
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Created: \(filename) (\(size)x\(size))")
    } catch {
        print("Failed to write \(filename): \(error)")
    }
}

print("\nIcon set generated! Run: iconutil -c icns \(outputDir)")
