import AppKit
import Security

/// The key from Todoist's settings (Integrations › Developer), kept in this Mac's keychain: never in config.toml.
enum TodoistKey {
    private static func item() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.copperlight.todoist", kSecAttrAccount as String: "key"]
    }

    static func read() -> String? {
        var found: CFTypeRef?
        let query = item().merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { $1 }
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the key as pasted, without the spaces and line breaks around it. false if there's nothing to save.
    @discardableResult static func save(_ typed: String) -> Bool {
        guard let key = cleaned(typed) else { return false }
        forget()
        let added = item().merging([kSecValueData as String: Data(key.utf8),
                                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]) { $1 }
        return SecItemAdd(added as CFDictionary, nil) == errSecSuccess
    }

    static func forget() { SecItemDelete(item() as CFDictionary) }

    static func cleaned(_ typed: String) -> String? {
        let key = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }
}

private let todoistAPI = URL(string: "https://api.todoist.com/api/v1/")!

private func todoistRequest(_ path: String, key: String, method: String = "GET") -> URLRequest {
    var request = URLRequest(url: todoistAPI.appending(path: path), timeoutInterval: 10)
    request.httpMethod = method
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    return request
}

/// Adds a task: the title, and its day (`due_date`) or its time in UTC (`due_datetime`).
func todoistAddRequest(_ title: String, due: CaptureDate?, key: String, calendar: Calendar = .current) -> URLRequest {
    var body = ["content": title]
    if let due, due.allDay {
        let parts = gregorian(calendar).dateComponents([.year, .month, .day], from: due.date)
        body["due_date"] = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    } else if let due {
        body["due_datetime"] = due.date.formatted(.iso8601)
    }
    var request = todoistRequest("tasks", key: key, method: "POST")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
    return request
}

/// Today's tasks and the overdue ones.
// ponytail: one page of 200; follow `next_cursor` if someone has more due than that.
func todoistDueRequest(key: String) -> URLRequest {
    var request = todoistRequest("tasks/filter", key: key)
    request.url?.append(queryItems: [URLQueryItem(name: "query", value: "today | overdue"), URLQueryItem(name: "limit", value: "200")])
    return request
}

func todoistCloseRequest(_ id: String, key: String) -> URLRequest { todoistRequest("tasks/\(id)/close", key: key, method: "POST") }

/// The tasks in a `tasks/filter` answer. A due date is a day ("2026-11-12"), a time in UTC ("…T17:00:00Z"), or a
/// floating time ("…T17:00:00"), which is read in this Mac's time zone. Any other shape: its day, or today.
func parseTodoistTasks(_ data: Data, calendar: Calendar = .current) throws -> [ReminderItem] {
    struct Page: Decodable { var results: [Task] }
    struct Task: Decodable { var id: String; var content: String; var due: Due? }
    struct Due: Decodable { var date: String }
    let local = DateFormatter()
    (local.calendar, local.timeZone, local.locale) = (gregorian(calendar), calendar.timeZone, Locale(identifier: "en_US_POSIX"))
    let date = { (text: String) -> (Date, Bool) in
        if let utc = try? Date(text, strategy: .iso8601) { return (utc, false) }
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if text.count > 10, let floating = local.date(from: text) { return (floating, false) }
        local.dateFormat = "yyyy-MM-dd"
        return (local.date(from: String(text.prefix(10))) ?? calendar.startOfDay(for: .now), true)
    }
    return try JSONDecoder().decode(Page.self, from: data).results.compactMap { task in
        guard let (due, allDay) = task.due.map({ date($0.date) }) else { return nil } // "today | overdue" are all due
        return ReminderItem(id: task.id, title: task.content, due: due, allDay: allDay, list: "")
    }
}

typealias TodoistSend = @Sendable (URLRequest) async throws -> (Data, URLResponse)
/// Todoist's requests carry the key, and its answers your tasks: a session that keeps neither on disk.
let todoistSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
}()
let urlSessionSend: TodoistSend = { try await todoistSession.data(for: $0) }

/// Why Todoist gave nothing, as a row or a notification says it.
enum TodoistFailure: Error, Equatable {
    case rejected, offline, server

    var title: String {
        switch self {
        case .rejected: String(localized: "Todoist didn't accept the key")
        case .offline: String(localized: "Couldn't reach Todoist")
        case .server: String(localized: "Todoist didn't answer")
        }
    }
}

/// Sends `request`, and says what failed.
func todoistSend(_ request: URLRequest, send: TodoistSend) async -> Result<Data, TodoistFailure> {
    guard let (data, response) = try? await send(request) else { return .failure(.offline) }
    switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
    case 200..<300: return .success(data)
    case 401, 403: return .failure(.rejected)
    default: return .failure(.server)
    }
}

/// What's due in Todoist, kept a minute after Enter on Show asked for it, so `due` again shows it at once.
actor TodoistDue {
    static let shared = TodoistDue()
    private var last: (items: [ReminderItem], at: Date)?

    func cached(now: Date = .now) -> [ReminderItem]? {
        last.flatMap { now.timeIntervalSince($0.at) < 60 ? $0.items : nil }
    }

    func load(key: String, send: TodoistSend) async -> Result<[ReminderItem], TodoistFailure> {
        let answer = await todoistSend(todoistDueRequest(key: key), send: send)
        guard case .success(let data) = answer else { return answer.map { _ in [] } }
        guard let items = try? parseTodoistTasks(data) else { return .failure(.server) }
        last = (items, .now)
        return .success(items)
    }

    /// Adds a to-do; once Todoist has it, the list is forgotten, so `due` asks again and shows it.
    func add(_ title: String, due: CaptureDate?, key: String, send: TodoistSend) async -> Result<Data, TodoistFailure> {
        let answer = await todoistSend(todoistAddRequest(title, due: due, key: key), send: send)
        if case .success = answer { last = nil }
        return answer
    }

    /// A task completed here leaves the list at once.
    func drop(_ id: String) { last?.items.removeAll { $0.id == id } }
}

/// `add todo …` with Todoist: sends it, then says so.
@MainActor func addToTodoist(_ title: String, due: CaptureDate?) {
    guard let key = TodoistKey.read() else {
        return notify(String(localized: "Connect Todoist in Settings"),
                      String(localized: "Settings › Options › To-dos", comment: "Copperlight's Settings pages"))
    }
    Task {
        switch await TodoistDue.shared.add(title, due: due, key: key, send: urlSessionSend) {
        case .success:
            notify(String(localized: "To-do added in Todoist"), [title, due.map { whenText($0, end: false) }].compactMap(\.self).joined(separator: " · "))
        case .failure(let failure): notify(failure.title, String(localized: "Not added: \(title)")) // what you typed, not lost
        }
    }
}

/// Enter on a Todoist task: completes it there.
@MainActor func completeInTodoist(_ id: String) {
    guard let key = TodoistKey.read() else {
        return notify(String(localized: "Connect Todoist in Settings"),
                      String(localized: "Settings › Options › To-dos", comment: "Copperlight's Settings pages"))
    }
    Task {
        switch await todoistSend(todoistCloseRequest(id, key: key), send: urlSessionSend) {
        case .success: await TodoistDue.shared.drop(id)
        case .failure(let failure): notify(failure.title)
        }
    }
}
