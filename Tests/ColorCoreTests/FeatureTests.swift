import XCTest
import AppKit
@testable import ColorCore

final class FeatureTests: XCTestCase {
    func testHistoryDeduplicatesWholeColorAndLimitsCount() {
        var library = ColorLibrary()
        for red in 0...110 { library.record(ColorValue(red: UInt8(red), green: 0, blue: 0)) }
        XCTAssertEqual(library.recent.count, 100)
        let repeated = library.recent[20]
        library.record(repeated)
        XCTAssertEqual(library.recent.first, repeated)
        XCTAssertEqual(library.recent.filter { $0 == repeated }.count, 1)
        library.record(ColorValue(red: repeated.red, green: 0, blue: 0, alpha: 128))
        XCTAssertEqual(library.recent[1], repeated, "Different alpha must remain a distinct color")
    }

    func testLibraryPersistsAndClearingHistoryKeepsFavorites() throws {
        let color = ColorValue(red: 40, green: 90, blue: 180, alpha: 128)
        var library = ColorLibrary()
        library.record(color)
        library.toggleFavorite(color)
        let restored = try JSONDecoder().decode(ColorLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(restored, library)
        library.clearRecent()
        XCTAssertEqual(library.recent, [])
        XCTAssertEqual(library.favorites, [color])
        library.toggleFavorite(color)
        XCTAssertEqual(library.favorites, [])
    }

    func testCodeRetainsBytePrecisionAndARGBOrder() {
        let color = ColorValue(red: 255, green: 10, blue: 0, alpha: 128)
        XCTAssertEqual(ColorCode.hexObjectiveC.render(color), "[UIColor ljrp_colorWithHextColorString:@\"#80FF0A00\"]")
        XCTAssertEqual(ColorCode.css.render(color), "rgba(255, 10, 0, 0.501961)")
        XCTAssertTrue(ColorCode.objectiveC.render(color).contains("alpha:128/255.0"))
        XCTAssertTrue(ColorCode.swiftUI.render(color).contains("opacity: 128.0/255.0"))
        XCTAssertTrue(ColorCode.swift.render(color).contains("green: 10.0/255.0"))
    }

    func testImageSamplingPreservesPixelCoordinatesAndAlpha() throws {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 8, bitsPerPixel: 32))
        let pixels: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255,
                               0, 0, 255, 255, 128, 0, 0, 128]
        let data = try XCTUnwrap(rep.bitmapData)
        pixels.withUnsafeBufferPointer { data.update(from: $0.baseAddress!, count: pixels.count) }
        let source = NSImage(size: NSSize(width: 1, height: 1))
        source.addRepresentation(rep)
        let image = try XCTUnwrap(SampleImage(image: source))
        XCTAssertEqual(image.width, 2, "Retina images must sample physical pixels")
        XCTAssertEqual(image.height, 2)
        XCTAssertEqual(image.color(x: 0, y: 0), ColorValue(red: 255, green: 0, blue: 0))
        XCTAssertEqual(image.color(x: 1, y: 0), ColorValue(red: 0, green: 255, blue: 0))
        XCTAssertEqual(image.color(x: 0, y: 1), ColorValue(red: 0, green: 0, blue: 255))
        XCTAssertEqual(image.color(x: 1, y: 1), ColorValue(red: 255, green: 0, blue: 0, alpha: 128))
        XCTAssertNil(image.color(x: -1, y: 0))
        XCTAssertNil(image.color(x: 2, y: 1))
    }
}
