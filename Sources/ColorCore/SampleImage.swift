#if canImport(AppKit)
import AppKit

public final class SampleImage {
    public let image: NSImage
    public let width: Int
    public let height: Int
    private let bitmap: NSBitmapImageRep

    public init?(image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        bitmap = NSBitmapImageRep(cgImage: cg)
        width = cg.width
        height = cg.height
        guard width > 0, height > 0 else { return nil }
        self.image = NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }

    /// Coordinates use the top-left image pixel as (0, 0).
    public func color(x: Int, y: Int) -> ColorValue? {
        guard x >= 0, y >= 0, x < width, y < height,
              let pixel = bitmap.colorAt(x: x, y: y) else { return nil }
        // colorAt may return calibrated components even for a bitmap tagged as sRGB.
        // Restore the bitmap's actual profile before converting to the output space.
        let count = bitmap.colorSpace.numberOfColorComponents + 1
        guard pixel.numberOfComponents == count else { return nil }
        var components = [CGFloat](repeating: 0, count: count)
        pixel.getComponents(&components)
        guard let color = NSColor(colorSpace: bitmap.colorSpace, components: &components, count: count)
            .usingColorSpace(.sRGB) else { return nil }
        func byte(_ component: CGFloat) -> UInt8 { UInt8((min(1, max(0, component))*255).rounded()) }
        return ColorValue(red: byte(color.redComponent), green: byte(color.greenComponent),
                          blue: byte(color.blueComponent), alpha: byte(color.alphaComponent))
    }
}
#endif
