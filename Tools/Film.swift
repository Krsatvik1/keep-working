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
    static func moment(_ n: Int) -> Moment {
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
        default: star = working(3); image = Assets.mock
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
        return Moment(sessions: [star] + others, act: act, actTick: act == nil ? nil : 6, image: image,
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
        .widget(28.16, 36.0, enter: true, exit: false),    // sizes, end card
    ]
    static let prompt = "Redesign the pricing page"
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
        // Dark, like the card it sits behind, and kept to the lower part so nothing lands behind the title.
        let view = VStack(spacing: 0) {
            Spacer(minLength: 0)
            MockCards()
            .padding(.bottom, 54)
        }
        .frame(width: 540, height: 560)
        .background(Color(white: 0.1))
        let r = ImageRenderer(content: view)
        r.scale = 1
        guard let cg = r.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }()

    static let icon: NSImage? = NSImage(contentsOfFile: "App/Resources/AppIcon-1024.png")
    /// A capture of the desktop the sizes shot plays on. Personal, so it stays in the ignored build folder.
    static let desktop: NSImage? = NSImage(contentsOfFile: "build/film-assets/desktop.jpg")
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
                if t >= 28 && t < 32.1 { sizes }
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
            if t >= 31.6 { endCard.opacity(ramp(t, 31.6, 32.1)) }
        }
        .frame(width: Script.size.width, height: Script.size.height)
        .clipped()
    }

    // MARK: Widget

    private func tile(_ m: Script.Moment, _ family: WidgetFamily, _ size: CGSize) -> some View {
        let image = Script.imageShown(t) ? m.image : nil
        let entry = PulseEntry(date: .now, sessions: m.sessions, error: nil, tick: tick, heroImage: image,
                               act: m.act, developing: false, actTick: m.actTick)
        return PulseWidgetView(entry: entry, forcedFamily: family)
            .environment(\.filmTime, t)
            .environment(\.developAmount, image == nil ? nil : Script.develop(t))
            .padding(16)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
    }

    /// The tile the desktop draws behind a widget: measured from a frame of the real one (704 x 344, radius 27.88).
    private func chrome<V: View>(_ size: CGSize, @ViewBuilder _ content: () -> V) -> some View {
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
    private func widget(_ family: WidgetFamily, _ size: CGSize) -> some View {
        let now = Script.moment(tick), before = Script.moment(tick - 1)
        let into = t - Double(tick) * Beat.seconds
        let changed = now.signature != before.signature
        let swap = now.state != before.state
        return chrome(size) {
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

    /// The four sizes where they live: a capture of a real Mac desktop (build/film-assets/desktop.jpg, kept out
    /// of git), shown as a screen, with the widgets tiling into its corner one after another at true size.
    private var sizes: some View {
        let desk = CGSize(width: 1372, height: 888)      // the desktop, in points
        let screenWidth = 1500.0, k = screenWidth / desk.width
        let slots: [(WidgetFamily, CGSize, CGPoint, Double)] = [
            (.systemExtraLarge, CGSize(width: 704, height: 344), CGPoint(x: 652, y: 40), 28.55),
            (.systemLarge, CGSize(width: 344, height: 344), CGPoint(x: 652, y: 400), 29.0),
            (.systemMedium, CGSize(width: 344, height: 164), CGPoint(x: 1012, y: 400), 29.45),
            (.systemSmall, CGSize(width: 164, height: 164), CGPoint(x: 1012, y: 580), 29.9),
        ]
        let m = Script.moment(tick)
        let screen = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .topLeading) {
            if let img = Assets.desktop {
                Image(nsImage: img).resizable().interpolation(.high).frame(width: desk.width, height: desk.height)
            } else {
                Color(red: 0.33, green: 0.47, blue: 0.24).frame(width: desk.width, height: desk.height)
            }
            ForEach(0..<slots.count, id: \.self) { i in
                let (family, size, at, start) = slots[i]
                // Each tile drops into its slot and settles with a small overshoot.
                let x = min(1, max(0, (t - start) / 0.42)), back = 1 + 2.3 * pow(x - 1, 3) + 1.3 * pow(x - 1, 2)
                chrome(size) { tile(m, family, size) }
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
        .scaleEffect(1 + 0.03 * ramp(t, 28.2, 31.6) + 0.24 * ramp(t, 30.45, 31.5), anchor: UnitPoint(x: 0.86, y: 0.26))
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
    private var endCard: some View {
        let rise = { (d: Double) in 18 * (1 - ramp(t, 32.0 + d, 32.5 + d)) }
        let show = { (d: Double) in ramp(t, 32.0 + d, 32.5 + d) }
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
    private static let win = CGSize(width: 1020, height: 585)
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
        header
        bubble(Script.prompt)
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
            MockCards()
                .scaleEffect(0.84)
                .frame(width: 500, height: 200)
                .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
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

// MARK: - Render

@main
enum FilmMain {
    @MainActor static func main() {
        _ = NSApplication.shared
        let args = Array(CommandLine.arguments.dropFirst())
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
        for seg in cut {
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
