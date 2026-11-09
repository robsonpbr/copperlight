import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

// The launcher's shortcut comes from config.toml ([hotkeys]); see Config.Hotkeys for the default.
extension KeyboardShortcuts.Name {
    static let toggleLauncher = Self("toggleLauncher")
}

extension Hotkey {
    var shortcut: KeyboardShortcuts.Shortcut { .init(.init(rawValue: keyCode), modifiers: modifiers) }
}

/// Launcher rows for Copperlight's own features.
struct BuiltinProvider: ResultProvider {
    let showNote: @MainActor @Sendable (URL) -> Void // a note's file
    let showClipboard: @MainActor @Sendable () -> Void
    var showWelcome: @MainActor @Sendable () -> Void = {}
    var showHelp: @MainActor @Sendable () -> Void = {}
    var showSettings: @MainActor @Sendable () -> Void = {}
    var newNote: @MainActor @Sendable (String) -> Void = { _ in } // a new note starting with this text ("": empty)
    var notesFolder = notesDir
    var noteFile = mainNoteFile

    /// The Notes chip (`note` ⇥): your notes alone, without apps or the search row.
    var modes: [Mode] {
        Feature.notes.isOn ? [Mode(prefix: "note ", title: String(localized: "Notes"), icon: .symbol("note.text"),
                                   hint: String(localized: "A word in them, or nothing for all", comment: "The Notes chip's empty field"))] : []
    }

    func modeResults(for query: String) async -> [LauncherResult] {
        // The launcher trims the query: the chip alone is "note".
        let lower = query.lowercased()
        return lower == "note" || lower.hasPrefix("note ") ? noteRows(query.dropFirst(4).trimmingCharacters(in: .whitespaces)) : results(for: query)
    }

    func results(for query: String) -> [LauncherResult] {
        var rows: [LauncherResult] = []
        let lower = query.lowercased()
        let notesOn = Feature.notes.isOn && !Feature.notes.isBlocked // `note`, replaced by your word, typed: not the note
        if notesOn, let score = score(query, prefixOf: "note", title: "Note") {
            let last = notes().first?.url
            rows.append(LauncherResult(id: "builtin:note", title: String(localized: "Note"),
                                       subtitle: String(localized: "Your last note · Esc hides it"), icon: .symbol("note.text"), score: score,
                                       action: { [showNote, newNote] in if let last { showNote(last) } else { newNote("") } }))
        }
        if notesOn {
            rows += notesStartRow(lower).map { [$0] } ?? []
            if lower.count >= 5, "new note".hasPrefix(lower) { rows.append(newNoteRow("", score: 50)) }
            rows += noteTextRows(query)
        }
        // From 3 letters: "c" and "cl" belong to Chrome, Calendar, Claude…
        if Feature.clipboard.isOn, !Feature.clipboard.isBlocked,
           let score = score(query, prefixOf: "clipboard", minLength: 3, title: "Clipboard History") {
            rows.append(LauncherResult(id: "builtin:clipboard", title: String(localized: "Clipboard History"),
                                       subtitle: String(localized: "Search past copies"), icon: .symbol("doc.on.clipboard"), score: score,
                                       action: showClipboard))
        }
        if let score = score(query, prefixOf: "welcome", minLength: 3, title: "Welcome to Copperlight") {
            rows.append(LauncherResult(id: "builtin:welcome", title: String(localized: "Welcome to Copperlight"),
                                       subtitle: String(localized: "The hotkey, permissions, Open at Login"), icon: .symbol("hand.wave"),
                                       score: score, action: showWelcome))
        }
        if let score = score(query, prefixOf: "help", minLength: 3, title: "Help") {
            rows.append(LauncherResult(id: "builtin:help", title: String(localized: "Help"), subtitle: String(localized: "Everything you can type"),
                                       icon: .symbol("questionmark.circle"), score: score, action: showHelp))
        }
        // "settings" alone is System Settings' too, so only a plain fuzzy match there; "copperlight" goes straight to it.
        if let score = score(query, prefixOf: "copperlight settings", minLength: 3, title: "Copperlight Settings") {
            rows.append(LauncherResult(id: "builtin:settings", title: String(localized: "Copperlight Settings"),
                                       subtitle: String(localized: "Hotkey, features, clipboard, files, browser, commands, snippets"),
                                       icon: .symbol("gearshape"), score: score, action: showSettings))
        }
        return rows
    }

    /// ponytail: every note is read on every keystroke that asks for them; cache by date if there are many.
    private func notes() -> [NoteFile] { notesByDate(in: notesFolder, main: noteFile) }

    private func noteRow(_ note: NoteFile, id: String, subtitle: String, score: Double) -> LauncherResult {
        let url = note.url
        return LauncherResult(id: id, title: note.title, subtitle: subtitle, accessory: shortAge(note.edited), icon: .symbol("note.text"),
                              score: score, action: { [showNote] in showNote(url) }, preview: note.text.isEmpty ? nil : note.text,
                              previewStyle: .prose)
    }

    /// `not`, `note`, `notes`: the list, a Tab away (the Notes chip); `note milk`: the list, already searching.
    private func notesStartRow(_ lower: String) -> LauncherResult? {
        let typed = lower.hasPrefix("note ") ? lower.dropFirst(5).trimmingCharacters(in: .whitespaces) : ""
        let score: Double
        if !typed.isEmpty { score = 50 }
        else if lower.count >= 3, "notes".hasPrefix(lower) { score = lower.hasPrefix("notes") ? 50.01 : 49.99 }
        else if let other = otherNameScore(lower, "All Notes") { score = other }
        else { return nil }
        return LauncherResult(id: "builtin:notes",
                              title: typed.isEmpty ? String(localized: "Notes") : String(localized: "Notes with “\(typed)”"),
                              subtitle: typed.isEmpty ? String(localized: "All your notes, the last edited first")
                                  : String(localized: "Your notes that say it"),
                              icon: .symbol("list.bullet.rectangle"), score: score,
                              actionTitle: String(localized: "List", comment: "Enter on the Notes row: lists them in the Notes chip"),
                              action: {}, completion: "note " + typed)
    }

    private func newNoteRow(_ text: String, score: Double) -> LauncherResult {
        LauncherResult(id: "note:new", title: String(localized: "New Note"),
                       subtitle: text.isEmpty ? String(localized: "An empty one", comment: "A new note")
                           : String(localized: "Starting with “\(text)”"),
                       icon: .symbol("square.and.pencil"), score: score, actionTitle: String(localized: "Create", comment: "Enter on New Note"),
                       action: { [newNote] in newNote(text) })
    }

    /// In the Notes chip: every note by its first line, last edited first, with the next line and, beside the list,
    /// its text; then New Note. `milk`: the notes with "milk" in them, and a new one starting with it.
    private func noteRows(_ typed: String) -> [LauncherResult] {
        notes().enumerated().compactMap { index, note -> LauncherResult? in
            let line = typed.isEmpty ? nil : matchingLine(note.text, typed)
            guard typed.isEmpty || line != nil else { return nil }
            return noteRow(note, id: "note:\(note.url.lastPathComponent)", subtitle: line ?? note.summary, score: 49 - Double(index) / 100)
        } + [newNoteRow(typed, score: 0)]
    }

    /// The notes with `query`'s words in them, anywhere, from 3 letters: below what matches by name, with the line.
    private func noteTextRows(_ query: String) -> [LauncherResult] {
        let lower = query.lowercased()
        guard query.count >= 3, lower != "note", !lower.hasPrefix("note ") else { return [] }
        return notes().compactMap { note in
            matchingLine(note.text, query).map {
                noteRow(note, id: "note-text:\(note.url.lastPathComponent)", subtitle: String(localized: "Note · \($0)"), score: 0.3)
            }
        }
    }

    /// A prefix of `keyword` (at least `minLength` long) ranks first: above apps, fuzzy commands and
    /// math; only an exact command alias (100) beats it. Anything else is a plain fuzzy match on the title.
    private func score(_ query: String, prefixOf keyword: String, minLength: Int = 1, title: String) -> Double? {
        query.count >= minLength && keyword.hasPrefix(query.lowercased()) ? 50 : titleScore(title) { fuzzyScore(query, $0) } ?? otherNameScore(query, title)
    }
}

@main
struct CopperlightApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var launchAtLogin = false

    var body: some Scene {
        MenuBarExtra("Copperlight", image: "Mark") { // the icon's C
            Button("Settings…") { delegate.showSettings() }.keyboardShortcut(",")
            Button("Welcome to Copperlight") { delegate.showWelcome() }
            Button("Help") { delegate.showHelp() }
            Toggle("Launch at Login", isOn: Binding(get: { launchAtLogin }, set: { launchAtLogin = setLaunchAtLogin($0) }))
                // The menu is built once, so ask again each time it opens: System Settings → Login Items may have
                // changed it. onAppear covers the first open, before onReceive is listening.
                .onAppear(perform: readLaunchAtLogin)
                .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in readLaunchAtLogin() }
            Divider()
            Button("Quit Copperlight") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }

    private func readLaunchAtLogin() { launchAtLogin = SMAppService.mainApp.status == .enabled }
}

/// Registers this copy of the app (wherever it is now) as a login item, or removes it.
/// Returns whether it ends up enabled.
@MainActor func setLaunchAtLogin(_ on: Bool) -> Bool {
    let service = SMAppService.mainApp
    do {
        if on { try service.register() } else { try service.unregister() }
    } catch {
        notify(String(localized: "Couldn't change Launch at Login"), error.localizedDescription)
    }
    if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    return service.status == .enabled
}

/// The windows, panels, notes, hotkey and menu bar's actions, around `AppCore`, which is everything else.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var core: AppCore = AppCore(
        configFile: Config.file, clipboardFile: ClipboardStore.file, state: .shared,
        actions: .init(
            showTyping: { [unowned self] in panel.show(typing: $0) },
            showNote: { [unowned self] in showNote($0) },
            newNote: { [unowned self] in newNote($0) },
            addToNote: { [unowned self] in addToNote($0) },
            releaseNote: { [unowned self] in releaseNote($0) },
            showClipboard: { [unowned self] in showClipboard() },
            showClipboardPanel: { [unowned self] in clipboardPanel.show() },
            showWelcome: { [unowned self] in showWelcome() },
            showHelp: { [unowned self] in showHelp() },
            showSettings: { [unowned self] in showSettings($0) },
            setHotkey: { KeyboardShortcuts.setShortcut($0.shortcut, for: .toggleLauncher) },
            styleNotes: { [unowned self] markdown in
                NotePanel.stylesMarkdown = markdown
                notes.values.forEach { $0.restyle() }
            },
            configReloaded: { [unowned self] in settings?.model.reload() }))
    private lazy var panel: LauncherPanel = LauncherPanel(model: core.model,
                                                          placeholder: String(localized: "Type anything", comment: "The launcher's empty field"))
    private lazy var clipboardPanel: LauncherPanel = LauncherPanel(model: core.clipboardModel,
                                                    placeholder: String(localized: "Search clipboard history, : for commands…"))
    private lazy var helpPanel = CheatSheetPanel(fill: { [unowned self] text in
        panel.model.fileDialog = frontFileDialog()
        core.refresh()
        panel.show()
        panel.model.put(text)
    })
    private var notes: [String: NotePanel] = [:] // by the file's path
    private var welcome: WelcomeWindow?
    private var settings: SettingsWindow?
    private var watcher: DirectoryWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests launch the app too: don't grab hotkeys, touch files or hit the network there.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true) // and configDir
        core.start()
        // Built now, so the first ⌥ Space is as quick as the rest: building it then took about 50 ms.
        panel.contentView?.layoutSubtreeIfNeeded()
        // ponytail: turned off later, a clock already running keeps going until it ends; it's what you started.
        if Feature.pomodoro.isOn { core.pomodoro.restore() }
        if Feature.timers.isOn { core.countdown.restore() }
        if Feature.stopwatch.isOn { core.stopwatch.restore() }
        if Feature.translate.isOn { Task { _ = await TranslateProvider.languages() } } // its language chips
        watcher = DirectoryWatcher(configDir) { [unowned self] in
            core.reloadConfig()
            notes[mainNoteFile.path]?.reloadIfChanged()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleLauncher) { [unowned self] in
            welcome?.model.triedHotkey = true
            toggleLauncher()
        }
        core.refresh()
        if StateStore.shared.get("welcomed", as: Bool.self) != true {
            StateStore.shared.set("welcomed", true)
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notes.values.forEach { $0.saveNow() }
        StateStore.shared.flush()
    }

    private func toggleLauncher() {
        if panel.isVisible { return panel.orderOut(nil) }
        let selection = frontSelection() // before the panel takes the keys, so it's still the app's
        panel.model.fileDialog = frontFileDialog()
        core.finderIdle = []
        if Feature.files.isOn, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" {
            if automationPermission("com.apple.finder", ask: false) == OSStatus(errAEEventWouldRequireUserConsent) {
                core.finderIdle = [finderAskRow()]
            } else {
                Task { [weak self] in
                    let paths = await finderSelection()
                    guard let self, !paths.isEmpty, panel.isVisible, panel.model.query.isEmpty else { return }
                    core.finderIdle = finderRows(paths)
                    panel.model.query = "" // shows them
                }
            }
        }
        core.refresh()
        panel.show(typing: selection)
        // A browser asked to share its text just now answers a moment later: in time, unless you've typed already.
        guard selection == nil else { return }
        Task { [panel] in
            try? await Task.sleep(for: .milliseconds(250))
            if panel.isVisible, panel.model.query.isEmpty, let late = frontSelection() { panel.begin(with: late) }
        }
    }

    /// Brings the welcome screen forward, or builds it again if it was closed (so it plays its entrance again).
    func showWelcome() {
        if welcome?.isVisible != true {
            welcome = WelcomeWindow { [unowned self] in
                welcome?.close()
                core.refresh()
                panel.show()
            }
        }
        welcome?.model.keycaps = KeyboardShortcuts.getShortcut(for: .toggleLauncher)?.keycaps ?? []
        welcome?.show()
    }

    /// `help`, and the menu bar's Help.
    func showHelp() { helpPanel.show(core.cheatSheet()) }

    /// Opens Settings, on `pane` when given.
    func showSettings(_ pane: Pane? = nil) {
        if settings?.isVisible != true {
            settings = SettingsWindow(showWelcome: { [unowned self] in showWelcome() }, forget: { [unowned self] in core.model.forget($0) })
        }
        if let pane { settings?.model.pane = pane }
        settings?.show()
    }

    private func showClipboard() {
        core.prepareClipboard()
        clipboardPanel.show()
    }

    private func note(_ file: URL) -> NotePanel {
        if let panel = notes[file.path] { return panel }
        let panel = NotePanel(file: file)
        notes[file.path] = panel
        return panel
    }

    private func showNote(_ file: URL) { note(file).show() }

    /// A new note, opened: empty (its file is written once you type), or starting with `text` on its first line.
    private func newNote(_ text: String) {
        let file = newNoteFile()
        if !text.isEmpty {
            try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
            try? (text + "\n").write(to: file, atomically: true, encoding: .utf8)
        }
        showNote(file)
    }

    /// Closes a note's panel, saved, before it goes to the Trash.
    private func releaseNote(_ file: URL) {
        guard let panel = notes.removeValue(forKey: file.path) else { return }
        panel.saveNow()
        panel.orderOut(nil)
    }

    /// Through the panel, open or not, so text being typed in it isn't overwritten by the file.
    private func addToNote(_ line: String) { note(mainNoteFile).append(line) }
}
