# QuillLook

QuillLook is a small macOS Quick Look extension for previewing Markdown files in Finder.

It renders Markdown locally with support for code highlighting, Mermaid diagrams, KaTeX math, tables, task lists, MDX files, and relative local images. The app stays intentionally quiet: open it once to install the extension, then use Space in Finder on `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, or `.mdx` files.

## Build

```bash
./script/build_and_run.sh --verify
```

This generates the Xcode project with XcodeGen, builds the app, installs it into `~/Applications`, refreshes Quick Look, and launches the containing app.

## Package

```bash
./script/package_release.sh
```

The packaged app zip is written to `dist/QuillLook-0.1.0-macOS.zip`.

This local package is ad-hoc signed for development/testing. For wider public distribution, sign with a Developer ID certificate and notarize the zip.

## Clean Old Registrations

```bash
./script/build_and_run.sh --clean-stale
```

This removes stale QuillLook and legacy MarkdownQL build products, unregisters old Quick Look extensions, and refreshes Quick Look caches.
