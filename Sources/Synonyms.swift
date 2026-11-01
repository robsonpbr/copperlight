import AppKit
import CoreServices

/// One sense of a word in the thesaurus: its example, and the words that mean the same there.
struct ThesaurusSense: Equatable, Sendable {
    var example: String
    var words: [String]
}

/// The Mac's thesaurus (Dictionary's Writer's Thesaurus), if it's turned on. Dictionary Services has no public way to
/// pick one dictionary, so its own calls are looked up; nil if they or the thesaurus aren't there.
nonisolated(unsafe) private let thesaurus: DCSDictionary? = {
    typealias Active = @convention(c) () -> Unmanaged<CFArray>?
    typealias Name = @convention(c) (UnsafeRawPointer) -> Unmanaged<CFString>?
    guard let services = dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_NOW),
          let active = dlsym(services, "DCSGetActiveDictionaries"), let name = dlsym(services, "DCSDictionaryGetName") else { return nil }
    let dictionaries = unsafeBitCast(active, to: Active.self)()?.takeUnretainedValue() as? [AnyObject] ?? []
    let found = dictionaries.first { dictionary in
        let title = unsafeBitCast(name, to: Name.self)(Unmanaged.passUnretained(dictionary).toOpaque())?.takeUnretainedValue() as String?
        return title?.localizedCaseInsensitiveContains("thesaurus") == true
    }
    return found.map { unsafeDowncast($0, to: DCSDictionary.self) }
}()

/// The thesaurus's entry for `word`, as plain text: "happy adjective 1 Melissa came in looking happy. contented, …".
func thesaurusEntry(_ word: String) -> String? {
    guard let thesaurus else { return nil }
    return DCSCopyTextDefinition(thesaurus, word as NSString, CFRange(location: 0, length: (word as NSString).length))
        .map { $0.takeRetainedValue() as String }
}

private let partsOfSpeech = "noun|verb|adjective|adverb|preposition|pronoun|conjunction|exclamation|determiner"
private let labels: Set<String> = ["informal", "dated", "literary", "archaic", "rare", "formal", "technical", "vulgar", "derogatory",
                                   "humorous", "offensive", "british", "north", "northern", "australian", "scottish", "irish", "us", "canadian",
                                   "south", "indian", "new"]

/// An entry's senses, in order: "1 example. words, words; more words; informal words. ANTONYMS …", a part of speech
/// before the first of each. The informal, dated and regional words are left out: what's left is safe to write.
func parseThesaurus(_ entry: String) -> [ThesaurusSense] {
    guard let start = entry.firstRange(of: try! Regex("\\b(?:\(partsOfSpeech))\\b")) else { return [] }
    let senseStart = try! Regex("(?:^\\s*|\\.\\s+)(?:(?:\(partsOfSpeech))\\s+)?\\d{1,2}\\s")
    return entry[start.upperBound...].split(separator: senseStart).compactMap { sense in
        // Up to its first all-capitals heading (ANTONYMS), its example, then its words.
        let text = sense.split(separator: #/\s[A-Z]{4,}\b/#, maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? ""
        guard let stop = text.range(of: ". ") else { return nil }
        let example = text[..<stop.lowerBound].components(separatedBy: " | ")[0]
        let words = text[stop.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: ". ")).components(separatedBy: "; ")
            .filter { group in !labels.contains(group.split(separator: " ").first.map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() } ?? "") }
            .flatMap { $0.components(separatedBy: ", ") }.filter { !$0.isEmpty }
        return words.isEmpty ? nil : ThesaurusSense(example: example, words: words)
    }
}

/// `synonyms happy`: a row for each word the Mac's thesaurus has for it, under the example of its sense (8 a sense, 5
/// senses at most). Enter copies one.
struct SynonymsProvider: ResultProvider {
    private static let icon = "text.book.closed"
    var lookUp: @Sendable (String) -> String? = { thesaurusEntry($0) }
    var hasThesaurus = thesaurus != nil
    var modes: [Mode] { [Mode(prefix: "synonyms ", title: "Synonyms", icon: .symbol(Self.icon), hint: "A word")] }

    func results(for query: String) async -> [LauncherResult] {
        if let start = startRow(query, keyword: "synonyms", title: "Synonyms", hint: "Type a word: synonyms happy", symbol: Self.icon) {
            return [start]
        }
        return query.lowercased().hasPrefix("synonyms ") ? await modeResults(for: query) : []
    }

    func modeResults(for query: String) async -> [LauncherResult] {
        let word = query.dropFirst(9).trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return [] }
        guard hasThesaurus else { return [note("This Mac has no thesaurus turned on", "Dictionary › Settings: tick a thesaurus")] }
        let senses = lookUp(word).map(parseThesaurus) ?? []
        guard !senses.isEmpty else { return [note("No synonyms for “\(word)”", "From the Mac's thesaurus")] }
        return senses.prefix(5).enumerated().flatMap { index, sense in
            sense.words.prefix(8).enumerated().map { position, synonym in
                LauncherResult(id: "synonym:\(index):\(synonym)", title: synonym, icon: .symbol(Self.icon),
                               score: 50 - Double(index) / 10 - Double(position) / 1000, actionTitle: "Copy",
                               action: { copyToClipboard(synonym) }, section: "“\(sense.example)”")
            }
        }
    }

    private func note(_ title: String, _ subtitle: String) -> LauncherResult {
        LauncherResult(id: "synonyms", title: title, subtitle: subtitle, icon: .symbol(Self.icon), score: 50, actionTitle: "", action: {})
    }
}
