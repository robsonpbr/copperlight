import AppKit
import UniformTypeIdentifiers

/// The newest files in `folder`, newest first by when they arrived there (else when they were made); hidden files and
/// downloads still coming left out. `keep` picks among the newest 100.
func latestFiles(in folder: URL, limit: Int, keep: (URL) -> Bool = { _ in true }) -> [URL] {
    let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
    let unfinished: Set<String> = ["download", "crdownload", "part"]
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)) ?? []
    let dated = files.filter { !unfinished.contains($0.pathExtension.lowercased()) }.map { file in
        let values = try? file.resourceValues(forKeys: Set(keys))
        let made = values?.creationDate ?? .distantPast
        return (file: file, added: values?.addedToDirectoryDate ?? made, made: made)
    }
    // Dates added are kept to the second: what was made later goes first among files added the same second.
    let newest = dated.sorted { ($0.added, $0.made) > ($1.added, $1.made) }.prefix(100).map(\.file)
    return Array(newest.filter(keep).prefix(limit))
}

/// Where screenshots are saved: the folder chosen in the Screenshot toolbar's Options, else the Desktop.
func screenshotFolder() -> URL {
    let chosen = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location").map { NSString(string: $0).expandingTildeInPath }
    return chosen.map { URL(filePath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
}

/// Whether macOS marked `file` as a screenshot (whatever its name, in any language).
func markedAsScreenshot(_ file: URL) -> Bool {
    guard let item = MDItemCreateWithURL(nil, file as CFURL) else { return false }
    return (MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool) == true
}

/// `screenshots` and `downloads`: your newest ones first (`latest screenshot`, `last download`: just the newest).
/// Enter pastes the file into the app you were in (or copies it, without Accessibility); Tab shows what else.
struct LatestFilesProvider: ResultProvider {
    var screenshots: @Sendable () -> URL = { screenshotFolder() }
    var downloads: @Sendable () -> URL = { FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads") }
    var isScreenshot: @Sendable (URL) -> Bool = { markedAsScreenshot($0) }

    func results(for query: String) async -> [LauncherResult] {
        let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
        let one = ["latest ", "last "].contains { lower.hasPrefix($0) }
        let kind = one ? String(lower.drop { $0 != " " }.dropFirst()) : lower
        let limit = one ? 1 : 20
        switch (kind, one) {
        case ("screenshots", _), ("screenshot", true): return rows(latestFiles(in: screenshots(), limit: limit, keep: isScreenshot))
        case ("downloads", _), ("download", true): return rows(latestFiles(in: downloads(), limit: limit))
        default: return []
        }
    }

    private func rows(_ files: [URL]) -> [LauncherResult] {
        let now = Date.now
        return files.enumerated().map { index, file in
            let values = try? file.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey, .fileSizeKey])
            let added = values?.addedToDirectoryDate ?? values?.creationDate ?? now
            let size = values?.fileSize.map { " · " + Int64($0).formatted(.byteCount(style: .file)) } ?? ""
            let path = file.path, image = UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) == true
            return LauncherResult(
                id: "latest:\(path)", title: file.lastPathComponent, subtitle: added.formatted(.relative(presentation: .named, unitsStyle: .wide)) + size,
                icon: .file(path), score: 50 - Double(index) / 100, actionTitle: AXIsProcessTrusted() ? "Paste" : "Copy",
                action: { pasteFile(file) }, actions: { fileActionRows(path, terminal: nil) }, previewStyle: .prose,
                previewImage: image ? { @MainActor in NSImage(contentsOf: file) } : nil)
        }
    }
}

/// Puts the file on the clipboard, and pastes it into the app in front when Accessibility allows.
@MainActor func pasteFile(_ file: URL) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([file as NSURL])
    if hasAccessibility("paste files") { sendPaste() }
}

/// The paths in what Finder's script returns, a line each; a folder's without its last "/".
func finderPaths(_ output: String) -> [String] {
    output.split(separator: "\n").map { $0.count > 1 && $0.hasSuffix("/") ? String($0.dropLast()) : String($0) }
}

/// What's selected in Finder, when it's in front and Copperlight may ask it (asked from the empty launcher, once).
func finderSelection() async -> [String] {
    guard automationPermission("com.apple.finder", ask: false) == noErr else { return [] }
    let script = """
        tell application "Finder" to set picked to selection as alias list
        set out to ""
        repeat with f in picked
            set out to out & POSIX path of f & linefeed
        end repeat
        return out
        """
    let run = await runTool(URL(filePath: "/usr/bin/osascript"), ["-e", script], timeout: 2)
    return run.succeeded ? finderPaths(run.output) : []
}

/// The files selected in Finder, on top of the empty launcher: Enter opens one, Tab shows what else (AirDrop, Copy
/// Path, Open With, Trash), and over an Open dialog Enter goes there.
func finderRows(_ paths: [String]) -> [LauncherResult] {
    paths.prefix(10).enumerated().map { index, path in
        LauncherResult(id: "file:\(path)", title: (path as NSString).lastPathComponent, subtitle: "Selected in Finder · " + shortParentPath(path),
                       icon: .file(path), score: 200 - Double(index) / 100, action: { _ = NSWorkspace.shared.open(URL(filePath: path)) },
                       actions: { fileActionRows(path, terminal: nil) })
    }
}

/// In the empty launcher over Finder, until it's answered: Enter asks macOS to let Copperlight see Finder's selection.
func finderAskRow() -> LauncherResult {
    LauncherResult(id: "finder:ask", title: "Use What's Selected in Finder", subtitle: "Asks to control Finder, once", icon: .symbol("cursorarrow.rays"),
                   score: 150, actionTitle: "Allow", action: {
        Task.detached {
            if automationPermission("com.apple.finder", ask: true) == noErr { await notify("Select files in Finder and press the hotkey") }
        }
    })
}
