import AppKit
import EventKit

/// The first video call link in an event's URL, location or notes: Google Meet, Zoom, Teams or Webex.
func joinLink(in texts: [String?]) -> URL? {
    let pattern = #/https://(?:meet\.google\.com/[a-z0-9-]+|[\w.-]*zoom\.us/(?:j|my|w)/[^\s<>"]+|teams\.microsoft\.com/l/meetup-join/[^\s<>"]+|[\w.-]*webex\.com/[^\s<>"]+)/#
    for text in texts.compactMap(\.self) {
        if let match = text.firstMatch(of: pattern.ignoresCase()) { return URL(string: String(match.output)) }
    }
    return nil
}

/// "in 15 min", "now", "in 2 h 5 min": how soon a meeting starts.
func startsIn(_ start: Date, end: Date, now: Date = .now) -> String {
    if start <= now {
        return end > now ? String(localized: "now", comment: "A meeting going on, where how soon it starts goes")
            : String(localized: "ended", comment: "A meeting over")
    }
    let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
    return minutes < 60 ? String(localized: "in \(minutes) min") : minutes % 60 == 0 ? String(localized: "in \(minutes / 60) h")
        : String(localized: "in \(minutes / 60) h \(minutes % 60) min")
}

/// An event, as the launcher shows it.
struct CalendarItem: Sendable {
    var title: String
    var start: Date
    var end: Date
    var link: URL?
    var calendar = ""
    var location: String?
    var notes: String?
    var people: [String] = []
    var organizer: String?
    var allDay = false
    var id = ""
    var busy = true // false for an event shown as free
}

extension CalendarItem {
    init(_ event: EKEvent) {
        let untitled = String(localized: "Untitled", comment: "An event or reminder without a title")
        self.init(title: event.title ?? untitled, start: event.startDate, end: event.endDate,
                  link: joinLink(in: [event.url?.absoluteString, event.location, event.notes]), calendar: event.calendar?.title ?? "",
                  location: event.location, notes: event.notes, people: (event.attendees ?? []).compactMap(\.name),
                  organizer: event.organizer?.name, allDay: event.isAllDay, id: event.eventIdentifier ?? "", busy: event.availability != .free)
    }
}

/// The week `now` is in (from the first weekday where you are), or the one after.
func weekInterval(now: Date = .now, calendar: Calendar = .current, next: Bool = false) -> DateInterval {
    let week = calendar.dateInterval(of: .weekOfYear, for: now)!
    let start = next ? week.end : week.start
    return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
}

/// `week`, at a glance: each day's events, all day first and then by time, at most 5 (and how many more); today and
/// the days and events already over marked. An event over midnight shows on both days ("until 6:00").
func weekCard(_ items: [CalendarItem], now: Date = .now, calendar: Calendar = .current, next: Bool = false) -> WeekCard {
    let week = weekInterval(now: now, calendar: calendar, next: next)
    let hours = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: calendar.timeZone)
    var range = Date.IntervalFormatStyle.interval.month(.abbreviated).day() // "Oct 26 – Nov 1", "Nov 2 – 8"
    range.timeZone = calendar.timeZone
    let days = (0..<7).map { offset in
        let start = calendar.date(byAdding: .day, value: offset, to: week.start)!, end = calendar.date(byAdding: .day, value: 1, to: start)!
        let mine = items.filter { $0.start < end && $0.end > start }.sorted { ($0.allDay ? 0 : 1, $0.start) < ($1.allDay ? 0 : 1, $1.start) }
        let events = mine.prefix(5).map { item in
            WeekCard.Event(time: item.allDay ? String(localized: "All day") : item.start < start
                               ? String(localized: "until \(item.end.formatted(hours))", comment: "An event from the day before: the time it ends")
                               : item.start.formatted(hours),
                           title: item.title, past: item.end <= now)
        }
        return WeekCard.Day(name: calendar.shortWeekdaySymbols[calendar.component(.weekday, from: start) - 1],
                            number: "\(calendar.component(.day, from: start))", today: start <= now && now < end, past: end <= now,
                            events: events, more: mine.count - events.count)
    }
    let last = calendar.date(byAdding: .day, value: 6, to: week.start)!
    // A repeating event's occurrences share an id: one event is an id and a start.
    let count = Set(items.filter { $0.start < week.end && $0.end > week.start }.map { "\($0.id)@\($0.start.timeIntervalSince1970)" }).count
    return WeekCard(kicker: next ? String(localized: "Next week") : String(localized: "This week"), range: (week.start..<last).formatted(range), count: count,
                    days: days)
}

/// The month `now` is in, or the one after.
func monthInterval(now: Date = .now, calendar: Calendar = .current, next: Bool = false) -> DateInterval {
    let month = calendar.dateInterval(of: .month, for: now)!
    return next ? calendar.dateInterval(of: .month, for: month.end)! : month
}

/// The whole weeks a month's grid shows: from the week its 1st is in to the week its last day is in.
func monthGrid(_ month: DateInterval, calendar: Calendar = .current) -> DateInterval {
    DateInterval(start: calendar.dateInterval(of: .weekOfYear, for: month.start)!.start,
                 end: calendar.dateInterval(of: .weekOfYear, for: month.end - 1)!.end)
}

/// `month`, at a glance: the grid's days with how many events each has, today and the days already over marked, and
/// the days of the months around it apart. The count is the month's own events.
func monthCard(_ items: [CalendarItem], now: Date = .now, calendar: Calendar = .current, next: Bool = false) -> MonthCard {
    let month = monthInterval(now: now, calendar: calendar, next: next), grid = monthGrid(month, calendar: calendar)
    let length = calendar.dateComponents([.day], from: grid.start, to: grid.end).day! // 28 to 42, whatever the clocks do
    let days = (0..<length).map { offset in
        let start = calendar.date(byAdding: .day, value: offset, to: grid.start)!, end = calendar.date(byAdding: .day, value: 1, to: start)!
        return MonthCard.Day(number: "\(calendar.component(.day, from: start))", inMonth: month.start <= start && start < month.end,
                             today: start <= now && now < end, past: end <= now, events: items.filter { $0.start < end && $0.end > start }.count)
    }
    let weekdays = (0..<7).map { calendar.shortWeekdaySymbols[(calendar.firstWeekday - 1 + $0) % 7] }
    let name = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone).month(.wide).year()
    // A repeating event's occurrences share an id: one event is an id and a start.
    let count = Set(items.filter { $0.start < month.end && $0.end > month.start }.map { "\($0.id)@\($0.start.timeIntervalSince1970)" }).count
    return MonthCard(kicker: next ? String(localized: "Next month") : String(localized: "This month"), range: month.start.formatted(name),
                     count: count, weekdays: weekdays,
                     weeks: stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) })
}

/// The meeting the empty launcher offers: one with a call to join, starting in the next 10 minutes or started in the
/// last 10 and not over; the one about to start before one already going.
/// The free time on `days` within working hours (9 to 18), at least `minimum` long, outside `busy` (overlaps and all),
/// and from `now` on, at the next quarter hour.
func freeSlots(busy: [DateInterval], days: [Date], hours: Range<Int> = 9..<18, minimum: TimeInterval = 1800, now: Date = .now,
               calendar: Calendar = .current) -> [DateInterval] {
    let quarter = (now.timeIntervalSinceReferenceDate / 900).rounded(.up) * 900
    let busy = busy.sorted { $0.start < $1.start }
    return days.flatMap { day -> [DateInterval] in
        guard let open = calendar.date(bySettingHour: hours.lowerBound, minute: 0, second: 0, of: day),
              let close = calendar.date(bySettingHour: hours.upperBound, minute: 0, second: 0, of: day) else { return [] }
        var cursor = max(open, Date(timeIntervalSinceReferenceDate: quarter))
        var free: [DateInterval] = []
        for event in busy where event.end > cursor && event.start < close {
            if event.start.timeIntervalSince(cursor) >= minimum { free.append(DateInterval(start: cursor, end: event.start)) }
            cursor = max(cursor, event.end)
        }
        if close.timeIntervalSince(cursor) >= minimum { free.append(DateInterval(start: cursor, end: close)) }
        return free
    }
}

/// The days `free …` asks about, at their start: `free` (today if its working hours aren't over, else the next
/// workday), `free today`, `free tomorrow`, `free monday` (today, if it's Monday), `free this week` (the workdays left),
/// `free next week`. nil for anything else.
func freeDays(_ query: String, now: Date = .now, calendar: Calendar = .current, hours: Range<Int> = 9..<18) -> (label: String, days: [Date])? {
    let words = query.lowercased().split(separator: " ").map(String.init)
    guard words.first == "free", words.count <= 3 else { return nil }
    let today = calendar.startOfDay(for: now)
    let day = { (offset: Int) in calendar.date(byAdding: .day, value: offset, to: today)! }
    let workday = { (date: Date) in !calendar.isDateInWeekend(date) }
    let rest = words.dropFirst().joined(separator: " ")
    let (todayName, tomorrowName) = (String(localized: "Today", comment: "A day: today"), String(localized: "Tomorrow", comment: "A day: tomorrow"))
    switch rest {
    case "":
        let over = calendar.component(.hour, from: now) >= hours.upperBound || !workday(today)
        let first = ((over ? 1 : 0)...).lazy.map(day).first(where: workday)!
        return (calendar.isDateInToday(first) ? todayName : calendar.isDateInTomorrow(first) ? tomorrowName : first.formatted(.dateTime.weekday(.wide)), [first])
    case "today": return (todayName, [today])
    case "tomorrow": return (tomorrowName, [day(1)])
    case "week", "this week", "next week":
        let week = calendar.dateInterval(of: .weekOfYear, for: rest == "next week" ? day(7) : today)!
        let days = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: week.start)! }.filter { workday($0) && $0 >= today }
        return (rest == "next week" ? String(localized: "Next week") : String(localized: "This week"), days)
    default:
        // In English, and in the Mac's language (sexta-feira): Sunday first.
        var english = Calendar(identifier: .gregorian)
        english.locale = Locale(identifier: "en_US_POSIX")
        let names = [english.weekdaySymbols, calendar.weekdaySymbols].map { $0.map { $0.lowercased() } }
        guard let weekday = names.lazy.compactMap({ $0.firstIndex(of: rest) }).first else { return nil }
        let first = (0..<7).map(day).first { calendar.component(.weekday, from: $0) == weekday + 1 }!
        return (calendar.weekdaySymbols[weekday], [first])
    }
}

/// Free slots as text to paste in a message, a line a day: "Wed, Nov 4: 9:00 – 10:00 AM, 1:00 – 5:40 PM".
func freeText(_ slots: [DateInterval], calendar: Calendar = .current) -> String {
    let locale = calendar.locale ?? .current
    let dayStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated).month(.abbreviated).day()
    let hours = Date.IntervalFormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    let days = Dictionary(grouping: slots) { calendar.startOfDay(for: $0.start) }
    return days.keys.sorted().map { day in
        day.formatted(dayStyle) + ": " + days[day]!.map { ($0.start..<$0.end).formatted(hours) }.joined(separator: ", ")
    }.joined(separator: "\n")
}

/// The ones of `all` named in `names` (any case), or nil, meaning all, when `names` is empty.
func chosen<Item>(_ all: [Item], named names: [String], name: (Item) -> String = { "\($0)" }) -> [Item]? {
    guard !names.isEmpty else { return nil }
    let wanted = Set(names.map { $0.lowercased() })
    return all.filter { wanted.contains(name($0).lowercased()) }
}

func nextMeeting(_ items: [CalendarItem], now: Date = .now, headsUp: TimeInterval = 10 * 60) -> CalendarItem? {
    let joinable = items.filter { item in
        let ahead = item.start.timeIntervalSince(now) // negative once it's started
        return item.link != nil && item.end > now && ahead <= headsUp && ahead >= -10 * 60
    }
    let upcoming = joinable.filter { $0.start > now }.min { $0.start < $1.start }
    return upcoming ?? joinable.max { $0.start < $1.start }
}

/// The copper badge beside an event that's coming up (within the hour: "in 17 min") or going ("Now"); nil otherwise.
func eventBadge(_ item: CalendarItem, now: Date = .now) -> String? {
    if item.start <= now { return item.end > now ? String(localized: "Now", comment: "Badge on an event going on") : nil }
    return item.start.timeIntervalSince(now) <= 60 * 60 ? startsIn(item.start, end: item.end, now: now) : nil
}

/// The call's service, by its link: "Google Meet", "Zoom", "Teams", "Webex".
func callService(_ link: URL) -> String {
    let host = link.host() ?? ""
    return host.contains("google") ? "Google Meet" : host.contains("zoom") ? "Zoom" : host.contains("teams") ? "Teams" : host.contains("webex") ? "Webex"
        : String(localized: "Call", comment: "A video call on a service not known")
}

/// What Tab shows beside an event: its title, day and times and notes, and under them its calendar, place, call (and
/// link), who's coming and who asked.
func eventPreview(_ item: CalendarItem, now: Date = .now) -> (text: String, details: [(String, String)]) {
    let hours = { (date: Date) in date.formatted(date: .omitted, time: .shortened) }
    let day = Calendar.current.isDate(item.start, inSameDayAs: now) ? String(localized: "Today", comment: "A day: today")
        : item.start.formatted(.dateTime.weekday(.wide).day().month())
    let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(3000) ?? ""
    let text = "\(item.title)\n\(day), \(hours(item.start))–\(hours(item.end))" + (notes.isEmpty ? "" : "\n\n\(notes)")
    let place = item.location.flatMap { location in
        location.isEmpty || item.link.map({ location.contains($0.absoluteString) }) == true ? nil : location
    }
    let people = item.people.isEmpty ? nil
        : item.people.prefix(4).joined(separator: ", ") + (item.people.count > 4 ? " +\(item.people.count - 4)" : "")
    let details: [(String, String?)] = [(String(localized: "Calendar", comment: "Label: the event's calendar"),
                                         item.calendar.isEmpty ? nil : item.calendar),
                                        (String(localized: "Where", comment: "Label: the event's place"), place),
                                        (String(localized: "Call", comment: "Label: the event's video call service"), item.link.map(callService)),
                                        (String(localized: "Link", comment: "Label: the event's call link"), item.link?.absoluteString),
                                        (String(localized: "People", comment: "Label: who's coming"), people),
                                        (String(localized: "Organizer", comment: "Label: who asked"), item.organizer)]
    return (text, details.compactMap { label, value in value.map { (label, $0) } })
}

/// The first line of an event's own notes, before any call's invitation (a divider, a link, "Join …"). nil: none.
func eventNote(_ notes: String?) -> String? {
    for line in (notes ?? "").split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }) {
        if line.contains("://") || line.contains(#/^[^\p{L}\d\s]{5,}/#) || line.contains(#/(?i)^(join|microsoft teams|or dial|meeting id)\b/#) {
            return nil
        }
        if line.contains(where: \.isLetter) { return String(line.prefix(80)) }
    }
    return nil
}

/// The meeting to join now on a band (how soon, its title, times and call, who's coming, a line of its notes), and
/// its rows under it: Join, then Open in Calendar (or the calendar `[meetings] open_in` picks).
func joinRows(_ item: CalendarItem, now: Date = .now, browser: Config.Browser, openIn: Config.Meetings.OpenIn = .calendar,
              score: Double) -> [LauncherResult] {
    let open = calendarOpener(openIn, .day, item.start, browser: browser)
    let hours = { (date: Date) in date.formatted(date: .omitted, time: .shortened) }
    let service = item.link.map(callService)
    let people = item.people.prefix(4).map { String($0.split(separator: "@").first ?? "") } // an address alone: its name part
    let card = MeetingCard(soon: eventBadge(item, now: now) ?? startsIn(item.start, end: item.end, now: now), calendar: item.calendar,
                           title: item.title, when: "\(hours(item.start))–\(hours(item.end))" + (service.map { " · \($0)" } ?? ""),
                           initials: people.map(initials),
                           names: people.map { String($0.split(separator: " ").first ?? "") }.joined(separator: ", ")
                               + (item.people.count > 4 ? " +\(item.people.count - 4)" : ""),
                           note: eventNote(item.notes))
    let join = String(localized: "Join", comment: "Enter on a meeting: opens its video call")
    let title = service.map { String(localized: "Join \($0)", comment: "The call's service: Google Meet, Zoom…") } ?? String(localized: "Join Call")
    return [LauncherResult(id: "meeting:\(item.id)", title: title,
                           subtitle: item.link.map { ($0.host() ?? "") + $0.path() } ?? "", icon: .symbol("video"), score: score,
                           actionTitle: join, action: item.link.map { webOpener($0, browser: browser) } ?? open, answer: .meeting(card)),
            LauncherResult(id: "meeting:\(item.id):calendar",
                           title: String(localized: "Open in \(calendarAppName(openIn))", comment: "The calendar app's name"),
                           icon: .symbol("calendar"), score: score - 0.001,
                           actionTitle: String(localized: "Open", comment: "Enter on Open in Calendar"), action: open, answer: .meeting(card))]
}

/// `meetings`, `agenda`, `events` (and `calendar`, below the Calendar app): the rest of today's events from Calendar,
/// all-day ones aside, soonest first, a copper badge on one that's soon or going, its details a Tab away. Enter joins a
/// video call (Meet, Zoom, Teams, Webex), opening web links where `[browser]` says; otherwise it opens Calendar. Reading
/// events needs full Calendars access, asked for from a row, not while typing. The meeting to join now (`nextMeeting`)
/// comes first, on its band. The empty launcher shows it (`upNext`), or with `[meetings] show_on_open`, the day's events.
actor MeetingsProvider: ResultProvider {
    private var store: EKEventStore? // made once access is granted: one made before it sees no events
    private var browser = Config.Browser()
    private var options = Config.Meetings()
    private var showsOnOpen: Bool { options.showOnOpen }
    private var showsNext: Bool { options.showNext }

    func setBrowser(_ browser: Config.Browser) { self.browser = browser }
    func setOptions(_ options: Config.Meetings) { self.options = options }
    private var headsUp: TimeInterval { TimeInterval(options.headsUp * 60) }

    /// `[meetings] calendars`, or all of them (nil).
    private func calendars(_ store: EKEventStore) -> [EKCalendar]? {
        chosen(store.calendars(for: .event), named: options.calendars, name: \.title)
    }

    /// The events left today, and the ones started in the last 10 minutes (still worth joining). Only with access.
    private func today(now: Date) -> [CalendarItem]? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let store = self.store ?? EKEventStore()
        self.store = store
        let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        return store.events(matching: store.predicateForEvents(withStart: now - 600, end: endOfDay, calendars: calendars(store)))
            .filter { !$0.isAllDay && $0.endDate > now }.sorted { $0.startDate < $1.startDate }.map(CalendarItem.init)
    }

    /// Every event in `interval`, all-day ones too. Only with access.
    private func events(in interval: DateInterval) -> [CalendarItem] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let store = self.store ?? EKEventStore()
        self.store = store
        return store.events(matching: store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars(store))).map(CalendarItem.init)
    }

    private func row(_ item: CalendarItem, score: Double, now: Date) -> LauncherResult {
        let hours = { (date: Date) in date.formatted(date: .omitted, time: .shortened) }
        let badge = eventBadge(item, now: now)
        let preview = eventPreview(item, now: now)
        return LauncherResult(
            id: "meeting:\(item.id)", title: item.title,
            subtitle: "\(hours(item.start))–\(hours(item.end))" + (badge == nil ? " · \(startsIn(item.start, end: item.end, now: now))" : "")
                + (item.link.map { " · \(callService($0))" } ?? ""),
            icon: .symbol(item.link == nil ? "calendar" : "video"), score: score,
            actionTitle: item.link == nil ? calendarActionTitle(options.openIn)
                : String(localized: "Join", comment: "Enter on a meeting: opens its video call"),
            action: item.link.map { webOpener($0, browser: browser) } ?? calendarOpener(options.openIn, .day, item.start, browser: browser),
            badge: badge, preview: preview.text, previewStyle: .prose, details: preview.details)
    }

    /// The meeting to join now on its band, then the other events.
    private func rows(_ items: [CalendarItem], base: Double, now: Date) -> [LauncherResult] {
        guard let next = nextMeeting(items, now: now, headsUp: headsUp) else { return items.enumerated().map { row($1, score: base - Double($0) / 100, now: now) } }
        let others = items.filter { $0.id != next.id || $0.start != next.start }
        return joinRows(next, now: now, browser: browser, openIn: options.openIn, score: base) + others.enumerated().map { row($1, score: base - Double($0 + 1) / 100, now: now) }
    }

    /// For the empty launcher: the meeting to join now, if any; with `show_on_open`, the day's next events. Never asks
    /// for access: opening the launcher shouldn't.
    func upNext() -> [LauncherResult] {
        let now = Date.now
        guard showsOnOpen || showsNext, let items = today(now: now) else { return [] }
        if showsOnOpen { return rows(Array(items.prefix(5)), base: 100, now: now) }
        return nextMeeting(items, now: now, headsUp: headsUp).map { joinRows($0, now: now, browser: browser, openIn: options.openIn, score: 100) } ?? []
    }

    /// The meeting to join now, as its Join row (what Enter does after `camera`); nil without one. Never asks for access.
    func joinable() -> LauncherResult? {
        let now = Date.now
        return today(now: now).flatMap { nextMeeting($0, now: now, headsUp: headsUp) }.map { joinRows($0, now: now, browser: browser, openIn: options.openIn, score: 100)[0] }
    }

    func results(for query: String) async -> [LauncherResult] {
        let lower = query.lowercased()
        let base: Double
        let week: Bool? = lower == "next week" ? true : lower == "this week" || lower.count >= 3 && "week".hasPrefix(lower) ? false : nil
        let month: Bool? = lower == "next month" ? true : lower == "this month" || lower.count >= 4 && "month".hasPrefix(lower) ? false : nil
        let span = week != nil ? "week" : month != nil ? "month" : nil // the card asked for, if any
        let free = freeDays(query, hours: options.workHours)
        if span != nil { base = 50 }
        else if free != nil { base = lower == "free" ? 1 : 50 } // alone, under the apps it starts (Freeform)
        else if lower.count >= 3, "meetings".hasPrefix(lower) || "agenda".hasPrefix(lower) { base = 50 }
        else if lower == "event" || lower == "events" { base = 50 }
        else if lower == "calendar" { base = 1 } // the app first: it's what "calendar" opens
        else { return [] }
        let message = { (title: String, subtitle: String, actionTitle: String, action: @escaping @MainActor @Sendable () -> Void) in
            LauncherResult(id: free != nil ? "builtin:free" : span.map { "builtin:\($0)" } ?? "builtin:meetings", title: title, subtitle: subtitle, icon: .symbol("calendar"),
                           score: base, actionTitle: actionTitle, action: action)
        }
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: break
        case .denied, .restricted:
            return [message(String(localized: "Allow Copperlight to see your calendars"),
                            String(localized: "Privacy & Security → Calendars → Copperlight: Full Access",
                                   comment: "System Settings' pages, by the names macOS gives them"),
                            String(localized: "Open System Settings"), {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            })]
        default: // not asked yet, or add-only (for `add event`)
            let asked = free != nil ? String(localized: "See When You're Free")
                : span.map { $0 == "week" ? String(localized: "See Your Week") : String(localized: "See Your Month") }
                ?? String(localized: "See Today's Meetings")
            return [message(asked, String(localized: "Asks to read your calendars, once"),
                            String(localized: "Allow", comment: "Enter asks macOS for Calendars access"), {
                Task {
                    guard (try? await EKEventStore().requestFullAccessToEvents()) == true else {
                        return notify(String(localized: "Copperlight can't see your calendars"))
                    }
                    notify(free != nil ? String(localized: "Type “\(lower)” again to see it", comment: "What was typed")
                           : span.map { String(localized: "Type “\($0)” again to see it", comment: "What was typed") }
                           ?? String(localized: "Type “meetings” again to see them"))
                }
            })]
        }
        let now = Date.now
        if let free {
            let busy = free.days.first.map { first in
                events(in: DateInterval(start: first, end: free.days.last!.addingTimeInterval(86_400)))
                    .filter { $0.busy && !$0.allDay }.map { DateInterval(start: $0.start, end: max($0.start, $0.end)) }
            } ?? []
            return freeRows(freeSlots(busy: busy, days: free.days, hours: options.workHours, now: now), days: free.days, label: free.label, hours: options.workHours, base: base,
                            open: (calendarActionTitle(options.openIn), calendarOpener(options.openIn, .day, free.days.first ?? now, browser: browser)))
        }
        if let next = month {
            let card = monthCard(events(in: monthGrid(monthInterval(now: now, next: next))), now: now, next: next)
            let total = card.count == 1 ? String(localized: "1 event") : String(localized: "\(card.count) events")
            return [LauncherResult(id: "builtin:month", title: "\(card.range): \(total)",
                                   subtitle: card.kicker, icon: .symbol("calendar"), score: base, actionTitle: calendarActionTitle(options.openIn),
                                   action: calendarOpener(options.openIn, .month, monthInterval(now: now, next: next).start, browser: browser),
                                   answer: .month(card))]
        }
        if let next = week {
            let card = weekCard(events(in: weekInterval(now: now, next: next)), now: now, next: next)
            let total = card.count == 1 ? String(localized: "1 event") : String(localized: "\(card.count) events")
            return [LauncherResult(id: "builtin:week", title: "\(card.kicker): \(total)",
                                   subtitle: card.range, icon: .symbol("calendar"), score: base, actionTitle: calendarActionTitle(options.openIn),
                                   action: calendarOpener(options.openIn, .week, weekInterval(now: now, next: next).start, browser: browser),
                                   answer: .week(card))]
        }
        let items = today(now: now) ?? []
        guard !items.isEmpty else {
            return [message(String(localized: "No more meetings today"), "", calendarActionTitle(options.openIn),
                            calendarOpener(options.openIn, .day, now, browser: browser))]
        }
        return rows(items, base: base, now: now)
    }
}

/// `free tomorrow`: all of it to copy first, then a row a slot, each copied as "Wed, Nov 4, 9:00 – 10:00 AM".
func freeRows(_ slots: [DateInterval], days: [Date], label: String, hours: Range<Int>, base: Double,
              open: (title: String, action: @MainActor @Sendable () -> Void), calendar: Calendar = .current) -> [LauncherResult] {
    let icon = LauncherResult.Icon.symbol("calendar.badge.checkmark")
    guard !days.isEmpty else { // `free this week` on a weekend
        return [LauncherResult(id: "builtin:free", title: String(localized: "No workdays left this week"),
                               subtitle: String(localized: "Enter shows next week's free time"), icon: icon, score: base,
                               actionTitle: String(localized: "Next Week", comment: "Enter on 'No workdays left this week': free next week"),
                               action: {}, completion: "free next week")]
    }
    // In a sentence: "today", "next week", but "Friday" as written.
    let label = calendar.weekdaySymbols.contains(label) ? label : label.lowercased()
    guard !slots.isEmpty else {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone)
        let clock = { (hour: Int) in calendar.date(bySettingHour: hour % 24, minute: 0, second: 0, of: days[0])!.formatted(style) }
        return [LauncherResult(id: "builtin:free",
                               title: String(localized: "No free time \(label)", comment: "A day: today, tomorrow, Monday, next week"),
                               subtitle: String(localized: "Between \(clock(hours.lowerBound)) and \(clock(hours.upperBound)), 30 minutes or more"),
                               icon: icon, score: base, actionTitle: open.title, action: open.action)]
    }
    let all = freeText(slots)
    let lengths = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .narrow)
    let count = slots.count == 1 ? String(localized: "1 slot") : String(localized: "\(slots.count) slots")
    let whole = LauncherResult(id: "builtin:free",
                               title: String(localized: "Free \(label): \(count)", comment: "A day (today, next week), then 3 slots"),
                               subtitle: all.replacing("\n", with: " · "), icon: icon, score: base,
                               actionTitle: String(localized: "Copy All", comment: "Enter on free's first row: copies every slot"),
                               action: { copyToClipboard(all) }, preview: all, previewStyle: .prose)
    return [whole] + slots.enumerated().map { index, slot in
        let text = freeText([slot]).replacing(": ", with: ", ", maxReplacements: 1)
        return LauncherResult(id: "free:\(index)", title: (slot.start..<slot.end).formatted(.interval.hour().minute()),
                              subtitle: slot.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) + " · "
                                  + Duration.seconds(slot.duration).formatted(lengths),
                              icon: icon, score: base - Double(index + 1) / 100,
                              actionTitle: String(localized: "Copy", comment: "Enter on a free slot"), action: { copyToClipboard(text) })
    }
}
