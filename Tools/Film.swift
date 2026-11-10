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

    static let captions: [(from: Double, to: Double, text: String)] = [
        (0.5, 3.5, "Prompt Claude. Go do something else."),
        (4.2, 6.0, "It keeps working."),
        (7.7, 11.6, "Step by step."),
        (12.3, 17.4, "It snaps each new image."),
        (18.5, 21.5, "It waves when Claude needs you."),
        (21.9, 24.3, "One click back."),
        (24.6, 27.7, "Done."),
        (28.2, 31.5, "Four sizes."),
    ]

    /// Camera on the extra-large widget: (clock, scale, focus x, focus y), focus in widget points from its centre.
    static let camera: [(Double, Double, Double, Double)] = [
        (1.0, 3.3, -262, 62), (2.0, 3.3, -262, 62), (3.4, 2.3, -191, 0), (6.0, 2.36, -172, 0), (8.0, 2.36, -172, 0),
        (12.0, 2.42, -150, 0), (12.5, 2.8, -128, 14), (13.5, 2.8, -128, 14), (14.4, 2.4, -191, 0), (17.5, 2.46, -191, 0),
        (18.7, 1.9, 0, 0), (23.15, 1.9, 0, 0), (23.8, 2.3, -191, 0), (28.0, 2.4, -191, 0),
    ]

    /// The cut: which stretches of the clock make the film. It opens a second before the prompt lands, and
    /// jumps one beat of the walk.
    static let cut: [(Double, Double)] = [(1.0, 6.0), (8.0, 36.0)]
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
}

// MARK: - Frame

func ease(_ x: Double) -> Double { let x = min(1, max(0, x)); return x * x * (3 - 2 * x) }
func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double { ease((t - a) / (b - a)) }

struct FilmFrame: View {
    let t: Double

    static let ink = Color(red: 0.105, green: 0.094, blue: 0.086)
    static let paperTop = Color(red: 0.949, green: 0.925, blue: 0.886)
    static let paperBottom = Color(red: 0.894, green: 0.855, blue: 0.804)
    /// The widget sits above centre, leaving the bottom of the frame for captions.
    static let stage = CGPoint(x: 960, y: 430)

    private var tick: Int { Int((t / Beat.seconds).rounded(.down)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.paperTop, Self.paperBottom], startPoint: .top, endPoint: .bottom)
            if t < 28.15 { story.opacity(1 - ramp(t, 28.0, 28.15)) }
            if t >= 28 && t < 32.1 { sizes }
            // Captions always sit on paper, never on the widget.
            LinearGradient(colors: [Self.paperBottom.opacity(0), Self.paperBottom, Self.paperBottom],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 290).position(x: 960, y: 1080 - 145)
            caption
            cursor
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

    /// The four sizes at one scale, so their real proportions show: one at a time, each swapping into the
    /// next over eight frames, then all four together.
    private var sizes: some View {
        let all: [(WidgetFamily, CGSize)] = [
            (.systemSmall, CGSize(width: 164, height: 164)), (.systemMedium, CGSize(width: 344, height: 164)),
            (.systemLarge, CGSize(width: 344, height: 344)), (.systemExtraLarge, CGSize(width: 704, height: 344)),
        ]
        let m = Script.moment(tick)
        let step = 0.62, first = 28.05, together = first + 4 * step
        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                let start = first + step * Double(i), end = i == 3 ? together : start + step
                if t >= start - 0.02 && t < end + 0.14 {
                    chrome(all[i].1) { tile(m, all[i].0, all[i].1) }
                        .scaleEffect(2.0 * (0.94 + 0.06 * ramp(t, start, start + 0.2)))
                        .opacity(ramp(t, start, start + 0.13) * (1 - ramp(t, end, end + 0.13)))
                }
            }
            if t >= together {
                HStack(alignment: .center, spacing: 22) {
                    ForEach(0..<4, id: \.self) { i in chrome(all[i].1) { tile(m, all[i].0, all[i].1) } }
                }
                .scaleEffect(1.1 * (0.96 + 0.04 * ramp(t, together, together + 0.25)))
                .opacity(ramp(t, together, together + 0.13))
            }
        }
        .position(Self.stage)
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

    /// A pointer comes in and clicks "answer in Claude"; the camera then pushes in as the session finishes.
    @ViewBuilder private var cursor: some View {
        if t >= 21.7 && t < 23.6 {
            let k = ramp(t, 21.7, 22.75)
            let from = CGPoint(x: 1500, y: 1130), to = CGPoint(x: 766, y: 683)
            let p = CGPoint(x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * k - 70 * sin(.pi * k))
            let click = t - 23.0
            ZStack {
                if click >= 0 && click < 0.45 {
                    let g = ease(click / 0.45)
                    Circle().strokeBorder(Color.white.opacity(0.95 * (1 - g)), lineWidth: 4)
                        .frame(width: 24 + 120 * g, height: 24 + 120 * g)
                        .position(p)
                    Circle().fill(Color.white.opacity(0.35 * (1 - g))).frame(width: 40, height: 40).position(p)
                }
                Pointer().fill(Color.black)
                    .overlay(Pointer().stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)))
                    .frame(width: 13, height: 20)
                    .scaleEffect(2.5 * (click >= 0 && click < 0.14 ? 0.86 : 1), anchor: .topLeading)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    .position(x: p.x + 6.5, y: p.y + 10)
            }
            .opacity(1 - ramp(t, 23.3, 23.55))
        }
    }

    private struct Pointer: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4.5, 13), (7.5, 20), (10, 19), (7, 12.5), (13, 12.5)]
            p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
            p.closeSubpath()
            return p
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
                Text("A desktop widget for your Claude sessions.")
                    .font(.system(size: 46, weight: .regular)).tracking(-0.9).foregroundStyle(Self.ink.opacity(0.62))
                    .padding(.top, 12).opacity(show(0.24)).offset(y: rise(0.24))
                Text("github.com/Krsatvik1/keep-working")
                    .font(.system(size: 36, weight: .medium)).tracking(-0.5).foregroundStyle(Self.ink.opacity(0.45))
                    .padding(.top, 52).opacity(show(0.4)).offset(y: rise(0.4))
            }
            .offset(y: -10)
        }
    }
}

// MARK: - Render

@main
enum FilmMain {
    @MainActor static func main() {
        _ = NSApplication.shared
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--still", args.count >= 3, let t = Double(args[1]) {
            guard let cg = frame(t) else { fatalError("no frame") }
            let rep = NSBitmapImageRep(cgImage: cg)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
            return
        }
        guard let out = args.first else { print("usage: film out.mp4 [from to] | --still t out.png"); return }
        // The whole cut, or one stretch of the clock when given.
        let stretches: [(Double, Double)] = args.count > 2
            ? [(Double(args[1]) ?? 0, Double(args[2]) ?? Script.length)] : Script.cut
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
        for (from, to) in stretches {
            for i in Int((from * Double(Script.fps)).rounded())..<Int((to * Double(Script.fps)).rounded()) {
                autoreleasepool {
                    guard let cg = frame(Double(i) / Double(Script.fps)) else { return }
                    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                    pipe.fileHandleForWriting.write(Data(bytesNoCopy: ctx.data!, count: w * h * 4, deallocator: .none))
                }
                written += 1
            }
        }
        print("\(written) frames, \(Double(written) / Double(Script.fps)) s")
        try? pipe.fileHandleForWriting.close()
        ffmpeg.waitUntilExit()
        print("wrote \(out)")
    }

    @MainActor static func frame(_ t: Double) -> CGImage? {
        let r = ImageRenderer(content: FilmFrame(t: t))
        r.scale = 1
        r.isOpaque = true
        return r.cgImage
    }
}
