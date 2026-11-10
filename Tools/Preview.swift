// Keep Working Preview: the widget's own views in a window, stepping through every state, with the animation tick
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
    /// Character mode: just the creature, every mood looping, at a chosen frame rate.
    @Published var character = true
    /// The image-arrives options page (I), shown over everything else while on.
    @Published var arrivals = true
    @Published var fps = 24
    @Published private(set) var sessions: [SessionSnapshot] = []
    private var timer: Timer?

    var scenario: Scenario { Scenarios.all[index] }

    init() {
        reload()
        // Same beat as the widget's timeline.
        schedule()
    }

    @Published private(set) var heroImage: Data?
    func reload() {
        sessions = scenario.sessions()
        heroImage = ordered(sessions).first?.transcript.flatMap { SessionStore.lastImage(transcript: $0) }
    }

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
        if model.arrivals { ArrivalGallery(model: model) }
        else if model.character { CharacterGallery(model: model) } else { widgets }
    }

    @ViewBuilder private var widgets: some View {
        let entry = PulseEntry(date: .now, sessions: model.sessions, error: model.scenario.error, tick: model.tick,
                               heroImage: model.heroImage)
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
                Button("Character") { model.character = true }
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
        window.title = "Keep Working Preview"
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
            case 8: model.arrivals = false; model.character.toggle(); return nil   // C
            case 34: model.arrivals.toggle(); return nil            // I
            case 3: model.fps = [12, 24, 60].first { $0 > model.fps } ?? 12; return nil   // F
            default: return e
            }
        }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--capture"), i + 1 < args.count {
            Task { await capture(to: args[i + 1]) }
        }
        if let i = args.firstIndex(of: "--acts"), i + 1 < args.count {
            actSheets(to: args[i + 1]); NSApp.terminate(nil)
        }
        if let i = args.firstIndex(of: "--sheets"), i + 1 < args.count {
            sheets(to: args[i + 1]); NSApp.terminate(nil)
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

    /// Every frame of the three image-arrival acts at 24 fps, for filmstrips and review.
    private func actSheets(to dir: String) {
        for act in ClawdMotion.Act.allCases {
            let sub = "\(dir)/\(act.rawValue)"
            try? FileManager.default.createDirectory(atPath: sub, withIntermediateDirectories: true)
            for i in 0..<Int(ClawdMotion.actLength * 24) {
                let view = ClawdSprite(mood: .working, t: Double(i) / 24, px: 6, act: act)
                    .padding(8).background(Color(white: 0.17)).environment(\.colorScheme, .dark)
                let r = ImageRenderer(content: view)
                r.scale = 2
                if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: URL(fileURLWithPath: String(format: "%@/f%03d.png", sub, i)))
                }
            }
        }
    }

    /// Exact frames of every mood loop, rendered off-screen at 24 fps, for filmstrips and review.
    private func sheets(to dir: String) {
        for dark in [false, true] {
            for (name, mood, walking) in CharacterGallery.loops {
                let sub = "\(dir)/\(dark ? "dark" : "light")-\(name)"
                try? FileManager.default.createDirectory(atPath: sub, withIntermediateDirectories: true)
                for i in 0..<Int(CharacterGallery.loopLength(mood) * 24) {
                    let view = ClawdSprite(mood: mood, t: Double(i) / 24, px: 6, walking: walking)
                        .padding(8)
                        .background(dark ? Color(white: 0.17) : Color(white: 0.93))
                        .environment(\.colorScheme, dark ? .dark : .light)
                    let r = ImageRenderer(content: view)
                    r.scale = 2
                    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                        try? rep.representation(using: .png, properties: [:])?
                            .write(to: URL(fileURLWithPath: String(format: "%@/f%03d.png", sub, i)))
                    }
                }
            }
        }
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
        model.character = false
        model.arrivals = false
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

// MARK: - Character gallery

/// Just the creature: every mood looping side by side, the walk along a bar, and a mood change, at 12, 24 or
/// 60 frames a second. Pose comes from wall-clock time, the way the desktop flip-book would cut it.
struct CharacterGallery: View {
    @ObservedObject var model: PreviewModel

    static let loops: [(String, Mood, Bool)] = [("working", .working, true), ("looking-about", .working, false),
                                               ("needs-you", .waiting, true), ("done", .done, true),
                                               ("paused", .resting, true), ("asleep", .sleeping, true)]
    static func loopLength(_ m: Mood) -> Double { ClawdMotion.loop(m) }

    var body: some View {
        TimelineView(.animation(paused: !model.playing)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            let t = model.fps >= 60 ? now : (now * Double(model.fps)).rounded(.down) / Double(model.fps)
            VStack(alignment: .leading, spacing: 18) {
                header
                HStack(spacing: 16) {
                    tile("Working", "trots along the bar", .working, t)
                    tile("Needs you", "hops, waves, ?", .waiting, t)
                    tile("Done", "jump, spin, land", .done, t)
                }
                HStack(spacing: 16) {
                    tile("Paused", "sits, glances, stretches", .resting, t)
                    tile("Asleep", "breathes, z's", .sleeping, t)
                    tile("At the end of the bar", "stops, looks about", .working, t, walking: false)
                }
                HStack(spacing: 16) {
                    walkTile(now: now, t: t)
                    switchTile(now: now, t: t)
                }
            }
            .environment(\.colorScheme, model.dark ? .dark : .light)
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.43, blue: 0.45), Color(red: 0.10, green: 0.33, blue: 0.36)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .fixedSize()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Character").font(.system(size: 20, weight: .semibold))
                Text("Every mood looping. F: frame rate, D: light/dark, C: back to the widget.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Picker("", selection: $model.fps) {
                Text("12 fps").tag(12); Text("24 fps").tag(24); Text("60 fps").tag(60)
            }
            .pickerStyle(.segmented).frame(width: 210)
            Button(model.playing ? "Pause" : "Play") { model.playing.toggle() }
            Button(model.dark ? "Light" : "Dark") { model.dark.toggle() }
            Button("Widget") { model.character = false }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func card<C: View>(_ title: String, _ note: String, width: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .frame(width: width, height: 190)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(note).font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white).fixedSize()
        }
    }

    private func tile(_ title: String, _ note: String, _ mood: Mood, _ t: Double, walking: Bool = true) -> some View {
        card(title, note, width: 230) {
            ClawdSprite(mood: mood, t: t, px: 7, walking: walking).offset(y: 4)
        }
    }

    /// The hero's walk: constant-speed travel (a timeline glide on the desktop) with the trot looping on top,
    /// a stop at each end to look about, and an edge-on turn.
    private func walkTile(now: Double, t: Double) -> some View {
        let px: CGFloat = 6, w: CGFloat = 520
        let sprite = ClawdSprite.size(px: px).width
        let run = w - 32 - sprite
        // Speed matched to the stride so the feet plant instead of sliding: two cells per cycle.
        let walkTime = Double(run) / (2 * Double(px) / ClawdMotion.stride)
        let stop = 2.4, period = 2 * (walkTime + stop)
        let u = now.truncatingRemainder(dividingBy: period)
        var x = 0.0, walking = true, turn = 1.0
        switch u {
        case ..<walkTime: x = u / walkTime
        case ..<(walkTime + stop): x = 1; walking = false; turn = cos(.pi * ClawdMotion.ramp(u - walkTime, 1.0, 1.4))
        case ..<(2 * walkTime + stop): x = 1 - (u - walkTime - stop) / walkTime; turn = -1
        default: x = 0; walking = false; turn = -cos(.pi * ClawdMotion.ramp(u - 2 * walkTime - stop, 1.0, 1.4))
        }
        return card("On the bar", "walk, stop, look, turn, walk back", width: w) {
            VStack(alignment: .leading, spacing: 2) {
                ClawdSprite(mood: .working, t: t, px: px, walking: walking, turn: turn)
                    .offset(x: CGFloat(x) * run)
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { i in
                        Capsule().fill(Color.primary.opacity(i < 3 ? 0.55 : 0.15)).frame(height: 4)
                    }
                }
            }
            .padding(16)
        }
    }

    /// A change of mood: on the desktop this is the glide between two timeline entries, so a short crossfade.
    private func switchTile(now: Double, t: Double) -> some View {
        let order: [Mood] = [.working, .waiting, .done, .resting, .sleeping]
        let hold = 4.0
        let k = now / hold
        let i = Int(k) % order.count
        let fade = ClawdMotion.ramp((k - k.rounded(.down)) * hold, 0, 0.35)
        return card("Mood change", "crossfade between moods", width: 230) {
            ZStack {
                ClawdSprite(mood: order[(i + order.count - 1) % order.count], t: t, px: 7).opacity(1 - fade)
                ClawdSprite(mood: order[i], t: t, px: 7).opacity(fade)
            }
            .offset(y: 4)
        }
    }
}


// MARK: - Image arrives: three options

/// Three ways the hero could greet a new image, each on a hero-sized card, looping: working, the image arrives
/// and the character reacts, back to work with the image settled behind. Only moves the desktop can play are
/// used: the act is a flip-book, and the image's entrance is one glide (fade, scale, offset or blur).
struct ArrivalGallery: View {
    @ObservedObject var model: PreviewModel

    static let cycle = 12.0, actStart = 2.0
    /// A real image from your sessions when there is one, so the options are judged on real material.
    static let image: NSImage? = {
        for s in ordered(SessionStore.load(limit: 10)) {
            if let p = s.transcript, let d = SessionStore.lastImage(transcript: p), let img = NSImage(data: d) { return img }
        }
        return nil
    }()

    var body: some View {
        TimelineView(.animation(paused: !model.playing)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            let fps = Double(model.fps)
            let q = model.fps >= 60 ? now : (now * fps).rounded(.down) / fps
            VStack(alignment: .leading, spacing: 18) {
                header
                HStack(alignment: .top, spacing: 18) {
                    option("A  Magnifier", "Image fades in; it inspects it through a glass", .magnify, now: now, q: q)
                    option("B  Look up", "Image drops in; it startles, then reads it", .lookUp, now: now, q: q)
                    option("C  Snapshot", "It takes the picture; the image develops", .snapshot, now: now, q: q)
                }
            }
            .environment(\.colorScheme, model.dark ? .dark : .light)
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.43, blue: 0.45), Color(red: 0.10, green: 0.33, blue: 0.36)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .fixedSize()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("A new image arrives").font(.system(size: 20, weight: .semibold))
                Text("Each card loops: working, the image comes in and it reacts, back to work. I: this page, C: character, F: frame rate.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Picker("", selection: $model.fps) {
                Text("12 fps").tag(12); Text("24 fps").tag(24); Text("60 fps").tag(60)
            }
            .pickerStyle(.segmented).frame(width: 210)
            Button(model.playing ? "Pause" : "Play") { model.playing.toggle() }
            Button(model.dark ? "Light" : "Dark") { model.dark.toggle() }
            Button("Character") { model.arrivals = false; model.character = true }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func option(_ title: String, _ note: String, _ act: ClawdMotion.Act, now: Double, q: Double) -> some View {
        let u = now.truncatingRemainder(dividingBy: Self.cycle)
        let a = u - Self.actStart                     // seconds into the act
        let inAct = a >= 0 && a < ClawdMotion.actLength
        // On the desktop a mood change is a short crossfade between flip-books; same here.
        let fadeIn = ClawdMotion.ramp(a, -0.3, 0.3), fadeOut = ClawdMotion.ramp(a, ClawdMotion.actLength - 0.3, ClawdMotion.actLength + 0.3)
        let actOpacity = fadeIn - fadeOut
        let qa = q.truncatingRemainder(dividingBy: Self.cycle) - Self.actStart
        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06))
                background(act, a: a, u: u)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Circle().strokeBorder(Color.secondary, lineWidth: 2).frame(width: 12, height: 12)
                        Text(inAct ? "Working · reading an image" : "Working · now").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("macOS home widget for chat progress").font(.system(size: 17, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 0)
                    ZStack(alignment: .bottomLeading) {
                        ClawdSprite(mood: .working, t: q, px: 4.5, walking: true).opacity(1 - actOpacity)
                        ClawdSprite(mood: .working, t: max(0, min(ClawdMotion.actLength, qa)), px: 4.5, act: act).opacity(actOpacity)
                    }
                    .offset(x: 40)
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule().fill(Color.primary.opacity(i < 2 ? 0.55 : 0.15)).frame(height: 4)
                        }
                    }
                    HStack { Text("portfolio_2"); Spacer(); Text("2 of 5 steps") }
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(note).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white)
        }
    }

    /// The image's entrance for each option. On the desktop each is a single glide at the entry change.
    @ViewBuilder private func background(_ act: ClawdMotion.Act, a: Double, u: Double) -> some View {
        let leaving = ClawdMotion.ramp(u, Self.cycle - 0.8, Self.cycle)   // reset before the next loop
        let r = { (x: Double, b: Double, e: Double) in ClawdMotion.ramp(x, b, e) }
        Group {
            if let img = Self.image {
                let base = Image(nsImage: img).resizable().scaledToFill()
                switch act {
                case .magnify:
                    let k = r(a, 0.2, 1.1)
                    Color.clear.overlay(base.scaleEffect(1.08 - 0.08 * k)).opacity(0.16 * k)
                case .lookUp:
                    let k = r(a, 0.0, 0.7)
                    // A drop with a small overshoot, as a spring glide would give.
                    let drop = 1 - k + 0.06 * sin(.pi * k)
                    Color.clear.overlay(base.offset(y: -120 * drop)).opacity(0.16 * min(1, k * 2))
                case .snapshot:
                    let dev = r(a, 0.65, 2.2)
                    ZStack {
                        Color.clear.overlay(base.blur(radius: 6 * (1 - dev))).opacity(a < 0.65 ? 0 : 0.16 + 0.3 * (1 - dev))
                        Color.white.opacity(a > 0.62 && a < 1.3 ? 0.35 * (1 - r(a, 0.62, 1.3)) : 0)
                    }
                }
            } else {
                Color.clear
            }
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        .opacity(1 - leaving)
        .allowsHitTesting(false)
    }
}
