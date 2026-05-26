import XCTest
@testable import QuillLookCore

final class QuillLookTests: XCTestCase {
    func testRendersBasicMarkdownFragments() {
        let result = MarkdownHTMLRenderer().render(markdown: """
        # Title

        This is **strong** and `code`.

        - [x] Done
        - [ ] Later
        """)

        XCTAssertTrue(result.previewHTML.contains("<h1>Title</h1>"))
        XCTAssertTrue(result.previewHTML.contains("<strong>strong</strong>"))
        XCTAssertTrue(result.previewHTML.contains("<code>code</code>"))
        XCTAssertTrue(result.previewHTML.contains("type=\"checkbox\" disabled checked"))
    }

    func testCodeFencePreservesLanguageClass() {
        let result = MarkdownHTMLRenderer().render(markdown: """
        ```swift
        let value = 42
        ```
        """)

        XCTAssertTrue(result.previewHTML.contains("class=\"language-swift\""))
        XCTAssertTrue(result.previewHTML.contains("let value = 42"))
        XCTAssertTrue(result.features.hasCode)
        XCTAssertFalse(result.features.hasMermaid)
    }

    func testMermaidFenceBecomesMermaidContainer() {
        let result = MarkdownHTMLRenderer().render(markdown: """
        ```mermaid
        flowchart LR
        A --> B
        ```
        """)

        XCTAssertTrue(result.previewHTML.contains("<div class=\"mermaid\">"))
        XCTAssertTrue(result.previewHTML.contains("flowchart LR"))
        XCTAssertTrue(result.features.hasMermaid)
        XCTAssertFalse(result.features.hasCode)
    }

    func testKaTeXDelimitersSurviveForAutoRender() {
        let result = MarkdownHTMLRenderer().render(markdown: "Inline math $E = mc^2$ and block $$x^2$$")

        XCTAssertTrue(result.previewHTML.contains("$E = mc^2$"))
        XCTAssertTrue(result.previewHTML.contains("$$x^2$$"))
        XCTAssertTrue(result.features.hasMath)
    }

    func testRawHTMLIsEscaped() {
        let result = MarkdownHTMLRenderer().render(markdown: "<script>alert('nope')</script>")

        XCTAssertTrue(result.previewHTML.contains("&lt;script&gt;"))
        XCTAssertFalse(result.previewHTML.contains("<script>alert"))
    }

    func testLocalImageEmbedsReadableDataURL() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let markdownURL = directory.appendingPathComponent("doc.md")
        let imageURL = directory.appendingPathComponent("tiny.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)

        let result = MarkdownHTMLRenderer().render(markdown: "![tiny](tiny.png)", fileURL: markdownURL)

        XCTAssertTrue(result.previewHTML.contains("data:image/png;base64,"))
        XCTAssertTrue(result.features.hasLocalImages)
    }

    func testMissingImageProducesPlaceholder() {
        let markdownURL = FileManager.default.temporaryDirectory.appendingPathComponent("doc.md")
        let result = MarkdownHTMLRenderer().render(markdown: "![missing](missing.png)", fileURL: markdownURL)

        XCTAssertTrue(result.previewHTML.contains("Missing image: missing.png"))
        XCTAssertTrue(result.features.hasLocalImages)
    }

    func testPlainMarkdownDoesNotRequestHeavyAssets() {
        let result = MarkdownHTMLRenderer().render(markdown: """
        # Notes

        A plain paragraph with **strong** text.
        """)
        var requestedAssets: [String] = []

        _ = MarkdownPreviewDocument(result: result) { name in
            requestedAssets.append(name)
            return "asset-\(name)"
        }.html()

        XCTAssertEqual(result.features, MarkdownRenderFeatures())
        XCTAssertEqual(Set(requestedAssets), ["styles.css", "quilllook.js"])
    }

    func testCodeMarkdownRequestsHighlightAssetsOnly() {
        let result = MarkdownHTMLRenderer().render(markdown: """
        ```swift
        let value = 42
        ```
        """)
        var requestedAssets: [String] = []

        _ = MarkdownPreviewDocument(result: result) { name in
            requestedAssets.append(name)
            return "asset-\(name)"
        }.html()

        XCTAssertTrue(result.features.hasCode)
        XCTAssertTrue(requestedAssets.contains("highlight.min.js"))
        XCTAssertTrue(requestedAssets.contains("highlight-light.css"))
        XCTAssertTrue(requestedAssets.contains("highlight-dark.css"))
        XCTAssertFalse(requestedAssets.contains("mermaid.min.js"))
        XCTAssertFalse(requestedAssets.contains("katex.min.js"))
    }

    func testMathAndMermaidRequestOnlyNeededAssets() {
        let result = MarkdownHTMLRenderer().render(markdown: """
        Inline math $E = mc^2$.

        ```mermaid
        flowchart LR
        A --> B
        ```
        """)
        var requestedAssets: [String] = []

        _ = MarkdownPreviewDocument(result: result) { name in
            requestedAssets.append(name)
            return "asset-\(name)"
        }.html()

        XCTAssertTrue(result.features.hasMath)
        XCTAssertTrue(result.features.hasMermaid)
        XCTAssertFalse(result.features.hasCode)
        XCTAssertTrue(requestedAssets.contains("katex.min.css"))
        XCTAssertTrue(requestedAssets.contains("katex.min.js"))
        XCTAssertTrue(requestedAssets.contains("auto-render.min.js"))
        XCTAssertTrue(requestedAssets.contains("mermaid.min.js"))
        XCTAssertFalse(requestedAssets.contains("highlight.min.js"))
    }
}
