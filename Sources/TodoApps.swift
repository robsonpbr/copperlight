import AppKit

/// The to-do app `[reminders] app` picks, by name.
func todoAppName(_ app: Config.Reminders.App) -> String {
    switch app {
    case .reminders: String(localized: "Reminders", comment: "Apple's Reminders app, by the name macOS gives it")
    case .things: "Things"
    case .ticktick: "TickTick"
    case .todoist: "Todoist"
    }
}

/// Each app's bundle id, to open it and to ask macOS before scripting it.
func todoAppBundleID(_ app: Config.Reminders.App) -> String {
    switch app {
    case .reminders: "com.apple.reminders"
    case .things: "com.culturedcode.ThingsMac"
    case .ticktick: "com.TickTick.task.mac"
    case .todoist: "com.todoist.mac.Todoist"
    }
}

/// A link's query, every value encoded but its letters: `&`, `+` and `#` in a title must reach the app as typed.
private func link(_ base: String, _ items: [(String, String)]) -> URL {
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))
    var parts = URLComponents(string: base)!
    parts.percentEncodedQueryItems = items.map { URLQueryItem(name: $0, value: $1.addingPercentEncoding(withAllowedCharacters: allowed)) }
    return parts.url!
}

/// Things' add link: the title, and `when` as its day ("2026-11-12") or day and time ("2026-11-12@17:05", which Things
/// makes a reminder).
func thingsAddLink(_ title: String, due: CaptureDate?, calendar: Calendar = .current) -> URL {
    var items = [("title", title)]
    if let due {
        let parts = gregorian(calendar).dateComponents([.year, .month, .day, .hour, .minute], from: due.date)
        let day = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        items.append(("when", due.allDay ? day : day + String(format: "@%02d:%02d", parts.hour!, parts.minute!)))
    }
    return link("things:///add", items)
}

/// TickTick's add link: the title only.
// ponytail: no date; its scheme's date parameter isn't documented for the Mac. Add it when someone confirms one.
func tickTickAddLink(_ title: String) -> URL { link("ticktick://x-callback-url/v1/add_task", [("title", title)]) }

/// `add todo …`, in the app `[reminders] app` picks: Reminders into its chosen list, Things and TickTick through their
/// links, Todoist through its API.
@MainActor func addTodo(_ title: String, due: CaptureDate?, todos: Config.Reminders) {
    let name = todoAppName(todos.app)
    let added = { (url: URL, note: String?) in
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else { return notify(String(localized: "\(name) isn't installed")) }
        NSWorkspace.shared.open(url)
        notify(String(localized: "To-do added in \(name)"), [title, note].compactMap(\.self).joined(separator: " · "))
    }
    switch todos.app {
    case .reminders: addReminder(title, due: due, list: todos.addTo)
    case .things: added(thingsAddLink(title, due: due), due.map { whenText($0, end: false) })
    case .ticktick: added(tickTickAddLink(title), due == nil ? nil : String(localized: "without its date", comment: "TickTick's link takes no date"))
    case .todoist: addToTodoist(title, due: due)
    }
}

/// The "Open Things" row at the end of `due`, for any app but Reminders.
func openTodoAppRow(_ app: Config.Reminders.App, title: String? = nil, score: Double) -> LauncherResult {
    let name = todoAppName(app)
    return LauncherResult(id: "builtin:due:open", title: title ?? String(localized: "Open \(name)"), icon: .symbol("checklist"), score: score,
                          actionTitle: String(localized: "Open", comment: "Enter on the row that opens the to-do app"), action: {
        if let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: todoAppBundleID(app)) {
            NSWorkspace.shared.openApplication(at: found, configuration: .init())
        } else if app == .todoist {
            NSWorkspace.shared.open(URL(string: "https://app.todoist.com/app/today")!)
        } else {
            notify(String(localized: "\(name) isn't installed"))
        }
    })
}

/// Prints the open to-dos in Things' Today list (by its id, the same in every language), projects left out, a to-do a
/// record (character 30), its id, title and deadline day a field each (character 31). Each property is read for the
/// whole list at once: a handful of Apple events, however long Today is. Things puts a to-do whose deadline came in Today.
let thingsTodayScript = #"""
const R = String.fromCharCode(30), F = String.fromCharCode(31);
const things = Application("com.culturedcode.ThingsMac");
const today = things.lists.byId("TMTodayListSource").toDos;
const projects = new Set(things.projects.id());
const ids = today.id(), names = today.name(), deadlines = today.dueDate(), states = today.status();
const day = (d) => d ? d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0") : "";
ids.flatMap((id, i) => projects.has(id) || states[i] !== "open" ? [] : [[id, names[i], day(deadlines[i])].join(F)]).join(R);
"""#

/// `thingsTodayScript`'s output as to-dos. In Today, each is for today; a deadline past makes it overdue.
func parseThingsToday(_ output: String, now: Date, calendar: Calendar = .current) -> [ReminderItem] {
    let today = calendar.startOfDay(for: now)
    let days = DateFormatter()
    (days.calendar, days.timeZone, days.locale, days.dateFormat) = (gregorian(calendar), calendar.timeZone, Locale(identifier: "en_US_POSIX"), "yyyy-MM-dd")
    return output.trimmingCharacters(in: .newlines).split(separator: "\u{1E}").compactMap { record in
        let fields = record.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 3, !fields[0].isEmpty else { return nil }
        let due = days.date(from: fields[2]).map { min($0, today) } ?? today
        return ReminderItem(id: fields[0], title: fields[1], due: due, allDay: true, list: "")
    }
}

/// What a look at Things found: its Today list, or why there's none.
enum ThingsLook: Sendable { case due([ReminderItem]), closed, unasked, refused, failed }

/// The Today list the empty launcher shows: what the last look found, while the next one runs behind it, so opening
/// the launcher never waits for Things.
actor ThingsToday {
    static let shared = ThingsToday()
    private var last: [ReminderItem] = []
    private var looking: Task<Void, Never>?

    /// The last look's to-dos; a new look starts unless one is running.
    func lastAndLook(_ look: @escaping @Sendable () async -> ThingsLook) -> [ReminderItem] {
        if looking == nil { looking = Task { keep(await look()) } }
        return last
    }

    func keep(_ look: ThingsLook) {
        looking = nil
        if case .due(let items) = look { last = items } else { last = [] }
    }

    /// A to-do completed here leaves at once.
    func drop(_ id: String) { last.removeAll { $0.id == id } }

    /// Waits for the look running, if any.
    func settle() async { await looking?.value }
}

/// Reads Things' Today list while it's open and Copperlight may control it. Never asks, and never opens Things.
func readThingsToday() async -> ThingsLook {
    let id = todoAppBundleID(.things)
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty else { return .closed }
    switch automationPermission(id, ask: false) {
    case noErr:
        let run = await runTool(URL(filePath: "/usr/bin/osascript"), ["-l", "JavaScript", "-e", thingsTodayScript], timeout: 3)
        return run.succeeded ? .due(parseThingsToday(run.output, now: .now)) : .failed
    case OSStatus(errAEEventWouldRequireUserConsent): return .unasked
    default: return .refused
    }
}

/// Marks the to-do done in Things.
@MainActor func completeInThings(_ id: String) {
    let quoted = String(decoding: try! JSONEncoder().encode(id), as: UTF8.self) // a JavaScript string, whatever's in it
    runDetached("/usr/bin/osascript", ["-l", "JavaScript", "-e", #"Application("com.culturedcode.ThingsMac").toDos.byId(\#(quoted)).status = "completed""#],
                label: String(localized: "Complete in Things"))
    Task { await ThingsToday.shared.drop(id) }
}
