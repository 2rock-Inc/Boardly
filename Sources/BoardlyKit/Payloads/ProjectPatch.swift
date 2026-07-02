import Foundation

/// Partial update for `PATCH /projects/{id}`. In PLANKA the background lives on
/// the *project*, not the board: pick a gradient (`backgroundType == "gradient"`
/// + `backgroundGradient`) or an uploaded image (`backgroundType == "image"` +
/// `backgroundImageId`). `clearBackground` sends `backgroundType: null` to remove
/// it entirely.
public struct ProjectPatch: Encodable, Sendable {
    public var name: String?
    public var backgroundType: String?
    public var backgroundGradient: String?
    public var backgroundImageId: String?
    public var clearBackground: Bool

    public init(
        name: String? = nil,
        backgroundType: String? = nil,
        backgroundGradient: String? = nil,
        backgroundImageId: String? = nil,
        clearBackground: Bool = false
    ) {
        self.name = name
        self.backgroundType = backgroundType
        self.backgroundGradient = backgroundGradient
        self.backgroundImageId = backgroundImageId
        self.clearBackground = clearBackground
    }

    private enum CodingKeys: String, CodingKey {
        case name, backgroundType, backgroundGradient, backgroundImageId
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        if clearBackground {
            try c.encodeNil(forKey: .backgroundType)
        } else {
            try c.encodeIfPresent(backgroundType, forKey: .backgroundType)
        }
        try c.encodeIfPresent(backgroundGradient, forKey: .backgroundGradient)
        try c.encodeIfPresent(backgroundImageId, forKey: .backgroundImageId)
    }
}
