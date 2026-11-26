import AppKit
import Testing
import ColorCore
@testable import ColorLens

@Test @MainActor
func savedColorsSurviveRelaunchAndClearPreservesFavorites() throws {
    let domain = "ColorLensTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let color = ColorValue(red: 17, green: 34, blue: 51, alpha: 204)
    let store = ColorStore(defaults: defaults)
    store.record(color)
    store.toggleFavorite(color)
    let relaunched = ColorStore(defaults: defaults)
    #expect(relaunched.library.recent == [color])
    #expect(relaunched.library.favorites == [color])
    relaunched.clearRecent()
    let cleared = ColorStore(defaults: defaults)
    #expect(cleared.library.recent.isEmpty)
    #expect(cleared.library.favorites == [color])
}

@Test @MainActor
func scaledCanvasClicksSelectTopLeftBasedPhysicalPixels() throws {
    _ = NSApplication.shared
    let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 8, bitsPerPixel: 32))
    let bytes: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 128, 0, 0, 128]
    let data = try #require(rep.bitmapData)
    bytes.withUnsafeBufferPointer { data.update(from: $0.baseAddress!, count: bytes.count) }
    let source = NSImage(size: NSSize(width: 2, height: 2))
    source.addRepresentation(rep)
    let image = try #require(SampleImage(image: source))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                          styleMask: [.titled], backing: .buffered, defer: false)
    let canvas = PixelCanvasView(frame: .zero)
    window.contentView = canvas
    canvas.image = image
    let expected: [ColorValue] = [.init(red: 255, green: 0, blue: 0), .init(red: 0, green: 255, blue: 0),
                                 .init(red: 0, green: 0, blue: 255), .init(red: 255, green: 0, blue: 0, alpha: 128)]
    for zoom in [0.5, 1.0, 8.0] {
        canvas.zoom = zoom
        for y in 0...1 {
            for x in 0...1 {
                var picked: ColorValue?
                canvas.sample = { color, px, py, isClick in
                    #expect(px == x && py == y && isClick)
                    picked = color
                }
                let point = canvas.convert(NSPoint(x: (Double(x)+0.5)*zoom, y: (Double(y)+0.5)*zoom), to: nil)
                let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                      modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                      context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                canvas.mouseDown(with: event)
                #expect(picked == expected[y*2+x])
            }
        }
    }
}

@Test @MainActor
func imageCanBeReadFromPrivatePasteboardWithoutTouchingUserClipboard() throws {
    // Tag the fixture as sRGB: Device RGB can acquire a display profile on TIFF export.
    let provider = try #require(CGDataProvider(data: Data([255, 0, 0, 255]) as CFData))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let cg = try #require(CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: 4, space: space,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let image = NSImage(cgImage: cg, size: NSSize(width: 1, height: 1))
    #expect(SampleImage(image: image)?.color(x: 0, y: 0) == ColorValue(red: 255, green: 0, blue: 0))
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    #expect(pasteboard.writeObjects([image]))
    let pasted = try #require(NSImage(pasteboard: pasteboard))
    let sampled = SampleImage(image: pasted)?.color(x: 0, y: 0)
    #expect(sampled == ColorValue(red: 255, green: 0, blue: 0))
}
