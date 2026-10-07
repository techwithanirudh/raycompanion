import AppKit

let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
let background = NSGradient(starting: NSColor(white: 0.88, alpha: 1), ending: NSColor(white: 0.99, alpha: 1))!
background.draw(in: tile, angle: 90)
NSColor.white.withAlphaComponent(0.8).setStroke()
tile.lineWidth = 3
tile.stroke()

let mark = NSBezierPath()
for (x, y, height) in [(360.0, 280.0, 460.0), (550.0, 330.0, 280.0)] {
    let beam = NSBezierPath(roundedRect: NSRect(x: x - 65, y: y, width: 130, height: height), xRadius: 65, yRadius: 65)
    let transform = AffineTransform(translationByX: -512, byY: -512)
    beam.transform(using: transform)
    var rotation = AffineTransform()
    rotation.rotate(byDegrees: -38)
    beam.transform(using: rotation)
    beam.transform(using: AffineTransform(translationByX: 512, byY: 512))
    mark.append(beam)
}
mark.transform(using: AffineTransform(translationByX: 512 - mark.bounds.midX, byY: 512 - mark.bounds.midY))
let color = NSGradient(starting: NSColor(red: 0.98, green: 0.22, blue: 0.30, alpha: 1), ending: NSColor(red: 1, green: 0.54, blue: 0.32, alpha: 1))!
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(red: 0.65, green: 0.18, blue: 0.17, alpha: 0.13)
shadow.shadowBlurRadius = 12
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
color.draw(in: mark, angle: 75)
NSGraphicsContext.restoreGraphicsState()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
if CommandLine.arguments.count > 2 {
    let glyph = NSImage(size: NSSize(width: 256, height: 256))
    glyph.lockFocus()
    let shape = mark.copy() as! NSBezierPath
    shape.transform(using: AffineTransform(translationByX: -shape.bounds.midX, byY: -shape.bounds.midY))
    shape.transform(using: AffineTransform(scale: 224 / max(mark.bounds.width, mark.bounds.height)))
    shape.transform(using: AffineTransform(translationByX: 128, byY: 128))
    NSColor.black.setFill()
    shape.fill()
    glyph.unlockFocus()
    let data = NSBitmapImageRep(data: glyph.tiffRepresentation!)!
    try data.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
