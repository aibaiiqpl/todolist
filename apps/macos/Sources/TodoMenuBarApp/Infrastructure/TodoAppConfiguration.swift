import Foundation

enum TodoAppConfiguration {
    static let apiBaseURL: URL = {
        let value = ProcessInfo.processInfo.environment["TODO_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value, !value.isEmpty else {
            return URL(string: "https://todo-api.example.invalid")!
        }
        guard let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty else {
            preconditionFailure("TODO_API_BASE_URL must be an absolute URL.")
        }
        return url
    }()

    static func localStoreURL(userID: String) throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("TodoMenuBarApp", isDirectory: true)
        .appendingPathComponent("Users", isDirectory: true)

        return directory
            .appendingPathComponent(safeFileName(userID), isDirectory: true)
            .appendingPathComponent("local-store.json")
    }

    private static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let fileName = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
        return fileName.isEmpty ? "unknown-user" : fileName
    }
}
