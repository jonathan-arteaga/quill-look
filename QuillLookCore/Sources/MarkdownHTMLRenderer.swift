import Foundation

public struct MarkdownHTMLRenderer {
    public var imageResolver: LocalImageResolver

    public init(imageResolver: LocalImageResolver = LocalImageResolver()) {
        self.imageResolver = imageResolver
    }

    public func render(markdown source: String, fileURL: URL? = nil, title: String? = nil) -> MarkdownRenderResult {
        var features = MarkdownRenderFeatures(hasMath: containsMathDelimiters(in: source))
        let body = renderBlocks(from: source, fileURL: fileURL, features: &features)
        let resolvedTitle = title ?? inferredTitle(from: source) ?? fileURL?.deletingPathExtension().lastPathComponent ?? "Markdown Preview"
        let sourceBody = """
        <pre><code class="language-markdown">\(HTML.escape(source))</code></pre>
        """
        return MarkdownRenderResult(previewBody: body, sourceBody: sourceBody, title: resolvedTitle, features: features)
    }

    private func renderBlocks(from source: String, fileURL: URL?, features: inout MarkdownRenderFeatures) -> String {
        let lines = normalizedLines(source)
        var index = 0
        var html: [String] = []

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            index = 1
            while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces) != "---" {
                index += 1
            }
            if index < lines.count {
                index += 1
            }
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let fence = fenceStart(in: line) {
                let block = consumeFence(lines: lines, start: index, fence: fence, fileURL: fileURL, features: &features)
                html.append(block.html)
                index = block.nextIndex
                continue
            }

            if let heading = heading(in: line) {
                html.append("<h\(heading.level)>\(renderInline(heading.text, fileURL: fileURL, features: &features))</h\(heading.level)>")
                index += 1
                continue
            }

            if isThematicBreak(trimmed) {
                html.append("<hr>")
                index += 1
                continue
            }

            if index + 1 < lines.count, isTableHeader(line, separator: lines[index + 1]) {
                let table = consumeTable(lines: lines, start: index, fileURL: fileURL, features: &features)
                html.append(table.html)
                index = table.nextIndex
                continue
            }

            if isBlockquote(line) {
                let quote = consumeBlockquote(lines: lines, start: index, fileURL: fileURL, features: &features)
                html.append(quote.html)
                index = quote.nextIndex
                continue
            }

            if isListItem(line) {
                let list = consumeList(lines: lines, start: index, fileURL: fileURL, features: &features)
                html.append(list.html)
                index = list.nextIndex
                continue
            }

            let paragraph = consumeParagraph(lines: lines, start: index, fileURL: fileURL, features: &features)
            html.append(paragraph.html)
            index = paragraph.nextIndex
        }

        return html.joined(separator: "\n")
    }

    private func consumeFence(lines: [String], start: Int, fence: Fence, fileURL: URL?, features: inout MarkdownRenderFeatures) -> (html: String, nextIndex: Int) {
        var index = start + 1
        var content: [String] = []
        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence.marker) {
                return (renderCodeBlock(language: fence.language, code: content.joined(separator: "\n"), features: &features), index + 1)
            }
            content.append(lines[index])
            index += 1
        }
        return (renderCodeBlock(language: fence.language, code: content.joined(separator: "\n"), features: &features), index)
    }

    private func renderCodeBlock(language: String, code: String, features: inout MarkdownRenderFeatures) -> String {
        let escaped = HTML.escape(code)
        if language.lowercased() == "mermaid" {
            features.hasMermaid = true
            return "<div class=\"mermaid\">\(escaped)</div>"
        }
        features.hasCode = true
        let languageClass = language.isEmpty ? "" : " class=\"language-\(HTML.attribute(language))\""
        return "<pre><code\(languageClass)>\(escaped)</code></pre>"
    }

    private func consumeTable(lines: [String], start: Int, fileURL: URL?, features: inout MarkdownRenderFeatures) -> (html: String, nextIndex: Int) {
        let headers = tableCells(from: lines[start])
        let alignments = tableCells(from: lines[start + 1]).map(tableAlignment)
        var index = start + 2
        var rows: [[String]] = []

        while index < lines.count, lines[index].contains("|"), !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            rows.append(tableCells(from: lines[index]))
            index += 1
        }

        let paddedAlignments = alignments + Array(repeating: "", count: max(0, headers.count - alignments.count))
        var headerCells: [String] = []
        for (header, alignment) in zip(headers, paddedAlignments) {
            headerCells.append("<th\(alignmentAttribute(alignment))>\(renderInline(header, fileURL: fileURL, features: &features))</th>")
        }

        var rowHTML: [String] = []
        for row in rows {
            var cells: [String] = []
            for (offset, cell) in row.enumerated() {
                let alignment = offset < alignments.count ? alignments[offset] : ""
                cells.append("<td\(alignmentAttribute(alignment))>\(renderInline(cell, fileURL: fileURL, features: &features))</td>")
            }
            rowHTML.append("<tr>\(cells.joined())</tr>")
        }

        return ("<table><thead><tr>\(headerCells.joined())</tr></thead><tbody>\(rowHTML.joined(separator: "\n"))</tbody></table>", index)
    }

    private func consumeBlockquote(lines: [String], start: Int, fileURL: URL?, features: inout MarkdownRenderFeatures) -> (html: String, nextIndex: Int) {
        var index = start
        var quoteLines: [String] = []
        while index < lines.count, isBlockquote(lines[index]) || lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            let stripped = lines[index].replacingOccurrences(of: #"^\s*>\s?"#, with: "", options: .regularExpression)
            quoteLines.append(stripped)
            index += 1
        }
        let nested = renderBlocks(from: quoteLines.joined(separator: "\n"), fileURL: fileURL, features: &features)
        return ("<blockquote>\(nested)</blockquote>", index)
    }

    private func consumeList(lines: [String], start: Int, fileURL: URL?, features: inout MarkdownRenderFeatures) -> (html: String, nextIndex: Int) {
        let ordered = isOrderedListItem(lines[start])
        var index = start
        var items: [String] = []
        var hasTasks = false

        while index < lines.count, isListItem(lines[index]), isOrderedListItem(lines[index]) == ordered {
            let raw = listItemText(lines[index])
            if let task = taskItem(raw) {
                hasTasks = true
                let checked = task.checked ? " checked" : ""
                items.append("<li><input type=\"checkbox\" disabled\(checked)> \(renderInline(task.text, fileURL: fileURL, features: &features))</li>")
            } else {
                items.append("<li>\(renderInline(raw, fileURL: fileURL, features: &features))</li>")
            }
            index += 1
        }

        let tag = ordered ? "ol" : "ul"
        let className = hasTasks ? " class=\"task-list\"" : ""
        return ("<\(tag)\(className)>\(items.joined())</\(tag)>", index)
    }

    private func consumeParagraph(lines: [String], start: Int, fileURL: URL?, features: inout MarkdownRenderFeatures) -> (html: String, nextIndex: Int) {
        var index = start
        var parts: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || fenceStart(in: lines[index]) != nil || heading(in: lines[index]) != nil || isBlockquote(lines[index]) || isListItem(lines[index]) || isThematicBreak(trimmed) {
                break
            }
            if index + 1 < lines.count, isTableHeader(lines[index], separator: lines[index + 1]) {
                break
            }
            parts.append(trimmed)
            index += 1
        }
        return ("<p>\(renderInline(parts.joined(separator: " "), fileURL: fileURL, features: &features))</p>", index)
    }

    private func renderInline(_ text: String, fileURL: URL?, features: inout MarkdownRenderFeatures) -> String {
        var placeholders = PlaceholderStore()
        var images = InlineImageStore()
        let codeProtected = protectInlineCode(in: text, placeholders: &placeholders)
        let protected = protectImages(in: codeProtected, store: &images)
        var rendered = HTML.escape(protected)

        rendered = replaceImages(in: rendered, imageStore: images, fileURL: fileURL, features: &features)
        rendered = replaceLinks(in: rendered)
        rendered = rendered.replacingOccurrences(of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        rendered = rendered.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        rendered = rendered.replacingOccurrences(of: #"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)"#, with: "<em>$1</em>", options: .regularExpression)
        rendered = placeholders.restore(in: rendered)
        return rendered
    }

    private func replaceImages(in escapedText: String, imageStore: InlineImageStore, fileURL: URL?, features: inout MarkdownRenderFeatures) -> String {
        replaceMatches(pattern: #"%%MARKDOWNQL_IMAGE_(\d+)%%"#, in: escapedText) { match in
            guard let id = Int(match[1]), let image = imageStore.image(for: id) else {
                return "<span class=\"missing-image\">Image unavailable</span>"
            }
            let alt = HTML.attribute(image.alt)
            if isLocalImageDestination(image.destination) {
                features.hasLocalImages = true
            }
            if let source = imageResolver.htmlSource(for: image.destination, markdownFileURL: fileURL) {
                return "<img src=\"\(HTML.attribute(source))\" alt=\"\(alt)\">"
            }
            return "<span class=\"missing-image\">Missing image: \(HTML.escape(image.destination))</span>"
        }
    }

    private func replaceLinks(in escapedText: String) -> String {
        escapedText.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: #"<a href="$2">$1</a>"#,
            options: .regularExpression
        )
    }

    private func protectInlineCode(in text: String, placeholders: inout PlaceholderStore) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "`", let end = text[text.index(after: index)...].firstIndex(of: "`") else {
                output.append(text[index])
                index = text.index(after: index)
                continue
            }
            let code = String(text[text.index(after: index)..<end])
            output.append(placeholders.store("<code>\(HTML.escape(code))</code>"))
            index = text.index(after: end)
        }

        return output
    }

    private func protectImages(in text: String, store: inout InlineImageStore) -> String {
        var result = text
        let regex = try? NSRegularExpression(pattern: #"\!\[([^\]]*)\]\(([^)]+)\)"#)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() ?? []
        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let altRange = Range(match.range(at: 1), in: result),
                  let destinationRange = Range(match.range(at: 2), in: result) else {
                continue
            }
            let id = store.insert(InlineImage(alt: String(result[altRange]), destination: String(result[destinationRange])))
            result.replaceSubrange(fullRange, with: "%%MARKDOWNQL_IMAGE_\(id)%%")
        }
        return result
    }

    private func inferredTitle(from source: String) -> String? {
        source.split(separator: "\n").lazy.compactMap { line -> String? in
            guard let heading = heading(in: String(line)), heading.level == 1 else {
                return nil
            }
            return heading.text
        }.first
    }

    private func normalizedLines(_ source: String) -> [String] {
        source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
    }
}

private func containsMathDelimiters(in source: String) -> Bool {
    source.range(of: #"(?s)(?<!\\)\$\$.*?(?<!\\)\$\$"#, options: .regularExpression) != nil ||
        source.range(of: #"(?<!\\)\$[^\s$][^\n$]*?(?<!\\)\$"#, options: .regularExpression) != nil ||
        source.contains(#"\("#) ||
        source.contains(#"\["#)
}

private func isLocalImageDestination(_ destination: String) -> Bool {
    let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return !trimmed.isEmpty &&
        !trimmed.hasPrefix("http://") &&
        !trimmed.hasPrefix("https://") &&
        !trimmed.hasPrefix("data:")
}

private struct Fence {
    let marker: String
    let language: String
}

private struct InlineImage {
    let alt: String
    let destination: String
}

private struct InlineImageStore {
    private var nextID = 0
    private var images: [Int: InlineImage] = [:]

    mutating func insert(_ image: InlineImage) -> Int {
        nextID += 1
        images[nextID] = image
        return nextID
    }

    func image(for id: Int) -> InlineImage? {
        images[id]
    }
}

private struct PlaceholderStore {
    private var values: [String: String] = [:]
    private var index = 0

    mutating func store(_ html: String) -> String {
        index += 1
        let token = "%%MARKDOWNQL_PLACEHOLDER_\(index)%%"
        values[token] = html
        return token
    }

    func restore(in html: String) -> String {
        values.reduce(html) { result, entry in
            result.replacingOccurrences(of: entry.key, with: entry.value)
        }
    }
}

private func heading(in line: String) -> (level: Int, text: String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let hashes = trimmed.prefix(while: { $0 == "#" }).count
    guard (1...6).contains(hashes), trimmed.dropFirst(hashes).first == " " else {
        return nil
    }
    return (hashes, String(trimmed.dropFirst(hashes + 1)).trimmingCharacters(in: .whitespaces))
}

private func fenceStart(in line: String) -> Fence? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else {
        return nil
    }
    let marker = String(trimmed.prefix(3))
    let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first ?? ""
    return Fence(marker: marker, language: language)
}

private func isThematicBreak(_ line: String) -> Bool {
    line.range(of: #"^([-*_])(?:\s*\1){2,}\s*$"#, options: .regularExpression) != nil
}

private func isBlockquote(_ line: String) -> Bool {
    line.range(of: #"^\s*>"#, options: .regularExpression) != nil
}

private func isListItem(_ line: String) -> Bool {
    line.range(of: #"^\s*(?:[-+*]|\d+[.)])\s+"#, options: .regularExpression) != nil
}

private func isOrderedListItem(_ line: String) -> Bool {
    line.range(of: #"^\s*\d+[.)]\s+"#, options: .regularExpression) != nil
}

private func listItemText(_ line: String) -> String {
    line.replacingOccurrences(of: #"^\s*(?:[-+*]|\d+[.)])\s+"#, with: "", options: .regularExpression)
}

private func taskItem(_ text: String) -> (checked: Bool, text: String)? {
    if text.hasPrefix("[ ] ") {
        return (false, String(text.dropFirst(4)))
    }
    if text.lowercased().hasPrefix("[x] ") {
        return (true, String(text.dropFirst(4)))
    }
    return nil
}

private func isTableHeader(_ header: String, separator: String) -> Bool {
    guard header.contains("|") else {
        return false
    }
    let parts = tableCells(from: separator)
    return parts.count >= 2 && parts.allSatisfy { $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }
}

private func tableCells(from line: String) -> [String] {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("|") { trimmed.removeFirst() }
    if trimmed.hasSuffix("|") { trimmed.removeLast() }
    return trimmed.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
}

private func tableAlignment(_ marker: String) -> String {
    if marker.hasPrefix(":"), marker.hasSuffix(":") { return "center" }
    if marker.hasSuffix(":") { return "right" }
    if marker.hasPrefix(":") { return "left" }
    return ""
}

private func alignmentAttribute(_ alignment: String) -> String {
    alignment.isEmpty ? "" : " style=\"text-align: \(alignment)\""
}

private func replaceMatches(pattern: String, in text: String, replacement: ([String]) -> String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return text
    }
    var result = text
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
    for match in matches {
        guard let range = Range(match.range(at: 0), in: result) else {
            continue
        }
        let groups = (0..<match.numberOfRanges).map { offset -> String in
            guard let groupRange = Range(match.range(at: offset), in: result) else {
                return ""
            }
            return String(result[groupRange])
        }
        result.replaceSubrange(range, with: replacement(groups))
    }
    return result
}
