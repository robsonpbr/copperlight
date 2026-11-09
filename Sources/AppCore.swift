import AppKit

/// Everything Copperlight is but its windows: the features, the search models, config.toml and the clipboard history,
/// put together in the order launch needs. AppDelegate owns one and adds the panels, the menu bar and the hotkey; tests
/// build one on a temporary folder, so the wiring runs in them as it does in the app.
@MainActor
final class AppCore {
    /// What needs a window or the hotkey: AppDelegate fills these in.
    struct Actions {
        // No defaults: one left out wouldn't compile, where it would otherwise do nothing, with no test to see it.
        let showTyping: @MainActor @Sendable (String) -> Void // the launcher, with this text
        let showNote: @MainActor @Sendable (URL) -> Void
        let newNote: @MainActor @Sendable (String) -> Void
        let addToNote: @MainActor @Sendable (String) -> Void
        let releaseNote: @MainActor @Sendable (URL) -> Void
        let showClipboard: @MainActor @Sendable () -> Void
        let showClipboardPanel: @MainActor @Sendable () -> Void // already prepared: to show a notice
        let showWelcome: @MainActor @Sendable () -> Void
        let showHelp: @MainActor @Sendable () -> Void
        let showSettings: @MainActor @Sendable (Pane?) -> Void
        let setHotkey: @MainActor @Sendable (Hotkey) -> Void
        let styleNotes: @MainActor @Sendable (Bool) -> Void // `[notes] markdown`
        let configReloaded: @MainActor @Sendable () -> Void
    }

    private let configFile: URL
    private let clipboardFile: URL
    private let state: StateStore
    private let actions: Actions
    private let sealed: Bool // for tests: the real pasteboard isn't watched, and the browsers' history isn't read

    init(configFile: URL, clipboardFile: URL, state: StateStore, actions: Actions, sealed: Bool = false) {
        (self.configFile, self.clipboardFile, self.state, self.actions, self.sealed) = (configFile, clipboardFile, state, actions, sealed)
        (pomodoro, countdown, stopwatch) = (Pomodoro(store: state), Countdown(store: state), Stopwatch(store: state))
    }

    private let apps = AppProvider()
    private let currency = CurrencyProvider()
    private let commands = CommandProvider()
    private let web = WebProvider()
    private let snippets = SnippetProvider()
    private let pages = BrowserPagesProvider()
    private let meetings = MeetingsProvider()
    private let contacts = ContactsProvider()
    private let tabs = BrowserTabsProvider()
    private lazy var reminders = RemindersProvider(show: actions.showTyping, showSettings: { [actions] in actions.showSettings(.options) })
    private let translate = TranslateProvider()
    private let weather = WeatherProvider()
    private let files = FileSearchProvider()
    private let photoText = Feature.photoText.isOn ? try? PhotoTextStore(path: PhotoTextStore.file.path) : nil
    private lazy var photoIndexer = photoText.map(PhotoIndexer.init)
    let pomodoro: Pomodoro
    let countdown: Countdown
    let stopwatch: Stopwatch
    private lazy var builtins = BuiltinProvider(showNote: actions.showNote, showClipboard: actions.showClipboard, showWelcome: actions.showWelcome, showHelp: actions.showHelp,
                                                showSettings: { [actions] in actions.showSettings(nil) }, newNote: actions.newNote)
    private lazy var capture = CaptureProvider(addToNote: actions.addToNote, showSettings: { [actions] in actions.showSettings(.options) })
    private lazy var verbs = VerbProvider(verbs: Verb.launcher(files: files) + Verb.notes(release: actions.releaseNote), more: { frontMenuRows($0) })
    private(set) lazy var model = SearchModel(
        providers: providers(),
        exclusive: [FileSearchProvider.prefix: Gated(.files, files), VerbProvider.prefix: verbs,
                    ShellProvider.prefix: Gated(.shell, ShellProvider(state: state)),
                    "~": Gated(.files, PathProvider(terminal: Self.terminal(files))), "/": Gated(.files, PathProvider(terminal: Self.terminal(files)))],
        frecency: state, idle: Self.upNext(meetings, reminders, showsDue: { [weak self] in self?.showsDue ?? false }, clocks: { [weak self] in self?.idleRows() ?? [] }))
    // What the empty launcher shows besides the meeting (config.toml; the meeting is MeetingsProvider's).
    private var (suggestsApps, showsDue, showsRunning) = (true, true, true)

    /// Each provider with the feature it belongs to (none: always on, or it asks per row), gated by it. In two typed
    /// halves: as one literal, it slows the compiler down.
    private func providers() -> [any ResultProvider] {
        let first: [(any ResultProvider, Feature?)] = [
            (commands, .commands), (ScriptProvider(), .scripts), (snippets, .snippets), (builtins, nil),
            (EmojiProvider(), .emoji), (DefineProvider(), .define), (SynonymsProvider(), .define), (SpellProvider(), .spelling),
            (WikipediaProvider(), .wikipedia), (MessageCodeProvider(), .messageCodes), (LatestFilesProvider(), .latestFiles),
            (translate, .translate), (StockProvider(), .stocks), (weather, .weather), (meetings, .calendar), (reminders, .reminders),
            (contacts, .contacts), (TextToolProvider(), .textTools),
            (CameraProvider(join: Self.joinable(meetings)), .camera), (WiFiProvider(show: actions.showTyping), .wifiPassword),
        ]
        let second: [(any ResultProvider, Feature?)] = [
            (ColorProvider(show: actions.showTyping, store: state), .colors), (QRCodeProvider(), .qr),
            (LargeTypeProvider(), .largeType), (ScreenTextProvider(show: actions.showTyping), .screenText),
            (capture, nil), (apps, nil), (SettingsProvider(), .systemSettings), (CalculatorProvider(), .calculator),
            (currency, .currency), (UnitProvider(), .units), (TimeZoneProvider(), .timeZones), (DateMathProvider(), .dates),
            (PomodoroProvider(pomodoro: pomodoro), .pomodoro), (TimerProvider(clock: countdown), .timers),
            (StopwatchProvider(watch: stopwatch), .stopwatch), (LookupProvider(), nil), (files, .files),
            (FileContentProvider(files: files), .fileContent), (tabs, .browserTabs), (pages, .bookmarks), (web, nil),
        ]
        let gated: [any ResultProvider] = (first + second).map { provider, feature in feature.map { Gated($0, provider) } ?? provider }
        return gated + (photoText.map { [PhotoTextProvider(store: $0)] } ?? [])
    }

    /// The empty launcher's rows besides meetings and reminders: Finder's selection, the next item to paste in order,
    /// what's running, and the apps you open around now. Its own function: inline, it slows the compiler down.
    private func idleRows() -> [LauncherResult] {
        var rows = finderIdle
        if let history { rows += pasteNextRows(.shared, store: history.store, paste: { [weak self] in self?.pasteFromLauncher($0) }) }
        if showsRunning { rows += runningClocks(pomodoro: pomodoro, timer: countdown, stopwatch: stopwatch) }
        if suggestsApps { rows += suggestionRows(state.get(AppOpen.stateSection, as: [AppOpen].self) ?? []) }
        return rows
    }
    /// The files selected in Finder when the hotkey was pressed over it (or the row asking to see them), on top.
    var finderIdle: [LauncherResult] = []

    /// The meeting to join now, for Enter after `camera`.
    nonisolated private static func joinable(_ meetings: MeetingsProvider) -> @Sendable () async -> LauncherResult? {
        { Feature.calendar.isOn ? await meetings.joinable() : nil }
    }

    /// `[files] terminal`, asked when a file's Open in Terminal row is made.
    nonisolated private static func terminal(_ files: FileSearchProvider) -> @Sendable () async -> String? { { await files.terminalApp() } }

    /// What the empty launcher shows: the meeting to join, a few minutes before it starts, what's counting, reminders
    /// that are due, and the apps you open around now.
    nonisolated private static func upNext(_ meetings: MeetingsProvider, _ reminders: RemindersProvider,
                                           showsDue: @escaping @MainActor @Sendable () -> Bool,
                                           clocks: @escaping @MainActor @Sendable () -> [LauncherResult]) -> @Sendable () async -> [LauncherResult] {
        {
            let events = Feature.calendar.isOn ? await meetings.upNext() : []
            let wantsDue = Feature.reminders.isOn ? await showsDue() : false
            let due = wantsDue ? await reminders.upNext() : []
            return (events + due + (await MainActor.run { clocks() })).sorted { $0.score > $1.score }
        }
    }

    private(set) var history: ClipboardHistory? // nil if clipboard.sqlite can't be opened
    private var historyError: String?
    // Lazy, from `history`: touched only once launch has opened it (prepareClipboard), or the panel has no rows.
    private lazy var clipboardProvider = history.map {
        ClipboardProvider(store: $0.store, paste: { [weak self] in self?.paste($0) }, copy: { [weak self] in self?.history?.restore($0) })
    }
    private(set) lazy var clipboardModel = SearchModel(
        providers: clipboardProvider.map { [$0] } ?? [], searchesEmptyQuery: true,
        exclusive: clipboardProvider.map { [VerbProvider.prefix: VerbProvider(verbs: $0.verbs)] } ?? [:])
    private var configText: String? // last config.toml contents seen; nil = no file
    private var config = Config() // the one in use, for what's asked later (`help`)
    private var configUpdate: Task<Void, Never>?

    /// Launch, in this order: the example config if there's none, the defaults (the "last valid config" if the file is
    /// broken from the start), the clipboard history, then the file.
    func start() {
        if !FileManager.default.fileExists(atPath: configFile.path) {
            try? Config.example.write(to: configFile, atomically: true, encoding: .utf8)
        }
        apply(Config())
        do {
            // After the defaults above, so retention only prunes with a config that actually loaded. It records only
            // while clipboard history is on (apply).
            history = ClipboardHistory(store: try ClipboardStore(path: clipboardFile.path))
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: clipboardFile.path)
            history?.recording = !sealed && (Feature.clipboard.isOn || Feature.cleanLinks.isOn)
        } catch {
            historyError = error.localizedDescription
        }
        reloadConfig()
    }

    /// Before the clipboard panel shows. Only from here on, once launch has opened clipboard.sqlite: `clipboardModel` is
    /// lazy and takes its provider from `history` when first touched, so touching it before left the panel empty for good.
    func prepareClipboard() {
        clipboardModel.keywords = model.keywords.filter { $0.value == VerbProvider.prefix } // its search is for what you copied
        clipboardModel.notice = historyError.map { error in
            LauncherResult(id: "clipboard-error", title: String(localized: "Clipboard history is off: can't open clipboard.sqlite"),
                           subtitle: error, icon: .symbol("exclamationmark.triangle"), score: .infinity,
                           actionTitle: "", action: {})
        }
    }

    /// Enter on Paste Next in the launcher: onto the clipboard, and into the app in front.
    private func pasteFromLauncher(_ content: ClipboardContent) {
        history?.restore(content)
        if hasAccessibility(String(localized: "paste", comment: "Ends “Allow Copperlight in Accessibility to …”")) { sendPaste() }
    }

    /// Enter in the clipboard panel. Without Accessibility it can only copy, so it says how to fix that.
    private func paste(_ content: ClipboardContent) {
        history?.restore(content)
        if AXIsProcessTrusted() { return sendPaste() }
        clipboardModel.notice = LauncherResult(
            id: "accessibility", title: String(localized: "Copied. To paste it too, allow Copperlight in Accessibility"),
            subtitle: String(localized: "Privacy & Security → Accessibility", comment: "Where System Settings has it, in its own words"),
            icon: .symbol("lock.shield"), score: .infinity,
            actionTitle: String(localized: "Open System Settings"), action: { requestAccessibility() })
        actions.showClipboardPanel()
    }

    /// Re-reads config.toml if it changed. A broken file keeps the current config and pins an
    /// error row to the launcher until it parses again.
    func reloadConfig() {
        let text = try? String(contentsOf: configFile, encoding: .utf8)
        guard text != configText else { return }
        configText = text
        do {
            apply(try text.map(Config.parse) ?? Config())
            model.notice = nil
        } catch {
            let file = configFile
            model.notice = LauncherResult(
                id: "config-error", title: String(localized: "config.toml: \(Config.describe(error))"),
                subtitle: String(localized: "Using the last valid config"), icon: .symbol("exclamationmark.triangle"),
                score: .infinity, actionTitle: String(localized: "Open config.toml"),
                action: { NSWorkspace.shared.open(file) })
        }
        actions.configReloaded() // an edit by hand shows in the settings window too
    }

    private func apply(_ config: Config) {
        self.config = config
        Feature.use(config.features)
        Palette.shared.use(config.look.accent)
        actions.setHotkey(config.hotkeys.launcher)
        history?.settings = config.clipboard
        history?.recording = !sealed && (Feature.clipboard.isOn || Feature.cleanLinks.isOn)
        actions.styleNotes(config.notes.markdown)
        pomodoro.defaultMinutes = config.pomodoro.defaultMinutes
        pomodoro.breakMinutes = config.pomodoro.breakMinutes
        (suggestsApps, showsDue, showsRunning) = (config.apps.suggestions, config.reminders.showDue, config.timers.showRunning)
        model.learning = config.learning
        model.keepsAppOpens = config.apps.suggestions
        model.showsCards = config.answers.cards
        let yours = Set(config.commands.map { $0.alias.lowercased() } + config.snippets.map { $0.name.lowercased() })
        model.keywords = keywordExpansions(config.keywords, languageTable: languageKeywordTable(), taken: yours,
                                           language: config.keywords.language) // wth → weather, clima → weather
        (model.retired, model.renamed) = (config.keywords.retired, config.keywords.renamed)
        // Chained so back-to-back reloads reach the providers in order.
        weather.setCity(config.weather.city ?? "")
        weather.setUnits(config.weather.units)
        RemindersProvider.chosenLists.withLock { $0 = config.reminders.lists }
        RemindersProvider.chosenApp.withLock { $0 = config.reminders.app }
        CaptureProvider.chosen.withLock { $0 = .init(calendar: config.meetings.addTo, todos: config.reminders) }
        TimeZoneProvider.chosenCities.withLock { $0 = config.timeZones.cities }
        ColorProvider.chosenNotation.withLock { $0 = config.colors.copy }
        chosenEndSound.withLock { $0 = config.timers.sound }
        ContactsProvider.chosenEnter.withLock { $0 = config.contacts.enter }
        configUpdate = Task { [previous = configUpdate, sealed, commands, currency, translate, files, apps, web, snippets] in
            await previous?.value
            await commands.setCommands(config.commands, browser: config.browser)
            await snippets.setSnippets(config.snippets)
            await web.setBrowser(config.browser)
            await pages.setBrowser(config.browser)
            await meetings.setBrowser(config.browser)
            await meetings.setOptions(config.meetings)
            if !sealed, Feature.bookmarks.isOn { await pages.refresh() }
            await currency.setDefaultTarget(config.currency.defaultTarget)
            translate.setDefaultTarget(config.translate.defaultTarget)
            await files.setSettings(config.files)
            await apps.setOnline(config.apps.online)
        }
    }

    /// `help`: every command there is, as this Mac is set up now.
    func cheatSheet() -> [CheatSection] {
        cheatSections(verbs: verbs.verbs, clipboardVerbs: clipboardProvider?.verbs ?? [], commands: config.commands, snippets: config.snippets,
                      scripts: scripts(in: scriptsDir), renamed: model.renamed, languageTable: languageKeywordTable(), expansions: model.keywords,
                      hotkey: config.hotkeys.launcher.shortcut.description)
    }

    /// Once the last config has reached the providers, which it does in the background.
    func settled() async { await configUpdate?.value }

    /// What's read when the launcher opens.
    func refresh() {
        // Hours the first time, for a big library: on its own, and only one at a time (it says when it's busy).
        Task.detached(priority: .utility) { [photoIndexer] in await photoIndexer?.update() }
        Task { [apps, currency, pages, contacts, tabs] in
            if Feature.browserTabs.isOn { await tabs.refresh() }
            await apps.rescan()
            if Feature.currency.isOn { await currency.refreshIfStale() }
            if Feature.bookmarks.isOn { await pages.refresh() }
            if Feature.contacts.isOn { await contacts.refresh() }
        }
    }
}
