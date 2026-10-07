import Foundation

public struct EventStream: Sendable {
    public enum Event: Equatable, Sendable { case text(String), done }
    public enum Failure: Error { case providerError, malformedEvent, incompleteStream }
    private var data: [String] = []
    public init() {}

    public mutating func consume(line: String) throws -> Event? {
        if line.isEmpty {
            guard !data.isEmpty else { return nil }
            let payload = data.joined(separator: "\n")
            data.removeAll()
            if payload == "[DONE]" { return .done }
            guard let bytes = payload.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
                throw Failure.malformedEvent
            }
            if object["error"] != nil { throw Failure.providerError }
            guard let choices = object["choices"] as? [[String: Any]] else { return nil }
            if choices.contains(where: { $0["error"] != nil || ($0["finish_reason"] as? String) == "error" }) {
                throw Failure.providerError
            }
            guard let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { return nil }
            return .text(content)
        }
        if line.hasPrefix("data:") {
            var value = String(line.dropFirst(5))
            if value.first == " " { value.removeFirst() }
            data.append(value)
        }
        return nil
    }
}

public struct APIConfiguration: Sendable {
    public var baseURL: String
    public var model: String
    public var key: String
    public init(baseURL: String, model: String, key: String) {
        self.baseURL = baseURL; self.model = model; self.key = key
    }
    public func endpoint() throws -> URL {
        guard let url = URL(string: baseURL), let host = url.host,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)),
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigurationError.invalidEndpoint
        }
        return url.appendingPathComponent("chat/completions")
    }
    public enum ConfigurationError: LocalizedError {
        case invalidEndpoint, missingKey, http(Int)
        public var errorDescription: String? {
            switch self {
            case .invalidEndpoint: "Enter an HTTPS API base URL and a model ID. Local HTTP is allowed only on localhost."
            case .missingKey: "Add your API key in Settings, or enable Demo mode."
            case .http(let code): "The provider returned HTTP \(code). Check your endpoint, model, key, and credits."
            }
        }
    }
}
