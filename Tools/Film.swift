// The showcase film, rendered one frame at a time from the widget's own views (docs/video.md has the script).
// Nothing here is a screen recording: every frame draws PulseWidgetView with a scripted entry and the film's
// clock, so the widget content is exact and the motion is what the desktop plays (2 s glides between entries,
// the character's flip-book at its own frame rate, the snapshot act on a 6 s boundary).
// The tile and the backdrop are matched to the desktop, not captured from it.
//
//   Tools/film.sh out.mp4              the whole film
//   Tools/film.sh out.mp4 2 20         only seconds 2 to 20
//   Tools/film.sh --still 13.2 f.png   one frame
import AppKit
import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

// MARK: - Script

enum Script {
    static let length = 36.0
    static let fps = 60
    static let size = CGSize(width: 1920, height: 1080)

    struct Moment {
        var sessions: [SessionSnapshot]
        var act: ClawdMotion.Act? = nil
        var actTick: Int? = nil
        var image: Data? = nil
        var walk = WalkPlan()
        /// The hero's state: a change of state swaps the whole layout.
        var state: SessionState = .idle
        /// What a viewer could tell apart from one entry to the next.
        var signature: String
    }

    private static func session(_ id: String, _ title: String, _ project: String, _ kind: SessionKind = .code,
                                _ state: SessionState = .idle, ago: TimeInterval, done: Int = 0, total: Int = 0,
                                detail: String? = nil) -> SessionSnapshot {
        SessionSnapshot(id: id, title: title, project: project, kind: kind, state: state,
                        lastActivity: Date().addingTimeInterval(-ago), stepsDone: done, stepsTotal: total,
                        detail: detail, url: URL(string: "claude://code/new")!)
    }

    static var stepNames: [String] { steps }
    private static let steps = ["Audit the current page", "Sketch three layouts", "Build the plan cards",
                                "Add the annual toggle", "Check it on mobile"]
    static let question = "Ship the annual toggle, or monthly only?"

    /// The story, one entry per 2 s beat: asleep, working through five steps, a new image (the snapshot act on
    /// beats 6–8, a 6 s boundary), needs you, done; then a busy state for the sizes shot.
    /// The desktop staging (DesktopFilm) keeps one clock running through the chat scenes, so its ending
    /// comes two beats later: done holds through beats 14–15, then the sizes shot.
    static var desktop = false
    static func moment(_ raw: Int) -> Moment {
        var n = raw
        if desktop { if n == 14 || n == 15 { n = 13 } else if n >= 16 { n -= 2 } }
        var star: SessionSnapshot
        var act: ClawdMotion.Act? = nil
        var image: Data? = nil
        func working(_ done: Int) -> SessionSnapshot {
            session("star", "Pricing page redesign", "acme-site", .code, .running, ago: 2, done: done, total: 5,
                    detail: steps[min(done, 4)])
        }
        switch n {
        case ..<1: star = session("star", "Pricing page redesign", "acme-site", ago: 190)
        case 1: star = working(0)
        case 2: star = working(1)
        case 3, 4: star = working(2)
        case 5: star = working(3)
        case 6, 7: star = working(3); act = .snapshot; image = Assets.mock
        case 8: star = working(4); act = .snapshot; image = Assets.mock
        case 9...11:
            star = session("star", "Pricing page redesign", "acme-site", .code, .waiting, ago: 4, done: 5, total: 5,
                           detail: question)
            image = Assets.mock
        case 12, 13:
            star = session("star", "Pricing page redesign", "acme-site", .code, .done, ago: 3, done: 5, total: 5)
            image = Assets.mock
        case 14, 15: star = working(3); image = Assets.mock
        default:
            star = session("star", "Pricing page redesign", "acme-site", .code, .waiting, ago: 4, done: 5, total: 5,
                           detail: question)
            image = Assets.mock
        }
        let loginState: SessionState = (3...8).contains(n) || n >= 14 ? .running : n >= 9 ? .done : .idle
        let others = [
            session("login", "Fix flaky login test", "acme-app", .code, loginState, ago: loginState == .running ? 30 : 260),
            session("rank", "Search ranking tweaks", "acme-api", ago: 400, done: 2, total: 5),
            session("notes", "Release notes for 2.4", "acme-docs", .code, .done, ago: 3100, done: 3, total: 3),
            session("mail", "Onboarding email copy", "acme-app", ago: 4000),
            session("ci", "CI cache cleanup", "infra", .terminal, ago: 7800),
            session("tokens", "Design tokens cleanup", "acme-site", ago: 11_500),
            session("events", "Analytics events audit", "acme-app", ago: 19_000),
            session("brief", "Competitor research brief", "Cowork", .cowork, ago: 90_000),
            session("dark", "Dark mode polish", "acme-app", ago: 180_000),
        ]
        let sig = "\(star.state)|\(star.stepsDone)|\(star.detail ?? "")|\(loginState)"
        // The walk: the snapshot pauses it for beats 6–8, and it stands still while not working (9–13, 16 on).
        let walk: WalkPlan
        switch n {
        case ..<1: walk = WalkPlan(pausedAt: 1)
        case ..<9: walk = WalkPlan(before: 0, after: 3, actTick: 6)
        case ..<14: walk = WalkPlan(before: 0, after: 3, actTick: 6, pausedAt: 9)
        case ..<16: walk = WalkPlan(before: 5, after: 8, actTick: 6)
        default: walk = WalkPlan(before: 5, after: 8, actTick: 6, pausedAt: 16)
        }
        return Moment(sessions: [star] + others, act: act, actTick: act == nil ? nil : 6, image: image, walk: walk,
                      state: star.state, signature: sig)
    }

    /// The snapshot's flash, as the widget's timeline plays it: the old picture until 0.6 s into the act, the new
    /// one flashes in bright and soft, and from 1.0 s it settles over 1.4 s. 1 just snapped … 0 settled.
    static let actStart = 12.0
    static func develop(_ t: Double) -> Double? {
        let a = t - actStart
        guard a >= 0.6, a < 2.5 else { return nil }
        if a < 0.8 { let k = (a - 0.6) / 0.2; return 1 - (1 - k) * (1 - k) }
        if a < 1.0 { return 1 }
        let k = min(1, (a - 1.0) / 1.4)
        return (1 - k) * (1 - k)
    }
    /// The new image isn't behind the card until the flash.
    static func imageShown(_ t: Double) -> Bool { !(t >= actStart && t < actStart + 0.6) }

    /// Captions over the widget, on the widget's clock.
    static let captions: [(from: Double, to: Double, text: String)] = [
        (0.0, 1.58, "A widget for your Claude sessions."),
        (1.6, 3.6, "Go do something else."),
        (4.2, 6.0, "It keeps working."),
        (7.7, 11.6, "Step by step."),
        (12.3, 16.0, "It snaps each new image."),
        (18.4, 21.0, "It waves when Claude needs you."),
        (24.3, 26.5, "Done."),
    ]

    /// Camera on the extra-large widget: (clock, scale, focus x, focus y), focus in widget points from its centre.
    static let camera: [(Double, Double, Double, Double)] = [
        (0.0, 3.3, -262, 62), (2.0, 3.3, -262, 62), (3.4, 2.3, -191, 0), (6.0, 2.36, -172, 0), (8.0, 2.36, -172, 0),
        (12.0, 2.42, -150, 0), (12.5, 2.8, -128, 14), (13.5, 2.8, -128, 14), (14.4, 2.4, -191, 0), (16.0, 2.43, -191, 0),
        (18.0, 2.43, -191, 0), (19.0, 1.9, 0, 0), (22.0, 1.9, 0, 0), (23.6, 2.35, -191, 0), (28.0, 2.35, -191, 0),
    ]

    /// Pointer clicks on the widget: when, and where on screen (worked out from the camera at that moment).
    static let clicks: [(at: Double, to: CGPoint)] = [
        (1.5, CGPoint(x: 1470, y: 672)),     // "open in Claude" on the sleeping hero
        (21.6, CGPoint(x: 766, y: 683)),     // "answer in Claude" on the needs-you card
        (26.3, CGPoint(x: 960, y: 400)),     // the finished card
    ]

    enum Scene { case prompt, answer, response }
    /// The cut. Widget stretches run on the widget's clock; between them the film steps into the chat and back.
    enum Seg {
        case widget(Double, Double, enter: Bool, exit: Bool)
        case scene(Scene, Double)
    }
    static let cut: [Seg] = [
        .widget(0.4, 1.8, enter: false, exit: true),       // asleep; click it
        .scene(.prompt, 4.0),                              // type the prompt, send
        .widget(1.6, 6.0, enter: true, exit: false),       // back: it wakes and gets to work
        .widget(8.0, 16.0, enter: false, exit: false),     // steps, the snapshot
        .widget(18.0, 21.95, enter: false, exit: true),    // needs you; click
        .scene(.answer, 2.4),                              // pick an answer
        .widget(23.6, 26.6, enter: true, exit: true),      // done; click
        .scene(.response, 4.2),                            // what it made
        .widget(28.16, endAt + 4.4, enter: true, exit: false),   // the desktop, then the download card
    ]
    static let prompt = "Redesign the pricing page"
    /// When the desktop shot gives way to the download card, on the widget's clock.
    static var endAt = 34.0
}

/// The picture in the story: the pricing page Claude designed. Bright and colourful on purpose, so that behind
/// the widget and in the chat it reads at once as an image, not as more interface. The top is left calm (it sits
/// behind the widget's title); the page's cards fill the lower half.
struct MockImage: View {
    static let size = CGSize(width: 540, height: 560)
    private static let accents = [Color(red: 1.0, green: 0.78, blue: 0.25), Color(red: 1.0, green: 0.42, blue: 0.45),
                                  Color(red: 0.30, green: 0.85, blue: 0.68)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.20, blue: 0.70), Color(red: 0.48, green: 0.24, blue: 0.80),
                                    Color(red: 0.98, green: 0.47, blue: 0.52)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color(red: 1.0, green: 0.82, blue: 0.32)).frame(width: 150, height: 150).offset(x: 175, y: -185)
            Circle().fill(Color.white.opacity(0.14)).frame(width: 260, height: 260).offset(x: -200, y: -60)
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                VStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white).frame(width: 250, height: 18)
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.7)).frame(width: 170, height: 9)
                }
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 10) {
                            Circle().fill(Self.accents[i]).frame(width: 30, height: 30)
                            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.12)).frame(width: 72, height: 22)
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.78)).frame(height: 6)
                            }
                            RoundedRectangle(cornerRadius: 9).fill(Self.accents[i]).frame(height: 30)
                        }
                        .padding(14)
                        .frame(width: 152, height: i == 1 ? 226 : 204)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    /// The image as the chat shows it: scaled to the column, showing this much of its lower part.
    static func inChat(height: CGFloat) -> some View {
        MockImage()
            .scaleEffect(500 / size.width, anchor: .bottom)
            .frame(width: 500, height: height, alignment: .bottom)
            .clipped()
    }
}

/// The three plan cards of the made-up pricing page: behind the hero as the snapped image, and in the chat.
struct MockCards: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<3, id: \.self) { i in
                VStack(alignment: .leading, spacing: 11) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.55)).frame(width: 56, height: 9)
                    RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.9)).frame(width: 78, height: 24)
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.4)).frame(height: 6)
                    }
                    RoundedRectangle(cornerRadius: 8).fill(i == 1 ? Pulse.clay : Color(white: 0.5)).frame(height: 28)
                }
                .padding(14)
                .frame(width: 150, height: 200)
                .background(Color(white: 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(i == 1 ? Pulse.clay : Color(white: 0.45), lineWidth: i == 1 ? 2.5 : 1.5))
            }
        }
    }
}

enum Assets {
    /// A neutral stand-in for "a screenshot Claude just looked at": a pricing page wireframe.
    nonisolated(unsafe) static let mock: Data? = MainActor.assumeIsolated { makeMock() }
    @MainActor static func makeMock() -> Data? {
        _makeMock
    }
    @MainActor private static let _makeMock: Data? = {
        let view = MockImage()
        let r = ImageRenderer(content: view)
        r.scale = 1
        guard let cg = r.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }()

    static let icon: NSImage? = NSImage(contentsOfFile: "App/Resources/AppIcon-1024.png")

}

// MARK: - Frame

func ease(_ x: Double) -> Double { let x = min(1, max(0, x)); return x * x * (3 - 2 * x) }
func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double { ease((t - a) / (b - a)) }

struct FilmFrame: View {
    let t: Double
    /// Seconds since this stretch began, when it comes back from the chat; seconds left, when it goes into it.
    var enter: Double? = nil
    var exit: Double? = nil

    static let ink = Color(red: 0.105, green: 0.094, blue: 0.086)
    static let paperTop = Color(red: 0.949, green: 0.925, blue: 0.886)
    static let paperBottom = Color(red: 0.894, green: 0.855, blue: 0.804)
    /// The widget sits above centre, leaving the bottom of the frame for captions.
    static let stage = CGPoint(x: 960, y: 430)

    private var tick: Int { Int((t / Beat.seconds).rounded(.down)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.paperTop, Self.paperBottom], startPoint: .top, endPoint: .bottom)
            // Stepping into the chat pushes in on the widget; coming back pulls out to it.
            let inK = enter.map { ramp($0, 0, 0.32) } ?? 1, outK = exit.map { ramp($0, 0, 0.28) } ?? 1
            Group {
                if t < 28.0 { story }
                if t >= 28 && t < Script.endAt + 0.5 { sizes }
            }
            .scaleEffect(1 + 0.22 * (1 - inK) + 0.22 * (1 - outK))
            .opacity(inK * outK)
            // Captions always sit on paper, never on the widget.
            LinearGradient(colors: [Self.paperBottom.opacity(0), Self.paperBottom, Self.paperBottom],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 290).position(x: 960, y: 1080 - 145)
                .opacity(t < 28 ? 1 : 0)
            caption.opacity(exit.map { ramp($0, 0, 0.2) } ?? 1)
            // Coming back from the chat, the click that took us there is over.
            if enter == nil { cursor.opacity(exit.map { ramp($0, 0, 0.15) } ?? 1) } else if (enter ?? 0) > 1.0 { cursor.opacity(exit.map { ramp($0, 0, 0.15) } ?? 1) }
            if t >= Script.endAt { endCard.opacity(ramp(t, Script.endAt, Script.endAt + 0.5)) }
        }
        .frame(width: Script.size.width, height: Script.size.height)
        .clipped()
    }

    // MARK: Widget

    func tile(_ m: Script.Moment, _ family: WidgetFamily, _ size: CGSize) -> some View {
        let image = Script.imageShown(t) ? m.image : nil
        let entry = PulseEntry(date: .now, sessions: m.sessions, error: nil, tick: tick, heroImage: image,
                               act: m.act, developing: false, actTick: m.actTick, walk: m.walk)
        return PulseWidgetView(entry: entry, forcedFamily: family)
            .environment(\.filmTime, t)
            .environment(\.developAmount, image == nil ? nil : Script.develop(t))
            .padding(16)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
    }

    /// The tile the desktop draws behind a widget: measured from a frame of the real one (704 x 344, radius 27.88).
    func chrome<V: View>(_ size: CGSize, @ViewBuilder _ content: () -> V) -> some View {
        let shape = RoundedRectangle(cornerRadius: 27.88, style: .continuous)
        return ZStack {
            shape.fill(Color(white: 0.17))
            content()
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.30), radius: 26, y: 16)
    }

    /// An entry change, as the desktop shows it. A new state swaps cleanly: the old content is out in five
    /// frames and the new in over the next five, so two layouts never show at once. A new step only changes a
    /// line of text, so the two entries add up to one image and just that line dissolves.
    @ViewBuilder func content(_ family: WidgetFamily, _ size: CGSize) -> some View {
        let now = Script.moment(tick), before = Script.moment(tick - 1)
        let into = t - Double(tick) * Beat.seconds
        let changed = now.signature != before.signature
        let swap = now.state != before.state
        if !changed || into >= (swap ? 0.17 : 0.35) {
            tile(now, family, size)
        } else if swap {
            if into < 0.085 { tile(before, family, size).opacity(1 - into / 0.085) }
            else { tile(now, family, size).opacity((into - 0.085) / 0.085) }
        } else {
            let k = ease(into / 0.35)
            ZStack {
                tile(before, family, size).opacity(1 - k)
                tile(now, family, size).opacity(k).blendMode(.plusLighter)
            }
            .compositingGroup()
        }
    }

    private func widget(_ family: WidgetFamily, _ size: CGSize) -> some View {
        chrome(size) { content(family, size) }
    }

    private var story: some View {
        let cam = camera
        return widget(.systemExtraLarge, CGSize(width: 704, height: 344))
            .scaleEffect(cam.scale)
            .position(x: Self.stage.x - cam.fx * cam.scale, y: Self.stage.y - cam.fy * cam.scale)
    }

    private var camera: (scale: Double, fx: Double, fy: Double) {
        let keys = Script.camera
        guard let j = keys.firstIndex(where: { $0.0 > t }) else { let l = keys.last!; return (l.1, l.2, l.3) }
        guard j > 0 else { let f = keys[0]; return (f.1, f.2, f.3) }
        let a = keys[j - 1], b = keys[j]
        let k = ease((t - a.0) / (b.0 - a.0))
        return (a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k, a.3 + (b.3 - a.3) * k)
    }

    /// The four sizes where they live: a stock Mac desktop, shown as a screen, with the widgets tiling into
    /// its top-left corner one after another at true size. Then all four turn to "needs you" together.
    private var sizes: some View {
        let desk = MacDesktop.size
        let k = 1500 / desk.width
        let slots: [(WidgetFamily, CGSize, CGPoint, Double)] = [
            (.systemExtraLarge, CGSize(width: 704, height: 344), CGPoint(x: 24, y: 46), 28.6),
            (.systemLarge, CGSize(width: 344, height: 344), CGPoint(x: 24, y: 406), 29.15),
            (.systemMedium, CGSize(width: 344, height: 164), CGPoint(x: 384, y: 406), 29.7),
            (.systemSmall, CGSize(width: 164, height: 164), CGPoint(x: 384, y: 586), 30.25),
        ]
        let waiting = Script.moment(tick).state == .waiting && t - Double(tick) * Beat.seconds >= 0.085
        let screen = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .topLeading) {
            MacDesktop()
            ForEach(0..<slots.count, id: \.self) { i in
                let (family, size, at, start) = slots[i]
                // Each tile drops into its slot and settles with a small overshoot.
                let x = min(1, max(0, (t - start) / 0.42)), back = 1 + 2.3 * pow(x - 1, 3) + 1.3 * pow(x - 1, 2)
                chrome(size) {
                    // The small widget has no inner card, so its whole tile takes the clay.
                    if family == .systemSmall && waiting {
                        LinearGradient(colors: [Pulse.clay.opacity(0.28), Pulse.clay.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                    }
                    content(family, size)
                }
                .scaleEffect(0.88 + 0.12 * back)
                .opacity(ramp(t, start, start + 0.16))
                .offset(x: at.x, y: at.y - 22 * (1 - back))
            }
        }
        .frame(width: desk.width, height: desk.height, alignment: .topLeading)
        .clipped()
        .scaleEffect(k)
        .frame(width: desk.width * k, height: desk.height * k)
        .clipShape(screen)
        .padding(11)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 22)
        // A slow drift, then a push in on the widgets once all four have landed.
        .scaleEffect(1 + 0.03 * ramp(t, 28.2, Script.endAt) + 0.3 * ramp(t, 30.9, 32.2), anchor: UnitPoint(x: 0.16, y: 0.3))
        .position(x: 960, y: 532)
    }

    // MARK: Captions, cursor, end card

    @ViewBuilder private var caption: some View {
        ForEach(Array(Script.captions.enumerated()), id: \.offset) { _, c in
            if t >= c.from && t < c.to {
                let k = ramp(t, c.from, c.from + 0.3) * (1 - ramp(t, c.to - 0.25, c.to))
                Text(c.text)
                    .font(.system(size: 68, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(Self.ink)
                    .opacity(k)
                    .position(x: 960, y: 912 + 16 * (1 - ramp(t, c.from, c.from + 0.3)))
            }
        }
    }

    /// A pointer comes in and clicks the widget; the film then steps into the chat.
    @ViewBuilder private var cursor: some View {
        ForEach(Array(Script.clicks.enumerated()), id: \.offset) { _, c in
            if t >= c.at - 1.1 && t < c.at + 0.6 {
                PointerMark(from: CGPoint(x: c.to.x + 520, y: c.to.y + 470), to: c.to,
                            k: ramp(t, c.at - 1.0, c.at - 0.1), click: t - c.at)
            }
        }
    }

    /// The character trots on, under the name.
    var endCard: some View {
        let base = Script.endAt + 0.4
        let rise = { (d: Double) in 18 * (1 - ramp(t, base + d, base + 0.5 + d)) }
        let show = { (d: Double) in ramp(t, base + d, base + 0.5 + d) }
        let fps = ClawdMotion.fps(.working)
        return ZStack {
            LinearGradient(colors: [Self.paperTop, Self.paperBottom], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                ClawdSprite(mood: .working, t: (t * fps).rounded(.down) / fps, px: 15, walking: true)
                    .environment(\.colorScheme, .light)
                    .frame(height: 240, alignment: .bottom)
                    .opacity(show(0)).offset(y: rise(0))
                Text("Keep Working")
                    .font(.system(size: 124, weight: .bold)).tracking(-4.6).foregroundStyle(Self.ink)
                    .padding(.top, 26).opacity(show(0.12)).offset(y: rise(0.12))
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 34, weight: .semibold))
                    Text("Download for macOS").font(.system(size: 42, weight: .semibold)).tracking(-0.9)
                }
                .foregroundStyle(Self.paperTop)
                .padding(.horizontal, 40).frame(height: 96)
                .background(Self.ink, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.top, 44).opacity(show(0.24)).offset(y: rise(0.24))
                Text("github.com/Krsatvik1/keep-working")
                    .font(.system(size: 36, weight: .medium)).tracking(-0.5).foregroundStyle(Self.ink.opacity(0.5))
                    .padding(.top, 30).opacity(show(0.4)).offset(y: rise(0.4))
            }
            .offset(y: -10)
        }
    }
}

// MARK: - A stock Mac desktop

/// A plain Mac desktop put together from this Mac's own system files: a stock wallpaper, the stock Dock apps'
/// real icons, a standard menu bar, and a few files down the right-hand side. Nothing personal in it.
struct MacDesktop: View {
    static let size = CGSize(width: 1440, height: 900)

    private static let wallpaper = NSImage(contentsOfFile: "build/film-assets/wallpaper.jpg")
    private static let apps: [NSImage] = [
        "/System/Library/CoreServices/Finder.app", "/System/Applications/Apps.app", "/Applications/Safari.app",
        "/System/Applications/Messages.app", "/System/Applications/Mail.app", "/System/Applications/Maps.app",
        "/System/Applications/Photos.app", "/System/Applications/FaceTime.app", "/System/Applications/Calendar.app",
        "/System/Applications/Contacts.app", "/System/Applications/Reminders.app", "/System/Applications/Notes.app",
        "/System/Applications/Freeform.app", "/System/Applications/TV.app", "/System/Applications/Music.app",
        "/System/Applications/App Store.app", "/System/Applications/System Settings.app",
    ].filter { FileManager.default.fileExists(atPath: $0) }.map { NSWorkspace.shared.icon(forFile: $0) }
    private static let downloads = NSWorkspace.shared.icon(for: .folder)
    private static let trash = NSImage(named: NSImage.trashEmptyName)
    private static let head = NSImage(contentsOfFile: "App/Resources/MenuIconTemplate@2x.png")

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let w = Self.wallpaper {
                Image(nsImage: w).resizable().interpolation(.high).scaledToFill()
                    .frame(width: Self.size.width, height: Self.size.height).clipped()
            } else {
                LinearGradient(colors: [Color(red: 0.2, green: 0.45, blue: 0.75), Color(red: 0.5, green: 0.3, blue: 0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            menuBar
            files
            dock
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private var menuBar: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 15, weight: .medium))
            Text("Finder").font(.system(size: 13.5, weight: .bold))
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0).font(.system(size: 13.5, weight: .medium)) }
            Spacer(minLength: 0)
            if let head = Self.head {
                Image(nsImage: head).renderingMode(.template).resizable().frame(width: 18, height: 18)
            }
            Image(systemName: "battery.100percent").font(.system(size: 17))
            Image(systemName: "wifi").font(.system(size: 14, weight: .semibold))
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .semibold))
            Image(systemName: "switch.2").font(.system(size: 13, weight: .semibold))
            Text("Wed 11 Nov  9:41 AM").font(.system(size: 13.5, weight: .medium))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
        .padding(.horizontal, 16)
        .frame(width: Self.size.width, height: 26)
        .background(Color.black.opacity(0.10))
    }

    private func icon(_ image: NSImage?, _ side: CGFloat) -> some View {
        Group {
            if let image { Image(nsImage: image).resizable().interpolation(.high) } else { Color.clear }
        }
        .frame(width: side, height: side)
    }

    private var dock: some View {
        HStack(spacing: 3) {
            ForEach(Array(Self.apps.enumerated()), id: \.offset) { i, app in
                icon(app, 52).overlay(alignment: .bottom) {
                    if i == 0 { Circle().fill(Color.white.opacity(0.85)).frame(width: 4, height: 4).offset(y: 5) }
                }
            }
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1, height: 44).padding(.horizontal, 7)
            icon(Self.downloads, 52)
            icon(Self.trash, 52)
        }
        .padding(.horizontal, 8).padding(.top, 5).padding(.bottom, 8)
        .background(Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6))
        .frame(width: Self.size.width, height: Self.size.height - 7, alignment: .bottom)
    }

    /// Where files usually end up: down the right-hand edge.
    private var files: some View {
        VStack(spacing: 22) {
            file(NSWorkspace.shared.icon(for: .folder), "Projects")
            file(NSWorkspace.shared.icon(for: .folder), "Screenshots")
            file(NSWorkspace.shared.icon(for: .png), "pricing-v2.png")
        }
        .frame(width: 110)
        .offset(x: Self.size.width - 122, y: 46)
    }

    private func file(_ image: NSImage, _ name: String) -> some View {
        VStack(spacing: 4) {
            icon(image, 62)
            Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
        }
    }
}

// MARK: - Pointer

struct PointerMark: View {
    let from: CGPoint, to: CGPoint
    /// 0…1 along the way in; seconds since the click (negative before it).
    let k: Double, click: Double

    var body: some View {
        let p = CGPoint(x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * k - 70 * sin(.pi * k))
        ZStack {
            if click >= 0 && click < 0.45 {
                let g = ease(click / 0.45)
                Circle().strokeBorder(Color.white.opacity(0.95 * (1 - g)), lineWidth: 4)
                    .frame(width: 24 + 120 * g, height: 24 + 120 * g).position(p)
                Circle().fill(Color.white.opacity(0.35 * (1 - g))).frame(width: 40, height: 40).position(p)
            }
            Arrow().fill(Color.black)
                .overlay(Arrow().stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)))
                .frame(width: 13, height: 20)
                .scaleEffect(2.5 * (click >= 0 && click < 0.14 ? 0.86 : 1), anchor: .topLeading)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                .position(x: p.x + 6.5, y: p.y + 10)
        }
    }

    private struct Arrow: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4.5, 13), (7.5, 20), (10, 19), (7, 12.5), (13, 12.5)]
            p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - The chat

/// The other half of the story: the chat you prompt, answer and read. A plain stand-in window, not a copy of
/// the Claude app: its session list and marks are the widget's own, so the two halves stay in step.
struct SceneFrame: View {
    let scene: Script.Scene
    let u: Double      // seconds into the scene
    let d: Double      // its length

    /// Laid out small and drawn a third larger, so its text reads at video size.
    static let win = CGSize(width: 1020, height: 585)
    private static let zoom = 4.0 / 3
    private static let sent = 2.55, picked = 1.25

    var body: some View {
        let k = ramp(u, 0, 0.32) * (1 - ramp(u, d - 0.28, d))
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            LinearGradient(colors: [FilmFrame.paperTop, FilmFrame.paperBottom], startPoint: .top, endPoint: .bottom)
            HStack(spacing: 0) { sidebar; main }
                .frame(width: Self.win.width, height: Self.win.height)
                .background(Color(white: 0.15))
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.32), radius: 40, y: 22)
                .environment(\.colorScheme, .dark)
                .environment(\.filmTime, u)
                .environment(\.pulseTick, Int(u / Beat.seconds))
                .scaleEffect(Self.zoom * (0.86 + 0.14 * k))
                .opacity(k)
                .position(x: 960, y: 440)
            Text(caption)
                .font(.system(size: 68, weight: .semibold)).tracking(-1.1).foregroundStyle(FilmFrame.ink)
                .opacity(ramp(u, 0.25, 0.55) * (1 - ramp(u, d - 0.4, d - 0.15)))
                .position(x: 960, y: 912)
            if scene == .answer && u < Self.picked + 0.6 {
                PointerMark(from: CGPoint(x: 1380, y: 900), to: CGPoint(x: 843, y: 506),
                            k: ramp(u, 0.3, 1.15), click: u - Self.picked)
                    .opacity(k)
            }
        }
        .frame(width: Script.size.width, height: Script.size.height)
        .clipped()
    }

    /// The window alone, at its own size: the desktop staging places it over the desktop itself.
    var window: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 0) { sidebar; main }
            .frame(width: Self.win.width, height: Self.win.height)
            .background(Color(white: 0.15))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 34, y: 18)
            .environment(\.colorScheme, .dark)
            .environment(\.filmTime, u)
            .environment(\.pulseTick, Int(u / Beat.seconds))
    }

    private var caption: String {
        switch scene { case .prompt: return "Prompt Claude."; case .answer: return "Answer in a click."; case .response: return "See what it made." }
    }

    /// Which beat of the widget's story the session list shows.
    private var moment: Script.Moment {
        switch scene {
        case .prompt: return Script.moment(u < Self.sent ? 0 : 1)
        case .answer: return Script.moment(u < Self.picked ? 9 : 5)
        case .response: return Script.moment(12)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.white.opacity(0.2)).frame(width: 13, height: 13) }
            }
            .padding(.bottom, 26)
            Text("Sessions").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                .padding(.leading, 10).padding(.bottom, 6)
            ForEach(Array(moment.sessions.prefix(9).enumerated()), id: \.offset) { i, s in
                HStack(spacing: 10) {
                    RingMark(s: s, size: 15)
                    Text(s.title).font(.system(size: 15, weight: i == 0 ? .semibold : .regular)).lineLimit(1)
                        .foregroundStyle(.white.opacity(i == 0 ? 0.95 : 0.55))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10).frame(height: 36)
                .background(i == 0 ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 264, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.115))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                switch scene {
                case .prompt: promptChat
                case .answer: answerChat
                case .response: responseChat
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            promptBox
        }
        .frame(width: 620)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Pricing page redesign").font(.system(size: 24, weight: .semibold)).tracking(-0.4).foregroundStyle(.white.opacity(0.95))
            Text("acme-site").font(.system(size: 15)).foregroundStyle(.white.opacity(0.45))
        }
    }

    private func bubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 0)
            Text(text).font(.system(size: 20)).foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// A line of reply text, drawn as a bar that writes itself in.
    private func line(_ width: CGFloat, at start: Double) -> some View {
        RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.16))
            .frame(width: max(0, width * ramp(u, start, start + 0.3)), height: 13)
            .frame(width: width, alignment: .leading)
            .opacity(u >= start ? 1 : 0)
    }

    private func working(at start: Double, steps: Bool) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                RingMark(s: Script.moment(3).sessions[1], size: 18)
                Text("Working").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            }
            .opacity(ramp(u, start, start + 0.2))
            if steps {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 12) {
                        Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5).frame(width: 14, height: 14)
                        Text(Script.stepNames[i]).font(.system(size: 17)).foregroundStyle(.white.opacity(0.6))
                    }
                    .opacity(ramp(u, start + 0.12 + 0.09 * Double(i), start + 0.3 + 0.09 * Double(i)))
                }
            }
        }
    }

    // You type the prompt and send it; the session starts on its five steps.
    @ViewBuilder private var promptChat: some View {
        header
        if u >= Self.sent {
            bubble(Script.prompt)
                .opacity(ramp(u, Self.sent, Self.sent + 0.22)).offset(y: 26 * (1 - ramp(u, Self.sent, Self.sent + 0.3)))
            working(at: 2.95, steps: true)
        }
    }

    // It has stopped on a question; one click answers it.
    @ViewBuilder private var answerChat: some View {
        // The picture Claude has already read, scrolled half out of the top of the chat.
        MockImage.inChat(height: 122)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous))
        VStack(alignment: .leading, spacing: 12) { line(520, at: -1); line(450, at: -1); line(320, at: -1) }
        VStack(alignment: .leading, spacing: 16) {
            Text(Script.question).font(.system(size: 22, weight: .semibold)).tracking(-0.3).foregroundStyle(.white.opacity(0.95))
            HStack(spacing: 12) {
                chip("Annual toggle", chosen: u >= Self.picked)
                chip("Monthly only", chosen: false)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Pulse.clay.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Pulse.clay.opacity(0.55), lineWidth: 1.5))
        if u >= Self.picked + 0.2 { working(at: Self.picked + 0.2, steps: false) }
    }

    private func chip(_ text: String, chosen: Bool) -> some View {
        Text(text).font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(chosen ? 1 : 0.85))
            .padding(.horizontal, 18).frame(height: 44)
            .background(chosen ? Pulse.clay : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // The reply: text writing itself in, the redesign it made, and the images it attached.
    @ViewBuilder private var responseChat: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                RingMark(s: Script.moment(12).sessions[0], size: 18)
                Text("Finished · 5 of 5 steps").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.75))
            }
            .opacity(ramp(u, 0.3, 0.5))
            VStack(alignment: .leading, spacing: 12) { line(520, at: 0.5); line(590, at: 0.64); line(430, at: 0.78) }
            MockImage.inChat(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .scaleEffect(0.95 + 0.05 * ramp(u, 1.15, 1.5), anchor: .topLeading)
                .opacity(ramp(u, 1.15, 1.4))
            VStack(alignment: .leading, spacing: 12) { line(540, at: 1.95); line(380, at: 2.09) }
            HStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { i in
                    HStack(spacing: 8) {
                        Image(systemName: "photo").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.2)).frame(width: i == 0 ? 96 : 74, height: 10)
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(ramp(u, 2.45 + 0.12 * Double(i), 2.65 + 0.12 * Double(i)))
                }
            }
        }
    }

    private var promptBox: some View {
        let typing = scene == .prompt && u < Self.sent
        let n = typing ? max(0, min(Script.prompt.count, Int((u - 0.6) / 0.056))) : 0
        let caretOn = typing && Int(u * 2.4) % 2 == 0
        let press = scene == .prompt && u >= Self.sent - 0.12 && u < Self.sent + 0.06
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.07))
            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            HStack(spacing: 1) {
                if n == 0 && !typing {
                    Text("Reply to Claude").font(.system(size: 20)).foregroundStyle(.white.opacity(0.32))
                } else {
                    Text(String(Script.prompt.prefix(n))).font(.system(size: 20)).foregroundStyle(.white.opacity(0.95))
                    Rectangle().fill(Color.white.opacity(caretOn ? 0.9 : 0)).frame(width: 2, height: 24)
                }
            }
            .padding(.horizontal, 22).padding(.top, 20)
            Circle().fill(n > 0 || press ? Pulse.clay : Color.white.opacity(0.16))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white))
                .scaleEffect(press ? 0.84 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(14)
        }
        .frame(height: 92)
    }
}

// MARK: - The film, staged on the desktop

/// The same story, but it never leaves the Mac: the widget sits in the top-left corner of a stock desktop from
/// the first frame, the chat opens over that desktop beside it and closes again, and the other three sizes
/// land under it at the end. One clock runs throughout (`w`, the widget's clock; the film starts at -2 so the
/// prompt is sent just as the widget's own beat 1 wakes it).
struct DesktopFilm: View {
    let w: Double

    static let cut: [(Double, Double)] = [(-2, 6), (8, 16), (18, 42.4)]
    static let endAt = 38.0
    private static let stageY = 430.0
    private static let slot = CGPoint(x: 24, y: 46)                 // the extra-large widget, in desktop points
    private static let xl = CGSize(width: 704, height: 344)
    private static let chat = CGRect(x: 350, y: 70, width: 750, height: 430)

    /// Camera: (clock, scale, the desktop point held at the middle of the stage).
    private static let keys: [(Double, Double, Double, Double)] = [
        (-2.0, 1.0417, 720, 352), (-0.9, 1.07, 715, 350),             // the whole screen
        (-0.3, 1.7, 575, 273), (3.0, 1.7, 575, 273),                  // hero on the left, chat on the right
        (3.7, 2.3, 400, 218), (6.0, 2.36, 404, 218), (8.0, 2.36, 404, 218), (12.0, 2.42, 392, 218),
        (12.5, 2.8, 335, 232), (13.5, 2.8, 335, 232), (14.4, 2.4, 396, 218), (16.0, 2.43, 396, 218),
        (18.0, 2.43, 396, 218), (19.0, 2.1, 440, 240), (21.6, 2.1, 440, 240),
        (22.1, 1.7, 575, 273), (24.3, 1.7, 575, 273), (24.9, 2.35, 398, 218), (26.4, 2.35, 398, 218),
        (26.9, 1.7, 575, 273), (30.7, 1.7, 575, 273),
        (31.6, 1.0417, 720, 352), (34.3, 1.06, 716, 350), (35.5, 1.5, 540, 316), (38.0, 1.54, 540, 316),
    ]
    /// Clicks, in desktop points.
    private static let clicks: [(at: Double, p: CGPoint)] = [
        (-1.0, CGPoint(x: 274, y: 351)),      // "open in Claude" on the sleeping hero
        (21.6, CGPoint(x: 274, y: 351)),      // "answer in Claude"
        (23.05, CGPoint(x: 660, y: 321)),     // the answer chip, in the chat
        (26.3, CGPoint(x: 185, y: 205)),      // the finished card
    ]
    /// The chat's three visits: scene, when it opens and closes, and the point it grows from.
    private static let visits: [(scene: Script.Scene, open: Double, close: Double, from: CGPoint)] = [
        (.prompt, -0.70, 3.35, CGPoint(x: 274, y: 351)),
        (.answer, 21.8, 24.65, CGPoint(x: 274, y: 351)),
        (.response, 26.55, 31.0, CGPoint(x: 185, y: 205)),
    ]
    private static let captions: [(from: Double, to: Double, text: String)] = [
        (-2.2, -0.75, "A widget for your Claude sessions."),
        (-0.5, 1.9, "Prompt Claude."),
        (2.2, 4.7, "Go do something else."),
        (4.9, 6.0, "It keeps working."),
        (7.7, 11.7, "Step by step."),
        (12.3, 16.0, "It snaps each new image."),
        (18.4, 21.4, "It waves when Claude needs you."),
        (21.9, 23.9, "Answer in a click."),
        (24.25, 26.45, "Done."),
        (26.8, 30.6, "See what it made."),
        (32.2, 37.7, "Four sizes."),
    ]

    private var camera: (s: Double, fx: Double, fy: Double) {
        let keys = Self.keys
        guard let j = keys.firstIndex(where: { $0.0 > w }) else { let l = keys.last!; return (l.1, l.2, l.3) }
        guard j > 0 else { let f = keys[0]; return (f.1, f.2, f.3) }
        let a = keys[j - 1], b = keys[j]
        let k = ease((w - a.0) / (b.0 - a.0))
        return (a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k, a.3 + (b.3 - a.3) * k)
    }

    /// Where a desktop point is on screen right now.
    private func onScreen(_ p: CGPoint) -> CGPoint {
        let c = camera
        return CGPoint(x: 960 + (p.x - c.fx) * c.s, y: Self.stageY + (p.y - c.fy) * c.s)
    }

    var body: some View {
        let film = FilmFrame(t: w)
        return ZStack {
            LinearGradient(colors: [FilmFrame.paperTop, FilmFrame.paperBottom], startPoint: .top, endPoint: .bottom)
            if w < Self.endAt + 0.5 { desktop(film) }
            caption
            pointer
            if w >= Self.endAt { film.endCard.opacity(ramp(w, Self.endAt, Self.endAt + 0.5)) }
        }
        .frame(width: Script.size.width, height: Script.size.height)
        .clipped()
    }

    private func desktop(_ film: FilmFrame) -> some View {
        let c = camera
        let size = MacDesktop.size
        let extra: [(WidgetFamily, CGSize, CGPoint, Double)] = [
            (.systemLarge, CGSize(width: 344, height: 344), CGPoint(x: 24, y: 406), 32.6),
            (.systemMedium, CGSize(width: 344, height: 164), CGPoint(x: 384, y: 406), 33.15),
            // Beside the big one, top right: clear of the caption at the bottom of the frame.
            (.systemSmall, CGSize(width: 164, height: 164), CGPoint(x: 744, y: 46), 33.7),
        ]
        let waiting = Script.moment(Int((w / Beat.seconds).rounded(.down))).state == .waiting
        return ZStack(alignment: .topLeading) {
            MacDesktop()
            film.chrome(Self.xl) { film.content(.systemExtraLarge, Self.xl) }
                .offset(x: Self.slot.x, y: Self.slot.y)
            ForEach(0..<extra.count, id: \.self) { i in
                let (family, tile, at, start) = extra[i]
                if w >= start {
                    // Each of the other sizes drops into its slot and settles with a small overshoot.
                    let x = min(1, max(0, (w - start) / 0.42)), back = 1 + 2.3 * pow(x - 1, 3) + 1.3 * pow(x - 1, 2)
                    film.chrome(tile) {
                        if family == .systemSmall && waiting {
                            LinearGradient(colors: [Pulse.clay.opacity(0.28), Pulse.clay.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                        }
                        film.content(family, tile)
                    }
                    .scaleEffect(0.88 + 0.12 * back)
                    .opacity(ramp(w, start, start + 0.16))
                    .offset(x: at.x, y: at.y - 22 * (1 - back))
                }
            }
            ForEach(0..<Self.visits.count, id: \.self) { i in
                let v = Self.visits[i]
                if w >= v.open && w < v.close {
                    // The window grows out of the spot that was clicked, and goes back into the widget.
                    let k = ramp(w, v.open, v.open + 0.36) * (1 - ramp(w, v.close - 0.3, v.close))
                    let zoom = Self.chat.width / SceneFrame.win.width
                    SceneFrame(scene: v.scene, u: w - v.open, d: 99).window
                        .scaleEffect(zoom * (0.12 + 0.88 * k))
                        .opacity(min(1, k * 3))
                        .position(x: v.from.x + (Self.chat.midX - v.from.x) * k, y: v.from.y + (Self.chat.midY - v.from.y) * k)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .padding(10)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 22)
        .scaleEffect(c.s)
        .position(x: 960 + (size.width / 2 - c.fx) * c.s, y: Self.stageY + (size.height / 2 - c.fy) * c.s)
    }

    /// Captions ride on a dark pill, since the backdrop is now a wallpaper.
    @ViewBuilder private var caption: some View {
        ForEach(Array(Self.captions.enumerated()), id: \.offset) { _, c in
            if w >= c.from && w < c.to {
                let inK = ramp(w, c.from, c.from + 0.28)
                Text(c.text)
                    .font(.system(size: 54, weight: .semibold)).tracking(-0.8)
                    .foregroundStyle(FilmFrame.paperTop)
                    .padding(.horizontal, 36).frame(height: 98)
                    .background(FilmFrame.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                    .opacity(inK * (1 - ramp(w, c.to - 0.22, c.to)))
                    .position(x: 960, y: 972 + 16 * (1 - inK))
            }
        }
    }

    @ViewBuilder private var pointer: some View {
        ForEach(Array(Self.clicks.enumerated()), id: \.offset) { _, c in
            if w >= c.at - 1.05 && w < c.at + 0.5 {
                let to = onScreen(c.p)
                PointerMark(from: CGPoint(x: to.x + 430, y: to.y + 400), to: to,
                            k: ramp(w, c.at - 0.95, c.at - 0.1), click: w - c.at)
                    .opacity(1 - ramp(w, c.at + 0.3, c.at + 0.5))
            }
        }
    }
}

// MARK: - Render

@main
enum FilmMain {
    @MainActor static func main() {
        _ = NSApplication.shared
        let all = Array(CommandLine.arguments.dropFirst())
        if all.first == "--desktop-still", all.count >= 3, let w = Double(all[1]) {
            Script.desktop = true; Script.endAt = DesktopFilm.endAt
            guard let cg = render(DesktopFilm(w: w)) else { fatalError("no frame") }
            try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: all[2]))
            return
        }
        let staged = all.first == "--desktop"
        if staged { Script.desktop = true; Script.endAt = DesktopFilm.endAt }
        let args = staged ? Array(all.dropFirst()) : all
        if args.first == "--scene", args.count >= 4, let u = Double(args[2]) {
            let scene: Script.Scene = args[1] == "answer" ? .answer : args[1] == "response" ? .response : .prompt
            let length = args[1] == "answer" ? 2.4 : args[1] == "response" ? 4.2 : 4.0
            guard let cg = render(SceneFrame(scene: scene, u: u, d: length)) else { fatalError("no frame") }
            try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
            return
        }
        if args.first == "--still", args.count >= 3, let t = Double(args[1]) {
            guard let cg = frame(t) else { fatalError("no frame") }
            let rep = NSBitmapImageRep(cgImage: cg)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
            return
        }
        guard let out = args.first else { print("usage: film out.mp4 [from to] | --still t out.png"); return }
        // The whole cut, or one stretch of the widget's clock when given.
        let cut: [Script.Seg] = args.count > 2
            ? [.widget(Double(args[1]) ?? 0, Double(args[2]) ?? 36, enter: false, exit: false)] : Script.cut
        let w = Int(Script.size.width), h = Int(Script.size.height)

        let ffmpeg = Process()
        ffmpeg.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        ffmpeg.arguments = ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(w)x\(h)",
                            "-r", "\(Script.fps)", "-i", "-", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "15",
                            "-pix_fmt", "yuv420p", "-movflags", "+faststart", out]
        let pipe = Pipe()
        ffmpeg.standardInput = pipe
        try! ffmpeg.run()

        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!
        var written = 0
        func write(_ cg: CGImage?) {
            guard let cg else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            pipe.fileHandleForWriting.write(Data(bytesNoCopy: ctx.data!, count: w * h * 4, deallocator: .none))
            written += 1
        }
        let f = Double(Script.fps)
        if staged {
            for (from, to) in DesktopFilm.cut {
                for i in Int((from * f).rounded())..<Int((to * f).rounded()) {
                    autoreleasepool { write(render(DesktopFilm(w: Double(i) / f))) }
                }
            }
        }
        for seg in staged ? [] : cut {
            switch seg {
            case let .widget(from, to, enter, exit):
                for i in Int((from * f).rounded())..<Int((to * f).rounded()) {
                    let t = Double(i) / f
                    autoreleasepool { write(render(FilmFrame(t: t, enter: enter ? t - from : nil, exit: exit ? to - t : nil))) }
                }
            case let .scene(scene, length):
                for i in 0..<Int((length * f).rounded()) {
                    autoreleasepool { write(render(SceneFrame(scene: scene, u: Double(i) / f, d: length))) }
                }
            }
        }
        print("\(written) frames, \(Double(written) / Double(Script.fps)) s")
        try? pipe.fileHandleForWriting.close()
        ffmpeg.waitUntilExit()
        print("wrote \(out)")
    }

    @MainActor static func frame(_ t: Double) -> CGImage? { render(FilmFrame(t: t)) }

    @MainActor static func render<V: View>(_ view: V) -> CGImage? {
        let r = ImageRenderer(content: view)
        r.scale = 1
        r.isOpaque = true
        return r.cgImage
    }
}
