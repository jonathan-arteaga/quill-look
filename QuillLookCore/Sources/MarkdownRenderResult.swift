import Foundation

public struct MarkdownRenderFeatures: Equatable {
    public var hasCode: Bool
    public var hasMermaid: Bool
    public var hasMath: Bool
    public var hasLocalImages: Bool

    public init(hasCode: Bool = false, hasMermaid: Bool = false, hasMath: Bool = false, hasLocalImages: Bool = false) {
        self.hasCode = hasCode
        self.hasMermaid = hasMermaid
        self.hasMath = hasMath
        self.hasLocalImages = hasLocalImages
    }
}

public struct MarkdownRenderResult: Equatable {
    public let previewBody: String
    public let sourceBody: String
    public let title: String
    public let features: MarkdownRenderFeatures

    public var previewHTML: String {
        previewBody
    }

    public var sourceHTML: String {
        sourceBody
    }

    public init(previewBody: String, sourceBody: String, title: String, features: MarkdownRenderFeatures = MarkdownRenderFeatures()) {
        self.previewBody = previewBody
        self.sourceBody = sourceBody
        self.title = title
        self.features = features
    }
}
