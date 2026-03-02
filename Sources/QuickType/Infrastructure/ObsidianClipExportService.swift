import Foundation

enum ObsidianClipExportError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Unable to encode clip payload for Obsidian."
        }
    }
}

struct ObsidianClipExportService {
    private let inlineLimit = 3500

    func buildObsidianURL(payload: ObsidianClipPayloadV1) throws -> URL {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        guard let json = String(data: data, encoding: .utf8) else {
            throw ObsidianClipExportError.encodingFailed
        }

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "quicktype-clip"

        if json.utf8.count <= inlineLimit {
            components.queryItems = [
                URLQueryItem(name: "payload", value: base64url(data: data))
            ]
        } else {
            let payloadFile = try writePayloadToDisk(data: data)
            components.queryItems = [
                URLQueryItem(name: "payloadFile", value: payloadFile.path)
            ]
        }

        guard let url = components.url else {
            throw ObsidianClipExportError.encodingFailed
        }
        return url
    }

    private func base64url(data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func writePayloadToDisk(data: Data) throws -> URL {
        let dir = AppPaths.obsidianPayloadsDirectory
        let filename = "payload-\(UUID().uuidString).json"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
