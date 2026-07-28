import AppKit
import Foundation
import ImageIO

struct PixelBuffer {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

struct LayerSpec {
    let imageName: String
    let topColor: (Double, Double, Double, Double)
    let bottomColor: (Double, Double, Double, Double)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: build-icon.swift <AppIcon.iconset> <Generated.iconset>\n", stderr)
    exit(2)
}

let sourceIconset = URL(fileURLWithPath: arguments[1])
let outputIconset = URL(fileURLWithPath: arguments[2])
let iconDirectory = sourceIconset
    .appendingPathComponent("TorrServeGUI.icon", isDirectory: true)
let assetsDirectory = iconDirectory
    .appendingPathComponent("Assets", isDirectory: true)
let iconJSONURL = iconDirectory.appendingPathComponent("icon.json")
let preferredAppearance = ProcessInfo.processInfo.environment["TORRSERVER_ICON_APPEARANCE"] ?? "dark"

let iconJSON = try Data(contentsOf: iconJSONURL)
let specs = try loadLayerSpecs(from: iconJSON).reversed()
let canvas = try renderIcon(specs: Array(specs), assetsDirectory: assetsDirectory)
try writeIconset(from: canvas, to: outputIconset)

func loadLayerSpecs(from data: Data) throws -> [LayerSpec] {
    guard
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let groups = root["groups"] as? [[String: Any]]
    else {
        throw NSError(domain: "IconBuild", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Invalid icon.json"
        ])
    }

    return groups.flatMap { group -> [LayerSpec] in
        guard let layers = group["layers"] as? [[String: Any]] else { return [] }

        return layers.compactMap { layer in
            guard let imageName = layer["image-name"] as? String else { return nil }
            let colors = gradientColors(from: layer)
            return LayerSpec(
                imageName: imageName,
                topColor: colors.top,
                bottomColor: colors.bottom
            )
        }
    }
}

func gradientColors(
    from layer: [String: Any]
) -> (top: (Double, Double, Double, Double), bottom: (Double, Double, Double, Double)) {
    let specializedFill = fillSpecialization(
        from: layer["fill-specializations"] as? [[String: Any]],
        appearance: preferredAppearance
    )
    let baseFill = layer["fill"] as? [String: Any]
    let fill = specializedFill ?? baseFill
    let gradient = fill?["linear-gradient"] as? [String] ?? []
    var top = parseDisplayP3(gradient.first) ?? (0.25, 0.70, 0.30, 1)
    var bottom = parseDisplayP3(gradient.dropFirst().first) ?? top

    if preferredAppearance == "dark", specializedFill == nil, baseFill != nil {
        top = darkened(top)
        bottom = darkened(bottom)
    }

    return (top, bottom)
}

func fillSpecialization(
    from specializations: [[String: Any]]?,
    appearance: String
) -> [String: Any]? {
    guard let specializations else { return nil }

    if let match = specializations.first(where: { $0["appearance"] as? String == appearance }),
       let value = match["value"] as? [String: Any] {
        return value
    }

    return specializations.first?["value"] as? [String: Any]
}

func darkened(
    _ color: (Double, Double, Double, Double)
) -> (Double, Double, Double, Double) {
    (
        max(0, color.0 * 0.28),
        max(0, color.1 * 0.28),
        max(0, color.2 * 0.28),
        color.3
    )
}

func parseDisplayP3(_ value: String?) -> (Double, Double, Double, Double)? {
    guard let value, let payload = value.split(separator: ":").last else { return nil }
    let components = payload.split(separator: ",").compactMap { Double($0) }
    guard components.count >= 3 else { return nil }
    return (
        components[0],
        components[1],
        components[2],
        components.count >= 4 ? components[3] : 1
    )
}

func renderIcon(specs: [LayerSpec], assetsDirectory: URL) throws -> PixelBuffer {
    let size = 1024
    var canvas = PixelBuffer(width: size, height: size, bytes: Array(repeating: 0, count: size * size * 4))

    for spec in specs {
        let mask = try loadRGBAImage(
            at: assetsDirectory.appendingPathComponent(spec.imageName)
        )
        composite(mask: mask, spec: spec, into: &canvas)
    }

    applySuperellipseMask(to: &canvas)
    return canvas
}

func loadRGBAImage(at url: URL) throws -> PixelBuffer {
    guard
        let image = NSImage(contentsOf: url),
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        throw NSError(domain: "IconBuild", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not load \(url.path)"
        ])
    }

    var bytes = Array(repeating: UInt8(0), count: cgImage.width * cgImage.height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &bytes,
        width: cgImage.width,
        height: cgImage.height,
        bitsPerComponent: 8,
        bytesPerRow: cgImage.width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "IconBuild", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Could not create bitmap context"
        ])
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return PixelBuffer(width: cgImage.width, height: cgImage.height, bytes: bytes)
}

func composite(mask: PixelBuffer, spec: LayerSpec, into canvas: inout PixelBuffer) {
    precondition(mask.width == canvas.width && mask.height == canvas.height)

    for y in 0..<canvas.height {
        let t = Double(y) / Double(canvas.height - 1)
        let color = interpolate(spec.topColor, spec.bottomColor, t: t)

        for x in 0..<canvas.width {
            let index = (y * canvas.width + x) * 4
            let maskAlpha = Double(mask.bytes[index + 3]) / 255.0
            guard maskAlpha > 0 else { continue }

            let sourceAlpha = maskAlpha * color[3]
            let destinationAlpha = Double(canvas.bytes[index + 3]) / 255.0
            let outputAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)

            guard outputAlpha > 0 else { continue }

            for channel in 0..<3 {
                let source = color[channel]
                let destination = Double(canvas.bytes[index + channel]) / 255.0
                let output = (source * sourceAlpha + destination * destinationAlpha * (1 - sourceAlpha)) / outputAlpha
                canvas.bytes[index + channel] = UInt8(clamping: Int(round(output * 255)))
            }
            canvas.bytes[index + 3] = UInt8(clamping: Int(round(outputAlpha * 255)))
        }
    }
}

func interpolate(
    _ top: (Double, Double, Double, Double),
    _ bottom: (Double, Double, Double, Double),
    t: Double
) -> [Double] {
    [
        top.0 + (bottom.0 - top.0) * t,
        top.1 + (bottom.1 - top.1) * t,
        top.2 + (bottom.2 - top.2) * t,
        top.3 + (bottom.3 - top.3) * t
    ]
}

func applySuperellipseMask(to buffer: inout PixelBuffer) {
    let radius = Double(buffer.width) / 2
    let exponent = 4.8
    let center = radius - 0.5

    for y in 0..<buffer.height {
        for x in 0..<buffer.width {
            let nx = abs((Double(x) - center) / radius)
            let ny = abs((Double(y) - center) / radius)
            let distance = pow(nx, exponent) + pow(ny, exponent)
            guard distance > 0.92 else { continue }

            let index = (y * buffer.width + x) * 4
            let edge = max(0, min(1, (1 - distance) / 0.08))
            buffer.bytes[index + 3] = UInt8(clamping: Int(Double(buffer.bytes[index + 3]) * edge))
        }
    }
}

func writeIconset(from source: PixelBuffer, to outputURL: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: outputURL.path) {
        try fileManager.removeItem(at: outputURL)
    }
    try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let sizes: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (filename, size) in sizes {
        let resized = try resize(source, width: size, height: size)
        try writePNG(resized, to: outputURL.appendingPathComponent(filename))
    }
}

func resize(_ source: PixelBuffer, width: Int, height: Int) throws -> PixelBuffer {
    guard let cgImage = try makeCGImage(from: source) else {
        throw NSError(domain: "IconBuild", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Could not create source CGImage"
        ])
    }

    var bytes = Array(repeating: UInt8(0), count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "IconBuild", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Could not create resize context"
        ])
    }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return PixelBuffer(width: width, height: height, bytes: bytes)
}

func writePNG(_ buffer: PixelBuffer, to url: URL) throws {
    guard
        let cgImage = try makeCGImage(from: buffer),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else {
        throw NSError(domain: "IconBuild", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Could not create PNG destination"
        ])
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "IconBuild", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "Could not write \(url.path)"
        ])
    }
}

func makeCGImage(from buffer: PixelBuffer) throws -> CGImage? {
    let bytes = buffer.bytes
    guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }

    return CGImage(
        width: buffer.width,
        height: buffer.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: buffer.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}
