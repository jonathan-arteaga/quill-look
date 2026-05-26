import AppKit
import Foundation

@main
struct UninstallQuillLook {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        DispatchQueue.main.async {
            Uninstaller().run()
            app.terminate(nil)
        }

        app.run()
    }
}

private final class Uninstaller {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    private var removedItems: [String] = []
    private var failedItems: [String] = []

    func run() {
        NSApp.activate(ignoringOtherApps: true)

        guard confirmUninstall() else {
            return
        }

        _ = runProcess("/usr/bin/pkill", ["-x", "QuillLook"])
        unregisterDiscoveredQuickLookProviders()

        for url in removableURLs() {
            removeIfPresent(url)
        }

        refreshQuickLook()
        showResult()
    }

    private func confirmUninstall() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Uninstall QuillLook?"
        alert.informativeText = "This removes QuillLook from Applications, unregisters its Quick Look extension, clears QuillLook caches and preferences, and refreshes Quick Look. Your Markdown files are not touched."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showResult() {
        let alert = NSAlert()
        alert.messageText = failedItems.isEmpty ? "QuillLook was uninstalled." : "QuillLook was mostly uninstalled."

        if failedItems.isEmpty {
            let count = removedItems.count
            alert.informativeText = count == 0
                ? "No installed QuillLook files were found. Quick Look caches were refreshed."
                : "Removed \(count) QuillLook item\(count == 1 ? "" : "s") and refreshed Quick Look."
            alert.alertStyle = .informational
        } else {
            alert.informativeText = "Some items could not be removed:\n\n" + failedItems.prefix(4).joined(separator: "\n")
            alert.alertStyle = .warning
        }

        alert.addButton(withTitle: "Done")
        _ = alert.runModal()
    }

    private func removableURLs() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications/QuillLook.app"),
            home.appendingPathComponent("Applications/QuillLook.app"),
            URL(fileURLWithPath: "/Applications/MarkdownQL.app"),
            home.appendingPathComponent("Applications/MarkdownQL.app"),
            home.appendingPathComponent("Library/Application Support/QuillLook"),
            home.appendingPathComponent("Library/Caches/QuillLook"),
            home.appendingPathComponent("Library/Caches/MarkdownQL"),
            home.appendingPathComponent("Library/Preferences/com.jonathanarteaga.QuillLook.plist"),
            home.appendingPathComponent("Library/Preferences/com.jonathanarteaga.MarkdownQL.plist"),
            home.appendingPathComponent("Library/Saved Application State/com.jonathanarteaga.QuillLook.savedState"),
            home.appendingPathComponent("Library/Saved Application State/com.jonathanarteaga.MarkdownQL.savedState")
        ]
    }

    private func removeIfPresent(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard fileManager.fileExists(atPath: path) else {
            return
        }

        unregisterBundles(under: url)
        unregister(url)

        do {
            try fileManager.removeItem(at: url)
            removedItems.append(displayPath(path))
        } catch {
            if canRequestPrivilegedRemoval(for: url), removeWithAdministratorPrompt(url) {
                removedItems.append(displayPath(path))
            } else {
                do {
                    var trashedURL: NSURL?
                    try fileManager.trashItem(at: url, resultingItemURL: &trashedURL)
                    removedItems.append(displayPath(path))
                } catch {
                    failedItems.append(displayPath(path))
                }
            }
        }
    }

    private func canRequestPrivilegedRemoval(for url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path == "/Applications/QuillLook.app" || path == "/Applications/MarkdownQL.app"
    }

    private func removeWithAdministratorPrompt(_ url: URL) -> Bool {
        runProcess("/usr/bin/osascript", [
            "-e", "on run argv",
            "-e", "do shell script \"/bin/rm -rf \" & quoted form of item 1 of argv with administrator privileges",
            "-e", "end run",
            url.standardizedFileURL.path
        ])
    }

    private func unregisterDiscoveredQuickLookProviders() {
        let output = processOutput("/usr/bin/pluginkit", ["-m", "-vv", "-p", "com.apple.quicklook.preview"])
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Path = ") else {
                continue
            }

            let path = String(trimmed.dropFirst("Path = ".count))
            if path.contains("QuillLook") || path.contains("MarkdownQL") {
                unregister(URL(fileURLWithPath: path))
            }
        }
    }

    private func unregisterBundles(under url: URL) {
        let bundleNames: Set<String> = [
            "QuillLook.app",
            "QuillLookPreviewExtension.appex",
            "MarkdownQL.app",
            "MarkdownQLPreviewExtension.appex"
        ]

        if bundleNames.contains(url.lastPathComponent) {
            unregister(url)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return
        }

        for case let child as URL in enumerator where bundleNames.contains(child.lastPathComponent) {
            unregister(child)
            enumerator.skipDescendants()
        }
    }

    private func unregister(_ url: URL) {
        _ = runProcess("/usr/bin/pluginkit", ["-r", url.path])
        _ = runProcess(lsregister, ["-u", url.path])
    }

    private func refreshQuickLook() {
        _ = runProcess("/usr/bin/qlmanage", ["-r"])
        _ = runProcess("/usr/bin/qlmanage", ["-r", "cache"])
    }

    private func runProcess(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func processOutput(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self)
        } catch {
            return ""
        }
    }

    private func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: home.path, with: "~")
    }
}
