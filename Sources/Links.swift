import Foundation

/// A copied link without what's there only to track where it was shared (`utm_…`, `fbclid`, YouTube's `si`), and out of
/// a search engine's or a social site's redirect. nil when there's nothing to take off, or the text isn't one link.
func cleanLink(_ text: String) -> String? {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.contains(where: \.isWhitespace), var components = URLComponents(string: text),
          ["http", "https"].contains(components.scheme?.lowercased() ?? ""), let host = components.host?.lowercased() else { return nil }
    let redirects = (host.hasSuffix("google.com") && components.path == "/url") || (host == "l.facebook.com" && components.path == "/l.php")
        || host == "l.instagram.com"
    if redirects, let inner = components.queryItems?.first(where: { ["q", "url", "u"].contains($0.name) })?.value, inner.hasPrefix("http") {
        return cleanLink(inner) ?? inner
    }
    guard let items = components.percentEncodedQueryItems else { return nil }
    let kept = items.filter { !isTracking($0.name, host: host) }
    guard kept.count < items.count else { return nil }
    components.percentEncodedQueryItems = kept.isEmpty ? nil : kept
    return components.string
}

private let trackers: Set<String> = ["fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid", "igshid", "igsh",
                                     "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok", "li_fat_id", "ref_src"]

/// A query parameter that only tracks: everywhere, or on the sites that use a short name for it.
private func isTracking(_ name: String, host: String) -> Bool {
    let name = name.lowercased()
    if name.hasPrefix("utm_") || trackers.contains(name) { return true }
    let on = { (site: String) in host == site || host.hasSuffix("." + site) }
    if name == "si", on("youtube.com") || on("youtu.be") || on("spotify.com") { return true }
    return ["s", "t"].contains(name) && (on("x.com") || on("twitter.com"))
}
