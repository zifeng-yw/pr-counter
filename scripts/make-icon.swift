import AppKit

let canvasSize: CGFloat = 1024
let outputPath = CommandLine.arguments[1]

func hexColor(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvasSize), pixelsHigh: Int(canvasSize),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let artworkInset: CGFloat = 100
let artworkScale = canvasSize / (canvasSize - artworkInset * 2)
let artworkTransform = NSAffineTransform()
artworkTransform.scale(by: artworkScale)
artworkTransform.translateX(by: -artworkInset, yBy: -artworkInset)
artworkTransform.concat()

let barColors: [UInt32] = [0x0E4429, 0x006D32, 0x26A641, 0x39D353, 0x56E36A]
let barHeights: [CGFloat] = [150, 250, 340, 460, 590]
let barWidth: CGFloat = 96
let barGap: CGFloat = 36
let barBaseline: CGFloat = 200
for (index, barHeight) in barHeights.enumerated() {
    let barX = 200 + CGFloat(index) * (barWidth + barGap)
    let barRect = NSRect(x: barX, y: barBaseline, width: barWidth, height: barHeight)
    hexColor(barColors[index]).setFill()
    NSBezierPath(roundedRect: barRect, xRadius: 24, yRadius: 24).fill()
}

let glyphStroke: CGFloat = 26
let glyphRadius: CGFloat = 32
hexColor(0xF0F3F6).setStroke()
hexColor(0xF0F3F6).setFill()

func strokeCircle(center: NSPoint) {
    let circle = NSBezierPath(ovalIn: NSRect(x: center.x - glyphRadius, y: center.y - glyphRadius, width: glyphRadius * 2, height: glyphRadius * 2))
    circle.lineWidth = glyphStroke
    circle.stroke()
}

let leftX: CGFloat = 250
let rightX: CGFloat = 390
let topY: CGFloat = 800
let bottomY: CGFloat = 610
strokeCircle(center: NSPoint(x: leftX, y: topY))
strokeCircle(center: NSPoint(x: leftX, y: bottomY))
strokeCircle(center: NSPoint(x: rightX, y: bottomY))

let leftStem = NSBezierPath()
leftStem.lineWidth = glyphStroke
leftStem.lineCapStyle = .round
leftStem.move(to: NSPoint(x: leftX, y: topY - glyphRadius - glyphStroke / 2))
leftStem.line(to: NSPoint(x: leftX, y: bottomY + glyphRadius + glyphStroke / 2))
leftStem.stroke()

let arrowTipX: CGFloat = 318
let rightStem = NSBezierPath()
rightStem.lineWidth = glyphStroke
rightStem.lineCapStyle = .round
rightStem.lineJoinStyle = .round
rightStem.move(to: NSPoint(x: rightX, y: bottomY + glyphRadius + glyphStroke / 2))
rightStem.line(to: NSPoint(x: rightX, y: topY - 50))
rightStem.curve(to: NSPoint(x: rightX - 50, y: topY), controlPoint1: NSPoint(x: rightX, y: topY - 22), controlPoint2: NSPoint(x: rightX - 22, y: topY))
rightStem.line(to: NSPoint(x: arrowTipX + 20, y: topY))
rightStem.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: arrowTipX, y: topY))
arrowHead.line(to: NSPoint(x: arrowTipX + 46, y: topY + 38))
arrowHead.line(to: NSPoint(x: arrowTipX + 46, y: topY - 38))
arrowHead.close()
arrowHead.lineJoinStyle = .round
arrowHead.lineWidth = 10
arrowHead.fill()
arrowHead.stroke()

NSGraphicsContext.restoreGraphicsState()
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outputPath))
