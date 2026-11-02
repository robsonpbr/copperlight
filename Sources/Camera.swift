import AppKit
import AVFoundation
import SwiftUI

/// The camera's card, its text ready to show.
struct CameraCard: Sendable {
    var name: String // "FaceTime HD Camera"
    var enter: String // what Enter does: "Join Google Meet", "Open Photo Booth"
    var meeting: String? // the call about to start: "Weekly sync · in 4 min"
}

/// `camera`, before a call: you, mirrored, across the card. Enter joins the meeting about to start (the one the empty
/// launcher offers), or else opens Photo Booth. Access is asked for from a row, once; nothing is recorded, and the
/// camera is on only while the card is on screen.
struct CameraProvider: ResultProvider {
    var status: @Sendable () -> AVAuthorizationStatus = { AVCaptureDevice.authorizationStatus(for: .video) }
    var device: @Sendable () -> String? = { AVCaptureDevice.default(for: .video)?.localizedName }
    var join: @Sendable () async -> LauncherResult? = { nil }

    func results(for query: String) async -> [LauncherResult] {
        let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard lower.count >= 4, "camera".hasPrefix(lower) else { return [] }
        let row = { (title: String, subtitle: String, actionTitle: String, action: @escaping @MainActor @Sendable () -> Void) in
            LauncherResult(id: "camera", title: title, subtitle: subtitle, icon: .symbol("video"), score: 50, actionTitle: actionTitle, action: action)
        }
        guard let name = device() else {
            return [row(String(localized: "This Mac has no camera"), String(localized: "Connect one, or use your iPhone's"), "", {})]
        }
        switch status() {
        case .authorized: break
        case .denied, .restricted:
            return [row(String(localized: "Allow Copperlight to use the camera"),
                        String(localized: "Privacy & Security → Camera → Copperlight",
                               comment: "System Settings' pages, by the names macOS gives them"),
                        String(localized: "Open System Settings"), {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
            })]
        default:
            return [row(String(localized: "See Yourself"), String(localized: "Asks to use the camera, once"),
                        String(localized: "Allow", comment: "Enter asks macOS for camera access"), {
                Task {
                    notify(await AVCaptureDevice.requestAccess(for: .video) ? String(localized: "Type “camera” again to see yourself")
                           : String(localized: "Copperlight can't use the camera"))
                }
            })]
        }
        let meeting = await join()
        var soon: String?
        if case .meeting(let card)? = meeting?.answer { soon = "\(card.title) · \(card.soon)" }
        let photoBooth = String(localized: "Open Photo Booth")
        let card = CameraCard(name: name, enter: meeting?.title ?? photoBooth, meeting: soon)
        return [LauncherResult(id: "camera", title: String(localized: "Camera", comment: "The camera row: you, before a call"),
                               subtitle: soon.map { String(localized: "Then Enter joins \($0)", comment: "A meeting's title · how soon") }
                                   ?? name,
                               icon: .symbol("video"), score: 50, actionTitle: meeting?.actionTitle ?? photoBooth,
                               action: meeting?.action ?? openPhotoBooth,
                               answer: .camera(card))]
    }
}

@MainActor private func openPhotoBooth() {
    NSWorkspace.shared.openApplication(at: URL(filePath: "/System/Applications/Photo Booth.app"), configuration: .init())
}

/// What the camera sees, mirrored. It runs only while its window is on screen: the launcher hides with its rows still
/// in it, and the camera's light goes off with it.
final class CameraView: NSView {
    private let session = AVCaptureSession()
    private let preview: AVCaptureVideoPreviewLayer
    private static let queue = DispatchQueue(label: "app.copperlight.camera") // starting and stopping block

    override init(frame: NSRect) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: frame)
        wantsLayer = true
        preview.videoGravity = .resizeAspectFill
        layer?.addSublayer(preview)
        if let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        preview.frame = bounds
    }

    override func viewWillMove(toWindow window: NSWindow?) {
        super.viewWillMove(toWindow: window)
        NotificationCenter.default.removeObserver(self)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        update()
    }

    @objc private func update() {
        nonisolated(unsafe) let session = session
        let on = window?.occlusionState.contains(.visible) == true
        Self.queue.async { on ? session.startRunning() : session.stopRunning() }
    }
}

/// The SwiftUI side of `CameraView`.
struct CameraPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraView { CameraView() }
    func updateNSView(_ view: CameraView, context: Context) {}
}
