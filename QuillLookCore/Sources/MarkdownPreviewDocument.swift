import Foundation

public struct MarkdownPreviewDocument {
    public var result: MarkdownRenderResult
    public var asset: (String) -> String?

    public init(result: MarkdownRenderResult, asset: @escaping (String) -> String?) {
        self.result = result
        self.asset = asset
    }

    public func html() -> String {
        let styles = [
            styleTag("styles.css"),
            result.features.hasCode ? styleTag("highlight-light.css", media: "(prefers-color-scheme: light)") : "",
            result.features.hasCode ? styleTag("highlight-dark.css", media: "(prefers-color-scheme: dark)") : "",
            result.features.hasMath ? styleTag("katex.min.css") : ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        let scripts = [
            result.features.hasCode ? scriptTag("highlight.min.js") : "",
            result.features.hasMath ? scriptTag("katex.min.js") : "",
            result.features.hasMath ? scriptTag("auto-render.min.js") : "",
            result.features.hasMermaid ? scriptTag("mermaid.min.js") : "",
            scriptTag("quilllook.js")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escape(result.title))</title>
          \(styles)
        </head>
        <body>
          <nav class="quilllook-modebar" aria-label="Preview mode">
            <button type="button" data-mode="preview" aria-pressed="true">Preview</button>
            <button type="button" data-mode="source" aria-pressed="false">Source</button>
          </nav>
          <main id="quilllook-preview" class="quilllook-panel">\(result.previewBody)</main>
          <main id="quilllook-source" class="quilllook-panel source-view" hidden>\(result.sourceBody)</main>
          <script>
            document.querySelectorAll(".quilllook-modebar button").forEach(function (button) {
              button.addEventListener("click", function () {
                var showingSource = button.dataset.mode === "source";
                document.getElementById("quilllook-preview").hidden = showingSource;
                document.getElementById("quilllook-source").hidden = !showingSource;
                document.querySelectorAll(".quilllook-modebar button").forEach(function (item) {
                  item.setAttribute("aria-pressed", item === button ? "true" : "false");
                });
              });
            });
          </script>
          \(scripts)
        </body>
        </html>
        """
    }

    private func styleTag(_ name: String, media: String? = nil) -> String {
        guard let css = asset(name) else {
            return ""
        }
        let mediaAttribute = media.map { #" media="\#(escape($0))""# } ?? ""
        return "<style\(mediaAttribute)>\(css)</style>"
    }

    private func scriptTag(_ name: String) -> String {
        guard let script = asset(name) else {
            return ""
        }
        let safeScript = script.replacingOccurrences(of: "</script", with: "<\\/script")
        return "<script>\(safeScript)</script>"
    }

    private func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
