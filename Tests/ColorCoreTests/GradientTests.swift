import XCTest
@testable import ColorCore

final class GradientTests: XCTestCase {
    let red = ColorValue(red: 255, green: 0, blue: 0, alpha: 128)
    let blue = ColorValue(red: 0, green: 0, blue: 255)

    func definition(_ angle: Double) throws -> LinearGradientDefinition {
        try XCTUnwrap(LinearGradientDefinition(stops: [.init(color: red, location: 0), .init(color: blue, location: 1)], angle: angle))
    }

    func testCardinalDirections() throws {
        for (angle, sx, sy, ex, ey) in [(0.0, 0.5, 1.0, 0.5, 0.0), (90.0, 0.0, 0.5, 1.0, 0.5),
                                       (180.0, 0.5, 0.0, 0.5, 1.0), (270.0, 1.0, 0.5, 0.0, 0.5)] {
            let points = try definition(angle).points(width: 400, height: 200)
            XCTAssertEqual(points.start.x, sx, accuracy: 0.000001)
            XCTAssertEqual(points.start.y, sy, accuracy: 0.000001)
            XCTAssertEqual(points.end.x, ex, accuracy: 0.000001)
            XCTAssertEqual(points.end.y, ey, accuracy: 0.000001)
        }
    }

    func testDiagonalPreservesPhysicalAngleInRectangularCanvas() throws {
        let points = try definition(45).points(width: 400, height: 200)
        XCTAssertEqual(points.start.x, 0.125, accuracy: 0.000001)
        XCTAssertEqual(points.start.y, 1.25, accuracy: 0.000001)
        XCTAssertEqual(points.end.x, 0.875, accuracy: 0.000001)
        XCTAssertEqual(points.end.y, -0.25, accuracy: 0.000001)
        let dx = (points.end.x-points.start.x)*400
        let dy = (points.end.y-points.start.y)*200
        XCTAssertEqual(dx, -dy, accuracy: 0.000001)
        let zero = try definition(45).points(width: 0, height: 0)
        XCTAssertTrue(zero.start.x.isFinite && zero.end.y.isFinite)
    }

    func testSortRetainsHardEdgeOrderingAndNormalizesAngle() throws {
        let stops: [GradientStop] = [.init(color: blue, location: 1), .init(color: red, location: 0.5),
                                     .init(color: blue, location: 0.5), .init(color: red, location: 0)]
        let value = try XCTUnwrap(LinearGradientDefinition(stops: stops, angle: -90))
        XCTAssertEqual(value.stops.map(\.location), [0, 0.5, 0.5, 1])
        XCTAssertEqual(value.stops[1].color, red)
        XCTAssertEqual(value.stops[2].color, blue)
        XCTAssertEqual(value.angle, 270)
        XCTAssertEqual(try definition(450).angle, 90)
    }

    func testRejectsInvalidNodesAndNonfiniteValues() {
        let one: [GradientStop] = [.init(color: red, location: 0)]
        XCTAssertNil(LinearGradientDefinition(stops: one, angle: 0))
        XCTAssertNil(LinearGradientDefinition(stops: Array(repeating: one[0], count: 9), angle: 0))
        XCTAssertNil(LinearGradientDefinition(stops: [.init(color: red, location: -0.1), .init(color: blue, location: 1)], angle: 0))
        XCTAssertNil(LinearGradientDefinition(stops: [.init(color: red, location: .nan), .init(color: blue, location: 1)], angle: 0))
        XCTAssertNil(LinearGradientDefinition(stops: [.init(color: red, location: 0), .init(color: blue, location: 1)], angle: .infinity))
    }

    func testExportsLocationsAndOriginalAlphaForEveryLanguage() throws {
        let value = try XCTUnwrap(LinearGradientDefinition(stops: [.init(color: red, location: 0.25),
                                                                  .init(color: blue, location: 0.75)], angle: 135))
        XCTAssertTrue(GradientCode.objectiveC.render(value).contains("@(0.25), @(0.75)"))
        XCTAssertTrue(GradientCode.objectiveC.render(value).contains("alpha:128/255.0"))
        XCTAssertTrue(GradientCode.swift.render(value).contains("NSNumber(value: 0.75)"))
        XCTAssertTrue(GradientCode.swiftUI.render(value).contains("location: 0.25"))
        XCTAssertTrue(GradientCode.swiftUI.render(value).contains("opacity: 128.0/255.0"))
        XCTAssertTrue(GradientCode.css.render(value).contains("135.0deg"))
        XCTAssertTrue(GradientCode.css.render(value).contains("rgba(255, 0, 0, 0.501961) 25.0%"))
    }
}
