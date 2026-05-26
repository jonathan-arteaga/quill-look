<p align="center">
  <img src="docs/assets/quilllook-icon.png" width="112" alt="QuillLook app icon">
</p>

<h1 align="center">QuillLook</h1>

<p align="center">
  <strong>Preview Markdown in Finder with Space.</strong>
</p>

<p align="center">
  <a href="https://github.com/jonathan-arteaga/quill-look/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/jonathan-arteaga/quill-look?label=release">
  </a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple">
  <img alt="Notarized Developer ID" src="https://img.shields.io/badge/Developer%20ID-notarized-2ea043">
</p>

<p align="center">
  <a href="https://github.com/jonathan-arteaga/quill-look/releases/download/v0.1.0/QuillLook-0.1.0-macOS.dmg"><strong>Download QuillLook 0.1.0 for macOS</strong></a>
</p>

QuillLook is a small macOS Quick Look extension that turns Markdown files into readable Finder previews. No editor, no web app, no network request: select a Markdown file, press Space, and read it where you already are.

- Read Markdown without opening a full editor.
- Preview docs, notes, READMEs, and MDX files while browsing Finder.
- Keep richer Markdown useful with tables, task lists, code highlighting, Mermaid diagrams, and KaTeX math.

## What It Does

QuillLook adds a polished Markdown preview to Finder. It works with common Markdown extensions, renders everything locally, and keeps a lightweight Preview/Source toggle for moments when you want to inspect the original text.

## Why It Helps

Finder is great for moving through folders, but Markdown files are usually hard to scan there. QuillLook makes Markdown feel like a first-class Mac document: quick to open, easy to read, and useful for checking project docs, personal notes, generated reports, or README files without breaking your flow.

## Screenshots

![QuillLook rendering Markdown in a Quick Look preview](docs/assets/quilllook-preview.png)

QuillLook renders common Markdown features directly inside Quick Look, including task lists, highlighted code, tables, Mermaid diagrams, and math.

## Get Started

1. Download [QuillLook 0.1.0 for macOS](https://github.com/jonathan-arteaga/quill-look/releases/download/v0.1.0/QuillLook-0.1.0-macOS.dmg).
2. Open the guided DMG.
3. Drag `QuillLook.app` into Applications.
4. Open QuillLook once so macOS can find the Quick Look extension.
5. Select a Markdown file in Finder and press Space.

If macOS asks whether to enable the extension, allow QuillLook in System Settings. After that, you can use it directly from Finder.

The DMG is signed with Developer ID, notarized by Apple, and stapled for public distribution.

## What QuillLook Handles

QuillLook is meant for everyday Markdown browsing, not editing. It is useful for checking project docs, generated reports, exported notes, README files, and MDX content without opening a separate app.

- **Files:** `md`, `markdown`, `mdown`, `mkd`, `mkdn`, `mdx`
- **Markdown:** headings, paragraphs, links, lists, blockquotes, tables, task lists, and inline formatting
- **Code:** fenced code blocks with language-aware highlighting
- **Diagrams:** Mermaid blocks using fenced `mermaid` code
- **Math:** KaTeX rendering when math delimiters are present
- **Images:** relative local images when the image files are readable
- **Source view:** a quick toggle when you want to inspect the original Markdown

## Privacy

QuillLook renders files locally on your Mac. It does not upload your Markdown, call a web service, or require an account. Bundled rendering assets are loaded from the app, and web links open outside the preview instead of navigating inside Quick Look.

## Remove QuillLook

Open the DMG and launch `Uninstall QuillLook.app`.

The uninstaller asks for confirmation, removes QuillLook from Applications, unregisters the Quick Look extension, clears QuillLook caches/preferences, and refreshes Quick Look. If the app was installed in `/Applications` with stricter permissions, macOS may ask for an administrator password. Your Markdown files are not touched.

## Troubleshooting

### QuillLook does not appear in Quick Look

Open QuillLook once from Applications, then try Finder again. If macOS shows an Extensions prompt, enable QuillLook there.

### The preview still looks stale after editing

Finder sometimes caches Quick Look previews. Select a different file, return to the Markdown file, and press Space again. If it still looks stale, restart Finder or clear the Quick Look cache:

```bash
qlmanage -r cache
```

### I see duplicate QuillLook entries

This usually happens after running local development builds from multiple folders. For normal installs, run `Uninstall QuillLook.app` from the DMG, then install the current DMG again.

Developers can also clean local build registrations from the repo:

```bash
./script/build_and_run.sh --clean-stale
```

### Why do I need to open the app once?

QuillLook is delivered as a normal Mac app that contains a Quick Look extension. Opening the app once gives macOS a clean chance to discover and register that extension.

### Where does QuillLook show up?

In Finder. Select a supported Markdown file and press Space. The app window is only for onboarding, sample files, and cleanup help.

## For Developers

<details>
<summary>Build from source, package the DMG, and publish releases</summary>

QuillLook uses XcodeGen to generate the Xcode project.

Build, install locally, refresh Quick Look, and launch the app:

```bash
./script/build_and_run.sh --verify
```

Create the public signed and notarized DMG:

```bash
./script/package_dmg.sh
```

The DMG is written to:

```text
dist/QuillLook-0.1.0-macOS.dmg
```

Public packaging requires a Developer ID Application certificate and a stored notary profile named `quilllook-notary`.

```bash
xcrun notarytool store-credentials quilllook-notary \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD
```

Publish the notarized DMG to the GitHub release:

```bash
./script/publish_release.sh
```

For local testing only, you can also create an ad-hoc signed zip:

```bash
./script/package_release.sh
```

</details>

## Status

QuillLook is early but usable. The current focus is a fast, minimal Finder preview experience before adding preferences, an updater, or App Store polish.
