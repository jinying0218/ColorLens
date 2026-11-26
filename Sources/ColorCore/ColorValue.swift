import Foundation

public enum HexFormat: String, CaseIterable, Sendable {
    case rgb = "RGB", argb = "ARGB", rgba = "RGBA"
}

public struct ColorValue: Hashable, Codable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public static func parse(_ input: String, format: HexFormat) -> ColorValue? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@\""), value.hasSuffix("\"") {
            value = String(value.dropFirst(2).dropLast())
        } else if value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        if value.hasPrefix("#") { value.removeFirst() }
        else if value.lowercased().hasPrefix("0x") { value = String(value.dropFirst(2)) }
        guard value.count == 6 || (value.count == 8 && format != .rgb),
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let bits = UInt32(value, radix: 16) else { return nil }
        func byte(_ shift: Int) -> UInt8 { UInt8((bits >> shift) & 255) }
        if value.count == 6 { return ColorValue(red: byte(16), green: byte(8), blue: byte(0)) }
        if format == .argb { return ColorValue(red: byte(16), green: byte(8), blue: byte(0), alpha: byte(24)) }
        return ColorValue(red: byte(24), green: byte(16), blue: byte(8), alpha: byte(0))
    }

    public func hex(_ format: HexFormat) -> String {
        switch format {
        case .rgb: return String(format: "#%02X%02X%02X", Int(red), Int(green), Int(blue))
        case .argb: return String(format: "#%02X%02X%02X%02X", Int(alpha), Int(red), Int(green), Int(blue))
        case .rgba: return String(format: "#%02X%02X%02X%02X", Int(red), Int(green), Int(blue), Int(alpha))
        }
    }
}
