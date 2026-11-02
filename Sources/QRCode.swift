import AppKit
import CoreImage.CIFilterBuiltins

/// `text` as a QR code, black on white with a white border, sharp at 600 pixels or more. nil when it's more than a
/// QR code holds (about 2,000 characters).
func qrCode(_ text: String) -> CGImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let code = filter.outputImage, code.extent.width > 0 else { return nil }
    let scale = (600 / code.extent.width).rounded(.up) // whole pixels a square, so its edges stay sharp
    let big = code.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let framed = big.extent.insetBy(dx: -2 * scale, dy: -2 * scale)
    return CIContext().createCGImage(big.composited(over: CIImage(color: .white).cropped(to: framed)), from: framed)
}

/// `qr https://copperlight.app`: the QR code for what's typed after it, or for what you copied, big in the QR Code chip
/// (Tab), with what you can do with it beside it: copy the picture (Enter), save it to Downloads, copy the text. Made on
/// the Mac: nothing is sent anywhere.
struct QRCodeProvider: ResultProvider {
    private static let icon = LauncherResult.Icon.symbol("qrcode")
    private let clipboard: @Sendable () async -> String?
    var modes: [Mode] {
        [Mode(prefix: "qr ", title: String(localized: "QR Code"), icon: Self.icon,
              hint: String(localized: "Text or a link, or nothing for what you copied"))]
    }

    init(clipboard: @escaping @Sendable () async -> String? = { @MainActor in Clip.current(withHTML: false).text }) {
        self.clipboard = clipboard
    }

    /// Outside the chip, a row that opens it: "qr" alone, or with the text it's for.
    func results(for query: String) async -> [LauncherResult] {
        let lower = query.lowercased()
        let offer = { (title: String, completion: String) in
            [LauncherResult(id: "builtin:qr", title: title,
                            subtitle: completion == "qr " ? String(localized: "Type text or a link, or use what you copied") : "", icon: Self.icon,
                            score: 50, actionTitle: String(localized: "Show", comment: "Enter on a row that opens the QR Code chip"), action: {},
                            completion: completion)]
        }
        if lower.count >= 2, "qr code".hasPrefix(lower) { return offer(String(localized: "QR Code"), "qr ") }
        guard lower.hasPrefix("qr ") else { return [] }
        return offer(String(localized: "QR Code for “\(oneLine(query.dropFirst(3).trimmingCharacters(in: .whitespaces)))”"), query)
    }

    func modeResults(for query: String) async -> [LauncherResult] {
        let typed = query.dropFirst(3).trimmingCharacters(in: .whitespaces)
        let text = typed.isEmpty ? await clipboard()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" : typed
        let note = { (title: String, subtitle: String) in
            [LauncherResult(id: "qr", title: title, subtitle: subtitle, icon: Self.icon, score: 50, actionTitle: "", action: {})]
        }
        guard !text.isEmpty else { return note(String(localized: "Type text or a link"), String(localized: "Or copy some first")) }
        guard let code = qrCode(text) else {
            return note(String(localized: "Too long for a QR code"), String(localized: "It holds about 2,000 characters"))
        }
        let kicker = typed.isEmpty ? String(localized: "QR code · from the clipboard") : String(localized: "QR code")
        let answer = Answer.picture(code, kicker: kicker, title: oneLine(text), subtitle: String(localized: "Made on your Mac"))
        let link = URL(string: text).map { ["http", "https"].contains($0.scheme?.lowercased() ?? "") && !text.contains(" ") } ?? false
        let copy = String(localized: "Copy", comment: "Enter on a QR code's row")
        let save = String(localized: "Save", comment: "Enter on a QR code's row: saves it to Downloads")
        let rows: [(id: String, title: String, symbol: String, actionTitle: String, action: @MainActor @Sendable () -> Void)] = [
            ("qr", String(localized: "Copy Picture"), "doc.on.doc", copy, { copyPicture(code) }),
            ("qr:save", String(localized: "Save to Downloads"), "square.and.arrow.down", save, {
                let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacing(":", with: ".")
                let file = URL.downloadsDirectory.appending(path: "QR Code \(stamp).png")
                do {
                    try NSBitmapImageRep(cgImage: code).representation(using: .png, properties: [:])?.write(to: file)
                    NSWorkspace.shared.activateFileViewerSelecting([file])
                } catch { notify(String(localized: "Couldn't save the QR code"), error.localizedDescription) }
            }),
            ("qr:text", link ? String(localized: "Copy Link") : String(localized: "Copy Text"), link ? "link" : "text.alignleft", copy,
             { copyToClipboard(text) }),
        ]
        return rows.enumerated().map { index, row in
            LauncherResult(id: row.id, title: row.title, icon: .symbol(row.symbol), score: 50 - Double(index) / 100, actionTitle: row.actionTitle,
                           action: row.action, answer: answer)
        }
    }
}

/// As PNG, and TIFF for apps that only take that.
@MainActor func copyPicture(_ image: CGImage) {
    let item = NSPasteboardItem()
    let bitmap = NSBitmapImageRep(cgImage: image)
    bitmap.representation(using: .png, properties: [:]).map { _ = item.setData($0, forType: .png) }
    bitmap.tiffRepresentation.map { _ = item.setData($0, forType: .tiff) }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([item])
}

/// The picture with its corners rounded, for the preview pane.
@MainActor func roundedPicture(_ image: CGImage) -> NSImage {
    NSImage(size: NSSize(width: image.width, height: image.height), flipped: false) { rect in
        NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.04, yRadius: rect.width * 0.04).addClip()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSGraphicsContext.current?.cgContext.draw(image, in: rect)
        return true
    }
}
