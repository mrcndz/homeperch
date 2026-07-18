// Renders AppIcon.png (1024x1024): house perched on a bar, macOS squircle style
// Run: swift Assets/genicon.swift
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

// macOS icon grid: content inset ~10%, corner radius ~22.4%
let inset = size * 0.1
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let squircle = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.224, cornerHeight: rect.width * 0.224, transform: nil)

ctx.addPath(squircle)
ctx.clip()
let colors = [
    NSColor(calibratedRed: 0.16, green: 0.47, blue: 0.96, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.65, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: size / 2, y: size - inset), end: CGPoint(x: size / 2, y: inset), options: [])

// Perch bar
let barY = rect.minY + rect.height * 0.22
ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
ctx.fill(CGRect(x: rect.minX + rect.width * 0.14, y: barY, width: rect.width * 0.72, height: rect.height * 0.045))

// House: body + roof + chimney, centered above the bar
let w = rect.width
let houseW = w * 0.44
let houseX = rect.midX - houseW / 2
let bodyY = barY + rect.height * 0.045
let bodyH = w * 0.26
let roofH = w * 0.20

ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: houseX, y: bodyY, width: houseW, height: bodyH))

let roof = CGMutablePath()
let overhang = w * 0.05
roof.move(to: CGPoint(x: houseX - overhang, y: bodyY + bodyH))
roof.addLine(to: CGPoint(x: rect.midX, y: bodyY + bodyH + roofH))
roof.addLine(to: CGPoint(x: houseX + houseW + overhang, y: bodyY + bodyH))
roof.closeSubpath()
ctx.addPath(roof)
ctx.fillPath()

// Chimney
ctx.fill(CGRect(x: houseX + houseW * 0.72, y: bodyY + bodyH + roofH * 0.35, width: w * 0.07, height: roofH * 0.55))

// "P" monogram punched into the house body in the gradient color
let pFont = NSFont.systemFont(ofSize: bodyH * 0.82, weight: .heavy)
let pAttrs: [NSAttributedString.Key: Any] = [
    .font: pFont,
    .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.32, blue: 0.75, alpha: 1),
]
let p = NSAttributedString(string: "P", attributes: pAttrs)
let pSize = p.size()
p.draw(at: CGPoint(x: rect.midX - pSize.width / 2, y: bodyY + (bodyH - pSize.height) / 2))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { fatalError() }
try! png.write(to: URL(fileURLWithPath: "Assets/AppIcon.png"))
print("Wrote Assets/AppIcon.png")
