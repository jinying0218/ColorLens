import Foundation

public struct ColorLibrary: Codable, Equatable {
    public private(set) var recent: [ColorValue] = []
    public private(set) var favorites: [ColorValue] = []
    public init() {}

    public mutating func record(_ color: ColorValue) {
        recent.removeAll { $0 == color }
        recent.insert(color, at: 0)
        recent = Array(recent.prefix(100))
    }

    public mutating func toggleFavorite(_ color: ColorValue) {
        if favorites.contains(color) { favorites.removeAll { $0 == color } }
        else { favorites.insert(color, at: 0) }
    }

    public mutating func clearRecent() { recent.removeAll() }
}
