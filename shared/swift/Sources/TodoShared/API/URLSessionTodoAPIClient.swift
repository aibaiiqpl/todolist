import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TodoAPIError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)
}

public final class URLSessionTodoAPIClient: TodoAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = JSONEncoder.todoSharedEncoder()
        self.decoder = JSONDecoder.todoSharedDecoder()
    }

    public func authenticateWithApple(identityToken: String) async throws -> AuthSession {
        let body = AppleAuthRequest(identityToken: identityToken)
        return try await send(path: "/auth/apple", method: "POST", body: body, session: nil)
    }

    public func organizeTasks(input: String, session: AuthSession) async throws -> [AITaskDraft] {
        let response: OrganizeTasksResponse = try await send(
            path: "/ai/organize",
            method: "POST",
            body: OrganizeTasksRequest(input: input),
            session: session
        )
        return response.drafts
    }

    public func fetchTaskChanges(sinceVersion: Int64, session: AuthSession) async throws -> TaskChanges {
        var components = URLComponents(url: endpointURL("tasks/changes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "since_version", value: String(sinceVersion))
        ]
        guard let url = components?.url else {
            throw TodoAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    public func syncTasks(operations: [SyncOperation], session: AuthSession) async throws -> SyncResult {
        try await send(
            path: "/tasks/sync",
            method: "POST",
            body: SyncTasksRequest(operations: operations),
            session: session
        )
    }

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody,
        session authSession: AuthSession?
    ) async throws -> ResponseBody {
        let url = endpointURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        if let authSession {
            request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private func perform<ResponseBody: Decodable>(_ request: URLRequest) async throws -> ResponseBody {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TodoAPIError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw TodoAPIError.httpStatus(httpResponse.statusCode, message)
        }
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func endpointURL(_ path: String) -> URL {
        path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .reduce(baseURL) { url, component in
                url.appendingPathComponent(String(component))
            }
    }
}

private struct AppleAuthRequest: Encodable {
    var identityToken: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
    }
}

private struct OrganizeTasksRequest: Encodable {
    var input: String
}

private struct OrganizeTasksResponse: Decodable {
    var drafts: [AITaskDraft]
}

private struct SyncTasksRequest: Encodable {
    var operations: [SyncOperation]
}
