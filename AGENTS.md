# Working on Copperlight

Read [SPEC.md](SPEC.md) (what fits and what never will) and [DEVELOPMENT.md](DEVELOPMENT.md) (building, how the
code is laid out, the rules a change has to fit) first. This file only adds what's easy to miss.

## Commands

- `make test` runs the whole suite. It regenerates the Xcode project first, so new files are picked up.
- One test: `make project`, then
  `xcodebuild -quiet -project Copperlight.xcodeproj -scheme Copperlight -derivedDataPath build -destination "platform=macOS,arch=$(uname -m)" test -testLanguage en -only-testing:"CopperlightTests/timerUntil()"`.
- `make run` builds and launches it. Never edit `Copperlight.xcodeproj`: it's generated from `project.yml`.

## Making a change

- Write the failing test first, in `Tests/CopperlightTests.swift` (Swift Testing). No live network calls: data from
  elsewhere is a recording in `Tests/Fixtures/`.
- A new feature's wiring goes in `Sources/AppCore.swift`, not the app delegate. Tests build a real `AppCore` on a
  temporary folder (`startedCore`, under "The app, assembled"): use one for anything that depends on launch order,
  config.toml or how the features fit together. A test of one provider alone can't see those. Under tests `configDir`
  is a temporary folder, so no test can reach your real `~/.config/copperlight`.
- `state.json` keeps dates as ISO 8601 in whole seconds, so a test date that goes through `StateStore` needs whole
  seconds too.
- In an actor provider, write `modeResults` as `async`, like the protocol: a synchronous one loses to the protocol
  extension's default, which only calls `results`.
- Say so up front when macOS already does something well: ROADMAP.md's "Maybe, someday" lists what it covers today.
- A feature is done when the docs say it: [FEATURES.md](FEATURES.md), [docs/guide.md](docs/guide.md),
  [docs/configuration.md](docs/configuration.md) for a config key, the README when it's worth showing, and
  ROADMAP.md.

## Writing

- Short, plain sentences that say what happens. A row says what Enter does.
- The README and docs describe Copperlight on its own and don't name other launchers. The apps it works with
  (Google Calendar, Things, Todoist) are named where you pick them.
- No personal data in fixtures, screenshots or examples: made-up names, events and paths.
- Text a person reads is translatable (TRANSLATING.md): SwiftUI's own `Text`, `Button` and `Toggle` text as is,
  `String(localized: "…")` everywhere else. Values go in with `\(…)`, never glued on, and only text and whole numbers
  (format a `Double` into text first: `%lf` prints 3.140000). Never localize ids, keywords, config keys or anything
  matched against what's typed; a title typing matches goes through `titleScore`. Then run `make strings`: CI fails
  when `Resources/en.lproj/Localizable.strings` is out of date. A new keyword or permission prompt also goes in
  `Resources/en.lproj/Keywords.strings` or `InfoPlist.strings`, by hand (a test says when they're behind).
- The tests run in English (`make test` passes `-testLanguage en`).
