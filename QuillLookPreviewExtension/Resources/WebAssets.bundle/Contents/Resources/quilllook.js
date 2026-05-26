(function () {
  function runEnhancements() {
    if (window.hljs) {
      window.hljs.highlightAll();
    }

    if (window.renderMathInElement) {
      window.renderMathInElement(document.body, {
        throwOnError: false,
        delimiters: [
          { left: "$$", right: "$$", display: true },
          { left: "\\[", right: "\\]", display: true },
          { left: "$", right: "$", display: false },
          { left: "\\(", right: "\\)", display: false }
        ]
      });
    }

    if (window.mermaid) {
      var dark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "strict",
        theme: dark ? "dark" : "default"
      });
      window.mermaid.run({ querySelector: ".mermaid" }).catch(function (error) {
        document.querySelectorAll(".mermaid").forEach(function (node) {
          node.textContent = node.textContent + "\n\nMermaid render failed: " + error.message;
        });
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", runEnhancements);
  } else {
    runEnhancements();
  }
})();

