import XCTest
@testable import ColorCore

final class ComparisonTests: XCTestCase {
    func testOpaqueAndTransparentForeground() {
        let background = ColorValue(red: 20, green: 90, blue: 180)
        XCTAssertEqual(ColorValue(red: 255, green: 0, blue: 0).composited(over: background),
                       ColorValue(red: 255, green: 0, blue: 0))
        XCTAssertEqual(ColorValue(red: 255, green: 0, blue: 0, alpha: 0).composited(over: background), background)
    }

    func testHalfRedOverWhiteAndBlack() {
        let red = ColorValue(red: 255, green: 0, blue: 0, alpha: 128)
        XCTAssertEqual(red.composited(over: .init(red: 255, green: 255, blue: 255)),
                       .init(red: 255, green: 127, blue: 127))
        XCTAssertEqual(red.composited(over: .init(red: 0, green: 0, blue: 0)),
                       .init(red: 128, green: 0, blue: 0))
    }

    func testBothTransparentAndPartiallyTransparentLayers() {
        let red = ColorValue(red: 255, green: 0, blue: 0, alpha: 128)
        let blue = ColorValue(red: 0, green: 0, blue: 255, alpha: 128)
        XCTAssertEqual(red.composited(over: blue), .init(red: 170, green: 0, blue: 85, alpha: 192))
        XCTAssertEqual(ColorValue(red: 255, green: 0, blue: 0, alpha: 0)
            .composited(over: .init(red: 0, green: 255, blue: 0, alpha: 0)),
                       .init(red: 0, green: 0, blue: 0, alpha: 0))
    }

    func testDifferencesAreSignedActualMinusReference() {
        let a = ColorValue(red: 10, green: 30, blue: 50, alpha: 255)
        let b = ColorValue(red: 20, green: 20, blue: 50, alpha: 127)
        let delta = ColorDifference(reference: a, actual: b)
        XCTAssertEqual(delta.red, 10)
        XCTAssertEqual(delta.green, -10)
        XCTAssertEqual(delta.blue, 0)
        XCTAssertEqual(delta.alpha, -128)
        XCTAssertEqual(delta.opacityPoints, -128.0/255*100, accuracy: 0.00001)
        XCTAssertEqual(ColorDifference(reference: a, actual: a).opacityPoints, 0)
    }
}
