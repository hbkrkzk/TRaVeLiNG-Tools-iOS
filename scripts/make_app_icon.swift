import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let clip = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
clip.addClip()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.14, blue: 0.29, alpha: 1.0),
    NSColor(calibratedRed: 0.11, green: 0.45, blue: 0.85, alpha: 1.0)
])!
gradient.draw(in: rect, angle: -45)

let circle = NSBezierPath(ovalIn: NSRect(x: 160, y: 160, width: 704, height: 704))
NSColor(calibratedWhite: 1.0, alpha: 0.14).setFill()
circle.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let tAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 290, weight: .black),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
    .kern: -8
]
NSString(string: "T").draw(in: NSRect(x: 0, y: 330, width: size, height: 340), withAttributes: tAttrs)

let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 94, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.92),
    .paragraphStyle: paragraph,
    .kern: 1
]
NSString(string: "TOOLS").draw(in: NSRect(x: 0, y: 210, width: size, height: 140), withAttributes: subtitleAttrs)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Failed to render PNG")
}

let out = URL(fileURLWithPath: "/Users/traveling/Development/TRaVeLiNG-Tools_iOS/TRaVeLiNG-Tools_iOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try png.write(to: out)
print("Wrote \(out.path)")
