import Foundation

public extension ColorValue {
    /// Source-over composition using normalized sRGB channel values.
    func composited(over background: ColorValue) -> ColorValue {
        let foregroundAlpha = Double(alpha)/255
        let backgroundAlpha = Double(background.alpha)/255
        let outputAlpha = foregroundAlpha + backgroundAlpha*(1-foregroundAlpha)
        guard outputAlpha > 0 else { return ColorValue(red: 0, green: 0, blue: 0, alpha: 0) }
        func channel(_ foreground: UInt8, _ back: UInt8) -> UInt8 {
            let value = (Double(foreground)*foregroundAlpha + Double(back)*backgroundAlpha*(1-foregroundAlpha))/outputAlpha
            return UInt8(min(255, max(0, value.rounded())))
        }
        return ColorValue(red: channel(red, background.red), green: channel(green, background.green),
                          blue: channel(blue, background.blue), alpha: UInt8((outputAlpha*255).rounded()))
    }
}

public struct ColorDifference: Equatable {
    public let red: Int
    public let green: Int
    public let blue: Int
    public let alpha: Int
    public var opacityPoints: Double { Double(alpha)/255*100 }

    /// Signed channel differences: actual (B) minus reference (A).
    public init(reference: ColorValue, actual: ColorValue) {
        red = Int(actual.red) - Int(reference.red)
        green = Int(actual.green) - Int(reference.green)
        blue = Int(actual.blue) - Int(reference.blue)
        alpha = Int(actual.alpha) - Int(reference.alpha)
    }
}
