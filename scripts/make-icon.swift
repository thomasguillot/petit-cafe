#!/usr/bin/env swift
//
// Generates every icon Petit Café ships, with CoreGraphics: no Icon Composer, no external tools.
// Deterministic and re-runnable: `swift scripts/make-icon.swift`.
//
//   App/Sources/Assets.xcassets/AppIcon.appiconset      10 PNGs, the cup with its steam
//   App/Sources/Assets.xcassets/MenuBarIconOn.imageset  template cup with steam (keeping awake)
//   App/Sources/Assets.xcassets/MenuBarIconOff.imageset template cup without steam (Mac can sleep)
//   site/assets/icon.png                                512px copy of the app icon
//
// The glyph is read from App/Icon/petit-cafe-glyph.svg, whose two paths carry the ids `cup` and
// `steam`. Edit that file to tweak the drawing; only absolute M, L, H, V, C and Z
// commands are understood.
//
// The app icon's rounded rect is full-bleed with a corner radius of 0.224 of the canvas, the same
// shape Hosts Switchr and Natalie ship, so the apps read at a consistent size in the Dock.

import AppKit
import CoreGraphics
import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let glyphURL = repoRoot.appendingPathComponent("App/Icon/petit-cafe-glyph.svg")
let assetsDir = repoRoot.appendingPathComponent("App/Sources/Assets.xcassets")
let siteAssetsDir = repoRoot.appendingPathComponent("site/assets")

let groundTopHex = "2B4D40"
let groundBottomHex = "17332A"
let glyphHex = "F3EDDA"

let iconCornerRadiusRatio: CGFloat = 0.224
let glyphSizeRatio: CGFloat = 0.58
let glyphViewBox: CGFloat = 24
let menuBarViewBoxInset: CGFloat = 1
let glyphSourceStrokeWidth: CGFloat = 1.5
let menuBarPointSize = 18

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func color(fromHex hex: String) -> CGColor {
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)
    return CGColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1)
}

// MARK: - Glyph

guard let glyphSource = try? String(contentsOf: glyphURL, encoding: .utf8) else {
    fail("could not read \(glyphURL.path)")
}

func pathData(id: String) -> String {
    let pattern = "id=\"\(id)\"\\s+d=\"([^\"]+)\""
    guard
        let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(
            in: glyphSource, range: NSRange(glyphSource.startIndex..., in: glyphSource)),
        let range = Range(match.range(at: 1), in: glyphSource)
    else { fail("no path with id \"\(id)\" in \(glyphURL.lastPathComponent)") }
    return String(glyphSource[range])
}

/// Parses an SVG path in viewBox units (y-down). Absolute M, L, H, V, C and Z only.
func parsePath(_ data: String) -> CGPath {
    guard let tokenizer = try? NSRegularExpression(pattern: "[A-Za-z]|-?\\d*\\.?\\d+") else {
        fail("could not build the path tokenizer")
    }
    let tokens = tokenizer.matches(in: data, range: NSRange(data.startIndex..., in: data))
        .compactMap { Range($0.range, in: data).map { String(data[$0]) } }

    let path = CGMutablePath()
    var command = ""
    var numbers: [CGFloat] = []

    func flush() {
        let current = path.isEmpty ? .zero : path.currentPoint
        switch command {
        case "M":
            guard numbers.count >= 2 else { return }
            path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            for i in stride(from: 2, to: numbers.count - 1, by: 2) {
                path.addLine(to: CGPoint(x: numbers[i], y: numbers[i + 1]))
            }
        case "L":
            for i in stride(from: 0, to: numbers.count - 1, by: 2) {
                path.addLine(to: CGPoint(x: numbers[i], y: numbers[i + 1]))
            }
        case "H":
            for x in numbers { path.addLine(to: CGPoint(x: x, y: current.y)) }
        case "V":
            for y in numbers { path.addLine(to: CGPoint(x: current.x, y: y)) }
        case "C":
            for i in stride(from: 0, to: numbers.count - 5, by: 6) {
                path.addCurve(
                    to: CGPoint(x: numbers[i + 4], y: numbers[i + 5]),
                    control1: CGPoint(x: numbers[i], y: numbers[i + 1]),
                    control2: CGPoint(x: numbers[i + 2], y: numbers[i + 3]))
            }
        case "Z":
            path.closeSubpath()
        default:
            break
        }
        numbers = []
    }

    for token in tokens {
        if let value = Double(token) {
            numbers.append(CGFloat(value))
        } else {
            guard "MLHVCZ".contains(token) else {
                fail("unsupported path command \"\(token)\" in \(glyphURL.lastPathComponent); use absolute M, L, H, V, C, Z")
            }
            flush()
            command = token
        }
    }
    flush()
    return path
}

func glyph(_ ids: [String]) -> CGPath {
    let path = CGMutablePath()
    for id in ids { path.addPath(parsePath(pathData(id: id))) }
    return path
}

let steamingCup = glyph(["cup", "steam"])
let plainCup = glyph(["cup"])

/// Maps a glyph from viewBox units (y-down) into a y-up canvas.
func placed(_ path: CGPath, scale: CGFloat, originX: CGFloat, topY: CGFloat) -> CGPath {
    var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: originX, ty: topY)
    return path.copy(using: &transform) ?? path
}

func makeContext(pixelSize: Int) -> CGContext {
    guard
        let ctx = CGContext(
            data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fail("could not create a \(pixelSize)px bitmap") }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    return ctx
}

// MARK: - Rendering

func renderAppIcon(pixelSize: Int) -> CGImage {
    let size = CGFloat(pixelSize)
    let ctx = makeContext(pixelSize: pixelSize)

    let radius = size * iconCornerRadiusRatio
    ctx.saveGState()
    ctx.addPath(
        CGPath(
            roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerWidth: radius,
            cornerHeight: radius, transform: nil))
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(fromHex: groundTopHex), color(fromHex: groundBottomHex)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: size / 2, y: size), end: CGPoint(x: size / 2, y: 0), options: [])
    ctx.restoreGState()

    let bounds = steamingCup.boundingBoxOfPath
    let scale = size * glyphSizeRatio / max(bounds.width, bounds.height)
    ctx.addPath(
        placed(
            steamingCup, scale: scale, originX: size / 2 - bounds.midX * scale,
            topY: size / 2 + bounds.midY * scale))
    ctx.setStrokeColor(color(fromHex: glyphHex))
    ctx.setLineWidth(glyphSourceStrokeWidth * scale)
    ctx.strokePath()

    return ctx.makeImage()!
}

/// The glyph keeps its viewBox position, so the cup does not move when the steam comes and goes.
/// The viewBox's empty margin is cropped so the cup fills the menu bar's height.
func renderMenuBarIcon(_ path: CGPath, pixelSize: Int) -> CGImage {
    let size = CGFloat(pixelSize)
    let ctx = makeContext(pixelSize: pixelSize)
    let scale = size / (glyphViewBox - 2 * menuBarViewBoxInset)
    let inset = menuBarViewBoxInset * scale

    ctx.addPath(placed(path, scale: scale, originX: -inset, topY: size + inset))
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.setLineWidth(glyphSourceStrokeWidth * scale)
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fail("could not encode \(url.lastPathComponent)")
    }
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    } catch {
        fail("could not write \(url.path): \(error.localizedDescription)")
    }
}

func writeText(_ text: String, to url: URL) {
    do {
        try text.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fail("could not write \(url.path): \(error.localizedDescription)")
    }
}

// MARK: - App icon

struct IconSpec { let pointSize: Int, scale: Int, filename: String }

let iconSpecs: [IconSpec] = [
    IconSpec(pointSize: 16, scale: 1, filename: "icon_16x16.png"),
    IconSpec(pointSize: 16, scale: 2, filename: "icon_16x16@2x.png"),
    IconSpec(pointSize: 32, scale: 1, filename: "icon_32x32.png"),
    IconSpec(pointSize: 32, scale: 2, filename: "icon_32x32@2x.png"),
    IconSpec(pointSize: 128, scale: 1, filename: "icon_128x128.png"),
    IconSpec(pointSize: 128, scale: 2, filename: "icon_128x128@2x.png"),
    IconSpec(pointSize: 256, scale: 1, filename: "icon_256x256.png"),
    IconSpec(pointSize: 256, scale: 2, filename: "icon_256x256@2x.png"),
    IconSpec(pointSize: 512, scale: 1, filename: "icon_512x512.png"),
    IconSpec(pointSize: 512, scale: 2, filename: "icon_512x512@2x.png"),
]

let appIconDir = assetsDir.appendingPathComponent("AppIcon.appiconset")
print("Rendering AppIcon.appiconset:")
for spec in iconSpecs {
    let pixelSize = spec.pointSize * spec.scale
    writePNG(renderAppIcon(pixelSize: pixelSize), to: appIconDir.appendingPathComponent(spec.filename))
    print("  \(spec.filename) (\(pixelSize)×\(pixelSize))")
}

let appIconImages = iconSpecs.map {
    "    {\"size\":\"\($0.pointSize)x\($0.pointSize)\",\"idiom\":\"mac\",\"filename\":\"\($0.filename)\",\"scale\":\"\($0.scale)x\"}"
}.joined(separator: ",\n")
writeText(
    """
    {
      "images" : [
    \(appIconImages)
      ],
      "info" : { "version" : 1, "author" : "xcode" }
    }

    """, to: appIconDir.appendingPathComponent("Contents.json"))

// MARK: - Menu bar icons

func writeMenuBarIcon(named name: String, path: CGPath) {
    let dir = assetsDir.appendingPathComponent("\(name).imageset")
    print("\nRendering \(name).imageset:")
    for scale in 1...2 {
        let filename = scale == 1 ? "menubar.png" : "menubar@\(scale)x.png"
        let pixelSize = menuBarPointSize * scale
        writePNG(renderMenuBarIcon(path, pixelSize: pixelSize), to: dir.appendingPathComponent(filename))
        print("  \(filename) (\(pixelSize)×\(pixelSize))")
    }
    writeText(
        """
        {
          "images" : [
            {"idiom":"universal","filename":"menubar.png","scale":"1x"},
            {"idiom":"universal","filename":"menubar@2x.png","scale":"2x"}
          ],
          "info" : { "version" : 1, "author" : "xcode" },
          "properties" : { "template-rendering-intent" : "template" }
        }

        """, to: dir.appendingPathComponent("Contents.json"))
}

writeMenuBarIcon(named: "MenuBarIconOn", path: steamingCup)
writeMenuBarIcon(named: "MenuBarIconOff", path: plainCup)

// MARK: - Site icon

print("\nRendering site/assets:")
writePNG(renderAppIcon(pixelSize: 512), to: siteAssetsDir.appendingPathComponent("icon.png"))
print("  icon.png (512×512)")

print("\nDone.")
