import Foundation
import QuillLookCore
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL)
        let source = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let result = MarkdownHTMLRenderer().render(markdown: source, fileURL: request.fileURL)
        let html = MarkdownPreviewDocument(result: result) { name in
            WebAssetCache.shared.asset(named: name, bundle: .main)
        }.html()
        let htmlData = Data(html.utf8)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1100)) { reply in
            reply.stringEncoding = .utf8
            return htmlData
        }
        return reply
    }
}

private final class WebAssetCache: @unchecked Sendable {
    static let shared = WebAssetCache()

    private var assets: [String: String] = [:]
    private let lock = NSLock()

    func asset(named name: String, bundle: Bundle) -> String? {
        lock.lock()
        if let cached = assets[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let bundleURL = bundle.url(forResource: "WebAssets", withExtension: "bundle"),
              let assetBundle = Bundle(url: bundleURL),
              let url = assetBundle.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        lock.lock()
        assets[name] = value
        lock.unlock()

        return value
    }
}
