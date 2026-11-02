// Copperlight's language files (TRANSLATING.md), run by the Makefile from the repository's folder:
//   swift Tools/Strings.swift english <build folder> <file>   the English list, from the compiler's .stringsdata files
//   swift Tools/Strings.swift new <code>                      a new language's folder, a copy of the English files
//   swift Tools/Strings.swift report                          each language: how much is translated, what's missing
import Foundation

let resources = URL(filePath: "Resources")
let files = ["Localizable", "Keywords", "InfoPlist"]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

/// A `.strings` file's lines, as key → translation; empty if it isn't there.
func table(_ url: URL) -> [String: String] {
    guard let data = try? Data(contentsOf: url) else { return [:] }
    guard let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
        fail("\(url.path): not a .strings file (a missing ; or \"?)")
    }
    return table
}

func quoted(_ text: String) -> String {
    "\"" + text.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"").replacing("\n", with: "\\n") + "\""
}

switch CommandLine.arguments.dropFirst().first {
case "english":
    let arguments = Array(CommandLine.arguments.dropFirst(2))
    guard arguments.count == 2 else { fail("english <build folder> <file>") }
    struct StringsData: Decodable {
        struct Entry: Decodable { var key: String; var comment: String?; var value: String? } // value: a `defaultValue`
        var tables: [String: [Entry]]
    }
    var comments: [String: Set<String>] = [:]
    var values: [String: String] = [:] // a key like "contact.call", with its English
    let found = FileManager.default.enumerator(at: URL(filePath: arguments[0]), includingPropertiesForKeys: nil)
    while let url = found?.nextObject() as? URL {
        // Copperlight's own text only: a package (KeyboardShortcuts) brings its own translations.
        guard url.pathExtension == "stringsdata", url.path.contains("/Copperlight.build/"), let data = try? Data(contentsOf: url) else { continue }
        guard let strings = try? JSONDecoder().decode(StringsData.self, from: data) else { fail("\(url.path): can't read it") }
        for entry in strings.tables["Localizable"] ?? [] {
            comments[entry.key, default: []].formUnion([entry.comment].compactMap { $0 }.filter { !$0.isEmpty })
            if let value = entry.value { values[entry.key] = value }
        }
    }
    guard !comments.isEmpty else { fail("no .stringsdata under \(arguments[0]): build with SWIFT_EMIT_LOC_STRINGS=YES") }
    var text = "/* Every piece of text Copperlight shows, written by `make strings`: don't edit it by hand. A language's\n"
        + "   Localizable.strings has these keys, each with its translation on the right. */\n"
    for key in comments.keys.sorted() {
        text += "\n"
        if let comment = comments[key], !comment.isEmpty { // a "*/" inside would end it early
            text += "/* \(comment.sorted().joined(separator: " / ").replacing("*/", with: "* /")) */\n"
        }
        text += "\(quoted(key)) = \(quoted(values[key] ?? key));\n"
    }
    try text.write(to: URL(filePath: arguments[1]), atomically: true, encoding: .utf8)
    print("\(comments.count) lines in \(arguments[1])")

case "new":
    guard let code = CommandLine.arguments.dropFirst(2).first else { fail("new <code>: make language CODE=pt-BR") }
    let folder = resources.appending(path: "\(code).lproj")
    guard !FileManager.default.fileExists(atPath: folder.path) else { fail("\(folder.path) is already there") }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for name in files {
        try FileManager.default.copyItem(at: resources.appending(path: "en.lproj/\(name).strings"), to: folder.appending(path: "\(name).strings"))
    }
    print("\(folder.path): translate the right side of each line in its three files (TRANSLATING.md)")

case "report":
    let languages = (try FileManager.default.contentsOfDirectory(atPath: resources.path))
        .filter { $0.hasSuffix(".lproj") && $0 != "en.lproj" }.sorted()
    guard !languages.isEmpty else { fail("no languages yet: make language CODE=pt-BR") }
    for language in languages {
        print(language.replacing(".lproj", with: ""))
        for name in files {
            let english = table(resources.appending(path: "en.lproj/\(name).strings"))
            let translated = table(resources.appending(path: "\(language)/\(name).strings"))
            let missing = english.keys.filter { translated[$0] == nil }.sorted()
            let stale = translated.keys.filter { english[$0] == nil }.sorted()
            print("  \(name): \(english.count - missing.count) of \(english.count)")
            for key in missing { print("    missing: \(quoted(key))") }
            for key in stale { print("    no longer in English: \(quoted(key))") }
        }
    }

default:
    fail("english <build folder> <file> | new <code> | report")
}
