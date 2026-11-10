# Using Copperlight

Everything you can type, in detail. [What you can type](../README.md#what-you-can-type) in the README is the short
version; [FEATURES.md](../FEATURES.md) lists every feature on one page, and [configuration.md](configuration.md) covers
config.toml.

> **Not offered yet**, with their code kept: the text inside files and photos. They're described below but don't
> appear in the app yet.

| Key | Action |
|---|---|
| ⌥Space | Show / hide the launcher. With text selected in the app you're in, it opens with that text typed and selected; over Finder, the files you selected wait on top; over an Open or Save dialog, Enter on a file or folder takes the dialog there |
| ↑ ↓ | Move selection. ↑ in the empty field: the last query you ran (↑ again for the one before) |
| Enter | Run: open app or file, copy a calculator, currency or text tool result, run command, open URL, search the web. Clipboard: paste the item |
| Tab | Fill in: on a row that says Tab (Translate, Quit Application, a folder), or with a name typed whole (`translate`), it types the name, which becomes a chip. On a row that names what Tab does beside Enter, it steps into it: a person's Actions, a calculation's Keep Going, and on a file, an app or a clipboard item what you can do with it (Esc goes back). On a row with something to show (a note, a snippet), it opens its preview beside the list, and Tab again closes it. In clipboard history and in chips the preview is open already |
| `:` (typed first) | Commands: the window in front, running apps, files, the Mac. Clipboard history has its own |
| Esc, or click elsewhere | Hide (or back out of a confirmation) |

The launcher is the only global hotkey, and the panel has no modifier keys: anything besides Enter is a
command you type after `:`. Everything else (note, clipboard history, pomodoro…) is found by typing.

**Every command on one sheet:** type `help` (`ajuda` in Portuguese), or pick Help in the menu bar. It lists everything
you can type on this Mac, in groups: a feature you turned off isn't there, a keyword you renamed shows your word, and
your own commands, snippets and scripts have a group of their own. Typing narrows it (`window`, `paste`, `:le`), ↑ ↓
and ← → move, and Esc closes it. Enter or a click puts that command in the launcher, ready to finish: `timer` becomes
its chip and waits for the time, `25 usd to eur` shows its answer, and `:shut down` waits for your Enter. Nothing runs
from the sheet.

**A new version:** once a day, Copperlight asks GitHub for the latest version number and sends nothing else. When a
newer one is out, the empty launcher says so at the bottom: Enter opens the download page, and Tab offers Skip This
Version, quiet until the next one. The menu bar has it too. Download the zip and replace the app in Applications: your
settings and permissions stay. Settings › Features › Update check turns it off.

**Reporting a problem:** Settings › About › Copy Diagnostics copies the versions, the permissions and what's wrong, to
paste in an issue. Nothing you typed or copied is in it, and your home folder shows as `~`.

**Your color:** Settings › General › Look sets the accent, the color of the field's edge, the selected row, chips
and the titles over answers: Copper (the icon's), Your Mac's accent color (it follows System Settings › Appearance),
or Your own color, from a color picker. It's `[look] accent` in config.toml.

It springs open, its card comes out of the field and glides to the rows and answers, and the selection glides as you
move. The weather and a stock show their card's shape at once, with the place or ticker, and fill it in when the
answer comes; with Reduce Motion
on (System Settings › Accessibility › Display), it changes in place and only fades in.

**Turning features off:** everything below is on. Settings › Features has a switch for each feature, by group:
answers (calculator, currency, weather…), yours (clipboard history, notes, calendar, files…), and windows and the
Mac (`:left`, `:quit`, `:lock`, `:play`…). Off means off: no rows, no chip, no `:` commands, nothing in the
background, nothing sent, no permission asked for, and its section leaves Settings. It's saved in config.toml as
`name = false` under `[features]` ([configuration.md](configuration.md) lists the names). Finding apps, the search
row and Copperlight's own rows are always on.

**Each feature's options:** Settings › Options has what you can set for the features that are on. Which calendars
count (a holidays calendar needn't make you busy) and how early the next meeting shows; your working hours, for
`free`; which reminder lists count; what Enter does on a person (message, call, FaceTime, email); °C or °F for the
weather; your cities, for `time` alone (the time now in each); whether a picked color is copied as hex, RGB or HSL; and
the sound a pomodoro or a timer ends with. Each is a key in config.toml ([configuration.md](configuration.md)).

**Your own keywords:** Settings › Keywords has a field beside each keyword (`translate`, `weather`, `:`…) for words of
your own, which replace its own. With `wth` for weather, `wth lisboa` then Tab gives the Weather chip, searching
Lisbon, and `weather` no longer does: Copperlight types `wth` wherever it would have typed `weather` (Tab on a row,
Delete on a chip, ↑), and its words in your Mac's language (`clima`) go with it. Other
ways in stay (`wea` still finds the Weather row by its name), and so does what else the word names, like the Weather
app. To keep a keyword's own word too, write it in: `weather, wth`. Several words are separated by commas. Reset beside
the field brings the keyword's own word back, and Reset All every one. Your word takes the place of what it would find:
with `t` for translate, typing `t` alone no longer finds apps. It's saved as `weather = "wth"` under `[keywords]`. `:`
and `:!` keep their own: a word of symbols for them works beside them, stuck to what follows (`;` for `:` is `;left`).

**Your language:** Copperlight's text follows your Mac's language, or the one chosen for Copperlight in System Settings
› General › Language & Region › Applications: English, Portuguese (Brazil) or Portuguese (Portugal). What isn't
translated yet shows in English. Each keyword has words in that language too, beside the English ones: on a Mac in
Portuguese, `clima lisboa` is `weather lisboa`. The `:` commands, System Settings pages and rows like Pick Color are found by their title in either
language: `:desligar` and `:shut down` both find Shut Down. Apps are found by both names too: `notes` and `notas`. Settings › Keywords lists each keyword's words in your language, and Words in your
language turns them off (`[keywords] language = false`), when one gets in the way of a file whose name starts with it.
Your own words win over your language's. Dates in `add todo` and `add event` are read as macOS reads them in your
language: on a Mac in Portuguese, `add todo pagar a renda amanhã 17h` is due tomorrow at 17:00. The words after a
keyword (`pomo break`, `25 usd to eur`) are English for now. To add a language, see [TRANSLATING.md](../TRANSLATING.md).

Things to type: `saf`, `vsc`, `2^10 / 3`, `sqrt(2) * pi`, `20% of 150`, `255 in hex`, `25 usd to eur`, `12,50 gbp in brl`, `100jpy usd`,
`25 usd` (converts to `default_target`), `25 eur` (the default itself converts to USD), `39*8 usd`, `20% off 80`,
`30 is what % of 150`, `10k * 3`, `days until dec 25`, `in 3 weeks`, `#c87533`, `pick color`, `qr`, `copy text`,
`large 555-0100`, `spell definately`, a person's name, an open tab's title, `due`, any command alias,
`note`, `note milk`, `clip` (opens clipboard history), `pomo`, `pomo 50`, `pomo break`, `pomo stop`, `timer 10 min tea`, `stopwatch`, `bluetooth`,
`dark mode`, `emoji party`, `define serendipity`, `translate bom dia`, `translate` (what you copied), `uuid`, `json`, `paste markdown`, `add`,
`add note buy milk`, `screenshot`, any file
name (`invoice`), text inside a file or a picture (`29.99`), an app by what it does (`draw`, `noise`), `f readme` (files only), `github.com/swiftlang` (opens it), anything at all (the last row
searches the web), `~/code/copperlight` or `/Applications` (lists the folder), `:` (every command), `:min`, `:quit saf`, `:window term`, `:!git status`. The selected row says what Enter does.

A calculation shows on a band over its row: what you typed = the answer, big, and what a percentage hid (`150 +
20%`: "20% of 150 is 30"; `20% off 80`: "You save 16"). A currency too: what you had → what it makes, with
the rate and the two flags faintly behind; Enter copies it as money (€21.48), the row below the number alone. Rates
are live, from Coinbase's public rates (every currency in one request, so it never learns which one you convert),
fetched when you open the launcher and they're over 5 minutes old; the band says how fresh they are. Numbers follow
your Mac's number format (System Settings › General › Language & Region): where it writes `1.234,56`, type `12,5 * 2`
and the answer is `25`, and `10 / 4` is `2,5`. With both marks, the last one is the decimal point on any Mac. Crypto converts
too: `0.1 btc in eur`.

**Chips:** a name that takes text (`translate `, `define `, `spell `, `emoji `, `stock `, `qr `, `large `, `contact `, `tabs `, `pomo `, `timer `, `port `, `note `, `add todo `, `add event `, `add note `,
`:quit `, `:window `, `:output `, `:connect `, `:!`, `f `, `cpu `, `memory `, and your script filters' names) turns into a copper chip at the start of the field when you press Tab:
`tra` Tab is the Translate chip, and `stock aapl` Tab is the Stock chip with `aapl` after it. Typing never makes one,
so `stock apple` still finds `stock_Apple.pdf`. The field then holds what follows, with a hint while it's empty, and
only that feature answers, so there's no search row in the way. Delete in the empty field turns the chip back
into text.

What you pick rises: every row you press Enter on (an app, a command, a file, a `:` command) ranks higher next
time, fading over a few weeks. So `s` + Enter opens Safari once you use it, and `:` lists your usual commands first.

What you typed counts too: the row you picked for some text comes first the next time you type exactly that, above
everything else. Pick Slack with `ss` typed, and `ss` is Slack from then on: an abbreviation, with nothing to set up.
Case and spaces around it don't matter; text over 15 characters isn't kept. Picking another row for the same text
takes over, and an abbreviation you stop using fades after a few weeks. Settings › Launcher › Rows you pick come first
(`[learning] picked`) turns both off, and its Forget deletes what was kept; ↑ bringing back what you ran has its own
switch and Forget beside it.

Answers take their own shape: most results are rows, with a preview beside them, but an answer that reads better big
takes the card instead. A stock, a dictionary entry and the speed test's result fill it, a QR code sits big beside
its actions, and a color is a band over its rows.
The rows under or beside it work as always, and the answer stays while you move between them. Settings › Launcher ›
Answers in their own shape (`[answers] cards`) turns them back into plain rows.

**Commands (`:`):** `:` lists them all, and what you type after it narrows them down (`:min`, `:fq`).

| Command | Does |
|---|---|
| `:export pdf`, `:new tab` | Choose a menu item of the app you were in (below) |
| `:window term` | Switch to a window: every window of every app, front app first, by title or app name. Accessibility sees this Space's windows and minimized ones, not other Spaces' |
| `:minimize`, `:fullscreen`, `:close` | Minimize the window in front, toggle its fullscreen, or close it |
| `:maximize`, `:center`, `:left`, `:right`, `:top`, `:bottom` | Fill the screen, center it, or take a half |
| `:top left`, `:top right`, `:bottom left`, `:bottom right` | Quarters |
| `:left third`, `:center third`, `:right third`, `:left two thirds`, `:right two thirds` | Thirds |
| `:nudge left`, `:nudge right`, `:nudge up`, `:nudge down` | Move it a step (5% of the screen), staying on screen. The panel stays open: Enter again for another step |
| `:layout save work`, `:layout work`, `:layout delete work` | Save every window on screen under a name, put them all back, or forget it. `:layout` lists them (below) |
| `:next display` | Move it to the next screen, same place and share of the screen |
| `:restore` | Put it back where it was before Copperlight moved it (several moves in a row count as one) |
| `:quit saf`, `:force quit saf`, `:hide saf` | Quit, force quit (asks first) or hide a running app. Alone, they list every running app |
| `:hide others`, `:unhide all`, `:relaunch slack` | Hide every app but the one in front, or show them all again; quit an app and open it again |
| `:quit all`, `:quit others` | Quit every app, or every app but the one in front (both ask first; Finder stays) |
| `:reveal readme`, `:copy path readme` | Reveal a file in Finder, or copy its path (file search, so from 2 letters). Given a path (`:copy path ~/code/copperlight/`), they list that folder |
| `:lock`, `:sleep`, `:sleep displays` | Lock the screen (sends ⌃⌘Q, so it needs Accessibility), sleep the Mac or only its displays |
| `:restart`, `:shut down`, `:log out`, `:empty trash` | Ask first, then do it. Apps with unsaved changes still get their say |
| `:screen saver`, `:show desktop`, `:open trash` | Start the screen saver; hide every app to see the desktop (`:unhide all` undoes it); open the Trash |
| `:open with readme` | Open a file with another app: pick the file (Tab), then the app, its default app first (`:open with ~/x/readme.md code`) |
| `:trash readme`, `:terminal readme` | Move a file to the Trash (asks first), or open its folder (a folder itself) in your terminal: Terminal, or the app in Settings › Files › Terminal |
| `:dark`, `:wifi`, `:hidden files` | Dark mode and Wi-Fi on or off (the row says which: Turn Wi-Fi Off); show or hide hidden files in Finder (Finder restarts) |
| `:awake` | Keep the Mac and its displays awake until you run it again (Stop Keeping Awake) or Copperlight quits. A sun in the menu bar shows it's on; click it to stop |
| `:awake 2h`, `:awake 90 min`, `:awake until 18:00` | Keep it awake for a while, then let go by itself. Lengths and times read like `timer`'s (`30` is minutes, `till 6pm`); `:awake` alone also offers an hour or two. Run again, it keeps going until the new time. The time left ticks in the empty launcher, and the sun's menu says until when |
| `:play`, `:next track`, `:previous track` | The keyboard's media keys: play or pause, skip, go back, in whatever is playing (Music, a browser tab, Spotify). Needs Accessibility, like pasting |
| `:mute`, `:volume 30` | Mute or unmute (the row says which), set the output volume (0–100, unmutes). A display's speakers can't be muted from the Mac: a beep says so |
| `:mute mic` | Mute or unmute the microphone (Mute Microphone, Unmute Microphone). One without a mute control gets its input level set to 0, and back |
| `:output airpods` | Switch the sound output: lists speakers, headphones, displays and AirPlay, the current one first |
| `:connect airpods` | Connect a paired Bluetooth device, or disconnect one that's connected (`:disconnect`, `:bluetooth` too). Lists the devices paired with this Mac, the ones to connect first, the most recently used first; connecting takes a few seconds and the row says whether it worked. The first time, the row is Allow: Enter asks for Bluetooth (typing never does). Pairing and switching Bluetooth off stay in System Settings (`bluetooth`) |
| `:eject` | Eject a disk (lists external drives and disk images) |
| `:shortcut name` | Run one of your Shortcuts. That's also the way to Focus modes: make a Shortcut that sets one. Text after the name (`:shortcut log water 500 ml`) is its input, as a text file |
| `:!git status` | Run a shell line (below) |
| `:config` | Open config.toml |
| `:copy …`, `:delete …`, `:clear` (clipboard history) | Copy an item without pasting it, or delete it, or all of them (asks first). Deleting keeps the panel open, for several in a row |

The first time, macOS may ask to let Copperlight control the app that does the work: Finder (`:empty trash`), System
Events (`:dark`), loginwindow (`:restart`, `:shut down`). One Allow each; change it later under Privacy & Security
→ Automation.

Window commands act on the window you were in when you opened the launcher (it never takes focus), and need
Accessibility, like pasting (see Signing). Enter on a command that needs a target (`Quit Application`) fills in
its keyword (`:quit `) so you can type the app.

**Layouts:** `:layout save work` keeps the windows on screen now, app by app: those of hidden apps, minimized and
full-screen ones stay out. `:layout work` puts each back, matching an app's windows by title first, then in order,
and unminimizing them. A screen that's gone since gets its windows on the main screen, at the same share. Apps that
aren't open are named in a notification: open them and run it again. Layouts live in `state.json`, not config.toml,
because their frames belong to this Mac's screens.

**Menus:** what you type after `:` also finds the menu items of the app you were in, from 3 letters, below the
commands: `:export pdf` in Pages, `:new tab` in a browser, `:show sidebar` in Finder. Each row says where the item is
(Pages › File › Export To) and shows its shortcut, so you learn it as you go; Enter chooses it, like clicking it. Only
items you could click right now are listed, and not the Apple menu or Services. It reads the menus through
Accessibility; without it, a row at the bottom offers to open the setting.

**Paths:** anything starting with `~` or `/` is a path. A folder that exists (`~/code/copperlight`, `/Applications`)
lists its contents, with the folder itself on top: Enter there opens it in Finder. Otherwise the last part
narrows the folder above it: `~/code/he` lists what in `~/code` matches "he". Enter on a folder goes into it
(types its path), and on a file or an app opens it. Hidden files show once the name starts with `.` (`~/.co`).
The first time you list Desktop, Documents or Downloads, macOS asks to let Copperlight read that folder.

**Shell (`:!`):** `:!git status` runs the line with `zsh -lc` in your home folder when you press Enter, never
while you type. Its output (stdout and stderr together, no colors) replaces the list, and Enter copies it; Esc goes
back to the line to edit or run it again. `:!` alone lists the lines you ran, most used first. A line is stopped
after 30 seconds. `~/.config/copperlight/scripts` is on its PATH. If you hide the launcher before the line finishes, a
notification shows how it ended. It's a login shell, not an interactive one: what `~/.zprofile` sets is there, but
aliases from `~/.zshrc` aren't.

**Text tools:** type a tool's name, then the text to work on (`upper hello`). With nothing after the name, it
works on the clipboard: copy some JSON, type `json`, Enter. Enter copies the result, and long results show in a
preview pane. Text after a name that the tool can't use (`hex f`) shows nothing, so other matches stay on top.
From 3 letters, the start of a name shows the tool too (`pas` → the paste tools).

| Type | Gives |
|---|---|
| `uuid`, `password`, `password 32`, `lorem`, `lorem 3` | A new UUID, a 20-character password (or 4–256), Lorem Ipsum paragraphs. Tab makes another UUID or password, in place |
| `fake name`, `fake email`, `fake phone`, `fake address`, `fake company`, `fake iban` | Made-up test data that's never anyone's: names from a list, example.com addresses, the 555-01xx numbers kept for fiction, a German IBAN whose check digits hold. `fake` lists them all; Tab makes another |
| `json`, `json min` | The JSON formatted (2 spaces) or minified, keys in their original order |
| `b64`, `b64 decode`, `url encode`, `url decode` | Encoded or decoded text (`b64 decode` takes URL-safe Base64 and missing padding too) |
| `upper`, `lower`, `snake`, `camel` | The text in that case, line by line (`fooBar baz` → `foo_bar_baz`) |
| `sort lines`, `count`, `sha256` | Lines in natural order (a9 before a10); words, characters and lines; the SHA-256 hash |
| `unix`, `unix 1700000000` | The time now as a timestamp; a timestamp (seconds or milliseconds) as a date |
| `hex #ff8800`, `hex 255 136 0` | The color in the other notation |
| `paste plain`, `paste markdown` | Pastes the clipboard into the app you were in: without its formatting, or as Markdown |

`paste markdown` converts anything copied with formatting (HTML or RTF: web pages, Google Docs, Slack, Word, TextEdit):
headings, bold, italic, links, lists, quotes, code and tables. Plain text pastes as it is. Pasting needs
Accessibility, like clipboard history; without it, Enter only copies. The pasted text stays on the clipboard.

**Capture:** `add` lists what you can add, and Enter on one types its name for you.

| Type | Does |
|---|---|
| `add note buy milk` | Adds the line at the end of the floating note, without opening it |
| `add todo call mom tomorrow 5pm` | A reminder in your default Reminders list, due (and alerting) at that time. No time typed: due that day. No date: no due date |
| `add event fri 10am dentist` | An event in your default calendar: an hour long, or the range you type (`10-11:30am`). A day without a time is all day |
| `screenshot`, `record` | The macOS screenshot toolbar (⌘⇧5), ready to capture or to record |

The row shows the title and date Copperlight read before you press Enter, and a notification confirms it. Dates are
read in English ("fri 10am", "tomorrow 5pm", "Oct 20 at 14:00", "next tuesday"). The first reminder asks for
Reminders access (macOS has no add-only option for reminders); the first event asks to add events only, so Copperlight
never reads your calendar. Google or Outlook calendars work when they're added in System Settings › Internet
Accounts, and so do Microsoft To Do's lists, in Reminders, with its Reminders switch on.

**Your calendar and to-do apps:** Settings › Options picks them. Until you do, nothing changes.

- **Calendar › Open in:** Calendar, Google Calendar or Outlook. "Your calendar" below means this one. Enter on
  `week`, `month` and a meeting without a call opens it: Google Calendar in your browser on that day, week or
  month; the Outlook app, or Outlook on the web without it. Google Calendar opens the browser's first Google account.
- **Calendar › Add events to:** the calendar `add event` uses. It lists your calendars once Copperlight may read them
  (`meetings` asks).
- **To-dos › Add to-dos to:** Reminders, Things, TickTick or Todoist. With Reminders, Reminders list picks the list
  new to-dos go in.
  - **Things:** `add todo` adds through Things' link, the date as its When. `due` lists Things' Today list, and Enter
    completes one there. macOS asks once to let Copperlight control Things. The empty launcher shows them only while
    Things is open.
  - **TickTick:** `add todo` adds the title, without its date. `due` keeps reading Reminders.
  - **Todoist:** paste your key, from Todoist › Settings › Integrations › Developer. It's kept in your Mac's
    keychain, not in config.toml. `add todo` sends the to-do and its date to Todoist. `due` shows Show What's Due in
    Todoist, and Enter asks Todoist for today's and overdue tasks, kept for a minute. Enter on one completes it in
    Todoist. They don't wait in the empty launcher, since that would mean asking Todoist each time it opens.
  - Any app but Reminders: `due` ends with a row that opens it.

**Your own tools:** a `[[command]]` with the same name as a built-in replaces it, so `screenshot` can open
CleanShot and `add todo` can go to any app with a link. Only the replacement shows, whatever Settings › Options picks. The text after the name reaches it as
typed (Copperlight reads dates only for what it adds itself).

```toml
[[command]]
alias = "screenshot"
type = "url"
url = "cleanshot://capture-area"

[[command]]
alias = "add todo"
type = "url"
url = "things:///add?title={query}"
```

**Scripts:** every executable file in `~/.config/copperlight/scripts/` (created on first run) becomes a command,
found by its file name without the extension. Text after the name is passed as arguments, each word one
argument (`deploy staging`). It runs through `zsh -lc`, so it gets the PATH a terminal has, in your home
folder. Optional comment lines near the top, in any comment style (`#`, `//`, `--`):

```sh
#!/bin/sh
# @title Deploy App
# @icon hammer
# @output show
```

`@title` names the row, `@icon` is an SF Symbol, and `@output` says what happens to what it prints: `silent`
(the default: runs in the background, a failure posts a notification), `show` (shown in place of the list,
like `:!`; stopped after 30 seconds) or `copy` (stdout goes to the clipboard). A script named like a built-in
replaces it, like a command. The folder is also on the `:!` shell's PATH. Remember `chmod +x`.

Community script commands work as they are: drop one in the folder and its own headers are read too. Its title
names the row, a `fullOutput` or `inline` mode shows the output (`silent` and `compact` run in the background), an
icon that's an SF Symbol name is its icon (an emoji or image isn't, so it gets the default), its description is the
row's subtitle, and `needsConfirmation true` asks before it runs. A script that declares its arguments
(`argument1`…) gets that many, the last one holding the rest of what you typed, so `ask will it ship` passes "will
it ship" whole. Where a script sets both, `@title`, `@icon` and `@output` win.

**Script filters:** a script with `@output rows` lists what it prints, and Enter acts on the row you pick. Its name
is a chip (`links` ⇥); as you type after it, the script runs with that text as its one argument, once typing pauses,
and its rows replace the list (`links docs` typed whole does the same). Each line it prints is a row: its title, then,
after tabs, a subtitle and the value Enter uses (the title without one). Enter opens a value that's a file or folder
(`/…`, `~/…`) or a link an app takes (`https://…`, `obsidian://…`), and copies anything else. Up to 100 rows, in the
order printed; a failure says so in a row.

```sh
#!/bin/sh
# @title Team Links
# @output rows
printf 'Docs\tThe handbook\thttps://example.com/docs\n'
printf 'Wiki\t\thttps://example.com/wiki\n'
printf 'On-call: %s\n' "$1"
```

**Colors:** a color typed as `#c87533`, `#f80`, `rgb(200, 117, 51)` or `hsl(27, 59%, 49%)` (spaces for commas
too) shows on a band with its hex and its contrast on white and on black (4.5 : 1 or more reads well as text),
two steps lighter and two darker at its end. Under the band: the other two notations, the one you typed, then a step
lighter and a step darker (a quarter of the way to white or black), each row with its swatch. Enter copies it. `pick color` (also `color picker`, `eyedropper`) opens macOS's magnifier: click anywhere on any
screen and its hex is copied, and the launcher comes back with that color typed, so the other notations are a row
away. Esc cancels. Colors are sRGB, what hex codes mean on the web. Every color you pick is kept (the last 30, in
`state.json`): `colors` (or `my colors`) lists them, newest first, each with its swatch and when you picked it. Enter
copies its hex, and the one you're on shows on the band.

**QR codes:** `qr https://copperlight.app` offers the code (Tab or Enter), and in the QR Code chip it shows big as you
type, with what it's of. `qr` alone makes one of what you copied. Beside the code: Copy Picture (Enter; PNG), Save to
Downloads (shown in Finder) and Copy Link, or Copy Text for anything that isn't a web address. Made on your Mac; up to
about 2,000 characters.

**Text from the screen:** `copy text` (also `ocr`, `scan text`, `grab text`) turns the pointer into the screenshot
crosshair: drag over any part of any screen (a video, a picture, a locked PDF, an error you can't select) and its
text is copied, line by line, read by the Mac's own text recognition. Esc cancels. If there's a QR code or a barcode,
what it says is copied instead, and a link in it comes back in the launcher, so Enter opens it. Taking the picture
needs the Screen Recording permission (Privacy & Security), asked for the first time; only the part you drag over
is read, and nothing is kept.

**Large Type:** `large 555-0100` (also `big text`) shows the text across the screen, as big as it fits, to show
someone across the desk; `large` alone shows what you copied. Any key, a click or switching apps puts it away.

**Snippets:** `[[snippet]]` entries ([configuration.md](configuration.md)) are found by name like commands. Enter pastes the text into the app
you were in, the same way the paste tools do (Accessibility; without it, Enter copies), and then puts your
clipboard back. Placeholders: `{date}` (`2026-10-13`), `{time}` (`16:55`), `{clipboard}`, and `{query}`, the text
typed after the name. A snippet without `{query}` only matches its name, so `sig more` finds nothing. `{cursor}` is
where the cursor ends up: after the paste, Copperlight presses ← that many times (the first `{cursor}`, if there are
more).

**Note:** type `n` (any start of "note") and it's the first result: your last note. Esc hides it again. It floats on a
glass card like the launcher's: drag it by its title, resize it from its bottom-right corner. Each note keeps its own
place on screen. `add note` adds a line to note.txt.

**Your notes:** they have no names. A note's first line is its title, on its card and in the list (without its
Markdown). The list has every note, the last edited first, each with the line after its title and how long ago it
changed; the selected one's text shows beside the list. New Note comes last: Enter opens an empty one, saved once you
type. The list is the Notes chip: `note` shows your last note and Notes, and Tab on it (or Enter) turns it into the chip,
with only your notes, no apps or search row. Typed in the chip, `milk` keeps the notes with "milk" in them (with the
line), and New Note then starts one with "milk" on its first line; `note milk` ⇥ goes straight there. `new note` works
from the field too. Anywhere else, from 3 letters, a note with the words you typed shows below what matches by name.
`:delete note milk` moves one to the Trash, after asking. Notes are text files: note.txt, and the ones in `notes/`.

**Markdown in notes:** as you type, `# headings` (to `###`), `**bold**`, `*italic*`, `` `code` ``, lists, `> quotes`
and links (`[text](url)`, or a bare `https://…`) show styled, the syntax dimmed beside them. `- [ ]` is a checkbox:
click it to tick it (`- [x]`, struck through), and ⌘Z to undo. A click on a link opens it. Only the look changes:
the file stays plain text. Settings › Options › Notes turns it off (`[notes] markdown`).

**Keys in a note:** each writes the Markdown for you, and pressed again takes it off. With Markdown turned off, they do
nothing.

| Keys | What they write |
|---|---|
| ⌘B, ⌘I, ⌘E | Bold, italic and code, around what's selected. With nothing selected: press it, type, and press it again to go on after it |
| ⌘K | A link: what's selected is its name, and the cursor waits where the address goes. With nothing selected, type its name and press ⌘K again |
| ⌘1, ⌘2, ⌘3 | A heading |
| ⌘⇧7, ⌘⇧9, ⌘⇧L | A bullet, a number, a checkbox, on every selected line |
| ⌘' | A quote, on every selected line |

**Enter in a list:** gives you the next bullet, number or checkbox. Enter on an empty one ends the list, and ⌥Enter
starts a plain line. With Markdown turned off, Enter is only a new line.

**Text size in notes:** ⌘+ makes the text bigger, ⌘- smaller, and ⌘0 brings back the normal size. It's one size for
all your notes, and it stays until you change it.

**System Settings:** a page by name from 3 letters (`bluetooth`, `displays`, `keyboard`, `privacy`), or by
something on it (`dark mode`, `night shift`, `dock`, `default browser`, `login items`). Enter opens that page.

**Emoji:** `emoji party` lists emoji whose names have words starting with each word you typed, using the names of
the macOS emoji picker (flags and combinations too, English). Enter pastes it, like snippets.

**Define:** `define serendipity` shows the entry from the Mac's dictionaries (offline) across the card: the word set
in a serif and its pronunciation, its meanings (three of the first part of speech, one of the next), each with its
first example, and where the word comes from. Enter opens the whole entry, phrases and derived words included, in
Dictionary.

**Synonyms:** `synonyms happy` (`syn` Tab is its chip) lists the words the Mac's thesaurus has for it, offline, a row
each under the example of its sense: up to 8 a sense, 5 senses. The informal, dated and regional ones are left out,
so what's there is safe to write. Enter copies one. The thesaurus is Dictionary's; turn one on in Dictionary ›
Settings if the row says there's none.

**Spell:** `spell definately` gives the word spelled right and the other guesses, the best first; `spell` with a
sentence gives it back with each misspelled word corrected. A word that's right says so. Enter copies it. It's the
Mac's own spelling, in the languages System Settings › Keyboard › Text Input has for it.

**Translate:** `translate bom dia`, `translate good morning to spanish` (`to`, `in` or `into`, then a language's
English name or code). Apple's on-device translation (macOS 26): the source language is detected, and without a
target it goes to the language in Settings › Options › Translate to (`[translate] default_target`), or, set to
Automatic or when the text is already in it, to your first language in System Settings that isn't the text's. With no text, `translate` (or
`translate to spanish`) translates what's on the clipboard: copy, ⌥Space, `translate`, Enter. The language joins the
chip (Translate to German) when you press Tab with it first (`to ger` ⇥) or at the end of the text
(`hello world to ger` ⇥); the field then holds only the text, and Delete takes the language back out. Enter copies it. Language pairs
download once, from System Settings → General → Language & Region → Translation Languages; until then the row
says so and opens that page.

**Clipboard history:** text and images you copy are recorded (looked for twice a second, every 2 s after a minute away from the keyboard and mouse, so the Mac sleeps more). A copy with both, like
spreadsheet cells, is kept as text. Images (screenshots, "Copy Image") are stored as PNG, shown as a
thumbnail in the list and full size in the preview, with their size; type `image` to list only them. Copying something already in the
list moves it to the top. Typing filters: items containing the text, then items whose first line matches
fuzzily ("gco" → "git checkout origin"). Not recorded: copies marked concealed/transient/auto-generated
(password managers mark theirs), copies made while an `ignore_apps` app is in front, and the items you
paste from the list itself. Enter pastes into the app you were in, which needs Accessibility (see Signing).
Without it, Enter copies only and the panel shows a row that takes you to the setting. Tab on an item shows what
else you can do with it: open a link, Large Type, a QR code, save a picture, pin it, paste from it in order, delete it.

**Pins:** Tab on an item, then Pin. It stays on top of the history, under Pinned, through pruning and `:clear`; Tab
on it again unpins it.

**Pasting in order:** to paste several things in the order you copied them (a name, then an email, then a phone
number, into a form), Tab on the first one, then Paste in Order from Here. It's pasted, and the next one waits on top
of the empty launcher as Paste Next: press the hotkey and Enter for each. Tab on Paste Next stops. Nothing watches
your ⌘V: the hotkey is the only key Copperlight hears.

**Latest screenshots and downloads:** `screenshots` lists your newest screenshots (the files macOS marked as
screenshots, in the folder the screenshot toolbar saves to), `downloads` your newest downloads, by when they arrived;
`latest screenshot` and `last download` give the newest alone. Enter pastes the file into the app you were in (copies
it, without Accessibility); Tab shows what else you can do with it.

**Links without tracking:** a link you copy loses what's only there to track where it was shared (`utm_source`
and the other `utm_` ones, `fbclid`, `gclid`, YouTube's and Spotify's `si`, X's `s` and `t`), and a Google or
Facebook redirect gives up the link inside it, before you paste. Only a copy that's a single link changes. Turn it
off in Settings › Features › Links without tracking (`clean_links = false`).

**Codes from Messages:** `codes` (or `2fa`, `otp`) lists the verification codes in the messages you got in the last
15 minutes, newest first, with who sent them. Enter copies the code; Tab shows the whole message. They're read from
Messages' own database on this Mac, which takes Full Disk Access: the row says where to give it (Privacy & Security
› Full Disk Access).

**File search:** after 2 letters, files and folders in the `[files]` scopes whose name has a word starting with
what you typed (each word, any order of words: `inv 2026`). Uses the Spotlight index, so anything Spotlight
skips (System Settings → Spotlight → Privacy) is skipped too. Files always rank below apps, commands,
math and currency, and arrive a moment later (150 ms after you stop typing). Order: exact name, then name
starts with it, then a later word does; within that, most recently opened first, then the shallowest path.
Start with `f ` for files only, with up to 60 results instead of 20.

**What you can do with it (Tab):** on a file, an app or a clipboard item, Tab puts what you can do with it in place
of the list, under its name, with its preview beside it. Esc goes back to the list, the item still selected; typing
searches again. A file (in a search, or a folder's listing): Open (the row says in which app), Open With… (fills in
`:open with`, to pick the app), Quick Look (full size, as Space shows it in Finder; `:look readme` too), Reveal in Finder, Copy Path, Copy File (the file itself, to paste in Finder, an email
or a chat), AirDrop, Send in Messages, Send in Mail (the file attached), Open in Terminal (its folder, in `[files] terminal`), Move to Trash (asks first); beside them a text
file's start, a picture or a PDF's first page, and where it is, its kind, size and when it changed. An app: its recent
documents first, then Open, and while it runs Hide, Quit, Force Quit (asks first) and Relaunch; Reveal in Finder, Copy
Path; beside them its icon, version and where it is. Its recent documents are the files in your home folder of the
kinds the Mac opens in it (TextEdit: text and Word files; Preview: pictures and PDFs, unless they open elsewhere), the
most recently opened first, five at most, from Spotlight: each says how long ago, its preview beside it, and Enter
opens it in that app. The app's own Open Recent list is kept where macOS lets in only apps with Full Disk Access, which
Copperlight doesn't ask for; an app's own files in `~/Library` are left out, but not your cloud drives there. A clipboard item: Paste (Copy, without Accessibility), Copy Without Pasting, Paste in Order from Here (when you copied
something after it), Pin or Unpin; for text, Open
Link if it's a web address, Large Type, and QR Code, the code beside the list (Enter copies the picture); for a
picture, Open in Preview and Save to Downloads; and Delete from History.

**Inside files and pictures:** from 3 letters, files in the same folders with the words in their text, below the
ones found by name ("Text inside", or "Text in image"). Spotlight reads documents, PDFs, and the text in images and
screenshots, in the background when the Mac is idle, so a picture saved minutes ago may not be found yet. The
preview shows the picture, or the lines with the words.

**Photos:** with Photos access (the welcome window asks), Copperlight reads the text in each photo of your library
once, on this Mac (Vision), newest first, then only new photos; Photos keeps its pictures out of Spotlight. A big
library takes a while the first time, and photos only in iCloud are downloaded at a medium size to be read. From
3 letters, photos with the typed text show with "Text in photo" and the photo in the preview; `29.99` finds 29,99
too. Enter opens a copy in Preview (Photos doesn't let other apps show one of its photos). Kept in `photos.sqlite`.

**Typos:** a name finds its app from a few letters in order (`vsc`, `ss`), and from 4 letters a slip is forgiven:
a letter wrong, extra or missing, or two swapped (`slcak` → Slack, `calender` → Calendar, `xcdoe` → Xcode; two
slips from 8 letters). The first letter has to be right, and typing past the end of a name isn't a slip (`notes`
isn't Note). A slip ranks under any real match, so it only leads when nothing else does. Commands, System Settings
pages and everything else found by name forgive it too.

**Apps by what they do:** `draw` finds Affinity, `noise` Krisp, `docker` OrbStack, with the word that matched beside
the name. Copperlight keeps an index of each app, `apps.json`: its App Store category, publisher and the documents it
opens; online, Homebrew's one-line description and the app homepage's own summary, or the App Store's description for
apps installed from it; then, with Apple Intelligence on, words from the Mac's on-device model (what kind of app it
is, what people do with it, other words for it). New and updated apps are indexed in the background; the Mac limits
how often a background app may use the model, so the first run takes a few minutes. `[apps] online = false` keeps it
all on this Mac.

**Installing an app:** with Homebrew installed, typing an app you don't have (`figma`, from 3 letters, when it isn't
the start of an app you have) offers Install Figma, with Homebrew's description, below everything else; two at most,
the closest name first. Enter runs `brew install --cask figma` with its output beside the row; Enter again hides the
launcher and lets it finish, and a notification says how it ended. Once it's installed, Enter opens it. An app that
needs your password to install (a .pkg) can't ask for it in the launcher: the row says so, and Enter copies the
command to paste in a terminal. The list is Homebrew's, the one app search already downloads, so `[apps] online =
false` turns this off too.

**Web:** text that looks like a URL (`github.com/x`, `https://…`, `localhost:3000`) gets an "Open" row.
A bare `name.tld` counts only for common TLDs (com, org, net, io, dev, app, co…), so file
names like `readme.md` don't. The last row is always "Search Google for …", so Enter on a query that matches
nothing searches the web. Settings › Browser › Search engine picks another: DuckDuckGo, Bing, Brave Search,
Ecosia or Kagi.

**Units:** `10 km in mi`, `10km mi`, `100 f to c`, `2,5 kg`, `1 gb in mb`, `90 min in h`. Length, weight,
temperature, volume, speed, data (`kb`… decimal, `kib`… binary), time and area, by symbol or name (`km`, `miles`,
`°c`, `lbs`, `kmh`, `cups`, `floz`). With no target, metric and US units convert to each other (`30c` → °F, `5 lb`
→ kg). `10 in cm` and `10 in in cm` both work. CSS lengths too: `2rem in px` (16 px a rem), `24px` (in rem), `96 px
in in`. Enter copies the number.

**Time zones:** `now in tokyo` (or `time in tokyo`), `3pm in sf` (3pm here), `15:30 lisbon in new york`, `noon utc
to sf`, also with `to`. A place is any time zone's city (`lisbon`, `new york`, `são paulo`), an alias (`sf`, `la`,
`nyc`, `india`, `china`, `uk`) or an abbreviation (`pst`, `utc`, `cet`). The row shows the time there, the day
and the difference in hours. Enter copies the time. `time` alone (or `times`) shows the time now in each of your cities,
set in Settings › Options › Time zones (`[time_zones] cities`).

**Dates:** `days until dec 25` (or `how many days until christmas?`), `weeks until dec 25` (8 weeks, 2 days), `days
since jan 1`; `in 3 weeks`, `3 weeks from now`, `100 days from today`, `3 days ago`, `in 2 months`, `30 days after dec
25`, `2 weeks before dec 25`, `dec 25 + 2 weeks`, `monday in 3 weeks` (the Monday of that week); `time in 4 hours`, `in
90 minutes`. A date alone shows its weekday, how far it is and its week number (as your Mac's calendar counts them):
`dec 25`, `25 december 2027`, `2026-12-25`, `tomorrow`, `next friday` (the one after this week's, as macOS reads it),
`last friday`, `christmas`, `new year`. Without a year it's the next one, or the last one after `since`. A weekday's
name alone ranks low, under an app with that name. While you type, `in 3` answers in 3 days, weeks, months and hours,
`3 weeks` from now and ago, each with its phrase at the right edge, and `days` or `weeks` offers until or since a
date: Tab, then the date. Enter copies the answer.

**Stocks:** `stock AAPL`, `stock MGLU3.SA`, `stock ^BVSP`, `stock BTC-USD` (`sto` ⇥ for the Stock chip; tickers as
Yahoo Finance writes them). The answer takes the whole card: the ticker and name, the price and today's change (▲
or ▼), when it last traded and where, the last 7 days drawn hourly with yesterday's close dashed across, and under it
the previous close and the change over the 7 days. Enter opens the stock on Yahoo Finance.
It says what you asked for, so it waits for you: only in the Stock chip, and only once you
pause typing, does the ticker go to Yahoo; the answer is kept for a minute. Typed without the chip, `stock aapl` asks
nothing: below the files, a row offers it (Stock Price of AAPL), and Tab or Enter on it makes the chip.

**Wikipedia:** `wiki lisbon`, in the Wikipedia chip (`wik` Tab), shows the article's picture beside its title, what
it is in a few words and its first three sentences, in the language your Mac reads first. Like a stock, it waits
for you: what you typed goes to Wikipedia only in the chip, once you pause typing. Enter opens the article.

**Weather:** `weather` ⇥ is the Weather chip. With nothing after it, it's the weather where you are: the first time, a
row asks for your location (Location Services), once. If you'd rather not share it, set a city in Settings › Options
› Weather (`[weather] city`), where °C or °F is set too (`[weather] units`). Type a city after the chip (`weather lisbon`) for that city. The card shows the
temperature now with its symbol, the conditions, today's high and low, how it feels and the wind, the next five days
with their lows and highs on bars of one scale, and the next seven hours. Enter opens the Weather app. It comes from
Open-Meteo, free and without an account: only in the chip and once you pause typing, and where you are goes rounded to
about a kilometer. An answer is kept for 10 minutes.

**Lookups:** `ip` lists each interface's IPv4 address (Wi-Fi, Ethernet; Enter copies it) and a Public IP row that
asks api.ipify.org only when you press Enter on it. `battery` (from `batt`) shows the charge and what it's doing
("87%, charging, 1:05 to full"), its health and cycle count; Enter opens Battery settings. `disk` shows free space on
each disk mounted, as Finder counts it; Enter opens Storage settings. `port` (`por` ⇥ for the Port chip) lists your
processes listening on TCP ports, `port 3000` (or `port 30`, `port node`) narrows them, and Enter ends one, after
asking. Another user's processes aren't listed.

**Processes:** `cpu` lists your 8 busiest processes by recent CPU use, `memory` (from `mem`, or `ram`) by memory, each
with its CPU, memory and pid, and the icon of the app it belongs to: a Chrome Helper shows Chrome's. `cpu chrome`
narrows them by name; `cpu` ⇥ or `memory` ⇥, the chip, lists every one. Enter ends a process after asking, the way
`kill` does (SIGTERM); on an app itself (not a helper inside it) it quits the app instead, so it can ask to save.
`kill process` and `processes` find it too. Copperlight and another user's processes aren't listed.

**Speed test:** `speed` (also `speedtest`, `internet speed`) offers Test Internet Speed. Enter runs macOS's own
`networkQuality`, which measures your connection against Apple's servers for about 20 seconds. Its card shows at
once, the download and upload speeds climbing as they're measured, with the seconds so far; Esc stops it. Then the
result settles on the card: the download and upload speed big ("322 Mbps", "243
Mbps"), the latency when the line is idle and when it's busy (what calls and games feel), whether it's Wi-Fi, Ethernet
or cellular, and when it was tested. Enter copies it ("322 Mbps down · 243 Mbps up · …"). Typing `speed` sends nothing.

**Bookmarks and history:** from 2 letters, pages from your browser where each word you typed starts a word of
the title or the address (`copperlight git`; `30c` doesn't match inside "HP30138C"): up to 4 bookmarks, then the 4 most
recently visited, the same title on a site only once, ranked just above files. The browser is
`[browser] name`, else the default one; the profile is `[browser] profile`, else all of them (each row names its
profile and opens there). Chrome, Brave, Edge, Vivaldi and Chromium (bookmarks JSON, `History`) and Firefox
(`places.sqlite`) are read as they are; the history files are copied first, since the browser keeps them locked.
Safari's `Bookmarks.plist` and `History.db` need Full Disk Access for Copperlight (Privacy & Security). Arc isn't read.
Loaded in the background when the launcher opens, at most every 2 minutes; never written anywhere.

**Browser tabs:** typing finds the tabs open in your browsers, like bookmarks: every word you typed starts a word of
the title or the address, from 2 letters, up to 4 tabs, ranked just above bookmarks. Enter switches to the tab, its
window coming forward, instead of opening the page again. `tabs` ⇥ is the Tabs chip: every open tab, in window order,
and typing narrows them. Chrome, Brave, Edge, Vivaldi, Chromium, Arc and Safari, whichever are running; private
windows aren't listed, and Firefox can't say what tabs it has. Copperlight asks each browser through AppleScript,
which needs your OK once per browser: the Tabs chip has a row that asks (System Settings › Privacy & Security ›
Automation, if you said no). Read when the launcher opens, kept in memory only.

**Contacts:** from 2 letters, the people in your contacts where each word you typed starts a word of their name,
nickname or company. The row shows their number and email; Enter messages them in Messages (their mobile number,
else their first number, else their email), or opens their card if they have neither. Tab goes into the person, the
Contact chip: Message, Call (through your iPhone), FaceTime and WhatsApp (when it's installed) for each number, Email
for each address, Copy for each, and Open in Contacts, beside their card: their photo (or initials), name, job and company,
and their numbers, emails and birthday.
`contact` ⇥ alone lists everyone. The first time, `contacts` (below the Contacts app) has a row that asks to read
them. Read on your Mac when the launcher opens, at most every 2 minutes, kept in memory only.

**Meetings:** `meetings` (from `mee`), `agenda` (from `age`) or `events` list the rest of today's events from
Calendar, all-day ones aside, with their times and how soon they start; `calendar` typed whole too, below the
Calendar app. One that starts within the hour, or is going, has a copper badge ("in 17 min", "Now"). Tab shows its
details beside the list: its day, times and notes, its calendar, place, call and link, who's coming and who asked.
Enter joins the video call it finds in the event's URL, location or notes (Google Meet, Zoom, Teams, Webex), opening
web links where `[browser]` says, or opens your calendar. The first time, the row asks to read your calendars (full
access; `add event` only asked to add).

**The week:** `week` (from `wee`) shows the week you're in across the card, a column a day starting on your first
weekday, each day's events stacked under it with their times: all-day ones first, up to five, then "+2 more".
Today's date sits on copper, and the days and events already over fade. `next week` shows the one after. Enter
opens your calendar.

**The month:** `month` (from `mont`) shows the month you're in as a grid, whole weeks from your first weekday, with
a dot under each day for each of its events, up to three. Today's date sits on copper; the days already over and
those of the months around it fade. `next month` shows the one after. Enter opens your calendar.

**Free time:** `free tomorrow` lists the gaps in your calendars between 9:00 and 18:00, 30 minutes or more, to offer
someone a time. Events shown as free and all-day events don't count. Also `free today`, `free friday` (the next
Friday, or today), `free this week` (the workdays left) and `free next week`; `free` alone is today, or the next
workday once today's hours are over, and comes under apps whose names start with "free". The first row has them all, a
line a day ("Wed, Nov 4: 9:00 – 10:00 AM, 1:00 – 5:40 PM"); Enter copies it. Then a row for each slot, Enter copying
that one.

**Before a call:** `camera` (from `came`) shows what your camera sees across the card, mirrored like a mirror. When
a meeting with a call is about to start, the card says which one and Enter joins it; otherwise Enter opens Photo
Booth. The first time, the row asks to use the camera. It's on only while the card shows, and nothing is recorded.

**Wi-Fi password:** `wifi password` offers the password of the network you're on (`wifi password Office` for another
one this Mac has joined). Enter asks macOS, which wants your Mac's password in its own window, then the launcher
shows the password beside a QR code: a phone's camera joins the network from it. Enter copies the password, Copy QR
Code the picture. It's kept in memory for 10 minutes. macOS tells apps which network you're on only with Location
Services, so without it a row asks for it, or you type the name.

**The next meeting:** a few minutes before a meeting with a call, there's no need to type: from 10 minutes before it
starts until 10 minutes after, the empty launcher shows that meeting on a band: how soon it starts, its title, times
and call, who's coming and the first line of its notes. Enter joins; the row under it opens your calendar. `meetings` puts
it first the same way. Settings › Launcher › Calendar picks what the empty launcher shows: Today's events (`[meetings]
show_on_open`), the day's next five, with or without a call; A meeting about to start, as above; or Nothing
(`show_next = false`). Either only once Calendars access is given; opening the launcher
never asks. Typing hides it.

**Due reminders:** the empty launcher lists the reminders that are overdue, due within the hour, or due today with no
time, the soonest deadline first, each with a copper badge ("Overdue", "in 20 min", "Today") and its list. Enter
completes one and keeps the launcher open, so you can tick off the next. `due` (or `overdue`, `todos`) lists all of
today's and the overdue ones. Reading them needs full Reminders access, which `add todo` asks for, or the row `due`
shows the first time; opening the launcher never asks. Settings › Launcher › Reminders that are due (`[reminders]
show_due`) keeps them out of the empty launcher. With Things or Todoist picked in Settings › Options › To-dos, `due`
reads that app instead (above, under Your calendar and to-do apps).

**Pomodoro:** `pomo` starts `default_minutes`, `pomo 50` starts 50 minutes (1–240), `pomo break` starts
`break_minutes` of break (`pomo break 15` for another length; a cup in the menu bar), `pomo stop` stops. While it
runs, the menu bar shows the countdown; click it to stop. Nothing is shown when no timer runs. The end time is
saved, so the timer keeps going through sleep and app restarts (if it ended while the app was closed, you get the
notification on the next launch). When it ends: a notification with a sound. Starting a timer the first time asks to
allow notifications. While one runs, `pomo` offers to stop it, its time left ticking, and a break (or, during a
break, a pomodoro), not another of the same; `pomo 50` replaces it, after asking.

**Timer:** `timer 10 min tea` counts down 10 minutes for tea, beside the pomodoro and like it: an hourglass and the
time left in the menu bar (click it to stop), kept through sleep and restarts, and a notification with a sound when
it's done ("Timer done", tea · 10 minutes). The length comes first: `10` (minutes), `10 min`, `90s`, `1h30m`,
`1 hour 30`, from one second to 24 hours; whatever follows is what it's for (`for` dropped:
`timer 20m for the laundry`). One runs at a time; starting another asks before replacing it. `timer` alone offers to
stop the one running, and so does `timer stop`. `tim` Tab is the Timer chip. A time of day works too:
`timer until 15:30 standup`, `timer at 3pm` (tomorrow's, if it's gone today).

**Stopwatch:** `stopwatch` (from `stopw`) starts one, counting up in the menu bar and kept through restarts;
`stopwatch` again, or a click on it in the menu bar, stops it and says the time in a notification.

**What's running, when you open it:** while a pomodoro, a break, a timer or the stopwatch runs, or the Mac is kept
awake, the empty launcher lists it with its time ticking in a copper pill: left for the pomodoro, the timer and keeping
awake for a while, so far for the stopwatch.
Enter stops it, after asking. A meeting about to start stays above them, so Enter still joins. Settings › Launcher ›
What's running (`[timers] show_running`) keeps them out of it; the menu bar still shows them.

**Suggestions:** below all that, the empty launcher shows up to 3 apps you open around this time of day: opened from
the launcher within an hour of now on 3 days or more of the last 4 weeks, the most often first (a recent day counts
more). The app you're in isn't one of them. Learned from what you open with Copperlight, kept in `state.json`;
Settings › Launcher › Apps you open around this time (`[apps] suggestions`) turns it off, and what you open stops being
kept; Forget beside it deletes what was.
