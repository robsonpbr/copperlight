import Foundation

/// A language's own words for the built-in keywords (Resources/<code>.lproj/Keywords.strings, TRANSLATING.md), as word
/// → keyword: "clima" → "weather". Each works without its accents too (reunioes). English words are left out, being
/// keywords already, and so are `taken` ones: your own commands' and snippets' names.
func languageKeywords(_ table: [String: String], keywords: [String] = Keyword.all, taken: Set<String> = []) -> [String: String] {
    var words: [String: String] = [:]
    for keyword in table.keys.sorted() where keywords.contains(keyword) {
        for word in table[keyword]!.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) {
            for spelling in Set([word, word.folding(options: .diacriticInsensitive, locale: nil)])
            where !spelling.isEmpty && !keywords.contains(spelling) && !taken.contains(spelling) {
                words[spelling] = words[spelling] ?? keyword
            }
        }
    }
    return words
}

/// The Keywords.strings macOS picks for this Mac's language: English's on an English Mac, whose words are the keywords.
func languageKeywordTable(bundle: Bundle = .main) -> [String: String] {
    guard let url = bundle.url(forResource: "Keywords", withExtension: "strings"), let data = try? Data(contentsOf: url) else { return [:] }
    return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: String] ?? [:]
}

/// The language Copperlight shows, in its own words as macOS writes them mid-sentence ("português (Brasil)"); nil when
/// it's English.
func languageName(bundle: Bundle = .main) -> String? {
    guard let code = bundle.preferredLocalizations.first, !code.hasPrefix("en") else { return nil }
    return Locale(identifier: code).localizedString(forIdentifier: code)
}

/// A title's English and, on a Mac in another language, its translation: what typing matches, so both find it.
func titles(_ english: String, translate: (String) -> String = { Bundle.main.localizedString(forKey: $0, value: $0, table: nil) }) -> [String] {
    let translated = translate(english)
    return translated == english ? [english] : [english, translated]
}

/// The better of `score` over a title's English and its translation.
func titleScore(_ english: String, translate: (String) -> String = { Bundle.main.localizedString(forKey: $0, value: $0, table: nil) },
                _ score: (String) -> Double?) -> Double? {
    titles(english, translate: translate).compactMap(score).max()
}
