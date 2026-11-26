import Foundation

public struct GradientStop: Equatable, Sendable {
    public let color: ColorValue
    public let location: Double
    public init(color: ColorValue, location: Double) { self.color = color; self.location = location }
}

public struct GradientPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
}

public struct LinearGradientDefinition: Equatable, Sendable {
    public let stops: [GradientStop]
    /// CSS convention: 0° points up, 90° right, 180° down. Clockwise.
    public let angle: Double

    public init?(stops: [GradientStop], angle: Double) {
        guard (2...8).contains(stops.count), angle.isFinite,
              stops.allSatisfy({ $0.location.isFinite && (0...1).contains($0.location) }) else { return nil }
        self.stops = stops.enumerated().sorted {
            $0.element.location == $1.element.location ? $0.offset < $1.offset : $0.element.location < $1.element.location
        }.map(\.element)
        self.angle = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    public func points(width: Double, height: Double) -> (start: GradientPoint, end: GradientPoint) {
        let w = width.isFinite && width > 0 ? width : 1
        let h = height.isFinite && height > 0 ? height : 1
        let radians = angle * .pi / 180
        let dx = sin(radians), dy = -cos(radians)
        let length = abs(w*dx) + abs(h*dy)
        return (.init(x: 0.5-dx*length/(2*w), y: 0.5-dy*length/(2*h)),
                .init(x: 0.5+dx*length/(2*w), y: 0.5+dy*length/(2*h)))
    }
}

public enum GradientCode: String, CaseIterable {
    case objectiveC = "Objective-C"
    case swift = "Swift"
    case swiftUI = "SwiftUI"
    case css = "CSS"

    private func number(_ value: Double) -> String {
        var text = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
        while text.last == "0" { text.removeLast() }
        if text.last == "." { text.append("0") }
        return text
    }

    public func render(_ definition: LinearGradientDefinition) -> String {
        let angle = number(definition.angle)
        switch self {
        case .css:
            let stops = definition.stops.map { "  \(ColorCode.css.render($0.color)) \(number($0.location*100))%" }.joined(separator: ",\n")
            return "background: linear-gradient(\(angle)deg,\n\(stops)\n);"
        case .objectiveC:
            let colors = definition.stops.map { "        (__bridge id)\(ColorCode.objectiveC.render($0.color)).CGColor" }.joined(separator: ",\n")
            let locations = definition.stops.map { "@(\(number($0.location)))" }.joined(separator: ", ")
            return """
            #import <UIKit/UIKit.h>
            #import <QuartzCore/QuartzCore.h>
            #import <math.h>

            CAGradientLayer *MakeColorLensGradient(CGRect frame) {
                CAGradientLayer *gradient = [CAGradientLayer layer];
                gradient.frame = frame;
                gradient.colors = @[
            \(colors)
                ];
                gradient.locations = @[\(locations)];
                CGFloat radians = \(angle) * M_PI / 180.0;
                CGFloat dx = sin(radians), dy = -cos(radians);
                CGFloat w = MAX(CGRectGetWidth(gradient.bounds), 1.0);
                CGFloat h = MAX(CGRectGetHeight(gradient.bounds), 1.0);
                CGFloat length = fabs(w * dx) + fabs(h * dy);
                gradient.startPoint = CGPointMake(0.5-dx*length/(2*w), 0.5-dy*length/(2*h));
                gradient.endPoint = CGPointMake(0.5+dx*length/(2*w), 0.5+dy*length/(2*h));
                return gradient;
            }
            // 容器尺寸改变时，同步更新 frame 和起止点。
            """
        case .swift:
            let colors = definition.stops.map { "        \(ColorCode.swift.render($0.color)).cgColor" }.joined(separator: ",\n")
            let locations = definition.stops.map { "NSNumber(value: \(number($0.location)))" }.joined(separator: ", ")
            return """
            import UIKit
            import QuartzCore

            func makeColorLensGradient(frame: CGRect) -> CAGradientLayer {
                let gradient = CAGradientLayer()
                gradient.frame = frame
                gradient.colors = [
            \(colors)
                ]
                gradient.locations = [\(locations)]
                let radians = \(angle) * Double.pi / 180.0
                let dx = sin(radians), dy = -cos(radians)
                let w = max(Double(gradient.bounds.width), 1.0)
                let h = max(Double(gradient.bounds.height), 1.0)
                let length = abs(w * dx) + abs(h * dy)
                gradient.startPoint = CGPoint(x: 0.5-dx*length/(2*w), y: 0.5-dy*length/(2*h))
                gradient.endPoint = CGPoint(x: 0.5+dx*length/(2*w), y: 0.5+dy*length/(2*h))
                return gradient
            }
            // 容器尺寸改变时，同步更新 frame 和起止点。
            """
        case .swiftUI:
            let stops = definition.stops.map { "                    .init(color: \(ColorCode.swiftUI.render($0.color)), location: \(number($0.location)))" }.joined(separator: ",\n")
            return """
            import SwiftUI

            struct ColorLensGradientView: View {
                var body: some View {
                    GeometryReader { proxy in
                        let radians = \(angle) * Double.pi / 180.0
                        let dx = sin(radians), dy = -cos(radians)
                        let w = max(Double(proxy.size.width), 1.0)
                        let h = max(Double(proxy.size.height), 1.0)
                        let length = abs(w * dx) + abs(h * dy)
                        LinearGradient(stops: [
            \(stops)
                        ], startPoint: UnitPoint(x: 0.5-dx*length/(2*w), y: 0.5-dy*length/(2*h)),
                           endPoint: UnitPoint(x: 0.5+dx*length/(2*w), y: 0.5+dy*length/(2*h)))
                    }
                }
            }
            """
        }
    }
}
