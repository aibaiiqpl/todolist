import Foundation
import TodoShared

protocol AuthSessionStoring {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear()
}

final class UserDefaultsAuthSessionStore: AuthSessionStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard, key: String = "authSession") {
        self.defaults = defaults
        self.key = key

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() throws -> AuthSession? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) throws {
        let data = try encoder.encode(session)
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
