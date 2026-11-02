import AppKit
import EventKit
import Synchronization

/// A reminder with a due date, as the launcher shows it.
struct ReminderItem: Equatable, Sendable {
    var id: String
    var title: String
    var due: Date
    var allDay: Bool // due on a day, with no time
    var list: String
}

extension ReminderItem {
    init?(_ reminder: EKReminder) {
        guard let parts = reminder.dueDateComponents, let due = Calendar.current.date(from: parts) else { return nil }
        let untitled = String(localized: "Untitled", comment: "An event or reminder without a title")
        self.init(id: reminder.calendarItemIdentifier, title: reminder.title ?? untitled, due: due, allDay: parts.hour == nil,
                  list: reminder.calendar?.title ?? "")
    }
}

/// When it has to be done by: its time, or the end of its day.
private func deadline(_ item: ReminderItem, calendar: Calendar) -> Date {
    item.allDay ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: item.due))! : item.due
}

/// What the empty launcher shows: overdue, due within the hour, or due today with no time; the soonest deadline first.
func dueNow(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> [ReminderItem] {
    items.filter { deadline($0, calendar: calendar) <= now + 3600 || ($0.allDay && calendar.isDate($0.due, inSameDayAs: now)) }
        .sorted { deadline($0, calendar: calendar) < deadline($1, calendar: calendar) }
}

/// The copper badge: "Overdue", "in 20 min", or "Today" for a day's reminder.
func reminderBadge(_ item: ReminderItem, now: Date, calendar: Calendar = .current) -> String {
    let end = deadline(item, calendar: calendar)
    if end <= now { return String(localized: "Overdue", comment: "Badge on a reminder past its time") }
    return item.allDay ? String(localized: "Today", comment: "A day: today") : startsIn(item.due, end: end, now: now)
}

/// Incomplete reminders due by the end of today, with full Reminders access (`add todo` asks for it); nil without it.
/// Never asks.
func fetchDueReminders() async -> [ReminderItem]? {
    guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return nil }
    // ponytail: a new store per look, when the launcher opens; keep one if that ever shows.
    let store = EKEventStore()
    let end = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
    return await withCheckedContinuation { done in
        store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)) {
            done.resume(returning: ($0 ?? []).compactMap(ReminderItem.init))
        }
    }
}

@MainActor private func complete(_ id: String) {
    let store = EKEventStore()
    guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
    reminder.isCompleted = true
    do { try store.save(reminder, commit: true) } catch { notify(String(localized: "Couldn't complete the reminder"), error.localizedDescription) }
}

/// Reminders that are due: the empty launcher shows what's overdue, due within the hour or due today with no time,
/// below a meeting about to start and what's running; `due` (or `overdue`, `todos`) lists the rest of today's too.
/// Enter completes one and keeps the launcher open for the next. Reading them needs full Reminders access, which
/// `add todo` asks for, or the row `due` shows; opening the launcher never asks.
struct RemindersProvider: ResultProvider {
    var calendar = Calendar.current
    var fetch: @Sendable () async -> [ReminderItem]? = fetchDueReminders
    /// `[reminders] lists`: only these lists' reminders count; none, all of them.
    var lists: @Sendable () -> [String] = { RemindersProvider.chosenLists.withLock { $0 } }
    static let chosenLists = Mutex<[String]>([])
    /// `[reminders] app`: Things is read instead; TickTick only adds, so Reminders is still read.
    var app: @Sendable () -> Config.Reminders.App = { RemindersProvider.chosenApp.withLock { $0 } }
    static let chosenApp = Mutex(Config.Reminders.App.reminders)
    var lookAtThings: @Sendable () async -> ThingsLook = readThingsToday
    var things = ThingsToday.shared
    var todoistKey: @Sendable () -> String? = { TodoistKey.read() }
    var todoist = TodoistDue.shared
    var send: TodoistSend = urlSessionSend
    /// Types the query again once Todoist answered, so the list shows; opens Settings, for the key.
    var show: @MainActor @Sendable (String) -> Void = { _ in }
    var showSettings: @MainActor @Sendable () -> Void = {}

    /// The reminders that are due, from the lists that count.
    private func due() async -> [ReminderItem]? {
        let names = lists()
        return await fetch().map { items in chosen(items, named: names, name: \.list) ?? items }
    }

    private func row(_ item: ReminderItem, score: Double, now: Date, app: Config.Reminders.App = .reminders) -> LauncherResult {
        let today = String(localized: "Today", comment: "A day: today")
        let when = item.allDay ? (calendar.isDate(item.due, inSameDayAs: now) ? today : item.due.formatted(.dateTime.weekday().day().month()))
            : calendar.isDate(item.due, inSameDayAs: now) ? item.due.formatted(date: .omitted, time: .shortened)
            : item.due.formatted(.dateTime.weekday().day().month().hour().minute())
        let id = item.id
        return LauncherResult(id: "reminder:\(id)", title: item.title, subtitle: [item.list, when].filter { !$0.isEmpty }.joined(separator: " · "),
                              icon: .symbol("checklist"), score: score,
                              actionTitle: String(localized: "Complete", comment: "Enter on a reminder or to-do: marks it done"),
                              action: {
                                  switch app {
                                  case .things: completeInThings(id)
                                  case .todoist: completeInTodoist(id)
                                  case .reminders, .ticktick: complete(id)
                                  }
                              }, staysOpen: true,
                              badge: reminderBadge(item, now: now, calendar: calendar))
    }

    /// For the empty launcher. Nothing without access.
    func upNext(now: Date = .now) async -> [LauncherResult] {
        let app = app()
        let items: [ReminderItem]
        switch app {
        case .things: items = await things.lastAndLook(lookAtThings)
        case .todoist: return [] // asked only on Enter, never when the launcher opens
        case .reminders, .ticktick: items = await due() ?? []
        }
        return dueNow(items, now: now, calendar: calendar).enumerated().map { row($1, score: 99.5 - Double($0) / 100, now: now, app: app) }
    }

    func results(for query: String) async -> [LauncherResult] { await results(for: query, now: .now) }

    func results(for query: String, now: Date) async -> [LauncherResult] {
        guard ["due", "overdue", "todos"].contains(query.lowercased().trimmingCharacters(in: .whitespaces)) else { return [] }
        let app = app()
        if app == .things { return await thingsRows(now: now) }
        if app == .todoist { return await todoistRows(query, now: now) }
        guard let items = await due() else {
            let status = EKEventStore.authorizationStatus(for: .reminder)
            return [status == .denied || status == .restricted
                ? LauncherResult(id: "builtin:due", title: String(localized: "Allow Copperlight to see your reminders"),
                                 subtitle: String(localized: "Privacy & Security → Reminders",
                                                  comment: "System Settings' pages, by the names macOS gives them"),
                                 icon: .symbol("checklist"), score: 50, actionTitle: String(localized: "Open System Settings"), action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
                })
                : LauncherResult(id: "builtin:due", title: String(localized: "See Due Reminders"),
                                 subtitle: String(localized: "Asks to read your reminders, once"), icon: .symbol("checklist"), score: 50,
                                 actionTitle: String(localized: "Allow", comment: "Enter asks macOS for Reminders access"), action: {
                    Task {
                        guard (try? await EKEventStore().requestFullAccessToReminders()) == true else {
                            return notify(String(localized: "Copperlight can't see your reminders"))
                        }
                        notify(String(localized: "Type “due” again to see them"))
                    }
                })]
        }
        let rows = dueRows(items, now: now, app: .reminders)
        return app == .reminders ? rows : rows + [openTodoAppRow(app, score: 50 - Double(rows.count) / 100)]
    }

    /// The to-dos due, soonest first, or a row saying there are none.
    private func dueRows(_ items: [ReminderItem], now: Date, app: Config.Reminders.App) -> [LauncherResult] {
        let due = items.sorted { deadline($0, calendar: calendar) < deadline($1, calendar: calendar) }
        guard !due.isEmpty else {
            return [LauncherResult(id: "builtin:due", title: String(localized: "Nothing due today"),
                                   icon: .symbol("checklist"), score: 50, actionTitle: "", action: {})]
        }
        return due.enumerated().map { row($1, score: 50 - Double($0) / 100, now: now, app: app) }
    }

    /// `due` with Todoist: what Enter on Show fetched in the last minute, or Show. Typing alone never asks Todoist.
    private func todoistRows(_ query: String, now: Date) async -> [LauncherResult] {
        let icon = LauncherResult.Icon.symbol("checklist")
        guard let key = todoistKey() else {
            return [LauncherResult(id: "builtin:due", title: String(localized: "Connect Todoist in Settings"),
                                   subtitle: String(localized: "Settings › Options › To-dos: paste your Todoist key"),
                                   icon: icon, score: 50, actionTitle: String(localized: "Open Settings"), action: showSettings)]
        }
        if let items = await todoist.cached(now: now) {
            let rows = dueRows(items, now: now, app: .todoist)
            return rows + [openTodoAppRow(.todoist, score: 50 - Double(rows.count) / 100)]
        }
        let (todoist, send, show) = (todoist, send, show)
        return [LauncherResult(id: "builtin:due", title: String(localized: "Show What's Due in Todoist"),
                               subtitle: String(localized: "Asks Todoist for today's and overdue tasks"), icon: icon, score: 50,
                               actionTitle: String(localized: "Show", comment: "Enter on due's row: asks Todoist"), action: {
            Task {
                switch await todoist.load(key: key, send: send) {
                case .success: show(query)
                case .failure(let failure): notify(failure.title)
                }
            }
        })]
    }

    /// `due` with Things: its Today list and a row that opens it; asked first, or opened first when it's closed.
    private func thingsRows(now: Date) async -> [LauncherResult] {
        let id = todoAppBundleID(.things)
        let message = { (title: String, subtitle: String, actionTitle: String, action: @escaping @MainActor @Sendable () -> Void) in
            [LauncherResult(id: "builtin:due", title: title, subtitle: subtitle, icon: .symbol("checklist"), score: 50, actionTitle: actionTitle, action: action)]
        }
        let look = await lookAtThings()
        await things.keep(look)
        switch look {
        case .due(let items):
            let rows = dueRows(items, now: now, app: .things)
            return rows + [openTodoAppRow(.things, score: 50 - Double(rows.count) / 100)]
        case .closed: return [openTodoAppRow(.things, title: String(localized: "Open Things to See What's Due"), score: 50)]
        case .failed: return [openTodoAppRow(.things, title: String(localized: "Couldn't read Things"), score: 50)]
        case .unasked:
            return message(String(localized: "See What's Due in Things"), String(localized: "Asks to control Things, once"),
                           String(localized: "Allow", comment: "Enter asks macOS to let Copperlight control Things"), {
                Task.detached {
                    guard automationPermission(id, ask: true) == noErr else { return }
                    await MainActor.run { notify(String(localized: "Type “due” again to see them")) }
                }
            })
        case .refused:
            return message(String(localized: "Allow Copperlight to control Things"),
                           String(localized: "Privacy & Security → Automation", comment: "System Settings' pages, by the names macOS gives them"),
                           String(localized: "Open System Settings"), {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            })
        }
    }
}
