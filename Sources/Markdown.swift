import AppKit

/// How a stretch of a note shows. The text itself never changes: this is drawing only, and the file stays plain text.
enum MarkdownStyle: Equatable, Sendable {
    case heading(Int) // the whole line, `#` to `###`
    case bold, italic, code
    case marker // the syntax around a style (`**`, `# `, `](url)`), dimmed
    case bullet // `- `, `* `, `1. `
    case checkbox(done: Bool) // `[ ]`, `[x]`: click to tick
    case done // what follows a ticked box
    case quote // the whole line, `> `
    case link(String)
}

struct MarkdownSpan: Equatable, Sendable {
    let range: NSRange
    let style: MarkdownStyle
}

private func regex(_ pattern: String) -> NSRegularExpression { try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) }

private let headingLine = regex(#"^(#{1,3} +).*$"#)
private let quoteLine = regex(#"^(> ?).*$"#)
private let checkboxLine = regex(#"^(\s*[-*+] )(\[( |x|X)\])(.*)$"#)
private let bulletLine = regex(#"^\s*([-*+]|\d+\.) (?!\[[ xX]\])"#)
private let codeSpan = regex(#"`([^`\n]+)`"#)
private let linkSpan = regex(#"\[([^\]\n]+)\]\(([^)\s]+)\)"#)
private let unfinishedOrWholeLink = regex(#"\[([^\]\n]*)\]\(([^)\s]*)\)"#) // also `[name]()` and `[](address)`, as the keys write them
private let bareURL = regex(#"https?://[^\s)\]>*`]+"#) // `*` and `` ` ``: `**https://a.b**` is bold around it
private let star: unichar = 42, underscore: unichar = 95, backtick: unichar = 96, space: unichar = 32, newline: unichar = 10

/// The styles of a note's Markdown: headings, bold, italic, code, lists and checkboxes, quotes and links. Ranges are
/// UTF-16, as NSTextStorage counts. ponytail: a line-by-line reading, not CommonMark (no code blocks).
/// `typingAt`: the caret. Spaces just typed before closing markers (`**hello |**`) don't end the style, or it would blink
/// off at each word. They're read as a sign of the same length, so the ranges hold.
func markdownSpans(_ text: String, typingAt caret: Int? = nil) -> [MarkdownSpan] {
    var text = text
    if let caret, caret < text.utf16.count, [star, underscore].contains((text as NSString).character(at: caret)) {
        var start = caret
        while start > 0, (text as NSString).character(at: start - 1) == space { start -= 1 }
        text = (text as NSString).replacingCharacters(in: NSRange(location: start, length: caret - start), with: String(repeating: ".", count: caret - start))
    }
    let string = text as NSString, all = NSRange(location: 0, length: string.length)
    var spans: [MarkdownSpan] = []
    func each(_ pattern: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
        pattern.enumerateMatches(in: text, range: all) { match, _, _ in match.map(body) }
    }
    each(headingLine) { match in
        let level = string.substring(with: match.range(at: 1)).filter { $0 == "#" }.count
        spans += [MarkdownSpan(range: match.range, style: .heading(level)), MarkdownSpan(range: match.range(at: 1), style: .marker)]
    }
    each(quoteLine) { spans += [MarkdownSpan(range: $0.range, style: .quote), MarkdownSpan(range: $0.range(at: 1), style: .marker)] }
    each(checkboxLine) { match in
        let done = string.substring(with: match.range(at: 3)) != " "
        spans += [MarkdownSpan(range: match.range(at: 1), style: .bullet), MarkdownSpan(range: match.range(at: 2), style: .checkbox(done: done))]
        let rest = match.range(at: 4), text = string.substring(with: rest)
        let lead = text.prefix { $0 == " " }.utf16.count
        if done, rest.length > lead { spans.append(MarkdownSpan(range: NSRange(location: rest.location + lead, length: rest.length - lead), style: .done)) }
    }
    each(bulletLine) { spans.append(MarkdownSpan(range: NSRange(location: $0.range(at: 1).location, length: $0.range(at: 1).length + 1), style: .bullet)) }
    each(codeSpan) { match in
        spans.append(MarkdownSpan(range: match.range(at: 1), style: .code))
        spans += markers(around: match.range, inner: match.range(at: 1))
    }
    spans += emphasisSpans(string)
    var linked: [NSRange] = []
    each(linkSpan) { match in
        let url = string.substring(with: match.range(at: 2))
        spans.append(MarkdownSpan(range: match.range(at: 1), style: .link(url)))
        spans += markers(around: match.range, inner: match.range(at: 1))
        linked.append(match.range)
    }
    each(bareURL) { match in
        guard !linked.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return }
        spans.append(MarkdownSpan(range: match.range, style: .link(string.substring(with: match.range))))
    }
    return spans
}

private func isWord(_ text: NSString, _ index: Int) -> Bool {
    index >= 0 && index < text.length && UnicodeScalar(text.character(at: index)).map(CharacterSet.alphanumerics.contains) == true
}

/// Bold and italic, as CommonMark reads them: runs of `*` or `_` on a line, where a run that can close takes the nearest
/// that opened, from the inside out. That's what lets them nest. One thing is stricter, so `2*3*4` and `a*b, c*d` stay as
/// they are: a single `*` with a letter or digit on both its outer sides isn't italic, nor a `_` with one on either.
private func emphasisSpans(_ text: NSString) -> [MarkdownSpan] {
    struct Run { let mark: unichar, start: Int, size: Int, canClose: Bool; var left: Int }
    func isSpace(_ index: Int) -> Bool {
        index < 0 || index >= text.length || UnicodeScalar(text.character(at: index)).map(CharacterSet.whitespacesAndNewlines.contains) == true
    }
    var spans: [MarkdownSpan] = [], open: [Run] = [], index = 0
    while index < text.length {
        let mark = text.character(at: index)
        if mark == newline { open = [] }
        guard mark == star || mark == underscore else { index += 1; continue }
        var end = index
        while end < text.length, text.character(at: end) == mark { end += 1 }
        let canOpen = !isSpace(end), canClose = !isSpace(index - 1), size = end - index
        var closing = index, opener = canClose ? open.count - 1 : -1
        while closing < end, opener >= 0 {
            let run = open[opener]
            let take = min(run.left, end - closing) >= 2 ? 2 : 1
            let before = run.start + run.left - take - 1, after = closing + take
            let inWord = take == 1 && (mark == star ? isWord(text, before) && isWord(text, after) : isWord(text, before) || isWord(text, after))
            // CommonMark's rule of three: in `**hello*x***` the middle `*` opens, it doesn't close the `**`.
            let threes = (canOpen || run.canClose) && (run.size + size) % 3 == 0 && (run.size % 3 != 0 || size % 3 != 0)
            guard run.mark == mark, !inWord, !threes else { opener -= 1; continue }
            let inner = NSRange(location: run.start + run.left, length: closing - run.start - run.left)
            spans += [MarkdownSpan(range: inner, style: take == 2 ? .bold : .italic),
                      MarkdownSpan(range: NSRange(location: inner.location - take, length: take), style: .marker),
                      MarkdownSpan(range: NSRange(location: closing, length: take), style: .marker)]
            closing += take
            open[opener].left -= take
            open.removeLast(open.count - opener - 1) // what opened inside it can't close now
            if open[opener].left == 0 { open.removeLast(); opener -= 1 }
        }
        if closing < end, canOpen { open.append(Run(mark: mark, start: closing, size: size, canClose: canClose, left: end - closing)) }
        index = end
    }
    return spans
}

/// The syntax on either side of `inner` within `whole`: `**` and `**`, `[` and `](url)`.
private func markers(around whole: NSRange, inner: NSRange) -> [MarkdownSpan] {
    [NSRange(location: whole.location, length: inner.location - whole.location),
     NSRange(location: NSMaxRange(inner), length: NSMaxRange(whole) - NSMaxRange(inner))]
        .filter { $0.length > 0 }.map { MarkdownSpan(range: $0, style: .marker) }
}

/// The checkbox at `location` and what clicking it makes it: `[ ]` becomes `[x]`, and back. nil if there's none there.
func checkboxToggle(_ text: NSString, at location: Int) -> (range: NSRange, replacement: String)? {
    let line = text.lineRange(for: NSRange(location: min(location, max(text.length - 1, 0)), length: 0))
    guard let match = checkboxLine.firstMatch(in: text as String, range: line) else { return nil }
    let box = match.range(at: 2)
    guard NSLocationInRange(location, box) || location == NSMaxRange(box) else { return nil }
    return (box, text.substring(with: match.range(at: 3)) == " " ? "[x]" : "[ ]")
}

/// The link a checkbox carries, so a click on it reaches the note (NSTextView hands clicks on links to its delegate).
let checkboxScheme = "copperlight-checkbox"

/// What a note's shortcuts write: only Markdown, so the file stays plain text.
enum NoteFormat: Equatable, Sendable {
    case bold, italic, code, link
    case heading(Int), bullet, numbered, checkbox, quote
}

/// A change to a note's text, and what's selected after it.
struct NoteEdit: Equatable, Sendable {
    let range: NSRange
    let replacement: String
    let selection: NSRange
}

/// What pressing `format`'s shortcut does to `text`: adds it, or takes it off what has it already.
func noteEdit(_ format: NoteFormat, in text: NSString, selection: NSRange) -> NoteEdit {
    switch format {
    case .bold: inlineEdit("**", .bold, text, selection)
    case .italic: inlineEdit("*", .italic, text, selection)
    case .code: inlineEdit("`", .code, text, selection)
    case .link: linkEdit(text, selection)
    default: lineEdit(format, text, selection)
    }
}

private let linePrefix = regex(#"^([ \t]*)(#{1,3} +|> ?|[-*+] \[[ xX]\] *|[-*+] |\d+\. )?"#)
private typealias Change = (range: NSRange, with: String)

/// `changes`, which don't overlap, as one replacement, with the selection carried along. Text added right where the
/// selection starts goes before it, and right where it ends, after it, so what was selected stays selected.
private func edit(_ changes: [Change], in text: NSString, selection: NSRange) -> NoteEdit {
    let sorted = changes.sorted { $0.range.location < $1.range.location }
    guard let first = sorted.first, let last = sorted.last else { return moved(to: selection) }
    var replacement = "", at = first.range.location
    for change in sorted {
        replacement += text.substring(with: NSRange(location: at, length: change.range.location - at)) + change.with
        at = NSMaxRange(change.range)
    }
    func carried(_ location: Int, pastAdded: Bool) -> Int {
        location + sorted.reduce(0) { shift, change in
            let end = NSMaxRange(change.range)
            if end < location || (end == location && (change.range.length > 0 || pastAdded)) { return shift + change.with.utf16.count - change.range.length }
            return change.range.location < location ? shift + change.range.location - location : shift // inside what's replaced: to its start
        }
    }
    let start = carried(selection.location, pastAdded: true)
    let end = selection.length == 0 ? start : carried(NSMaxRange(selection), pastAdded: false)
    return NoteEdit(range: NSRange(location: first.range.location, length: NSMaxRange(last.range) - first.range.location),
                    replacement: replacement, selection: NSRange(location: start, length: end - start))
}

/// No text changes, only where the cursor is.
private func moved(to selection: NSRange) -> NoteEdit { NoteEdit(range: NSRange(location: selection.location, length: 0), replacement: "", selection: selection) }

/// The lines `range` is on, without their line endings.
private func lines(_ text: NSString, _ range: NSRange) -> [NSRange] {
    var found: [NSRange] = []
    text.enumerateSubstrings(in: text.lineRange(for: range), options: [.byLines, .substringNotRequired]) { _, line, _, _ in found.append(line) }
    return found
}

/// What's selected, line by line: without the spaces at its ends, a line's list mark or heading, or blank lines. A mark
/// inside the markers, or spaces against them, wouldn't draw.
private func selectedParts(_ text: NSString, _ selection: NSRange) -> [NSRange] {
    guard selection.length > 0 else { return [] }
    return lines(text, selection).compactMap { line in
        let start = linePrefix.firstMatch(in: text as String, range: line).map { NSMaxRange($0.range) } ?? line.location
        var part = NSIntersectionRange(selection, NSRange(location: start, length: NSMaxRange(line) - start))
        while part.length > 0, CharacterSet.whitespaces.contains(UnicodeScalar(text.character(at: part.location)) ?? "x") { part = NSRange(location: part.location + 1, length: part.length - 1) }
        while part.length > 0, CharacterSet.whitespaces.contains(UnicodeScalar(text.character(at: NSMaxRange(part) - 1)) ?? "x") { part.length -= 1 }
        return part.length > 0 ? part : nil
    }
}

/// The word the caret is inside, with letters or digits on both sides of it. At a word's end there's none: what you
/// type next isn't part of it.
private func wordAround(_ text: NSString, _ location: Int) -> NSRange? {
    guard isWord(text, location - 1), isWord(text, location) else { return nil }
    var start = location, end = location
    while isWord(text, start - 1) { start -= 1 }
    while isWord(text, end) { end += 1 }
    return NSRange(location: start, length: end - start)
}

/// Every link, named or a bare address, whole.
private func linkRanges(_ text: NSString) -> [NSRange] {
    let all = NSRange(location: 0, length: text.length)
    let named = unfinishedOrWholeLink.matches(in: text as String, range: all).map(\.range)
    return named + bareURL.matches(in: text as String, range: all).map(\.range).filter { url in !named.contains { NSIntersectionRange($0, url).length > 0 } }
}

/// Bold, italic and code: the markers around what's selected, or off what has them. It finds what's styled the way it's
/// drawn, so `__bold__` and `_italic_` come off too, and `***both***` loses only the one pressed.
private func inlineEdit(_ marker: String, _ style: MarkdownStyle, _ text: NSString, _ selection: NSRange) -> NoteEdit {
    let size = marker.utf16.count, caret = selection.location
    let spans = markdownSpans(text as String, typingAt: selection.length == 0 ? caret : nil).filter { $0.style == style }.map(\.range)
    let links = linkRanges(text)
    func off(_ span: NSRange) -> [Change] { [(NSRange(location: span.location - size, length: size), ""), (NSRange(location: NSMaxRange(span), length: size), "")] }
    func on(_ part: NSRange) -> [Change] { [(NSRange(location: part.location, length: 0), marker), (NSRange(location: NSMaxRange(part), length: 0), marker)] }
    func isMark(_ index: Int) -> Bool { index >= 0 && index < text.length && [star, underscore, backtick].contains(text.character(at: index)) }

    if selection.length > 0 {
        // An address stays one, and italic can't start and end inside a word: they take all of it.
        let parts = selectedParts(text, selection).map { part -> NSRange in
            if let link = links.first(where: { NSIntersectionRange($0, part) == part }) { return link }
            guard style == .italic, isWord(text, part.location - 1), isWord(text, NSMaxRange(part)) else { return part }
            var start = part.location, end = NSMaxRange(part)
            while isWord(text, start - 1) { start -= 1 }
            while isWord(text, end) { end += 1 }
            return NSRange(location: start, length: end - start)
        }
        guard !parts.isEmpty else { return moved(to: selection) } // only spaces, or a list mark
        let styled = parts.map { part in spans.filter { NSIntersectionRange($0, part).length > 0 } }
        if styled.allSatisfy({ !$0.isEmpty }) { return edit(Set(styled.flatMap { $0 }).flatMap(off), in: text, selection: selection) }
        return edit(zip(parts, styled).filter { $0.1.isEmpty }.flatMap { on($0.0) }, in: text, selection: selection)
    }

    let touched = spans.first { span in
        var start = span.location, end = NSMaxRange(span)
        while isMark(start - 1) { start -= 1 }
        while isMark(end) { end += 1 }
        return caret >= start && caret <= end
    }
    if let span = touched {
        var closers = caret
        while isMark(closers) { closers += 1 }
        // Right before its closing markers: done typing it, so on past them. Elsewhere in it, it comes off.
        guard caret > span.location, closers >= NSMaxRange(span) + size, caret + size <= closers else { return edit(off(span), in: text, selection: selection) }
        var typed = caret
        while typed > span.location, text.character(at: typed - 1) == space { typed -= 1 }
        if typed == span.location { return edit(off(span), in: text, selection: selection) }
        if typed == caret { return moved(to: NSRange(location: caret + size, length: 0)) }
        // Spaces go after the markers: `**hello **` wouldn't draw.
        return NoteEdit(range: NSRange(location: typed, length: caret + size - typed),
                        replacement: text.substring(with: NSRange(location: caret, length: size)) + text.substring(with: NSRange(location: typed, length: caret - typed)),
                        selection: NSRange(location: caret + size, length: 0))
    }
    // Markers with nothing in them yet aren't drawn, so they're counted: `**|**` is bold and `***|***` both.
    let mark = marker.utf16.first!
    var pairs = 0
    while caret - pairs > 0, caret + pairs < text.length, text.character(at: caret - pairs - 1) == mark, text.character(at: caret + pairs) == mark { pairs += 1 }
    if style == .bold ? pairs >= 2 : pairs % 2 == 1 { return edit(off(NSRange(location: caret, length: 0)), in: text, selection: selection) }
    if let link = links.first(where: { $0.location < caret && caret < NSMaxRange($0) }) { return edit(on(link), in: text, selection: selection) }
    if let word = wordAround(text, caret) { return edit(on(word), in: text, selection: selection) }
    return NoteEdit(range: NSRange(location: caret, length: 0), replacement: marker + marker, selection: NSRange(location: caret + size, length: 0))
}

/// `[name](address)`: what's selected or the word becomes the name, with the cursor where the address goes. Pressed in a
/// name with no address yet, on to the address; on a link, it comes off. On a bare address, the cursor goes where its name would.
private func linkEdit(_ text: NSString, _ selection: NSRange) -> NoteEdit {
    let caret = selection.location, all = NSRange(location: 0, length: text.length)
    func touched(_ whole: NSRange) -> Bool {
        selection.length > 0 ? NSIntersectionRange(whole, selection).length > 0 : caret >= whole.location && caret <= NSMaxRange(whole)
    }
    if let link = unfinishedOrWholeLink.matches(in: text as String, range: all).first(where: { touched($0.range) }) {
        let name = link.range(at: 1), address = link.range(at: 2)
        if selection.length == 0, address.length == 0, caret <= NSMaxRange(name) { return moved(to: NSRange(location: address.location, length: 0)) }
        if name.length == 0 { // back to the address it was, or to nothing
            return NoteEdit(range: link.range, replacement: text.substring(with: address), selection: NSRange(location: link.range.location + address.length, length: 0))
        }
        return edit([(NSRange(location: link.range.location, length: 1), ""), (NSRange(location: NSMaxRange(name), length: NSMaxRange(link.range) - NSMaxRange(name)), "")],
                    in: text, selection: selection)
    }
    if let bare = bareURL.matches(in: text as String, range: all).first(where: { touched($0.range) })?.range {
        return NoteEdit(range: bare, replacement: "[](\(text.substring(with: bare)))", selection: NSRange(location: bare.location + 1, length: 0))
    }
    if let name = selectedParts(text, selection).first ?? (selection.length == 0 ? wordAround(text, caret) : nil) {
        return NoteEdit(range: name, replacement: "[\(text.substring(with: name))]()", selection: NSRange(location: NSMaxRange(name) + 3, length: 0))
    }
    return NoteEdit(range: NSRange(location: caret, length: 0), replacement: "[]()", selection: NSRange(location: caret + 1, length: 0))
}

/// What a line's mark is: `# `, `- `, `- [ ] `, `1. `, `> `.
private func lineFormat(_ mark: String) -> NoteFormat? {
    switch mark.first {
    case nil: nil
    case "#": .heading(mark.filter { $0 == "#" }.count)
    case ">": .quote
    case "-", "*", "+": mark.contains("[") ? .checkbox : .bullet
    default: .numbered
    }
}

/// Headings, lists and quotes: the mark at the start of each line, in place of the one there. If they all have it, it
/// comes off. Blank lines stay blank, unless the caret's on one.
private func lineEdit(_ format: NoteFormat, _ text: NSString, _ selection: NSRange) -> NoteEdit {
    func prefix(_ line: NSRange) -> (indent: NSRange, mark: NSRange) {
        let match = linePrefix.firstMatch(in: text as String, range: line)!
        let mark = match.range(at: 2)
        return (match.range(at: 1), mark.location == NSNotFound ? NSRange(location: NSMaxRange(match.range(at: 1)), length: 0) : mark)
    }
    func has(_ line: NSRange) -> Bool { lineFormat(text.substring(with: prefix(line).mark)) == format }
    var chosen = lines(text, selection).filter { !text.substring(with: $0).trimmingCharacters(in: .whitespaces).isEmpty }
    if chosen.isEmpty {
        var start = 0, end = 0
        text.getLineStart(&start, end: nil, contentsEnd: &end, for: NSRange(location: selection.location, length: 0))
        chosen = [NSRange(location: start, length: end - start)]
    }
    if chosen.allSatisfy(has) { return edit(chosen.map { (prefix($0).mark, "") }, in: text, selection: selection) }

    // A list's number, if it's one to count on from.
    func listNumber(_ line: NSRange) -> Int? {
        let mark = text.substring(with: prefix(line).mark)
        guard lineFormat(mark) == .numbered, let number = Int(mark.dropLast(2)), number < 1_000_000 else { return nil }
        return number
    }
    var number = 1
    if let first = chosen.first, first.location > 0 {
        let above = text.lineRange(for: NSRange(location: first.location - 1, length: 0))
        number = (listNumber(NSRange(location: above.location, length: first.location - 1 - above.location)) ?? 0) + 1
    }
    var changes: [Change] = []
    for line in chosen {
        if has(line) {
            number = (listNumber(line) ?? 0) + 1
            continue
        }
        let (indent, mark) = prefix(line)
        switch format {
        case .heading(let level): changes.append((NSUnionRange(indent, mark), String(repeating: "#", count: level) + " ")) // a heading or a quote
        case .quote: changes.append((NSUnionRange(indent, mark), "> ")) // starts its line, or doesn't draw
        case .bullet: changes.append((mark, "- "))
        case .checkbox: changes.append((mark, "- [ ] "))
        default: changes.append((mark, "\(number). "))
        }
        number += 1
    }
    return edit(changes, in: text, selection: selection)
}
