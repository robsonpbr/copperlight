import AppKit
import SwiftUI

/// A line of the sheet: what you type and what you get. `fill` is what Enter puts in the launcher, a keyword or an
/// example, and nothing here ever runs it. nil: not something typed there (a key).
struct CheatLine: Identifiable, Equatable, Sendable {
    let typed: String
    let about: String
    var fill: String? = nil
    var id: String { typed + "\t" + about }
}

struct CheatSection: Identifiable, Equatable, Sendable {
    let title: String
    let symbol: String
    var lines: [CheatLine]
    /// One piece of a section too long for a column, while a search has left room for it in the others.
    var split = false
    var id: String { split ? title + "\t" + (lines.first?.id ?? "") : title }
}

private struct CheatRow {
    let feature: Feature?
    let line: CheatLine
}

/// `help`: everything there is to type on this Mac, as it's set up. The `:` commands and text tools come from their
/// own lists, so a new one is here by itself; a new keyword or feature fails a test until it has a line.
@MainActor func cheatSections(verbs: [Verb], clipboardVerbs: [Verb] = [], commands: [Config.Command] = [], snippets: [Config.Snippet] = [],
                              scripts: [Script] = [], renamed: [String: String] = [:], languageTable: [String: String] = [:],
                              expansions: [String: String] = [:], hotkey: String? = nil,
                              isOn: (Feature) -> Bool = { $0.isOn }) -> [CheatSection] {
    /// The word to show for a keyword: yours, else your language's while typing it works, else its own.
    func word(_ keyword: String) -> String {
        if let yours = renamed[keyword] { return yours }
        let local = languageTable[keyword]?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        return local.flatMap { expansions[$0] == keyword ? $0 : nil } ?? keyword
    }
    func say(_ feature: Feature?, _ keyword: String, _ about: String) -> CheatRow {
        CheatRow(feature: feature, line: CheatLine(typed: word(keyword), about: about, fill: keyword))
    }
    /// With an example of what follows the keyword. Enter leaves it out: the chip waits for yours, and a place or a
    /// ticker goes nowhere you didn't type it.
    func example(_ feature: Feature?, _ keyword: String, _ rest: String, _ about: String) -> CheatRow {
        CheatRow(feature: feature, line: CheatLine(typed: word(keyword) + " " + rest, about: about, fill: keyword))
    }
    /// Recognized by what it looks like: Enter puts the example in, to see the answer.
    func shape(_ feature: Feature?, _ example: String, _ about: String) -> CheatRow {
        CheatRow(feature: feature, line: CheatLine(typed: example, about: about, fill: example))
    }
    func key(_ feature: Feature?, _ keys: String, _ about: String) -> CheatRow {
        CheatRow(feature: feature, line: CheatLine(typed: keys, about: about))
    }
    func colon(_ verbs: [Verb]) -> [CheatRow] { verbs.map { shape($0.feature, ":" + $0.keyword, $0.shown) } }
    func section(_ title: String, _ symbol: String, _ rows: [CheatRow]) -> CheatSection? {
        let lines = rows.filter { $0.feature.map(isOn) ?? true }.map(\.line)
        return lines.isEmpty ? nil : CheatSection(title: title, symbol: symbol, lines: lines)
    }

    let own: Set<Feature?> = [.windows, .runningApps, .files, .sound, .notes]
    let tools = textTools.sorted { $0.name < $1.name }.map { shape(.textTools, $0.name, String(localized: $0.title)) }
    let yours = commands.map { command -> CheatRow in
        let what = switch command.action {
        case .url(let url, _, _): url
        case .app(let app): app
        case .file(let path): (path as NSString).lastPathComponent
        case .shell(let line): line
        }
        return shape(.commands, command.alias, what)
    } + snippets.map { shape(.snippets, $0.name, oneLine($0.text)) } + scripts.map { shape(.scripts, $0.name, $0.title) }
    let inClipboard = clipboardVerbs.map { key(.clipboard, ":" + $0.keyword, String(localized: "In clipboard history: \($0.shown)")) }

    let sections: [CheatSection?] = [
        section(String(localized: "Find"), "magnifyingglass", [
            shape(nil, "saf", String(localized: "An app, by a few letters")),
            example(.files, "f", "invoice", String(localized: "Files, by name")),
            shape(.files, "~/", String(localized: "A folder, and what's in it")),
            say(.browserTabs, "tabs", String(localized: "Your open tabs")),
            shape(.bookmarks, "github", String(localized: "Bookmarks and recent pages")),
            shape(.systemSettings, "displays", String(localized: "A System Settings page")),
            shape(nil, "gmail.com", String(localized: "Opens that address")),
            shape(.homebrew, "figma", String(localized: "Installs an app you don't have")),
            key(nil, String(localized: "any text"), String(localized: "Searches the web")),
        ]),
        section(String(localized: "Math and money"), "function", [
            shape(.calculator, "150 + 20%", String(localized: "Math and percentages")),
            shape(.calculator, "255 in hex", String(localized: "Hex and binary")),
            shape(.currency, "25 usd to eur", Feature.currency.name),
            shape(.units, "5 km in miles", Feature.units.name),
            shape(.timeZones, "3pm lisbon in sf", Feature.timeZones.name),
            shape(.dates, "days until dec 25", Feature.dates.name),
            shape(.dates, "in 3 weeks", String(localized: "A date from now")),
            example(.stocks, "stock", "aapl", Feature.stocks.name),
        ]),
        section(String(localized: "Your day"), "calendar", [
            example(.weather, "weather", "lisbon", Feature.weather.name),
            say(.calendar, "meetings", String(localized: "The rest of today")),
            say(.calendar, "week", String(localized: "Your week")),
            say(.calendar, "month", String(localized: "Your month")),
            example(.calendar, "free", "tomorrow", String(localized: "Your free time")),
            example(.calendar, "add event", "fri 9am gym", String(localized: "Adds an event")),
            say(.reminders, "due", String(localized: "What's due")),
            example(.reminders, "add todo", "call ana", String(localized: "Adds a to-do")),
            example(.contacts, "contact", "ana", Feature.contacts.name),
            say(.camera, "camera", String(localized: "See yourself before a call")),
        ]),
        section(String(localized: "Words"), "character.book.closed", [
            example(.define, "define", "serendipity", Feature.define.name),
            example(.define, "synonyms", "happy", String(localized: "Words that mean the same")),
            example(.spelling, "spell", "recieve", Feature.spelling.name),
            example(.translate, "translate", "bom dia", Feature.translate.name),
            example(.wikipedia, "wiki", "lisbon", Feature.wikipedia.name),
            example(.emoji, "emoji", "heart", Feature.emoji.name),
        ]),
        section(Feature.notes.name, "note.text", [
            say(.notes, "note", String(localized: "Your notes")),
            example(.notes, "add note", "buy milk", String(localized: "Adds a line to your note")),
            say(.clipboard, "clip", Feature.clipboard.name),
            say(.latestFiles, "screenshots", String(localized: "Your latest screenshots")),
            say(.latestFiles, "downloads", String(localized: "Your latest downloads")),
            say(.messageCodes, "codes", String(localized: "Codes from Messages")),
        ] + colon(verbs.filter { $0.feature == .notes }) + inClipboard),
        section(String(localized: "Clocks"), "timer", [
            example(.timers, "timer", "10m tea", Feature.timers.name),
            example(.timers, "timer", "until 15:30", String(localized: "A timer until a time")),
            say(.pomodoro, "pomo", Feature.pomodoro.name),
            example(.pomodoro, "pomo", "break", String(localized: "A break")),
            say(.stopwatch, "stopwatch", Feature.stopwatch.name),
        ]),
        section(Feature.macInfo.name, "laptopcomputer", [
            shape(.macInfo, "ip", String(localized: "Your IP addresses")),
            shape(.macInfo, "battery", String(localized: "The battery")),
            shape(.macInfo, "disk", String(localized: "Free space")),
            say(.processes, "cpu", String(localized: "What's using the processor")),
            say(.processes, "memory", String(localized: "What's using memory")),
            example(.processes, "port", "3000", String(localized: "What's on a port")),
            say(.speedTest, "speed", Feature.speedTest.name),
            say(.wifiPassword, "wifi password", Feature.wifiPassword.name),
        ]),
        section(String(localized: "The screen"), "viewfinder", [
            shape(.colors, "#c87533", String(localized: "A color, in every notation")),
            say(.colors, "pick color", String(localized: "A color from the screen")),
            say(.colors, "colors", String(localized: "The colors you picked")),
            example(.qr, "qr", "hello", Feature.qr.name),
            say(.screenText, "copy text", Feature.screenText.name),
            example(.largeType, "large", "555-0100", Feature.largeType.name),
            shape(nil, "screenshot", String(localized: "The screenshot toolbar")),
            shape(nil, "record", String(localized: "Records the screen")),
        ]),
        section(Feature.textTools.name, "textformat", tools),
        section(Feature.windows.name, "macwindow", colon(verbs.filter { $0.feature == .windows })),
        section(Feature.runningApps.name, "square.grid.2x2", colon(verbs.filter { $0.feature == .runningApps })),
        section(Feature.files.name, "folder", colon(verbs.filter { $0.feature == .files })),
        section(Feature.sound.name, "speaker.wave.2", colon(verbs.filter { $0.feature == .sound })),
        section(Feature.mac.name, "command", [
            shape(nil, ":", String(localized: "Every command")),
            shape(.menus, ":export pdf", String(localized: "A menu of the app in front")),
        ] + colon(verbs.filter { !own.contains($0.feature) })),
        section(Feature.Group.yours.title, "star", yours),
        section(String(localized: "Keys"), "keyboard", (hotkey.map { [key(nil, $0, String(localized: "Opens it, from any app"))] } ?? []) + [
            key(nil, "↑ ↓", String(localized: "Moves through the rows")),
            key(nil, "↵", String(localized: "Does what the row says")),
            key(nil, "tab", String(localized: "Fills in, or shows more")),
            key(nil, "esc", String(localized: "Goes back, or hides it")),
            key(nil, "↑", String(localized: "In the empty field: what you ran")),
        ]),
        section(String(localized: "Keys in a note"), "text.cursor", [
            key(.notes, "⌘B", String(localized: "Bold")),
            key(.notes, "⌘I", String(localized: "Italic")),
            key(.notes, "⌘E", String(localized: "Code")),
            key(.notes, "⌘K", String(localized: "Link")),
            key(.notes, "⌘1 ⌘2 ⌘3", String(localized: "Headings")),
            key(.notes, "⌘⇧7", String(localized: "Bullets")),
            key(.notes, "⌘⇧9", String(localized: "Numbers")),
            key(.notes, "⌘⇧L", String(localized: "Checkboxes")),
            key(.notes, "⌘'", String(localized: "Quotes")),
            key(.notes, "⌘+ ⌘-", String(localized: "Bigger and smaller text")),
            key(.notes, "⌘0", String(localized: "The normal size")),
            key(.notes, "⌥↵", String(localized: "A plain line, in a list")),
        ]),
    ]
    return sections.compactMap(\.self)
}

/// The lines with every word of `filter` in them, or in their keyword or section's name, accents and case aside.
func cheatMatching(_ sections: [CheatSection], _ filter: String) -> [CheatSection] {
    let words = filter.split(whereSeparator: \.isWhitespace)
    guard !words.isEmpty else { return sections }
    return sections.compactMap { section in
        var kept = section
        kept.lines = section.lines.filter { line in
            let text = [line.typed, line.about, line.fill ?? "", section.title].joined(separator: " ")
            return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        return kept.lines.isEmpty ? nil : kept
    }
}

/// Each section onto the column that's shortest so far. With columns to spare, a long one is cut in two until they're
/// used: a search for `window` fills the sheet, not its left edge.
func cheatColumns(_ sections: [CheatSection], count: Int) -> [[CheatSection]] {
    var pieces = sections
    while pieces.count < count, let longest = pieces.indices.max(by: { pieces[$0].lines.count < pieces[$1].lines.count }), pieces[longest].lines.count > 10 {
        var tail = pieces[longest]
        let half = tail.lines.count / 2
        tail.lines.removeFirst(half)
        pieces[longest].lines.removeLast(tail.lines.count)
        (pieces[longest].split, tail.split) = (true, true)
        pieces.insert(tail, at: longest + 1)
    }
    var columns = Array(repeating: [CheatSection](), count: max(1, count))
    var heights = Array(repeating: 0, count: columns.count)
    for section in pieces {
        let shortest = heights.indices.min { heights[$0] < heights[$1] }!
        columns[shortest].append(section)
        heights[shortest] += section.lines.count + 3 // its heading and the gap under it
    }
    return columns
}

/// What the sheet shows: `filter` narrows it, ↑ ↓ go through what Enter can fill in, down a column and on to the next.
@MainActor @Observable final class CheatSheet {
    var sections: [CheatSection] = [] { didSet { selection = 0 } }
    var filter = "" { didSet { if filter != oldValue { selection = 0 } } } // the field also writes back what it already has
    var columns = 3
    /// How many times it came up: each one plays its entrance.
    var opens = 0
    private(set) var selection = 0

    var laidOut: [[CheatSection]] { cheatColumns(cheatMatching(sections, filter), count: columns) }
    var lines: [CheatLine] { laidOut.flatMap(\.self).flatMap(\.lines).filter { $0.fill != nil } }
    var selected: CheatLine? { lines.indices.contains(selection) ? lines[selection] : nil }
    var total: Int { sections.flatMap(\.lines).filter { $0.fill != nil }.count }

    func move(_ delta: Int) { selection = max(0, min(lines.count - 1, selection + delta)) }

    /// ← →: the next column, about as far down it.
    func hop(_ delta: Int) {
        let columns = laidOut.map { $0.flatMap(\.lines).filter { $0.fill != nil } }.filter { !$0.isEmpty }
        guard let selected, let here = columns.firstIndex(where: { $0.contains(selected) }), let row = columns[here].firstIndex(of: selected),
              columns.indices.contains(here + delta) else { return }
        let next = columns[here + delta]
        selection = lines.firstIndex(of: next[min(row, next.count - 1)]) ?? selection
    }
}

/// `help`. Like the launcher, a panel that never takes focus from the app you were in, and it goes when you switch away.
final class CheatSheetPanel: NSPanel {
    private static let widest: CGFloat = 1420, tallest: CGFloat = 860, screenEdge: CGFloat = 48, column: CGFloat = 340
    let model = CheatSheet()
    private let fill: @MainActor (String) -> Void

    init(fill: @escaping @MainActor (String) -> Void) {
        self.fill = fill
        super.init(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // the pieces draw their own
        // Inside a plain view, as the launcher does: as the content view, NSHostingView would size the window to fit.
        let host = NSHostingView(rootView: CheatSheetView(model: model, choose: { [weak self] in self?.choose($0) }))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        host.frame = container.bounds
        container.addSubview(host)
        contentView = container
    }

    override var canBecomeKey: Bool { true }

    /// In the middle of the screen the pointer is on, as big as it fits, up to `widest`.
    func prepare(_ sections: [CheatSection], in area: NSRect) {
        let width = min(Self.widest, area.width - 2 * Self.screenEdge), height = min(Self.tallest, area.height - 2 * Self.screenEdge)
        let margin = LauncherPanel.margin
        setFrame(NSRect(x: area.midX - width / 2 - margin, y: area.midY - height / 2 - margin, width: width + 2 * margin, height: height + 2 * margin), display: false)
        model.columns = max(2, Int((width - 44) / Self.column))
        model.sections = sections
        model.filter = ""
        model.opens += 1
    }

    func show(_ sections: [CheatSection]) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        prepare(sections, in: screen.visibleFrame)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    private func choose(_ line: CheatLine) {
        guard let text = line.fill else { return }
        orderOut(nil)
        fill(text)
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else { return super.sendEvent(event) }
        switch event.keyCode {
        case 53: orderOut(nil) // Esc
        case 125: model.move(1) // ↓
        case 126: model.move(-1) // ↑
        case 123 where model.filter.isEmpty: model.hop(-1) // ←, with no text for it to move through
        case 124 where model.filter.isEmpty: model.hop(1) // →
        case 36, 76, 48: model.selected.map(choose) // Return, keypad Enter, Tab
        default: if !performEditShortcut(event) { super.sendEvent(event) }
        }
    }
}

/// The launcher's two floating pieces, grown: the field as a pill, and everything there is on a card under it.
private struct CheatSheetView: View {
    private static let fieldHeight: CGFloat = 62, radius: CGFloat = 26
    @Bindable var model: CheatSheet
    let choose: @MainActor (CheatLine) -> Void
    @Environment(\.accessibilityReduceMotion) private var still
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                BrandMark(height: 24)
                TextField(String(localized: "Search \(model.total) commands"), text: $model.filter)
                    .textFieldStyle(.plain).font(.system(size: 21)).focused($focused)
                Keycap(label: "esc")
            }
            .padding(.horizontal, 26)
            .frame(height: Self.fieldHeight)
            .modifier(GlassBackground(shape: Capsule(), radius: Self.fieldHeight / 2 - 0.5))
            .overlay(Capsule().strokeBorder(LinearGradient.brand, lineWidth: 1.5))
            CheatSheetCard(model: model, choose: choose)
                .id(model.opens) // new each time: the top of the sheet, and its entrance
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: Self.radius))
                .modifier(Card(radius: Self.radius))
        }
        .keyframeAnimator(initialValue: 1.0, trigger: model.opens) { content, scale in
            content.scaleEffect(scale, anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                MoveKeyframe(Motion.opening(still: still))
                SpringKeyframe(1, duration: 0.3 / Motion.pace, spring: Spring(duration: 0.3 / Motion.pace, bounce: 0.15))
            }
        }
        .padding(LauncherPanel.margin)
        // Only its own panel, and a turn after the first show: the launcher's field needed the same.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
            if ($0.object as? CheatSheetPanel)?.model === model { focused = true }
        }
        .onAppear { Task { focused = true } }
    }
}

private struct CheatSheetCard: View {
    let model: CheatSheet
    let choose: @MainActor (CheatLine) -> Void
    @State private var shown = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        let columns = model.laidOut, selected = model.selected?.id
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heading.rise(shown, 0)
                    if columns.allSatisfy(\.isEmpty) {
                        Text(verbatim: String(localized: "Nothing for “\(model.filter)”"))
                            .font(.system(size: 15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 60)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { column, sections in
                            VStack(spacing: 14) {
                                ForEach(Array(sections.enumerated()), id: \.element.id) { row, section in
                                    CheatSectionView(section: section, selected: selected, choose: choose)
                                        .rise(shown, 0.06 + Double(column) * 0.05 + Double(row) * 0.07)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 40)
            }
            // Rows fade out at the bottom edge instead of being cut. The padding above leaves the last one clear of it.
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 36)
                }
            }
            .onChange(of: selected) { _, id in
                guard let id else { return }
                withAnimation(Motion.at(.snappy(duration: 0.16), still: still)) { proxy.scrollTo(id) }
            }
        }
        .background(alignment: .top) {
            // The accent as a soft light behind the heading, as on the welcome screen.
            let strength = scheme == .dark ? 0.26 : 0.15
            ZStack {
                RadialGradient(colors: [.accent.opacity(strength), .clear], center: UnitPoint(x: 0.2, y: 0), startRadius: 0, endRadius: 520)
                RadialGradient(colors: [.accentDeep.opacity(strength), .clear], center: UnitPoint(x: 0.75, y: 0), startRadius: 0, endRadius: 460)
            }
            .frame(height: 540).allowsHitTesting(false) // past the gradients' reach: cut short, it shows an edge
        }
        .onAppear { shown = true }
    }

    private var heading: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Everything you can type").font(.system(size: 30, weight: .semibold)).tracking(-0.5)
                    .foregroundStyle(LinearGradient(colors: scheme == .dark ? [.accentLight, .accent] : [.accent, .accentDeep],
                                                    startPoint: .leading, endPoint: .trailing))
                Text("Pick one and it waits in the launcher. Nothing runs until you press Enter there.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            HStack(spacing: 6) {
                Keycap(label: "↑ ↓")
                Keycap(label: "← →")
                Text("Move").padding(.trailing, 8)
                Keycap(label: "↵")
                Text("Try it")
            }
            .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize()
        }
        .padding(.horizontal, 8)
    }
}

private struct CheatSectionView: View {
    let section: CheatSection
    let selected: String?
    let choose: @MainActor (CheatLine) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 9) {
                Circle().strokeBorder(Color.accent.opacity(0.4), lineWidth: 1)
                    .overlay {
                        Image(systemName: section.symbol).font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(scheme == .dark ? Color.accentLight : Color.accentDeep)
                    }
                    .frame(width: 26, height: 26)
                Text(section.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 6)
                if !section.split { Text(verbatim: "\(section.lines.count)").font(.system(size: 11.5).monospacedDigit()).foregroundStyle(.tertiary) }
            }
            .padding(.horizontal, 6).padding(.bottom, 7)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
            ForEach(section.lines) { line in
                CheatLineView(line: line, selected: line.id == selected).id(line.id)
                    .contentShape(Rectangle())
                    .onTapGesture { choose(line) }
            }
        }
        .padding(10)
        .modifier(Tray())
    }
}

private struct CheatLineView: View {
    let line: CheatLine
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            CheatChip(typed: line.typed, typable: line.fill != nil).layoutPriority(1)
            Spacer(minLength: 0)
            Text(line.about).font(.system(size: 12.5)).foregroundStyle(selected ? .primary : .secondary).lineLimit(1).truncationMode(.tail)
            if selected { Keycap(label: "↵") }
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
        .background { if selected { SelectionWash() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// What you type, as it's typed; a command's `:` in the accent, since that's what opens them all.
private struct CheatChip: View {
    let typed: String
    let typable: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colon = typed.hasPrefix(":")
        HStack(spacing: 0) {
            if colon { Text(verbatim: ":").foregroundStyle(scheme == .dark ? Color.accentLight : Color.accentDeep).fontWeight(.bold) }
            Text(verbatim: colon ? String(typed.dropFirst()) : typed)
        }
        .font(.system(size: 12, weight: .medium, design: typable ? .monospaced : .default))
        .lineLimit(1)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accent.opacity(0.28), lineWidth: 0.5))
        .fixedSize(horizontal: true, vertical: false)
    }
}
