<p align="center">
  <img src="docs/assets/quilllook-icon.png" width="112" alt="QuillLook app icon">
</p>

<h1 align="center">QuillLook</h1>

<p align="center">
  A clean, local Quick Look previewer for Markdown on macOS.
</p>

<p align="center">
  <a href="https://github.com/jonathan-arteaga/quill-look/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/jonathan-arteaga/quill-look?label=release">
  </a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?logo=apple">
  <img alt="Notarized Developer ID" src="https://img.shields.io/badge/Developer%20ID-notarized-2ea043">
</p>

QuillLook lets Finder preview Markdown files with the Space bar. It is intentionally small: install the app once, enable the Quick Look extension if macOS asks, then preview `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, and `.mdx` files without opening an editor.

## Download

[Download QuillLook 0.1.0 for macOS](https://github.com/jonathan-arteaga/quill-look/releases/download/v0.1.0/QuillLook-0.1.0-macOS.dmg)

The DMG is signed with Developer ID, notarized by Apple, and stapled for public distribution.

## Install

1. Download the latest `QuillLook-0.1.0-macOS.dmg`.
2. Open the DMG and drag `QuillLook.app` into Applications.
3. Open QuillLook once.
4. If macOS prompts you, enable the Quick Look extension in System Settings.
5. Select a Markdown file in Finder and press Space.

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

## Supported Files

`md`, `markdown`, `mdown`, `mkd`, `mkdn`, `mdx`

## Why QuillLook

Most Markdown previewers either do too little or become a full editor. QuillLook is just the missing Finder preview: readable typography, useful Markdown extras, and a quiet containing app that stays out of the way.

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

## Clean Old Quick Look Registrations

```bash
./script/build_and_run.sh --clean-stale
```

This removes stale QuillLook and legacy MarkdownQL build products, unregisters old Quick Look extensions, and refreshes Quick Look caches.

## Status

QuillLook is early but usable. The current focus is a fast, minimal Finder preview experience before adding preferences, an updater, or App Store polish.
