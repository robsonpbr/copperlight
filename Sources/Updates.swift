import AppKit

/// "0.17" comes after "0.9": as numbers, not letters.
func isNewerVersion(_ version: String, than other: String) -> Bool { version.compare(other, options: .numeric) == .orderedDescending }

/// The version in GitHub's answer for the latest release (`v0.16` is 0.16). Nil for anything that isn't one.
func latestVersion(in release: Data) -> String? {
    struct Release: Decodable { let tag_name: String }
    guard let tag = (try? JSONDecoder().decode(Release.self, from: release))?.tag_name else { return nil }
    return tag.wholeMatch(of: /v?(\d+(?:\.\d+)*)/).map { String($0.1) }
}

/// GitHub's latest release: never a draft or a pre-release. Nothing about you goes with it.
@Sendable func fetchLatestRelease() async -> Data? {
    let request = URLRequest(url: URL(string: "https://api.github.com/repos/robsonpbr/copperlight/releases/latest")!, timeoutInterval: 15)
    guard let (data, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return data
}

/// Is a newer Copperlight out? Asked when the launcher opens, at most once a day. The answer waits in the empty launcher
/// and the menu bar, kept in state.json. ponytail: it only tells you, and the page has the download; installing it
/// for you is on the way to 1.0.
@MainActor @Observable final class UpdateCheck {
    static let page = URL(string: "https://github.com/robsonpbr/copperlight/releases/latest")!
    private static let section = "update"
    private struct Saved: Codable {
        var checked = Date.distantPast
        var latest: String?
        var skipped: String?
    }

    /// `[features] updates`: off asks nothing and says nothing.
    var isOn = true
    private let current: String
    private let store: StateStore
    private let fetch: @Sendable () async -> Data?
    private var saved: Saved

    init(store: StateStore, current: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
         fetch: @escaping @Sendable () async -> Data?) {
        (self.store, self.current, self.fetch) = (store, current, fetch)
        saved = store.get(Self.section, as: Saved.self) ?? Saved()
    }

    /// The newer version that's out, skipped or not.
    var available: String? {
        guard isOn, let latest = saved.latest, isNewerVersion(latest, than: current) else { return nil }
        return latest
    }

    func refreshIfStale(now: Date = .now) async {
        guard isOn, now.timeIntervalSince(saved.checked) >= 24 * 60 * 60 else { return }
        saved.checked = now // before asking: a failure is still the day's one request, and two opens can't both ask
        store.set(Self.section, saved)
        guard let data = await fetch(), let latest = latestVersion(in: data) else { return }
        saved.latest = latest
        store.set(Self.section, saved)
    }

    /// The empty launcher's row, below everything else there: Enter opens the download page, Tab offers Skip.
    var rows: [LauncherResult] {
        guard let available, available != saved.skipped else { return [] }
        return [LauncherResult(id: "update:\(available)", title: String(localized: "Copperlight \(available) is available"),
                               subtitle: String(localized: "You have \(current)"), icon: .symbol("arrow.down.circle"), score: 40,
                               actionTitle: String(localized: "Open Download Page", comment: "Enter on the row saying a new version is out"),
                               action: { NSWorkspace.shared.open(Self.page) }, actions: { [self] in
            [LauncherResult(id: "update:skip", title: String(localized: "Skip This Version"), icon: .symbol("forward.end"), score: 50,
                            actionTitle: String(localized: "Skip", comment: "Enter on Skip This Version"), action: { [self] in skip(available) })]
        })]
    }

    private func skip(_ version: String) {
        saved.skipped = version
        store.set(Self.section, saved)
    }
}
