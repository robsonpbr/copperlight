# Translating Copperlight

Copperlight shows its text in your Mac's language, when it has a translation for it. Adding a language takes three
plain text files and one pull request. You don't need Xcode, and you don't need to know Swift.

## Add a language

1. Make a folder for your language: `Resources/<code>.lproj`, where `<code>` is its code, like `de`, `el`, `ja`,
   `pt-BR` or `pt-PT`.
   - On GitHub's website: open each file in [Resources/en.lproj](Resources/en.lproj), copy it, and add a file with the
     same name in your folder.
   - From a copy of the repository: `make language CODE=de` makes the folder, the English files in it.
2. Translate the right side of every line, in its three files:
   - `Localizable.strings`: everything Copperlight shows.
   - `Keywords.strings`: the words people type, like `weather`.
   - `InfoPlist.strings`: what macOS shows when Copperlight asks for a permission.
3. Open a pull request. A check reads your files and says, line by line, what needs fixing.

Each line looks like this. Keep the left side as it is, and end each line with `;`:

```
"Open Calendar" = "Abrir Calendário";
```

A `"` inside a translation is written `\"`. A line you leave out shows in English, so you can translate a part now and
the rest later.

## Values in the text

`%@`, `%lld` and `%d` are where Copperlight puts a value: `%@` a word or a name, `%lld` and `%d` a number. Keep each
one. `%%` is a percent sign: write it as `%%` too, never a single `%`. If your language needs the values in another
order, number them:

```
"Open %@" = "Abrir %@";
"%1$@ in %2$@" = "%2$@: %1$@";
```

## What stays as it is

- Product names: Google Calendar, Outlook, Things, TickTick, Todoist, macOS, Wi-Fi, Bluetooth, Homebrew.
- Text people type as an example, like "call mom tomorrow 5pm": leave it as it is.
- A keyword inside a sentence, like “meetings”: keep the English word, or use your language's word from
  `Keywords.strings`. Both work when people type them.
- The `:` commands' words (`:left`, `:quit`). Their titles, like "Left Half", are translated.
- What Copperlight types into the field for you (Tab or Enter on a name, like `add todo `) stays English for now, so
  it isn't in these files.

## The words people type

`Keywords.strings` has a line for each keyword. Write the words in your language that people would type for it,
separated by commas. All of them work, and the English one always works too:

```
"weather" = "clima, previsão";
"add todo" = "adicionar tarefa";
```

- A word can't be another keyword's English word, and it can't be in two lines.
- A word can't be the name of one of the Mac's own apps in your language, or its first word: in Portuguese, “notas”
  is the Notes app and “tempo” the Weather app, so typing them would open the keyword instead. The check says which.
- Choose words people don't type for other reasons. Copperlight takes a keyword's word as that keyword, so a word
  that also starts many file names would stop finding those files. People can turn your language's words off in
  Settings › Keywords.

## Try it

Every pull request gets the app built from it.

1. In the pull request, open **Checks**, then **Tests**, and download **Copperlight** under **Artifacts**.
2. Unzip it and open it. The first time, macOS asks you to confirm: open System Settings › Privacy & Security, then
   **Open Anyway**.
3. Choose your language for Copperlight in System Settings › General › Language & Region › Applications.

## See what's left

`make translations` lists, for each language, how many lines are translated, which are missing, and which are no
longer in English (you can delete those).

## Counts

Text with a count has a line for one ("1 event") and one for more ("%lld events"). If your language needs more forms
than that, say so in your pull request.

## For developers

Text a person reads goes through localization: SwiftUI's own `Text`, `Button` and `Toggle` text as it is,
`String(localized: "…")` everywhere else. Put values in with `\(…)`, never by gluing text together, and only text and
whole numbers: format other numbers into text first. Add a `comment:` to a short line whose meaning depends on where
it shows. `make strings` updates `Resources/en.lproj/Localizable.strings`, and CI checks that it's up to date. The
English `Keywords.strings` (a line per keyword) and `InfoPlist.strings` (the permission prompts in `project.yml`) are
kept by hand: a test fails when either is out of date.
