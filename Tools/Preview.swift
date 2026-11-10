// Pulse Preview: the widget's own views in a window, stepping through every state, with the animation tick
// running live. Build and open with Tools/preview.sh.
//   ← / → or the side arrows: previous / next state      space: pause the tick      D: light / dark
//   --capture <dir>  saves every state at two ticks as PNGs of the window, then quits
import AppKit
import SwiftUI
import WidgetKit

struct Scenario {
    let name: String
    let note: String
    let sessions: () -> [SessionSnapshot]
    var error: String? = nil
}

enum Scenarios {
    static let all: [Scenario] = {
        let s = SessionSnapshot.samples
        func not(_ ids: String...) -> [SessionSnapshot] { s.filter { !ids.contains($0.id) } }
        return [
            Scenario(name: "Needs you", note: "A session asked you something and is waiting.", sessions: { s }),
            Scenario(name: "Working, with a task list", note: "The hero walks the steps bar; the current step pulses.",
                     sessions: { not("1") }),
            Scenario(name: "Working, no task list", note: "Running without a plan: no bar, the ring turns.",
                     sessions: { not("1", "2") }),
            Scenario(name: "Finished", note: "Wrapped up its list.", sessions: { not("1", "2", "3", "5") }),
            Scenario(name: "Paused", note: "Stopped part-way through its list.", sessions: { not("1", "2", "3", "4") }),
            Scenario(name: "Idle", note: "Nothing running: the lazy idle.", sessions: { not("1", "2", "3", "4", "5") }),
            Scenario(name: "Terminal session", note: "A session started in the terminal.",
                     sessions: { not("1", "2", "3", "4", "5", "6") }),
            Scenario(name: "No sessions", note: "Nothing found yet.", sessions: { [] }),
            Scenario(name: "Can't read", note: "Claude's session folder is missing or blocked.", sessions: { [] },
                     error: "unreadable"),
            Scenario(name: "Your sessions", note: "Live, read from this Mac right now.",
                     sessions: { SessionStore.load(limit: 10) }),
        ]
    }()
}

@MainActor
final class PreviewModel: ObservableObject {
    @Published var index = 0 { didSet { reload() } }
    @Published var tick = 0
    @Published var dark = true
    @Published var playing = true
    @Published private(set) var sessions: [SessionSnapshot] = []
    private var timer: Timer?

    var scenario: Scenario { Scenarios.all[index] }

    init() {
        reload()
        // Same beat as the widget's timeline.
        schedule()
    }

    func reload() { sessions = scenario.sessions() }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Beat.seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.playing { self.tick += 1 }
                self.schedule()
            }
        }
    }

    func step(_ d: Int) {
        let n = Scenarios.all.count
        withAnimation(Beat.morph) { index = (index + d + n) % n }
        schedule()
    }
}

struct WidgetTile: View {
    let entry: PulseEntry
    let family: WidgetFamily
    let size: CGSize
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PulseWidgetView(entry: entry, forcedFamily: family)
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(family == .systemSmall && ordered(entry.sessions).first?.state == .waiting
                            ? AnyShapeStyle(LinearGradient(colors: [Pulse.clay.opacity(0.28), Pulse.clay.opacity(0.06)],
                                                           startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.clear))
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7)).fixedSize()
        }
    }
}

struct PreviewRoot: View {
    @ObservedObject var model: PreviewModel

    var body: some View {
        let entry = PulseEntry(date: .now, sessions: model.sessions, error: model.scenario.error, tick: model.tick)
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.scenario.name).font(.system(size: 20, weight: .semibold))
                    Text(model.scenario.note).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("\(model.index + 1) of \(Scenarios.all.count) · tick \(model.tick)")
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                Button(model.playing ? "Pause" : "Play") { model.playing.toggle() }
                Button(model.dark ? "Light" : "Dark") { model.dark.toggle() }
            }
            .foregroundStyle(.white)
            HStack(spacing: 18) {
                arrow("chevron.left") { model.step(-1) }
                VStack(alignment: .leading, spacing: 22) {
                    WidgetTile(entry: entry, family: .systemExtraLarge, size: CGSize(width: 714, height: 344), label: "Extra large")
                    HStack(alignment: .top, spacing: 22) {
                        WidgetTile(entry: entry, family: .systemLarge, size: CGSize(width: 344, height: 344), label: "Large")
                        WidgetTile(entry: entry, family: .systemMedium, size: CGSize(width: 344, height: 158), label: "Medium")
                        WidgetTile(entry: entry, family: .systemSmall, size: CGSize(width: 170, height: 170), label: "Small")
                    }
                }
                .environment(\.colorScheme, model.dark ? .dark : .light)
                arrow("chevron.right") { model.step(1) }
            }
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.43, blue: 0.45), Color(red: 0.10, green: 0.33, blue: 0.36)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .fixedSize()
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 120)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Plain AppKit: one window with the SwiftUI view in it, created at launch. (A SwiftUI `App` scene sometimes
/// never opens its window when the app is started from a shell, which broke the capture modes.)
@MainActor
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    let model = PreviewModel()
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: PreviewRoot(model: model))
        window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Pulse Preview"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [model] e in
            switch e.keyCode {
            case 123: model.step(-1); return nil                    // ←
            case 124: model.step(1); return nil                     // →
            case 49: model.playing.toggle(); return nil             // space
            case 2: model.dark.toggle(); return nil                 // D
            default: return e
            }
        }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--capture"), i + 1 < args.count {
            Task { await capture(to: args[i + 1]) }
        }
        if let i = args.firstIndex(of: "--frames"), i + 2 < args.count {
            Task { await frames(scenario: Int(args[i + 1]) ?? 1, to: args[i + 2]) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func snapshot(_ path: String) {
        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// A burst while the tick plays: 64 frames 0.4 s apart (about 26 s, a full walk turn), to check the motion.
    private func frames(scenario: Int, to dir: String) async {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        model.index = max(0, scenario - 1)
        try? await Task.sleep(for: .seconds(2.5))
        let start = Date()
        for f in 0..<64 {
            snapshot(String(format: "%@/f%02d-%05d.png", dir, f, Int(Date().timeIntervalSince(start) * 1000)))
            try? await Task.sleep(for: .seconds(0.4))
        }
        NSApp.terminate(nil)
    }

    /// Snapshots the window itself (no screen-recording permission needed): each state at two ticks, both appearances.
    private func capture(to dir: String) async {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        model.playing = false
        try? await Task.sleep(for: .seconds(1))
        for dark in [true, false] {
            model.dark = dark
            for i in Scenarios.all.indices {
                model.index = i
                for t in [0, 1] {
                    model.tick = t
                    try? await Task.sleep(for: .seconds(2.2))   // let the glide finish
                    let slug = Scenarios.all[i].name.lowercased().replacingOccurrences(of: " ", with: "-")
                        .replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "'", with: "")
                    snapshot(String(format: "%@/%02d-%@-%@-t%d.png", dir, i + 1, slug, dark ? "dark" : "light", t))
                }
            }
        }
        NSApp.terminate(nil)
    }
}

@main
enum PulsePreviewMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
