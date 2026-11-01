import AppKit
import CoreWLAN

/// What a phone's camera reads to join a network: `WIFI:T:WPA;S:name;P:password;;`, with `\ ; , : "` escaped.
func wifiJoinText(network: String, password: String) -> String {
    let escape = { (text: String) in
        text.reduce(into: "") { escaped, character in
            if #"\;,:""#.contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
    }
    return password.isEmpty ? "WIFI:T:nopass;S:\(escape(network));;" : "WIFI:T:WPA;S:\(escape(network));P:\(escape(password));;"
}

/// The Wi-Fi network this Mac is on. macOS tells only apps that Location Services allows: nil otherwise, or off Wi-Fi.
func currentWiFiNetwork() -> String? { CWWiFiClient.shared().interface()?.ssid() }

/// A network's password, from the keychain macOS keeps them in. macOS asks for your Mac's password first, in its own
/// window; nil if you cancel, or it doesn't know the network.
func keychainWiFiPassword(_ network: String) async -> String? {
    await Task.detached {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "AirPort", "-a", network, "-w"]
        let output = Pipe()
        process.standardOutput = output // a pipe, not a file: the password never touches the disk
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
    }.value
}

/// `wifi password` (or `wifi password Office`): Enter asks macOS for the password of the network you're on, then
/// shows it with a QR code that joins a phone to it. Enter copies the password. It's kept in memory for 10 minutes.
actor WiFiProvider: ResultProvider {
    private static let icon = LauncherResult.Icon.symbol("wifi")
    private let network: @Sendable () -> String?
    private let located: @Sendable () -> LocationStatus
    private let password: @Sendable (String) async -> String?
    private let show: @MainActor @Sendable (String) -> Void
    private var revealed: [String: (password: String, at: Date)] = [:]

    init(network: @escaping @Sendable () -> String? = { currentWiFiNetwork() }, located: @escaping @Sendable () -> LocationStatus = { Locator.status },
         password: @escaping @Sendable (String) async -> String? = { await keychainWiFiPassword($0) },
         show: @escaping @MainActor @Sendable (String) -> Void) {
        (self.network, self.located, self.password, self.show) = (network, located, password, show)
    }

    func results(for query: String) async -> [LauncherResult] {
        let lower = query.lowercased()
        guard let prefix = ["wifi password", "wi-fi password"].first(where: { lower == $0 || lower.hasPrefix($0 + " ") }) else { return [] }
        let typed = query.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard let name = typed.isEmpty ? network() : typed else { return [unknown()] }
        if let known = revealed[name], known.at.timeIntervalSinceNow > -600 { return card(name, known.password) }
        return [LauncherResult(id: "wifi:\(name)", title: "Show the Password for “\(name)”", subtitle: "macOS asks for your Mac's password first",
                               icon: Self.icon, score: 50, actionTitle: "Show", action: { [self] in
            Task {
                guard await reveal(name) else { return notify("Couldn't get the password for “\(name)”", "Asked to cancel, or it isn't a network this Mac knows") }
                show(query)
            }
        })]
    }

    /// Asks macOS for the password of `name`, and keeps it for the card. false if it couldn't.
    func reveal(_ name: String) async -> Bool {
        guard let found = await password(name) else { return false }
        revealed[name] = (found, .now)
        return true
    }

    private func card(_ name: String, _ password: String) -> [LauncherResult] {
        guard let code = qrCode(wifiJoinText(network: name, password: password)) else { return [] }
        let answer = Answer.picture(code, kicker: "Wi-Fi · scan to join", title: name, subtitle: password.isEmpty ? "No password" : password)
        return [LauncherResult(id: "wifi:\(name)", title: password, subtitle: "The password for “\(name)”", icon: Self.icon, score: 50,
                               actionTitle: "Copy", action: { copyToClipboard(password) }, answer: answer),
                LauncherResult(id: "wifi:qr", title: "Copy QR Code", subtitle: "To share it in a message", icon: .symbol("qrcode"),
                               score: 49.9, actionTitle: "Copy", action: { copyPicture(code) })]
    }

    /// Without the network's name: Location Services lets macOS say it, or you type it.
    private func unknown() -> LauncherResult {
        let row = { (title: String, subtitle: String, actionTitle: String, action: @escaping @MainActor @Sendable () -> Void) in
            LauncherResult(id: "wifi", title: title, subtitle: subtitle, icon: Self.icon, score: 50, actionTitle: actionTitle, action: action)
        }
        if located() == .unasked {
            return row("See Which Wi-Fi You're On", "macOS tells apps the network's name only with Location Services", "Allow", { Locator.shared.ask() })
        }
        return row("Type the network's name: wifi password Home",
                   located() == .refused ? "Without Location Services, macOS keeps it from apps" : "This Mac isn't on Wi-Fi", "", {})
    }
}
