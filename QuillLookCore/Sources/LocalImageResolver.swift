import Foundation

public struct LocalImageResolver {
    public init() {}

    public func htmlSource(for destination: String, markdownFileURL: URL?) -> String? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("data:") {
            return trimmed
        }

        guard let markdownFileURL else {
            return nil
        }

        let candidate: URL
        if trimmed.hasPrefix("file://"), let fileURL = URL(string: trimmed) {
            candidate = fileURL
        } else {
            candidate = markdownFileURL.deletingLastPathComponent().appendingPathComponent(trimmed.removingPercentEncoding ?? trimmed)
        }

        guard let data = try? Data(contentsOf: candidate), let mimeType = mimeType(for: candidate) else {
            return nil
        }

        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func mimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        default:
            return nil
        }
    }
}

