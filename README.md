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

## Features

- Native Finder Quick Look previews for Markdown and MDX files.
- Local rendering with no network requests.
- GitHub-style Markdown basics, including tables and task lists.
- Syntax highlighting for fenced code blocks.
- Mermaid diagrams for `mermaid` code fences.
- KaTeX math rendering when math delimiters are present.
- Relative local image support when files are readable.
- Preview and source modes.
- Lightweight asset loading so simple Markdown stays fast.

## Install

1. Download `QuillLook-0.1.0-macOS.dmg`.
2. Open the guided DMG and drag `QuillLook.app` into Applications.
3. Open QuillLook once so macOS discovers the Quick Look extension.
4. If macOS prompts you, enable the extension in System Settings.
5. Select a Markdown file in Finder and press Space.

The DMG is signed with Developer ID, notarized by Apple, and stapled for public distribution.

## Uninstall

Open the DMG and launch `Uninstall QuillLook.app`.

The uninstaller asks for confirmation, removes QuillLook from Applications, unregisters the Quick Look extension, clears QuillLook caches/preferences, and refreshes Quick Look. If the app was installed in `/Applications` with stricter permissions, macOS may ask for an administrator password. Your Markdown files are not touched.

## Supported Files

`md`, `markdown`, `mdown`, `mkd`, `mkdn`, `mdx`

## FAQ

### Why do I need to open the app once?

macOS discovers Quick Look extensions from installed apps. Opening QuillLook once gives the system a clean chance to register the extension.

### Where does QuillLook show up?

QuillLook appears in Finder Quick Look. Select a supported Markdown file and press Space. The containing app is only there for onboarding, samples, and cleanup help.

### Does it send my files anywhere?

No. Rendering is local and offline. Bundled assets are loaded from the app, and links are blocked from navigating inside the preview.

### Why is a preview stale after editing?

Finder can cache Quick Look previews. Re-selecting the file usually refreshes it; if it stays stale, run:

```bash
qlmanage -r cache
```

### How do I remove duplicate Quick Look entries?

If you used local development builds, stale copies can remain registered with macOS. From the repo, run:

```bash
./script/build_and_run.sh --clean-stale
```

End users can also run `Uninstall QuillLook.app` from the DMG to remove installed copies and clear Quick Look registrations.

## Build From Source

QuillLook uses XcodeGen to generate the Xcode project.

```bash
./script/build_and_run.sh --verify
```

This generates the project, builds the app, installs it into `~/Applications`, refreshes Quick Look, and launches the containing app.

## Public Release

To produce the signed and notarized DMG:

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

After packaging, publish the DMG to the GitHub release:

```bash
./script/publish_release.sh
```

## Local Development Package

```bash
./script/package_release.sh
```

This creates an ad-hoc signed zip for local testing only. Use the DMG flow for public downloads.

## Status

QuillLook is early but usable. The current focus is a fast, minimal Finder preview experience before adding preferences, an updater, or App Store polish.
