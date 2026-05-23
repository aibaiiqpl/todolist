import Foundation

public struct AuthSession: Codable, Equatable, Sendable {
    public var userID: String
    public var accessToken: String
    public var expiresAt: Date

    public init(userID: String, accessToken: String, expiresAt: Date) {
        self.userID = userID
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case expiresAt = "expires_at"
    }
}
