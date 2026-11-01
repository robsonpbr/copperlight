import AppKit

/// A Wikipedia article's summary, its text ready to show.
struct WikiCard: Sendable {
    var title: String, description: String, extract: String
    var url: URL
    var imageURL: URL?
    var image: CGImage? = nil
    var loading = false

    /// The card's shape while the summary comes: what you typed, the rest in gray bars.
    static func loading(_ typed: String) -> WikiCard {
        WikiCard(title: typed, description: "What it is, in a few words",
                 extract: String(repeating: "A sentence or two about it, the way the article starts. ", count: 4),
                 url: URL(string: "https://wikipedia.org")!, loading: true)
    }
}

/// The best match's summary in Wikipedia's answer (`generator=search` with extracts, descriptions and a thumbnail);
/// nil when nothing matched.
func parseWikipedia(_ data: Data, language: String) -> WikiCard? {
    struct Answer: Decodable {
        struct Query: Decodable { var pages: [Page] }
        struct Page: Decodable { var title: String, extract: String?, description: String?, thumbnail: Thumbnail? }
        struct Thumbnail: Decodable { var source: URL }
        var query: Query?
    }
    guard let page = (try? JSONDecoder().decode(Answer.self, from: data))?.query?.pages.first,
          let path = page.title.replacing(" ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let url = URL(string: "https://\(language).wikipedia.org/wiki/\(path)") else { return nil }
    return WikiCard(title: page.title, description: page.description ?? "", extract: page.extract ?? "", url: url, imageURL: page.thumbnail?.source)
}

/// Wikipedia's best match for `query`: its title, short description, first sentences and a thumbnail, in one request.
func fetchWikipedia(_ query: String, language: String) async -> Data? {
    var url = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
    let items: KeyValuePairs<String, String> = [
        "action": "query", "format": "json", "formatversion": "2", "generator": "search", "gsrsearch": query, "gsrlimit": "1",
        "prop": "extracts|pageimages|description", "exintro": "1", "explaintext": "1", "exsentences": "3", "piprop": "thumbnail",
        "pithumbsize": "400", "redirects": "1",
    ]
    url.queryItems = items.map { URLQueryItem(name: $0.key, value: $0.value) }
    return await fetchNamed(url.url)
}

/// What `url` answers, asked with a User-Agent that says who's asking, as Wikipedia wants. nil if it can't be reached.
func fetchNamed(_ url: URL?) async -> Data? {
    guard let url else { return nil }
    var request = URLRequest(url: url, timeoutInterval: 8)
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    request.setValue("Copperlight/\(version) (https://copperlight.app)", forHTTPHeaderField: "User-Agent")
    guard let (data, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return data
}

/// `wiki serendipity`: the article's summary across the card, its picture beside it, in the language your Mac reads
/// first. Only in the Wikipedia chip (Tab), and only once typing pauses, does what you typed go to Wikipedia. Enter
/// opens the article.
struct WikipediaProvider: ResultProvider {
    private static let icon = "book.closed"
    var pause = Duration.milliseconds(350)
    var language = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    var fetch: @Sendable (String, String) async -> Data? = { await fetchWikipedia($0, language: $1) }
    var image: @Sendable (URL) async -> CGImage? = { url in await fetchNamed(url).flatMap { thumbnail($0, maxPixels: 600) } }
    var modes: [Mode] { [Mode(prefix: "wiki ", title: "Wikipedia", icon: .symbol(Self.icon), hint: "Anything: serendipity, Lisbon")] }

    func results(for query: String) async -> [LauncherResult] {
        if let start = startRow(query, keyword: "wiki", title: "Wikipedia", hint: "Type a subject: wiki Lisbon", symbol: Self.icon) {
            return [start]
        }
        let typed = query.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard query.lowercased().hasPrefix("wiki "), !typed.isEmpty else { return [] }
        // Under what else it may be, over the search row; Tab (or Enter) makes it the chip, which asks.
        return [LauncherResult(id: "wiki:offer", title: "Wikipedia: \(typed)", subtitle: "Its summary, from Wikipedia", icon: .symbol(Self.icon),
                               score: -5, actionTitle: "Look Up", action: {}, completion: "wiki " + typed)]
    }

    func modeResults(for query: String) async -> [LauncherResult] {
        let typed = query.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return [] }
        return [LauncherResult(id: "wiki", title: typed, subtitle: "Asking Wikipedia…", icon: .symbol(Self.icon), score: 50, actionTitle: "",
                               action: {}, answer: .wiki(.loading(typed)), later: { await summary(typed) })]
    }

    private func summary(_ typed: String) async -> [LauncherResult] {
        try? await Task.sleep(for: pause) // the next keystroke cancels this round, so only a pause asks Wikipedia
        guard !Task.isCancelled else { return [] }
        guard let data = await fetch(typed, language) else { return [note("Couldn't reach Wikipedia", "Check the connection and try again")] }
        guard var card = parseWikipedia(data, language: language) else { return [note("Nothing on Wikipedia for “\(typed)”", "Try other words")] }
        if let url = card.imageURL { card.image = await image(url) }
        let url = card.url
        return [LauncherResult(id: "wiki:\(card.title)", title: card.title, subtitle: card.description, icon: .symbol(Self.icon), score: 50,
                               actionTitle: "Open", action: { NSWorkspace.shared.open(url) }, answer: .wiki(card))]
    }

    private func note(_ title: String, _ subtitle: String) -> LauncherResult {
        LauncherResult(id: "wiki", title: title, subtitle: subtitle, icon: .symbol(Self.icon), score: 50, actionTitle: "", action: {})
    }
}
