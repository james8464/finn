import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func color(_ hex: UInt32) -> NSColor { NSColor(calibratedRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1) }
func line(_ points: [NSPoint], width: CGFloat, ink: NSColor) {
    let path=NSBezierPath(); path.lineWidth=width; path.lineCapStyle = .round; path.lineJoinStyle = .round
    path.move(to: points[0]); for p in points.dropFirst() { path.line(to:p) }
    ink.setStroke(); path.stroke()
}
func save(_ relative: String, size: Int, drawing: () -> Void) {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep); NSGraphicsContext.current?.imageInterpolation = .high
    drawing(); NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent(relative))
}
func fMark(_ ink: NSColor) { line([NSPoint(x:390,y:311),NSPoint(x:390,y:699),NSPoint(x:623,y:699)],width:61,ink:ink); line([NSPoint(x:390,y:519),NSPoint(x:565,y:519)],width:61,ink:ink) }
// Bitmap coordinates are bottom-up; SVG coordinates are top-down.
for (name,ink) in [("FinnMark.png", color(0x141414)),("FinnMark-Dark.png",NSColor.white)] {
  save("Finn/Finn/Assets.xcassets/FinnMark.imageset/\(name)",size:560) {
    let transform=AffineTransform(translationByX:-230,byY:-220)
    (transform as NSAffineTransform).concat()
    fMark(ink)
  }
}
save("Finn/BrandArtwork/AppIconPreview.png",size:1024) {
    NSColor.white.setFill(); NSRect(x:0,y:0,width:1024,height:1024).fill()
    line([NSPoint(x:210,y:704),NSPoint(x:210,y:814),NSPoint(x:320,y:814)],width:34,ink:color(0x141414))
    line([NSPoint(x:720,y:214),NSPoint(x:810,y:214),NSPoint(x:810,y:304)],width:34,ink:color(0x141414))
    fMark(color(0x141414))
}
