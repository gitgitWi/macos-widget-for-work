import Foundation

enum HTTPError: LocalizedError {
    case invalidResponse
    case unauthorized
    case statusCode(Int, Data)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid HTTP response"
        case .unauthorized: return "Unauthorized (401) - token may be expired"
        case .statusCode(let code, let data):
            let body = String(data: data, encoding: .utf8) ?? ""
            return "HTTP \(code): \(body.prefix(200))"
        }
    }
}

actor HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "WorkWidget/1.0",
        ]
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func get<T: Decodable>(url: URL, bearerToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw HTTPError.unauthorized
            }
            throw HTTPError.statusCode(httpResponse.statusCode, data)
        }

        return try decoder.decode(T.self, from: data)
    }

    func get<T: Decodable>(
        url: URL,
        bearerToken: String,
        additionalHeaders: [String: String] = [:]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw HTTPError.unauthorized
            }
            throw HTTPError.statusCode(httpResponse.statusCode, data)
        }

        return try decoder.decode(T.self, from: data)
    }

    func post<T: Decodable>(
        url: URL,
        bearerToken: String,
        body: Data,
        additionalHeaders: [String: String] = [:]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw HTTPError.unauthorized
            }
            throw HTTPError.statusCode(httpResponse.statusCode, data)
        }

        return try decoder.decode(T.self, from: data)
    }
}
