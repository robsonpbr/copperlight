import AppKit

/// What an "Open Calendar" row shows: a day (meetings, `free`), a week or a month.
enum CalendarSpan: String { case day, week, month }

/// A Gregorian calendar in `calendar`'s time zone: dates other apps read and write are Gregorian, whatever this Mac
/// uses (a Thai Mac's year 2569 is 2026).
func gregorian(_ calendar: Calendar) -> Calendar {
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    return gregorian
}

/// The parts of `date` a calendar's address takes: the month's first day for a month.
private func dayPath(_ span: CalendarSpan, _ date: Date, _ calendar: Calendar) -> String {
    let parts = gregorian(calendar).dateComponents([.year, .month, .day], from: date)
    return "\(parts.year!)/\(parts.month!)/\(span == .month ? 1 : parts.day!)"
}

/// Google Calendar on that day, week or month, in the browser's first Google account.
// ponytail: the first account; `authuser` when someone with two accounts asks.
func googleCalendarLink(_ span: CalendarSpan, _ date: Date, calendar: Calendar = .current) -> URL {
    URL(string: "https://calendar.google.com/calendar/r/\(span.rawValue)/\(dayPath(span, date, calendar))")!
}

/// Outlook on the web on that day, week or month.
func outlookCalendarLink(_ span: CalendarSpan, _ date: Date, calendar: Calendar = .current) -> URL {
    URL(string: "https://outlook.office.com/calendar/view/\(span.rawValue)/\(dayPath(span, date, calendar))")!
}

/// The calendar `[meetings] open_in` picks, by name.
func calendarAppName(_ app: Config.Meetings.OpenIn) -> String {
    switch app {
    case .calendar: String(localized: "Calendar", comment: "Apple's Calendar app, by the name macOS gives it")
    case .google: "Google Calendar"
    case .outlook: "Outlook"
    }
}

/// What Enter on an "Open Calendar" row says.
func calendarActionTitle(_ app: Config.Meetings.OpenIn) -> String {
    String(localized: "Open \(calendarAppName(app))", comment: "Enter on a calendar row: the calendar app's name")
}

/// Opens the calendar `[meetings] open_in` picks: Calendar as it is, Google Calendar on that day in the browser links
/// open in, the Outlook app (it can't be sent to a day), or Outlook on the web without it.
func calendarOpener(_ app: Config.Meetings.OpenIn, _ span: CalendarSpan, _ date: Date, browser: Config.Browser) -> @MainActor @Sendable () -> Void {
    switch app {
    case .calendar: return openCalendar
    case .google: return webOpener(googleCalendarLink(span, date), browser: browser)
    case .outlook:
        let web = webOpener(outlookCalendarLink(span, date), browser: browser)
        return {
            guard let outlook = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Outlook") else { return web() }
            NSWorkspace.shared.openApplication(at: outlook, configuration: .init())
        }
    }
}

@MainActor func openCalendar() {
    NSWorkspace.shared.openApplication(at: URL(filePath: "/System/Applications/Calendar.app"), configuration: .init())
}

/// Names for a picker: each once (two accounts may both have a "Calendar"), sorted.
func pickerNames(_ names: [String]) -> [String] { Array(Set(names)).sorted() }

/// What a picker shows for `name`: nil (Default) when it's gone, since things go to the default then.
func pickerChoice(_ name: String?, among names: [String]) -> String? { name.flatMap { names.contains($0) ? $0 : nil } }

/// The calendar or list named `name` in Settings; nil when unset or gone, for the Mac's default.
func chosenCalendar<C>(_ all: [C], named name: String?, title: KeyPath<C, String>) -> C? {
    name.flatMap { name in all.first { $0[keyPath: title] == name } }
}
