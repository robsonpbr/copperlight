import AppKit
import Contacts
import EventKit

/// Copy Diagnostics in Settings › About: what a bug report needs, and nothing you typed, copied or named. Your home
/// folder is `~`. ponytail: English on purpose, for whoever fixes the bug; and what's wrong now, not a history, since
/// nothing keeps a log of errors. Add one if reports need it.
@MainActor func diagnosticsReport(configProblem: String?, clipboard: String, featuresOff: [String], home: String = NSHomeDirectory()) -> String {
    let info = Bundle.main
    let version = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    #if arch(arm64)
    let chip = "Apple silicon"
    #else
    let chip = "Intel"
    #endif
    /// EKAuthorizationStatus and CNAuthorizationStatus number their cases alike.
    func allowed(_ status: Int) -> String {
        let words = ["not asked", "restricted", "refused", "yes", "partly"]
        return words.indices.contains(status) ? words[status] : String(status)
    }
    let permissions = [
        "Accessibility \(AXIsProcessTrusted() ? "yes" : "no")", "Screen Recording \(CGPreflightScreenCaptureAccess() ? "yes" : "no")",
        "Calendars \(allowed(EKEventStore.authorizationStatus(for: .event).rawValue))",
        "Reminders \(allowed(EKEventStore.authorizationStatus(for: .reminder).rawValue))",
        "Contacts \(allowed(CNContactStore.authorizationStatus(for: .contacts).rawValue))",
    ]
    return [
        "Copperlight \(version) (\(build))",
        "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString), \(chip)",
        "Language: \(info.preferredLocalizations.first ?? "?"), the Mac's \(Locale.preferredLanguages.first ?? "?")",
        "Running from: \(info.bundlePath)",
        "config.toml: \(configProblem ?? "fine")",
        "Clipboard history: \(clipboard)",
        "Features off: \(featuresOff.isEmpty ? "none" : featuresOff.joined(separator: ", "))",
        "Permissions: \(permissions.joined(separator: ", "))",
    ].joined(separator: "\n").replacingOccurrences(of: home, with: "~")
}
