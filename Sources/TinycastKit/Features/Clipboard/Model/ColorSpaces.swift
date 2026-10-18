import Foundation

/// Oklab and its polar form, the space behind the one perceptual notation a colour copies as.
extension ColorValue {
    /// The inverse of `oklch`: a colour picker states its swatch in the space, not in hex.
    init(lightness: Double, chroma: Double, hue: Double, alpha: Double = 1) {
        let radians = hue * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)
        let long = Self.cubed(lightness + 0.3963377774 * a + 0.2158037573 * b)
        let medium = Self.cubed(lightness - 0.1055613458 * a - 0.0638541728 * b)
        let short = Self.cubed(lightness - 0.0894841775 * a - 1.2914855480 * b)
        self.init(
            red: Self.gamma(4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short),
            green: Self.gamma(-1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short),
            blue: Self.gamma(-0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short),
            alpha: alpha)
    }

    private static func cubed(_ value: Double) -> Double { value * value * value }

    /// The inverse of `linear`; a channel below the split can be negative, and `pow` answers NaN.
    private static func gamma(_ channel: Double) -> Double {
        channel <= 0.0031308 ? channel * 12.92 : 1.055 * pow(channel, 1 / 2.4) - 0.055
    }
}
