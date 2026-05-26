import AppKit
import SwiftUI

struct ContentView: View {
    private let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "md")
    @State private var cleanupMessage = "Ready"
    @State private var isCleaning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("QuillLook")
                    .font(.title.weight(.semibold))
                Text("Local Quick Look previews for Markdown, diagrams, math, code, tables, and images.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                StatusRow(symbol: "checkmark.seal.fill", title: "Quick Look extension", detail: "Installed locally")
                StatusRow(symbol: "lock.fill", title: "Offline renderer", detail: "Uses bundled assets only")
                StatusRow(symbol: "arrow.triangle.2.circlepath", title: "Extension list", detail: cleanupMessage)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    revealSample()
                } label: {
                    Label("Reveal Sample", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openExtensionsSettings()
                } label: {
                    Label("Open Extensions Settings", systemImage: "gearshape")
                }

                Button {
                    cleanDuplicates()
                } label: {
                    Label(isCleaning ? "Cleaning" : "Clean Duplicates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isCleaning)

                Spacer()
            }
        }
        .padding(28)
    }

    private func revealSample() {
        guard let sampleURL else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([sampleURL])
    }

    private func openExtensionsSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!,
            URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        ]

        for url in urls where NSWorkspace.shared.open(url) {
            return
        }
    }

    private func cleanDuplicates() {
        isCleaning = true
        cleanupMessage = "Cleaning stale copies..."

        Task.detached {
            let message = StaleQuillLookCleaner.clean()
            await MainActor.run {
                cleanupMessage = message
                isCleaning = false
            }
        }
    }
}

private struct StatusRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum StaleQuillLookCleaner {
    static func clean() -> String {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let currentAppPath = Bundle.main.bundleURL.standardizedFileURL.path
        let installedApp = home.appendingPathComponent("Applications/QuillLook.app")

        let candidates = [
            home.appendingPathComponent("Applications/MarkdownQL.app"),
            home.appendingPathComponent("Documents/QuillLook/dist/QuillLook.app"),
            home.appendingPathComponent("Documents/QuillLook/dist/MarkdownQL.app"),
            home.appendingPathComponent("Documents/QuillLook/build/DerivedData"),
            home.appendingPathComponent("Documents/MarkdownQL/dist/MarkdownQL.app"),
            home.appendingPathComponent("Documents/MarkdownQL/build/DerivedData"),
            home.appendingPathComponent("Library/Caches/QuillLook/TestDerivedData"),
            home.appendingPathComponent("Library/Caches/QuillLook/PackageDerivedData"),
            home.appendingPathComponent("Library/Caches/QuillLook/DerivedData/Build/Products/Debug"),
            home.appendingPathComponent("Library/Caches/QuillLook/DerivedData/Build/Products/Release/QuillLook.app"),
            home.appendingPathComponent("Library/Caches/QuillLook/DerivedData/Build/Products/Release/QuillLookPreviewExtension.appex"),
            home.appendingPathComponent("Library/Caches/MarkdownQL")
        ]

        var removedCount = 0
        var failedCount = 0

        for candidate in candidates {
            let path = candidate.standardizedFileURL.path
            guard path != currentAppPath, fileManager.fileExists(atPath: path) else {
                continue
            }

            unregisterBundles(under: candidate)
            unregister(candidate)
            do {
                try fileManager.removeItem(at: candidate)
                removedCount += 1
            } catch {
                failedCount += 1
            }
        }

        if fileManager.fileExists(atPath: installedApp.path) {
            _ = run("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", "-R", "-trusted", installedApp.path])
        }
        refreshQuickLook()

        if failedCount > 0 {
            return "Removed \(removedCount), \(failedCount) need manual cleanup"
        }
        return removedCount == 0 ? "No stale copies found" : "Removed \(removedCount) stale copies"
    }

    private static func unregister(_ url: URL) {
        _ = run("/usr/bin/pluginkit", ["-r", url.path])
        _ = run("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-u", url.path])
    }

    private static func unregisterBundles(under url: URL) {
        let bundleNames: Set<String> = [
            "QuillLook.app",
            "QuillLookPreviewExtension.appex",
            "MarkdownQL.app",
            "MarkdownQLPreviewExtension.appex"
        ]
        if bundleNames.contains(url.lastPathComponent) {
            unregister(url)
        }

        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return
        }

        for case let child as URL in enumerator where bundleNames.contains(child.lastPathComponent) {
            unregister(child)
            enumerator.skipDescendants()
        }
    }

    private static func refreshQuickLook() {
        _ = run("/usr/bin/qlmanage", ["-r"])
        _ = run("/usr/bin/qlmanage", ["-r", "cache"])
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
