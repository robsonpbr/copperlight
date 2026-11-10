import AppKit
import SwiftUI

/// The notes: note.txt, and a text file each in notes/. They have no names: a note's first line is its title.
let notesDir = configDir.appending(path: "notes")
let mainNoteFile = configDir.appending(path: "note.txt")

/// Every note that exists: note.txt and the .txt files in `folder` (hidden ones aren't notes).
func noteFiles(in folder: URL = notesDir, main: URL = mainNoteFile) -> [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
    return ([main] + files.filter { $0.pathExtension == "txt" }).filter { FileManager.default.fileExists(atPath: $0.path) }
}

/// A note's title: its first line with text, as it reads, without its Markdown. nil for an empty note.
func noteTitle(_ text: String) -> String? {
    text.split(separator: "\n").lazy
        .map { withoutMarkdown(String($0.trimmingCharacters(in: .whitespaces).drop { $0 == "#" })) }
        .first { !$0.isEmpty }.map { String($0.prefix(80)) }
}

private func withoutMarkdown(_ line: String) -> String {
    var marks = IndexSet() // a set: a link's address can hold another style's marker
    for span in markdownSpans(line) {
        switch span.style {
        case .marker, .bullet, .checkbox: marks.insert(integersIn: Range(span.range)!)
        default: break
        }
    }
    let plain = marks.rangeView.reversed().reduce(line as NSString) { $0.replacingCharacters(in: NSRange($1), with: "") as NSString }
    return (plain as String).trimmingCharacters(in: .whitespaces)
}

/// Where a new note goes: notes/, named by the time (nobody sees it). The file is written once you type.
func newNoteFile(in folder: URL = notesDir, now: Date = .now) -> URL {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    let stamp = formatter.string(from: now)
    var file = folder.appending(path: stamp + ".txt"), number = 2
    while FileManager.default.fileExists(atPath: file.path) {
        file = folder.appending(path: "\(stamp)-\(number).txt")
        number += 1
    }
    return file
}

/// A note as the launcher lists it.
struct NoteFile: Sendable {
    var url: URL
    var text: String
    var edited: Date
    var title: String { noteTitle(text) ?? String(localized: "Empty Note") }
    /// The line after the title, for its row.
    var summary: String {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.dropFirst().first
            .map { String($0.prefix(80)) } ?? ""
    }
}

/// Every note, last edited first.
func notesByDate(in folder: URL = notesDir, main: URL = mainNoteFile) -> [NoteFile] {
    noteFiles(in: folder, main: main).map { url in
        NoteFile(url: url, text: (try? String(contentsOf: url, encoding: .utf8)) ?? "",
                 edited: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
    }.sorted { $0.edited > $1.edited }
}

/// The first line with `query`'s first word, if the text has every word in it (in any case, accents or not); nil if not.
func matchingLine(_ text: String, _ query: String) -> String? {
    let words = query.split(separator: " ").map(String.init)
    guard let first = words.first, words.allSatisfy({ text.localizedStandardContains($0) }) else { return nil }
    return text.split(separator: "\n").first { $0.localizedStandardContains(first) }.map { String($0.trimmingCharacters(in: .whitespaces).prefix(80)) }
}

extension Verb {
    /// `:delete note milk`: a note, found by its title or what's in it, moved to the Trash after asking. `release` closes
    /// its panel first, saved.
    @MainActor static func notes(folder: URL = notesDir, main: URL = mainNoteFile,
                                 release: @escaping @MainActor @Sendable (URL) -> Void) -> [Verb] {
        [Verb(keyword: "delete note", title: "Delete Note", icon: .symbol("trash"), targets: { filter in
            notesByDate(in: folder, main: main).enumerated().compactMap { index, note in
                let match = filter.isEmpty ? -0.01 * Double(index) : fuzzyScore(filter, note.title) ?? matchingLine(note.text, filter).map { _ in 0.5 }
                guard let score = match else { return nil }
                let url = note.url
                return LauncherResult(id: "delete note:\(url.path)", title: String(localized: "Delete Note: \(note.title)"), subtitle: note.summary,
                                      icon: .symbol("trash"), score: score,
                                      actionTitle: String(localized: "Delete", comment: "Enter on a note to delete"),
                                      action: { release(url); moveToTrash(url.path) },
                                      confirm: String(localized: "Move the note “\(note.title)” to the Trash?"))
            }
        })].belonging(to: .notes)
    }
}

/// The title the note's card shows: its first line, as you type it.
@MainActor @Observable final class NoteHeader {
    var title = ""
}

/// What a key does in a note. Non-activating panels get no menu shortcuts, so they're routed by hand.
enum NoteShortcut: Equatable {
    case format(NoteFormat), bigger, smaller, normalSize
}

/// Letters and signs by what they type; digits by where they are, since not every keyboard types them without Shift.
func noteShortcut(_ event: NSEvent) -> NoteShortcut? {
    guard event.type == .keyDown else { return nil }
    // What it types with ⌘ held: on Russian or Greek, ⌘ has a Latin layer of its own.
    let key = (event.characters?.isEmpty == false ? event.characters : event.charactersIgnoringModifiers)?.lowercased()
    switch event.modifierFlags.intersection([.command, .shift, .option, .control]) {
    case .command:
        switch (key, event.keyCode) {
        case (_, 18), (_, 83): return .format(.heading(1))
        case (_, 19), (_, 84): return .format(.heading(2))
        case (_, 20), (_, 85): return .format(.heading(3))
        case (_, 29), (_, 82): return .normalSize
        case ("b", _): return .format(.bold)
        case ("i", _): return .format(.italic)
        case ("e", _): return .format(.code)
        case ("k", _): return .format(.link)
        case ("'", _), (_, 39): return .format(.quote) // 39: where `'` waits for the next key, it types nothing
        case ("+", _), ("=", _): return .bigger
        case ("-", _): return .smaller
        default: return nil
        }
    case [.command, .shift]:
        switch (key, event.keyCode) {
        case (_, 26): return .format(.bullet)
        case (_, 25): return .format(.numbered)
        case ("l", _): return .format(.checkbox)
        case ("'", _): return .format(.quote)
        case ("+", _), ("=", _): return .bigger
        default: return nil
        }
    default: return nil
    }
}

/// A floating note: plain text on a glass card like the launcher's, autosaved to its file (note.txt, or one in notes/). It's a non-activating panel, so typing in it never pulls the app you were in out of the
/// foreground, and hiding it hands keyboard focus straight back to that app. Drag it by its title; resize it from
/// its bottom-right corner.
final class NotePanel: NSPanel, NSTextViewDelegate, NSWindowDelegate {
    private static let stateSection = "windows" // [window name: frame of the card]
    static let minSize = CGSize(width: 240, height: 140)
    /// Clear room around the card for its shadow, as in the launcher.
    static let margin = LauncherPanel.margin

    /// `[notes] markdown`: draw the Markdown in notes (headings, bold, checkboxes…), or show plain text.
    static var stylesMarkdown = true

    static let defaultTextSize: CGFloat = 14
    /// How big every note's text is: ⌘+, ⌘-, ⌘0. In state.json, beside where the notes are.
    static var textSize: CGFloat {
        get { min(max(StateStore.shared.get("noteTextSize", as: CGFloat.self) ?? defaultTextSize, 10), 40) }
        set { StateStore.shared.set("noteTextSize", newValue) }
    }

    let file: URL
    private let frameKey: String // "note", "note:work"
    let textView: NSTextView
    private let header = NoteHeader()
    private var pendingSave: Task<Void, Never>?

    /// `file`: note.txt, a note in notes/, or a new one there, written once you type.
    init(file: URL) {
        self.file = file
        frameKey = file == mainNoteFile ? "note" : "note:" + file.deletingPathExtension().lastPathComponent
        let scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView
        let card = NSRect(x: 0, y: 0, width: 360, height: 300)
        super.init(contentRect: card.insetBy(dx: -Self.margin, dy: -Self.margin),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // the card draws a soft one; the window's traced it with a gray rim

        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        textView.drawsBackground = false
        textView.isRichText = false
        textView.typingAttributes = base
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 0, height: 2)
        text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0)) // ready to go on writing
        textView.delegate = self

        // As the launcher: a plain view holds the hosting view, which never sizes the window itself.
        let host = NSHostingView(rootView: NoteView(header: header, text: scroll))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.addSubview(host)
        host.frame = container.bounds
        contentView = container

        // Restore the saved card unless a display change left it off every screen.
        if let saved = StateStore.shared.get(Self.stateSection, as: [String: CGRect].self)?[frameKey],
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(saved) }) {
            setFrame(saved.insetBy(dx: -Self.margin, dy: -Self.margin), display: false)
        } else {
            center()
        }
        delegate = self
        // Undo doesn't tell the text view's delegate, and the file would keep what you took back.
        NotificationCenter.default.addObserver(self, selector: #selector(textChanged), name: .NSUndoManagerDidUndoChange, object: undoManager)
        NotificationCenter.default.addObserver(self, selector: #selector(textChanged), name: .NSUndoManagerDidRedoChange, object: undoManager)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var canBecomeKey: Bool { true } // borderless windows can't by default

    /// AppKit keeps a window's top below the menu bar, and this window's top is the clear margin: the card stopped
    /// 60 pt short. The same rule, applied to the card.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        super.constrainFrameRect(frameRect.insetBy(dx: Self.margin, dy: Self.margin), to: screen).insetBy(dx: -Self.margin, dy: -Self.margin)
    }

    func show() {
        reloadIfChanged() // in case it changed while the app wasn't watching
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textView)
    }

    /// The note's font, color and spacing.
    private var base: [NSAttributedString.Key: Any] {
        let lines = NSMutableParagraphStyle()
        lines.lineSpacing = 3 * Self.textSize / Self.defaultTextSize
        return [.font: NSFont.systemFont(ofSize: Self.textSize), .foregroundColor: NSColor.labelColor, .paragraphStyle: lines]
    }

    /// The note's text, set in the note's own font and spacing.
    private var text: String {
        get { textView.string }
        set {
            textView.textStorage?.setAttributedString(NSAttributedString(string: newValue, attributes: base))
            restyle()
        }
    }

    /// Draws the note's Markdown, or plain text (`stylesMarkdown`). Only how it looks: the text never changes.
    /// ponytail: the whole note, each keystroke; restyle only the edited paragraphs if long notes ever lag.
    func restyle() {
        header.title = noteTitle(text) ?? String(localized: "New Note")
        // The accent's, again each time: it may have changed (Settings › General › Look).
        textView.linkTextAttributes = [.foregroundColor: NSColor(Color.accent), .cursor: NSCursor.pointingHand] // underlined below, checkboxes not
        textView.insertionPointColor = NSColor(Color.accent)
        textView.selectedTextAttributes = [.backgroundColor: NSColor(Color.accent).withAlphaComponent(0.22)]
        guard let storage = textView.textStorage else { return }
        let scale = Self.textSize / Self.defaultTextSize
        storage.beginEditing()
        storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
        if Self.stylesMarkdown {
            // A heading sets the font over code's, bold and italic add to whichever it is, and markers only dim.
            let order = { (style: MarkdownStyle) -> Int in
                switch style {
                case .code: 0
                case .heading: 1
                case .marker: 3
                default: 2
                }
            }
            let selected = textView.selectedRange()
            for span in markdownSpans(storage.string, typingAt: selected.length == 0 ? selected.location : nil).sorted(by: { order($0.style) < order($1.style) }) {
                switch span.style {
                case .bold: storage.applyFontTraits(.boldFontMask, range: span.range) // traits, so bold and italic stack
                case .italic: storage.applyFontTraits(.italicFontMask, range: span.range)
                default: storage.addAttributes(attributes(span.style, at: span.range, scale: scale), range: span.range)
                }
            }
        }
        storage.endEditing()
        textView.typingAttributes = base
    }

    private func attributes(_ style: MarkdownStyle, at range: NSRange, scale: CGFloat) -> [NSAttributedString.Key: Any] {
        let copper = NSColor(Color.accent)
        switch style {
        case .heading(let level): return [.font: NSFont.systemFont(ofSize: [20, 17, 15][min(max(level, 1), 3) - 1] * scale, weight: level < 3 ? .bold : .semibold)]
        case .bold, .italic: return [:] // restyle's
        case .code: return [.font: NSFont.monospacedSystemFont(ofSize: 13 * scale, weight: .regular), .backgroundColor: NSColor.labelColor.withAlphaComponent(0.07)]
        case .marker: return [.foregroundColor: NSColor.tertiaryLabelColor]
        case .bullet: return [.foregroundColor: copper]
        case .checkbox: return [.foregroundColor: copper, .link: URL(string: "\(checkboxScheme):\(range.location)")!]
        case .done: return [.foregroundColor: NSColor.secondaryLabelColor, .strikethroughStyle: NSUnderlineStyle.single.rawValue]
        case .quote: return [.foregroundColor: NSColor.secondaryLabelColor]
        case .link(let url): return URL(string: url).map { [.link: $0, .underlineStyle: NSUnderlineStyle.single.rawValue] } ?? [:]
        }
    }

    /// A click on a checkbox ticks it (undoable, saved like typing); on a link, the browser opens it.
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard (link as? URL)?.scheme == checkboxScheme, let storage = textView.textStorage,
              let toggle = checkboxToggle(storage.string as NSString, at: charIndex)
        else { return false }
        if textView.shouldChangeText(in: toggle.range, replacementString: toggle.replacement) {
            storage.replaceCharacters(in: toggle.range, with: toggle.replacement)
            textView.didChangeText()
        }
        return true
    }

    /// Enter goes on with a list. Return while typing an accent never gets here: the keyboard keeps that for itself.
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)), Self.stylesMarkdown,
              let edit = noteNewline(in: textView.string as NSString, selection: textView.selectedRange())
        else { return false }
        apply(edit)
        return true
    }

    // Covers Esc.
    override func close() {
        saveNow()
        orderOut(nil)
    }

    /// Writes unsaved edits now. Called on hide and on quit; typing saves after a 500 ms pause.
    func saveNow() {
        guard pendingSave != nil else { return }
        pendingSave?.cancel()
        pendingSave = nil
        write()
    }

    /// Adds `line` at the end of the note, on a line of its own, and saves (`add note …`).
    func append(_ line: String) {
        text += (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + line + "\n"
        undoManager?.removeAllActions() // undo steps point into the text as it was
        write()
    }

    private func write() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            notify(String(localized: "Couldn't save the note"), error.localizedDescription) // the text stays in the panel
        }
    }

    /// Picks up edits made to the file elsewhere, unless the note is being edited here.
    func reloadIfChanged() {
        guard !isKeyWindow, pendingSave == nil,
              let saved = try? String(contentsOf: file, encoding: .utf8), saved != text
        else { return }
        text = saved
        undoManager?.removeAllActions() // old undo steps point into text that's gone
    }

    func textDidChange(_ notification: Notification) { textChanged() }

    @objc private func textChanged() {
        restyle()
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { saveNow() }
        }
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        var frames = StateStore.shared.get(Self.stateSection, as: [String: CGRect].self) ?? [:]
        frames[frameKey] = frame.insetBy(dx: Self.margin, dy: Self.margin)
        StateStore.shared.set(Self.stateSection, frames)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 { return close() } // Esc
        if let shortcut = noteShortcut(event) { return perform(shortcut, held: event.isARepeat) }
        if performEditShortcut(event) { return }
        super.sendEvent(event)
    }

    private func perform(_ shortcut: NoteShortcut, held: Bool) {
        switch shortcut {
        case .format(let format):
            guard Self.stylesMarkdown, !held else { return } // plain text asked for, or a toggle flickering
            apply(noteEdit(format, in: textView.string as NSString, selection: textView.selectedRange()))
        case .bigger: resize(to: Self.textSize + 2)
        case .smaller: resize(to: Self.textSize - 2)
        case .normalSize: resize(to: Self.defaultTextSize)
        }
    }

    /// As typing: undoable, styled and saved.
    private func apply(_ edit: NoteEdit) {
        if (edit.range.length > 0 || !edit.replacement.isEmpty), textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) {
            textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
            textView.didChangeText()
        }
        textView.setSelectedRange(edit.selection)
    }

    /// One size for every note, so they all change.
    private func resize(to size: CGFloat) {
        Self.textSize = size
        for note in NSApp.windows.compactMap({ $0 as? NotePanel }) { note.restyleInPlace() }
    }

    /// Restyled at a new size, with the same text at the top of the note. A cursor you could see, you still can.
    private func restyleInPlace() {
        let visible = textView.visibleRect, selected = textView.selectedRange(), length = (textView.string as NSString).length
        func character(atY y: CGFloat) -> Int { textView.characterIndexForInsertion(at: NSPoint(x: visible.minX + 1, y: y)) }
        let top = character(atY: visible.minY + 1), bottom = character(atY: visible.maxY - 1)
        restyle()
        // Asked about text not laid out yet, the view answers the note's end. Better to stay put than to jump there.
        guard let layout = textView.textLayoutManager, textView.window != nil, top < length else { return }
        layout.ensureLayout(for: layout.documentRange) // or where it is now is only an estimate
        textView.scrollRangeToVisible(NSRange(location: top, length: 0)) // it only reports where text is on screen once it's in view
        let onScreen = textView.firstRect(forCharacterRange: NSRange(location: top, length: 0), actualRange: nil)
        let place = textView.convert(convertFromScreen(onScreen), from: nil)
        textView.scroll(NSPoint(x: 0, y: place.minY - textView.textContainerInset.height))
        if selected.location >= top, selected.location <= bottom { textView.scrollRangeToVisible(selected) }
    }
}

/// The note's card: its title (drag it there) over the text, a corner to resize it by.
private struct NoteView: View {
    let header: NoteHeader
    let text: NSView

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(height: 16)
                Text(header.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Keycap(label: "esc").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(height: 42)
            .overlay(WindowGrip(resizes: false))
            Hosted(view: text).padding(.leading, 13).padding(.trailing, 6).padding(.bottom, 12)
        }
        .modifier(Card(radius: 22))
        .overlay(alignment: .bottomTrailing) { WindowGrip(resizes: true).frame(width: 18, height: 18) }
        .padding(NotePanel.margin)
    }
}

private struct Hosted: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ view: NSView, context: Context) {}
}

/// Dragging it moves the window, or resizes it from the bottom-right corner, keeping the top left in place.
private struct WindowGrip: NSViewRepresentable {
    let resizes: Bool

    final class Grip: NSView {
        var resizes = false
        private var start: (mouse: NSPoint, frame: NSRect)?

        // The first click drags, even with another app in front; without this it only brought the note forward.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            start = (window.convertPoint(toScreen: event.locationInWindow), window.frame) // where it was pressed, not where it is now
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let start else { return }
            let mouse = NSEvent.mouseLocation
            if !resizes {
                // Moved here, not by performDrag: the window server stops a dragged window's top at the menu bar, and
                // this window's top is the clear margin. setFrameOrigin goes through constrainFrameRect, which knows.
                return window.setFrameOrigin(NSPoint(x: start.frame.minX + mouse.x - start.mouse.x, y: start.frame.minY + mouse.y - start.mouse.y))
            }
            let margin = 2 * NotePanel.margin
            let width = max(NotePanel.minSize.width + margin, start.frame.width + mouse.x - start.mouse.x)
            let height = max(NotePanel.minSize.height + margin, start.frame.height - (mouse.y - start.mouse.y))
            window.setFrame(NSRect(x: start.frame.minX, y: start.frame.maxY - height, width: width, height: height), display: true)
        }

        override func mouseUp(with event: NSEvent) { start = nil }

        override func resetCursorRects() {
            if resizes { addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all)) }
        }
    }

    func makeNSView(context: Context) -> Grip {
        let grip = Grip()
        grip.resizes = resizes
        return grip
    }

    func updateNSView(_ grip: Grip, context: Context) {}
}
