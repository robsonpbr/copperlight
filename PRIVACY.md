# Privacy

Copperlight has no account, no analytics and no crash reports, and it uses no AI service. What you type stays on
your Mac. It only goes somewhere when you ask for something that lives elsewhere, like a stock price or the weather,
and then only what that answer needs.

This page lists every server Copperlight contacts, every permission it can ask for, and everything it keeps. The
source is open, so you can check: every request it makes is a `URLSession` call or one of the two tools listed below.

## Every server it contacts

Searches and links open in your browser, so they're between you and the site you chose. Everything else Copperlight
asks for itself is here.

### Without being asked: public lists, nothing about you

| Server | When | What it sends | To turn it off |
|---|---|---|---|
| api.coinbase.com | When you open the launcher, at most every 5 minutes | Nothing: it asks for every currency's rate at once, so it never learns which ones you convert | `[features] currency = false` |
| api.github.com | When you open the launcher, at most once a day | Nothing: it asks for Copperlight's latest version number | `[features] updates = false` |
| formulae.brew.sh | Once a week | Nothing: it downloads Homebrew's whole public app list, so it never learns which apps you have | `[apps] online = false` |
| Each app's homepage | Once per app, for the apps in Homebrew's list that you have | A plain request for the page, to read its one-line summary | `[apps] online = false` |
| itunes.apple.com | Once per app you got from the App Store | The app's bundle id, to read the App Store's description | `[apps] online = false` |

Those descriptions let you find an app by what it does, like "draw" or "noise". They're kept in
`~/.config/copperlight/apps.json`.

### Only when you ask, with what you asked

| Server | When | What it sends |
|---|---|---|
| query1.finance.yahoo.com | In the Stock chip (`stock aapl`, then Tab), once you pause typing | The ticker |
| api.open-meteo.com, geocoding-api.open-meteo.com | In the Weather chip, once you pause typing | The city you typed or set in Settings, or where you are, rounded to about a kilometer |
| *language*.wikipedia.org | In the Wikipedia chip (`wiki lisbon`, then Tab), once you pause typing | What you typed, in your Mac's first language |
| api.ipify.org | Enter on the Public IP row (`ip`) | Nothing besides the request: it answers with your public address |
| Apple's servers | Enter on `speed` | The speed test macOS runs itself (`networkQuality`) |
| Homebrew, and the app's own site | Enter on Install, on an app you don't have | `brew install --cask` downloads the app |
| api.todoist.com | Only with Todoist picked in Settings › Options › To-dos and your key saved: Enter on `add todo`, on Show in `due`, or on a to-do | Your key, with the to-do and its date; a request for today's and overdue tasks; or the task to complete |

Typing alone never sends anything: an answer from elsewhere waits for the chip, a pause or Enter. Translation runs on
your Mac, with the languages macOS downloads; so do the dictionary, the thesaurus, spelling, the text in photos and
on screen, and search words for your apps (written by Apple Intelligence's on-device model, when it's on).

## Every permission it can ask for

macOS asks the first time a feature needs one, and the welcome window (`welcome`) asks for the common ones together.
Saying no only turns off what that permission is for.

| Permission | Asked | What it turns on | Without it |
|---|---|---|---|
| Accessibility | The first paste or window command | Pasting into your app, window commands and layouts, menu search, the media keys, opening on the text you selected | A paste copies instead, and the row says Copy |
| Automation | The first `:empty trash`, `:dark`, `:restart`, `:shut down` or `:log out`; a browser's row in `tabs` ⇥; the hotkey over Finder, from its row; `due` with Things picked, from its row | Asking Finder, System Events or loginwindow to do it; listing and switching a browser's tabs; the files selected in Finder; reading and completing Things' Today list | Those commands, the tabs, Finder's selection and Things' to-dos don't work |
| Calendars, add only | The first `add event` | Adding events | `add event` doesn't work |
| Calendars, full access | `meetings`, `week`, `month` or `free`, from its Allow row | Reading your events, the next meeting in the empty launcher, and your free time | No events |
| Reminders | The first `add todo`, or `due`'s Allow row | Adding reminders, and the ones that are due | No reminders |
| Contacts | `contacts`, from its Allow row | Finding people as you type their name | No people |
| Location Services | The Weather chip, when no city is set; `wifi password` | The weather where you are; the name of the Wi-Fi network you're on, which macOS tells only apps it lets know where you are | Set a city in Settings › Options › Weather; type the network's name |
| Camera | `camera`, from its Allow row | Showing you yourself before a call; nothing is recorded | No camera |
| Bluetooth | `:connect`, from its Allow row | Listing, connecting and disconnecting your paired devices | No devices |
| Screen Recording | The first `copy text` | Reading the part of the screen you drag over | No text from the screen |
| Photos | From the welcome window | Reading the text in your photos, on your Mac | Photos aren't searched |
| Notifications | The first pomodoro, timer or notification | The end of a pomodoro or a timer, shell lines that finish, errors | Those end silently |
| Desktop, Documents, Downloads | The first time a path lists one | Listing that folder | That folder isn't listed |
| Full Disk Access, given by hand | Never asked: rows say where to give it | Safari's bookmarks and history, and `codes` from Messages | No Safari, no codes |

## What it keeps, and where

Everything is in `~/.config/copperlight/`, on your Mac, and nowhere else:

- `config.toml`: your settings. Never a key or a password.
- `note.txt` and `notes/`: your notes.
- `state.json`: what you open most and what you picked for what you typed, recent queries, saved layouts, the
  running timer, the apps you open around each time of day, the colors you picked, and the last update check.
- `clipboard.sqlite`: your clipboard history, readable only by you. Deleted items are overwritten. Copies that apps
  mark as passwords, and copies made in password managers, are never recorded.
- `rates.json`, `apps.json` and `homebrew-apps.json`: currency rates and app descriptions.
- `photos.sqlite`: the text in your photos.
- `scripts/`: your scripts.

One thing is kept outside it: your Todoist key, if you save one, in your Mac's keychain. Settings › Options ›
To-dos › Forget Key deletes it.

Settings › Launcher has a Forget button for what it learned. Deleting the folder removes everything but the Todoist key,
which Forget Key deletes.

## What it reads and doesn't keep

Contacts, browser tabs, reminders and events are read on your Mac when you open the launcher, and kept in memory
only. What's due in Todoist is kept in memory for a minute after you ask. A Wi-Fi password you ask for is shown
after macOS asks for your Mac's password, and kept in memory for 10 minutes. `codes` reads only the last 15 minutes of Messages, when you type it. The camera shows only while the row is on
screen. A link you copy loses its tracking (`utm_…`, `fbclid`) before it's saved, and Settings › Features turns that
off.

## Turning things off

Any feature can be turned off in Settings › Features, or in `config.toml` (`[features] weather = false`). Off means
off: no rows, no background work, no network, no permission asked.
