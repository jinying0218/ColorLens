import Foundation

public enum ColorCode: String, CaseIterable, Sendable {
    case objectiveC = "Objective-C"
    case swift = "Swift · UIColor"
    case swiftUI = "SwiftUI"
    case css = "CSS"
    case hexObjectiveC = "OC · Hex 方法"

    public func render(_ color: ColorValue) -> String {
        let r = color.red, g = color.green, b = color.blue, a = color.alpha
        switch self {
        case .objectiveC:
            return "[UIColor colorWithRed:\(r)/255.0 green:\(g)/255.0 blue:\(b)/255.0 alpha:\(a)/255.0]"
        case .swift:
            return "UIColor(red: \(r).0/255.0, green: \(g).0/255.0, blue: \(b).0/255.0, alpha: \(a).0/255.0)"
        case .swiftUI:
            return "Color(.sRGB, red: \(r).0/255.0, green: \(g).0/255.0, blue: \(b).0/255.0, opacity: \(a).0/255.0)"
        case .css:
            let opacity = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), Double(a)/255)
            return "rgba(\(r), \(g), \(b), \(opacity))"
        case .hexObjectiveC:
            return "[UIColor ljrp_colorWithHextColorString:@\"\(color.hex(.argb))\"]"
        }
    }
}
