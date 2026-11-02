import Foundation
import Synchronization

/// What can be turned off, in Settings › Features or config.toml's `[features]` (`currency = false`). Off means off:
/// no rows, no chip, no `:` commands, no background work, no network, no permission asks. Everything is on until
/// config.toml says otherwise. Finding apps, the search row and Copperlight's own rows can't be turned off.
enum Feature: String, CaseIterable, Sendable {
    // Answers
    case calculator, currency, units, timeZones = "time_zones", dates, colors, qr, stocks, weather, wikipedia, define, spelling,
         translate, emoji, textTools = "text_tools", largeType = "large_type", macInfo = "mac_info", speedTest = "speed_test",
         processes
    // Yours
    case clipboard, cleanLinks = "clean_links", notes, snippets, scripts, commands, contacts, messageCodes = "message_codes", calendar, reminders, files, latestFiles = "latest_files", browserTabs = "browser_tabs",
         bookmarks, systemSettings = "system_settings", menus, timers, pomodoro, stopwatch, screenText = "screen_text"
    // Windows and the Mac
    case windows, runningApps = "running_apps", mac, sound, keepAwake = "keep_awake", bluetooth, wifiPassword = "wifi_password", camera, shortcuts, shell, homebrew
    // Not offered yet
    case fileContent = "file_content", photoText = "photo_text"

    /// Built and tested but not offered yet: always off, and not in Settings or config.toml.
    static let parked: Set<Feature> = [.fileContent, .photoText]
    /// What Settings lists, in this order.
    static var listed: [Feature] { allCases.filter { !parked.contains($0) } }

    /// config.toml's `[features]`, set each time it loads.
    private static let config = Mutex(Config.Features())
    static func use(_ features: Config.Features) { config.withLock { $0 = features } }
    var isOn: Bool { Self.config.withLock { $0.isOn(self) } }

    enum Group: CaseIterable {
        case answers, yours, mac

        /// Its heading in Settings › Features and Keywords.
        var title: String {
            switch self {
            case .answers: String(localized: "Answers", comment: "Settings › Features: the group of features that answer what you type")
            case .yours: String(localized: "Yours", comment: "Settings › Features: the group of features for your own things (notes, files)")
            case .mac: String(localized: "Windows and the Mac")
            }
        }
    }

    var group: Group {
        switch self {
        case .calculator, .currency, .units, .timeZones, .dates, .colors, .qr, .stocks, .weather, .wikipedia, .define, .spelling,
             .translate, .emoji, .textTools, .largeType, .macInfo, .speedTest, .processes: .answers
        case .windows, .runningApps, .mac, .sound, .keepAwake, .bluetooth, .wifiPassword, .camera, .shortcuts, .shell, .homebrew: .mac
        default: .yours
        }
    }

    var name: String { info.name }
    /// One line for Settings: what you type, or what it does.
    var about: String { info.about }

    /// The words that start it, which config.toml's `[keywords]` can add your own to (`translate = "t"`).
    var keywords: [String] {
        switch self {
        case .colors: ["colors", "pick color"]
        case .qr: ["qr"]
        case .stocks: ["stock"]
        case .weather: ["weather"]
        case .wikipedia: ["wiki"]
        case .define: ["define", "synonyms"]
        case .spelling: ["spell"]
        case .translate: ["translate"]
        case .emoji: ["emoji"]
        case .largeType: ["large"]
        case .speedTest: ["speed"]
        case .processes: ["cpu", "memory", "port"]
        case .clipboard: ["clip"]
        case .notes: ["note", "add note"]
        case .contacts: ["contact"]
        case .messageCodes: ["codes"]
        case .latestFiles: ["screenshots", "downloads"]
        case .wifiPassword: ["wifi password"]
        case .calendar: ["meetings", "week", "month", "free", "add event"]
        case .reminders: ["due", "add todo"]
        case .files: ["f"]
        case .browserTabs: ["tabs"]
        case .timers: ["timer"]
        case .pomodoro: ["pomo"]
        case .stopwatch: ["stopwatch"]
        case .screenText: ["copy text"]
        case .camera: ["camera"]
        case .shell: [":!"]
        default: []
        }
    }

    /// An about line that's only what you type stays English, as the words after a keyword do (TRANSLATING.md).
    private var info: (name: String, about: String) {
        switch self {
        case .calculator: (String(localized: "Calculator"), "150 + 20%, 30 is what % of 150, 255 in hex")
        case .currency: (String(localized: "Currency"), String(localized: "25 usd to eur, 0.1 btc in eur. Rates from Coinbase"))
        case .units: (String(localized: "Units"), "5 km in miles, 72 f in c")
        case .timeZones: (String(localized: "Time zones"), "time in tokyo")
        case .dates: (String(localized: "Date math"), "days until dec 25, in 3 weeks")
        case .colors: (String(localized: "Colors"), "#c87533, pick color, colors")
        case .qr: (String(localized: "QR codes"), String(localized: "qr and a link or any text"))
        case .stocks: (String(localized: "Stocks"), String(localized: "stock aapl. Prices from Yahoo Finance"))
        case .weather: (String(localized: "Weather"), String(localized: "weather lisbon. Forecasts from Open-Meteo"))
        case .wikipedia: ("Wikipedia", String(localized: "wiki lisbon. Summaries from Wikipedia"))
        case .define: (String(localized: "Dictionary"), "define serendipity, synonyms happy")
        case .spelling: (String(localized: "Spelling"), "spell recieve")
        case .translate: (String(localized: "Translate"), String(localized: "translate bom dia, on this Mac"))
        case .emoji: (String(localized: "Emoji"), "emoji heart")
        case .textTools: (String(localized: "Text tools"), "uuid, password, fake name, lowercase, paste plain")
        case .largeType: (String(localized: "Large Type"), String(localized: "large and any text, across the screen"))
        case .macInfo: (String(localized: "Your Mac"), "ip, battery, disk")
        case .speedTest: (String(localized: "Speed test"), String(localized: "speed, against Apple's servers"))
        case .processes: (String(localized: "Processes"), "cpu, memory, port 3000")
        case .clipboard: (String(localized: "Clipboard history"), String(localized: "clip: what you copied, kept on this Mac"))
        case .cleanLinks: (String(localized: "Links without tracking"), String(localized: "utm_, fbclid and the like taken off the links you copy"))
        case .notes: (String(localized: "Notes"), "note, add note")
        case .snippets: (String(localized: "Snippets"), String(localized: "Text you paste by name"))
        case .scripts: (String(localized: "Scripts"), String(localized: "The scripts folder, as rows"))
        case .commands: (String(localized: "Your commands"), String(localized: "The links, apps, files and shell lines in config.toml"))
        case .contacts: (String(localized: "Contacts"), "contact ana")
        case .messageCodes: (String(localized: "Codes from Messages"), String(localized: "codes: the latest verification codes, to copy"))
        case .calendar: (String(localized: "Calendar"), String(localized: "The next meeting, meetings, week, month, free time, add event"))
        case .reminders: (String(localized: "Reminders"), String(localized: "Reminders that are due, add todo"))
        case .files: (String(localized: "Files"), "f invoice, ~/code, :reveal, :trash")
        case .latestFiles: (String(localized: "Latest screenshots and downloads"),
                            String(localized: "screenshots, downloads: newest first, Enter pastes one"))
        case .browserTabs: (String(localized: "Browser tabs"), String(localized: "Your open tabs, by title"))
        case .bookmarks: (String(localized: "Bookmarks and history"), String(localized: "Pages from your browser, by title"))
        case .systemSettings: (String(localized: "System Settings"), String(localized: "Its pages, as rows: wi-fi, displays"))
        case .menus: (String(localized: "Menu search"), String(localized: "The menus of the app in front, after :"))
        case .timers: (String(localized: "Timers"), "timer 10m, timer until 15:00")
        case .pomodoro: (String(localized: "Pomodoro"), "pomo, pomo break")
        case .stopwatch: (String(localized: "Stopwatch"), "stopwatch")
        case .screenText: (String(localized: "Copy text from the screen"), "copy text")
        case .windows: (String(localized: "Windows"), String(localized: ":left, :maximize, :window, saved layouts"))
        case .runningApps: (String(localized: "Running apps"), ":quit, :hide, :relaunch")
        case .mac: (String(localized: "Mac commands"), ":lock, :sleep, :dark, :wifi, screenshot")
        case .sound: (String(localized: "Sound"), ":play, :volume 30, :mute, :output")
        case .keepAwake: (String(localized: "Keep awake"), ":awake 2h")
        case .bluetooth: ("Bluetooth", ":connect airpods")
        case .wifiPassword: (String(localized: "Wi-Fi password"), String(localized: "wifi password, with a QR code to join"))
        case .camera: (String(localized: "Camera"), String(localized: "camera: see yourself before a call"))
        case .shortcuts: (String(localized: "Shortcuts"), String(localized: ":shortcut and a shortcut's name"))
        case .shell: (String(localized: "Shell"), String(localized: ":! and a command"))
        case .homebrew: (String(localized: "Install with Homebrew"), String(localized: "Apps you don't have, installed from their row"))
        case .fileContent: (String(localized: "Text inside files"), "")
        case .photoText: (String(localized: "Text in photos"), "")
        }
    }
}

extension Feature {
    /// One of its keywords is replaced and its own word was typed (`Keyword.blocked`): its rows stay out. A provider
    /// that answers a keyword outside `Gated` checks this itself.
    var isBlocked: Bool { Keyword.blocked.map(keywords.contains) ?? false }
}

/// The built-in keywords, which config.toml's `[keywords]` replaces with your own words (`weather = "wth"`), or adds
/// yours beside for `:` and `:!` (`commands = ";"`). A keyword's key there is the word, `_` for its spaces; `:` is
/// `commands`, `:!` is `shell`.
enum Keyword {
    static var all: [String] { [":"] + Feature.listed.flatMap(\.keywords) }

    /// The replaced keyword (`[keywords] weather = "wth"`) whose own word was typed, while the providers answer it: its
    /// feature's rows stay out. Set for the general search only, never inside a chip.
    @TaskLocal static var blocked: String?

    /// The longest of `retired` that `text` starts with, typed alone or before a space: only the word itself stops.
    static func retiredWord(_ text: String, in retired: Set<String>) -> String? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return retired.filter { lower == $0 || lower.hasPrefix($0 + " ") }.max { $0.count < $1.count }
    }
    static func key(_ word: String) -> String { [":": "commands", ":!": "shell"][word] ?? word.replacingOccurrences(of: " ", with: "_") }
}

/// A provider that answers only while its feature is on: no rows and no chips while it's off.
struct Gated: ResultProvider {
    let feature: Feature
    let provider: any ResultProvider
    var isOn: @Sendable (Feature) -> Bool = { $0.isOn }

    init(_ feature: Feature, _ provider: any ResultProvider, isOn: @escaping @Sendable (Feature) -> Bool = { $0.isOn }) {
        (self.feature, self.provider, self.isOn) = (feature, provider, isOn)
    }

    var modes: [Mode] { isOn(feature) ? provider.modes : [] }
    var patient: Bool { provider.patient }
    func results(for query: String) async -> [LauncherResult] {
        guard isOn(feature), !feature.isBlocked else { return [] } // its own word, replaced, was typed
        return await provider.results(for: query)
    }
    func modeResults(for query: String) async -> [LauncherResult] { isOn(feature) ? await provider.modeResults(for: query) : [] }
}
