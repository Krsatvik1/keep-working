import AppKit
import CoreServices
import ServiceManagement
import SwiftUI
import WidgetKit

/// A small menu-bar agent. Its real job is to watch Claude's session files and tell the widget to refresh,
/// so progress moves within seconds instead of on WidgetKit's own slow schedule.
@main
struct KeepWorkingApp: App {
    @NSApplicationDelegateAdaptor(PulseAppDelegate.self) private var delegate
    @StateObject private var model = PulseModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: Self.logo)
        }
    }

    /// Claude's own menu-bar spark, copied in from Claude.app at build time.
    private static let logo: NSImage = {
        let img = NSImage(named: "TrayIconTemplate") ?? NSImage(systemSymbolName: "asterisk", accessibilityDescription: "Claude")!
        img.isTemplate = true
        img.size = NSSize(width: 18, height: 18)
        return img
    }()
}

/// Receives widget clicks (keepworking://open?to=…) and opens the session in Claude.
final class PulseAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let target = PulseLink.unwrap(url) { NSWorkspace.shared.open(target) }
        }
    }
}

@MainActor
final class PulseModel: ObservableObject {
    @Published private(set) var sessions: [SessionSnapshot] = []
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var watcher: FileWatcher?
    private var pending: DispatchWorkItem?
    private var lastReload = Date.distantPast

    var running: Int { sessions.filter { $0.state == .running }.count }

    init() {
        refresh()
        watcher = FileWatcher(paths: SessionStore.watchedPaths) { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        // Keeps relative times and stale "running" states honest even when no file changes.
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Coalesce bursts (a busy transcript is written many times a second) into one reload every few seconds.
    func scheduleRefresh() {
        guard pending == nil else { return }
        let wait = max(0, 4 - Date().timeIntervalSince(lastReload))
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.refresh()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: work)
    }

    func refresh() {
        lastReload = Date()
        let next = SessionStore.load(limit: 10)
        if next != sessions {
            sessions = next
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Keep Working: login item change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct MenuContent: View {
    @ObservedObject var model: PulseModel

    var body: some View {
        if model.sessions.isEmpty {
            Text("No sessions found")
        }
        ForEach(model.sessions) { s in
            Button {
                NSWorkspace.shared.open(s.url)
            } label: {
                Text(label(for: s))
            }
        }
        Divider()
        Button("Refresh widget") {
            model.refresh()
            WidgetCenter.shared.reloadAllTimelines()
        }
        Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { _ in model.toggleLaunchAtLogin() }))
        Divider()
        Button("Quit Keep Working") { NSApp.terminate(nil) }
    }

    private func label(for s: SessionSnapshot) -> String {
        let mark: String
        switch s.state {
        case .running: mark = "●"
        case .waiting: mark = "○"
        case .done: mark = "✓"
        case .idle: mark = "·"
        }
        let steps = s.stepsTotal > 0 ? "  \(s.stepsDone)/\(s.stepsTotal)" : ""
        return "\(mark)  \(s.title)\(steps)  ·  \(s.lastActivity.shortAgo)"
    }
}

/// FSEvents over a handful of folders, file-level, coalesced by the stream's own latency.
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let callback: () -> Void

    init(paths: [String], onChange: @escaping () -> Void) {
        callback = onChange
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        stream = FSEventStreamCreate(nil, { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue().callback()
        }, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)
        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
