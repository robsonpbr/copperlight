import AppKit
import GRDB

/// A message someone sent you, from Messages.
struct ChatMessage: Sendable {
    var text: String
    var date: Date
    var sender: String // their number, address or name ("Apple")
}

/// Messages' own database: reading it takes Full Disk Access, given by hand.
let messagesDatabase = NSHomeDirectory() + "/Library/Messages/chat.db"

/// The messages you got since `since`, newest first. Newer ones keep their text only in `attributedBody`.
func recentMessages(in path: String = messagesDatabase, since: Date) throws -> [ChatMessage] {
    var configuration = Configuration()
    configuration.readonly = true
    let db = try DatabaseQueue(path: path, configuration: configuration)
    let after = Int64(since.timeIntervalSinceReferenceDate * 1_000_000_000) // nanoseconds since 2001
    return try db.read { db in
        try Row.fetchAll(db, sql: """
            SELECT message.text, message.attributedBody, message.date, handle.id AS sender FROM message
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            WHERE message.is_from_me = 0 AND message.date > ? ORDER BY message.date DESC LIMIT 50
            """, arguments: [after]).compactMap { row in
            let text: String? = row["text"], body: Data? = row["attributedBody"], date: Int64 = row["date"]
            guard let text = text ?? body.flatMap(messageText(fromAttributedBody:)) else { return nil }
            return ChatMessage(text: text, date: Date(timeIntervalSinceReferenceDate: Double(date) / 1_000_000_000), sender: row["sender"] ?? "")
        }
    }
}

/// The text in a message's `attributedBody`: an attributed string archived the old way (a typedstream), its string
/// stored after the `NSString` class as "+", a length, and the UTF-8 bytes. nil if it isn't one.
func messageText(fromAttributedBody data: Data) -> String? {
    let bytes = [UInt8](data)
    guard let marker = bytes.firstRange(of: Array("NSString".utf8)),
          var at = bytes[marker.upperBound...].firstIndex(of: UInt8(ascii: "+")).map({ $0 + 1 }), at < bytes.count else { return nil }
    // A length under 128 is its own byte; 0x81 and 0x82 say a 2- or 4-byte one follows, low byte first.
    var length = Int(bytes[at])
    at += 1
    for (marker, size) in [(0x81, 2), (0x82, 4)] where length == marker {
        guard at + size <= bytes.count else { return nil }
        length = bytes[at..<at + size].reversed().reduce(0) { $0 << 8 | Int($1) }
        at += size
    }
    guard at + length <= bytes.count else { return nil }
    return String(bytes: bytes[at..<at + length], encoding: .utf8)
}

/// The verification code in a message that says it has one: 4 to 8 digits, or two groups of 3 ("123 456"); a 6-digit
/// one first. Never a time, an amount, a price or an order number. nil if there's none.
func verificationCode(in text: String) -> String? {
    let says = text.contains(#/(?i)\b(code|codes|c[oó]digo|verification|verify|otp|passcode|one[- ]time|2fa|pin|token)\b/#)
        || ["验证码", "認証", "コード", "인증"].contains(where: text.contains)
    guard says else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    let candidates = codePattern.matches(in: text, range: range).compactMap { match -> String? in
        let groups = (1...3).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        return groups.isEmpty ? nil : groups.joined()
    }
    return candidates.first { $0.count == 6 } ?? candidates.first
}

// Not after a digit, a currency sign, a slash, "+" or "#", or a digit and a separator; not before more digits, a
// separator and a digit, "%" or a slash.
private let codePattern = try! NSRegularExpression(pattern: #"""
    (?<![\d$€£/+#\-]|\d[.,:])(\d{3})[ \-](\d{3})(?!\d|[.,:]\d|%|/)|(?<![\d$€£/+#]|\d[.,:])(\d{4,8})(?!\d|[.,:]\d|%|/)
    """#)

/// `codes` (or `2fa`, `otp`): the verification codes in the messages of the last 15 minutes, newest first, from
/// Messages' own database on this Mac. Enter copies one; Tab shows its message. Reading it needs Full Disk Access.
struct MessageCodeProvider: ResultProvider {
    var read: @Sendable (Date) throws -> [ChatMessage] = { try recentMessages(since: $0) }

    func results(for query: String) async -> [LauncherResult] {
        guard ["codes", "2fa", "otp"].contains(query.lowercased().trimmingCharacters(in: .whitespaces)) else { return [] }
        let note = { (title: String, subtitle: String, actionTitle: String, action: @escaping @MainActor @Sendable () -> Void) in
            LauncherResult(id: "codes", title: title, subtitle: subtitle, icon: .symbol("lock.shield"), score: 50, actionTitle: actionTitle, action: action)
        }
        let messages: [ChatMessage]
        do { messages = try read(.now - 15 * 60) } catch {
            return [note("Allow Full Disk Access to read codes from Messages", "Privacy & Security → Full Disk Access → Copperlight",
                         "Open System Settings", {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            })]
        }
        let codes = messages.compactMap { message in verificationCode(in: message.text).map { (message, $0) } }.prefix(5)
        guard !codes.isEmpty else { return [note("No codes in the last 15 minutes", "From Messages", "", {})] }
        return codes.enumerated().map { index, found in
            let (message, code) = found
            let minutes = Int(Date.now.timeIntervalSince(message.date) / 60)
            return LauncherResult(id: "codes:\(index)", title: code, subtitle: "\(message.sender) · \(minutes < 1 ? "just now" : "\(minutes) min ago")",
                                  icon: .symbol("lock.shield"), score: 50 - Double(index) / 100, actionTitle: "Copy",
                                  action: { copyToClipboard(code) }, preview: message.text, previewStyle: .prose)
        }
    }
}
