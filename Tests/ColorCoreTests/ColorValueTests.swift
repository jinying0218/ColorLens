import XCTest
@testable import ColorCore

final class ColorValueTests: XCTestCase {
    func testByteOrder() {
        let expected = ColorValue(red: 255, green: 0, blue: 0, alpha: 128)
        XCTAssertEqual(ColorValue.parse("#80FF0000", format: .argb), expected)
        XCTAssertEqual(ColorValue.parse("#FF000080", format: .rgba), expected)
        XCTAssertEqual(expected.hex(.argb), "#80FF0000")
        XCTAssertEqual(expected.hex(.rgba), "#FF000080")
    }
    func testAcceptedWrappersAndRGB() {
        for text in ["#007aff", "0x007AFF", " @\"#007AFF\" \n", "\"007AFF\""] {
            XCTAssertEqual(ColorValue.parse(text, format: .argb), ColorValue(red: 0, green: 122, blue: 255))
        }
    }
    func testRejectsMalformedInput() {
        for text in ["", "#FFF", "#GG0000", "#1234567", "@", "#FF0000junk", "123456789"] {
            XCTAssertNil(ColorValue.parse(text, format: .argb))
        }
        XCTAssertNil(ColorValue.parse("#80FF0000", format: .rgb))
    }
    func testRoundTripAllAlphaValues() {
        for alpha in UInt8.min...UInt8.max {
            let color = ColorValue(red: 13, green: 157, blue: 242, alpha: alpha)
            for format in [HexFormat.argb, .rgba] {
                XCTAssertEqual(ColorValue.parse(color.hex(format), format: format), color)
            }
        }
    }
}
