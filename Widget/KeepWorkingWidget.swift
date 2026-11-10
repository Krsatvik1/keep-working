import AppKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct PulseEntry: TimelineEntry {
    let date: Date
    let sessions: [SessionSnapshot]
    let error: String?
    /// Counts up between entries; poses, pulses and the spinning ring animate from one value to the next.
    var tick = 0
    /// The hero session's last image, small, shown faded behind the hero.
    var heroImage: Data? = nil
}

/// A widget can't loop an animation. It can only animate from one timeline entry to the next, so the
/// timeline is a run of identical entries one beat apart, and every animated value glides for the whole
/// beat to its next keyframe. Motion never snaps and holds; it keeps moving, like a slow loop.
enum Beat {
    static let seconds: TimeInterval = 2
    /// Back-and-forth values (bob, sway, breathing): eased, so a ping-pong reads as a sine.
    static let ease = Animation.easeInOut(duration: seconds * 1.1)
    /// Travel and spin: constant speed.
    static let linear = Animation.linear(duration: seconds * 1.1)
    /// A change of state: one smooth morph.
    static let morph = Animation.smooth(duration: 0.9)
}

struct PulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, sessions: SessionSnapshot.samples, error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        var base = load()
        let beat = Beat.seconds
        // The first entry shows now, so it carries now's beat. (It used to carry tick 0, and since the app
        // reloads every few seconds while a session works, the walker kept snapping back to the start.)
        base.tick = Int((base.date.timeIntervalSince1970 / beat).rounded(.down))
        let count = 20                        // 40 s of 2 s beats. Each entry carries every flip-book frame, and macOS rejects a timeline archive much past ~5–10 MB; the app reloads on every session change anyway
        let start = (base.date.timeIntervalSince1970 / beat).rounded(.up) * beat
        let entries = (0..<count).map { i -> PulseEntry in
            let t = start + Double(i) * beat
            return PulseEntry(date: Date(timeIntervalSince1970: t), sessions: base.sessions, error: base.error,
                              tick: Int(t / beat), heroImage: base.heroImage)
        }
        // The menu-bar app also nudges a reload whenever a session file changes.
        completion(Timeline(entries: [base] + entries, policy: .after(entries.last!.date)))
    }

    private func load() -> PulseEntry {
        let sessions = SessionStore.load(limit: 10)
        let image = ordered(sessions).first?.transcript.flatMap { SessionStore.lastImage(transcript: $0) }
        return PulseEntry(date: .now, sessions: sessions, error: sessions.isEmpty ? SessionStore.lastError : nil,
                          heroImage: image)
    }
}

private struct TickKey: EnvironmentKey { static let defaultValue = 0 }
private struct HeroImageKey: EnvironmentKey { static let defaultValue: Data? = nil }
extension EnvironmentValues {
    var heroImage: Data? {
        get { self[HeroImageKey.self] }
        set { self[HeroImageKey.self] = newValue }
    }
    var pulseTick: Int {
        get { self[TickKey.self] }
        set { self[TickKey.self] = newValue }
    }
}

// MARK: - Palette (clay is reserved for "needs you")

enum Pulse {
    static let clay = Color(red: 0.851, green: 0.467, blue: 0.341)
    static let green = dynamic(light: (0.20, 0.55, 0.32), dark: (0.42, 0.76, 0.53))
    /// Question text on the clay card.
    static let clayText = dynamic(light: (0.62, 0.27, 0.15), dark: (0.965, 0.80, 0.745))
    /// The "Needs you" chip.
    static let clayLabel = dynamic(light: (0.56, 0.24, 0.12), dark: (0.94, 0.725, 0.647))

    static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

// MARK: - Derived state

extension SessionSnapshot {
    /// Not running, list unfinished: it stopped part-way.
    var isPaused: Bool { state == .idle && stepsTotal > 0 && stepsDone < stepsTotal }
    var isActive: Bool { state == .running || state == .waiting }

    /// "2/4 · now", "terminal · 1d", "6m"
    var trailing: String {
        if stepsTotal > 0 { return "\(stepsDone)/\(stepsTotal) · \(lastActivity.shortAgo)" }
        switch kind {
        case .terminal: return "terminal · \(lastActivity.shortAgo)"
        case .cowork: return "cowork · \(lastActivity.shortAgo)"
        case .code: return lastActivity.shortAgo
        }
    }

    /// The inline "· …" after a list title.
    var inlineDetail: String? {
        switch state {
        case .waiting: return detail
        case .running: return detail ?? "working"
        default: return isPaused ? "paused" : nil
        }
    }
}

/// Urgent first (needs you, then running), then most recent.
func ordered(_ sessions: [SessionSnapshot]) -> [SessionSnapshot] {
    let rank: [SessionState: Int] = [.waiting: 0, .running: 1, .done: 2, .idle: 2]
    return sessions.sorted {
        let (a, b) = (rank[$0.state] ?? 3, rank[$1.state] ?? 3)
        if a != b { return a < b }
        if $0.state == .running, ($0.stepsTotal > 0) != ($1.stepsTotal > 0) { return $0.stepsTotal > 0 }
        return $0.lastActivity > $1.lastActivity
    }
}

extension SessionKind {
    var label: String {
        switch self {
        case .code: return "Code"
        case .cowork: return "Cowork"
        case .terminal: return "Terminal"
        }
    }
}

// MARK: - Marks

/// The 16pt mark in front of a list row. Each state differs by shape, not only colour.
struct RingMark: View {
    @Environment(\.pulseTick) private var tick
    let s: SessionSnapshot
    var size: CGFloat = 16

    var body: some View {
        let line = size / 8
        let ring = Circle().inset(by: line)
        ZStack {
            switch s.state {
            case .waiting:
                Circle().fill(Pulse.clay).padding(size * 0.22)
                Circle().stroke(Pulse.clay.opacity(tick % 2 == 0 ? 0.45 : 0.12), lineWidth: size * 0.18)
                    .padding(size * 0.13)
                    .scaleEffect(tick % 2 == 0 ? 0.85 : 1.15)
            case .running where s.stepsTotal > 0:
                ring.stroke(Color.primary.opacity(0.16), lineWidth: line)
                ring.trim(from: 0, to: max(0.06, s.progress ?? 0))
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            case .running:
                ring.stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: line, dash: [size / 5, size / 5]))
                ring.trim(from: 0, to: 0.25)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90 + Double(tick) * 120))
                    .animation(Beat.linear, value: tick)
            case .done:
                ring.stroke(Pulse.green, lineWidth: line)
                Image(systemName: "checkmark").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(Pulse.green)
            case .idle where s.isPaused:
                ring.stroke(Color.primary.opacity(0.16), lineWidth: line)
                ring.trim(from: 0, to: s.progress ?? 0)
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            case .idle where s.kind == .terminal:
                Image(systemName: "terminal").font(.system(size: size * 0.62)).foregroundStyle(.secondary)
            case .idle:
                Circle().fill(Color.secondary).frame(width: size * 0.32, height: size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .animation(Beat.ease, value: tick)
    }
}

/// One segment per step: done ones solid, the current one half, the rest a faint track.
struct StepSegments: View {
    @Environment(\.pulseTick) private var tick
    let s: SessionSnapshot
    var height: CGFloat = 4

    var body: some View {
        let total = s.stepsTotal
        Group {
            if total == 0 {
                Capsule().fill(Color.primary.opacity(0.1))
            } else if total > 14 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.14))
                        Capsule().fill(fill).frame(width: max(height, g.size.width * (s.progress ?? 0)))
                    }
                }
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<max(total, 1), id: \.self) { i in
                        Capsule().fill(i < s.stepsDone ? fill : (i == s.stepsDone && s.state == .running ? fill.opacity(tick % 2 == 0 ? 0.25 : 0.8) : Color.primary.opacity(0.14)))
                    }
                }
            }
        }
        .frame(height: height)
        .animation(Beat.ease, value: tick)
    }

    private var fill: Color { s.state == .idle ? Color.secondary : Color.primary }
}

// MARK: - The character (the Claude Code block creature)

/// What the character is doing; one per session state.
enum Mood: String, Hashable { case working, waiting, done, resting, sleeping }


extension SessionSnapshot {
    var mood: Mood {
        switch state {
        case .running: return .working
        case .waiting: return .waiting
        case .done: return .done
        case .idle: return isPaused ? .resting : .sleeping
        }
    }
}

/// Drawn on the terminal glyph's grid: 18 half-cells wide, 5 half-rows tall, plus 2 rows of headroom
/// for raised arms, jumps and the "?"/"z" marks. Every part is always present so a pose change animates
/// as parts moving, not as a cut.
struct Clawd: View {
    @Environment(\.pulseTick) private var envTick
    let mood: Mood
    /// Overrides the timeline's tick (render harness).
    var tick: Int? = nil
    /// Width of one half-cell in points; a half-row is 1.7× taller, like a monospace glyph.
    var px: CGFloat = 5
    /// Mirrors the creature (not its "?"/"z") so it faces the way it walks.
    var facingLeft = false

    static let cols: CGFloat = 20
    static let head: CGFloat = 4      // headroom rows for raised arms, jumps and marks
    static func size(px: CGFloat) -> CGSize { CGSize(width: cols * px, height: (head + 5) * (px * 1.7).rounded()) }

    private var t: Int { tick ?? envTick }
    private var py: CGFloat { (px * 1.7).rounded() }
    private var lazy: Bool { mood == .resting || mood == .sleeping }

    var body: some View {
        let p = pose
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(p.solid.enumerated()), id: \.offset) { _, c in cell(c, p.lift) }
                cell(Part(x: 18, y: 1, w: 1, h: 2), p.lift).opacity(p.cursor)
                // Eyes are holes, so whatever is behind the card shows through.
                ForEach(Array(p.eyes.enumerated()), id: \.offset) { _, c in cell(c, p.lift).blendMode(.destinationOut) }
            }
            .frame(width: Self.cols * px, height: (Self.head + 5) * py, alignment: .topLeading)
            .compositingGroup()
            .scaleEffect(x: facingLeft ? -1 : 1, anchor: .center)
            // "?" and "z" on a square pixel grid of their own, so they match the creature.
            ForEach(Array(p.marks.enumerated()), id: \.offset) { _, m in
                glyph(m.bits, unit: px * m.scale)
                    .opacity(m.opacity)
                    .offset(x: markX(m) * px, y: (m.y + Self.head) * py)
            }
        }
        .foregroundStyle(color)
        .frame(width: Self.cols * px, height: (Self.head + 5) * py, alignment: .topLeading)
        .animation(Beat.ease, value: t)
        .animation(Beat.morph, value: mood)
        .accessibilityHidden(true)
    }

    /// A mark keeps reading the right way round; only its place mirrors with the body.
    private func markX(_ m: Mark) -> CGFloat {
        guard facingLeft else { return m.x }
        let w = CGFloat(m.bits.first?.count ?? 0) * m.scale
        return Self.cols - m.x - w
    }

    private var color: AnyShapeStyle {
        switch mood {
        case .waiting: return AnyShapeStyle(Pulse.clay)   // clay stays reserved for "needs you"
        case .working, .done: return AnyShapeStyle(Color.primary.opacity(0.85))
        case .resting, .sleeping: return AnyShapeStyle(Color.secondary.opacity(0.8))
        }
    }

    private func cell(_ c: Part, _ lift: CGFloat) -> some View {
        Rectangle()
            .frame(width: c.w * px, height: max(0, c.h) * py)
            .offset(x: c.x * px, y: (c.y + lift + Self.head) * py)
    }

    private func glyph(_ rows: [String], unit: CGFloat) -> some View {
        Canvas { ctx, _ in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() where ch == "1" {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit)),
                             with: .foreground)
                }
            }
        }
        .frame(width: CGFloat(rows.first?.count ?? 0) * unit, height: CGFloat(rows.count) * unit)
    }

    private static let question = ["0110", "1001", "0001", "0010", "0000", "0010"]
    private static let zed = ["1111", "0010", "0100", "1111"]

    private struct Part { var x: CGFloat; var y: CGFloat; var w: CGFloat; var h: CGFloat }
    private struct Mark { var bits: [String]; var x: CGFloat; var y: CGFloat; var scale: CGFloat = 0.7; var opacity: Double = 1 }

    /// Fixed slots, so every pose has the same parts and a change animates as parts moving.
    private struct Pose {
        var lift: CGFloat = 0
        var armL = Part(x: 1, y: 2, w: 2, h: 1)
        var armR = Part(x: 15, y: 2, w: 2, h: 1)
        var extraL = Part(x: 1, y: 2, w: 0, h: 0)     // forearm / hand
        var extraR = Part(x: 16, y: 2, w: 0, h: 0)
        var hand = Part(x: 16, y: 2, w: 0, h: 0)
        var cursor: Double = 0      // the blinking block's opacity
        var legs: [CGFloat] = [1, 1, 1, 1]
        var eyes: [Part] = Pose.openEyes(dx: 0, y: 1, h: 1)
        var marks: [Mark] = []

        static func openEyes(dx: CGFloat, y: CGFloat, h: CGFloat) -> [Part] {
            [Part(x: 5 + dx, y: y, w: 1, h: h), Part(x: 12 + dx, y: y, w: 1, h: h),
             Part(x: 5, y: 1.5, w: 0, h: 0), Part(x: 12, y: 1.5, w: 0, h: 0)]
        }
        /// ^ ^ : two low pixels with a raised one between, per eye.
        static let happyEyes: [Part] = [Part(x: 4, y: 1.5, w: 1, h: 0.5), Part(x: 11, y: 1.5, w: 1, h: 0.5),
                                        Part(x: 5, y: 1, w: 1, h: 0.5), Part(x: 12, y: 1, w: 1, h: 0.5),
                                        Part(x: 6, y: 1.5, w: 1, h: 0.5), Part(x: 13, y: 1.5, w: 1, h: 0.5)]

        var solid: [Part] {
            [Part(x: 3, y: 0, w: 12, h: 4), armL, armR, extraL, extraR, hand] +
            zip([4.0, 6, 11, 13], legs).map { Part(x: $0, y: 4, w: 1, h: $1) }
        }
    }

    private var pose: Pose {
        var p = Pose()
        let odd = t % 2 == 1
        switch mood {
        case .working:
            // At the keyboard: eyes down, arms typing in turn, a block cursor blinking beside it.
            p.eyes = Pose.openEyes(dx: 0, y: 1.6, h: 0.9)
            p.armL = Part(x: 1, y: odd ? 1.6 : 2, w: 2, h: 1)
            p.armR = Part(x: 15, y: odd ? 2 : 1.6, w: 2, h: 1)
            p.cursor = odd ? 0.15 : 1
            p.lift = odd ? -0.25 : 0
            p.legs = odd ? [1, 0.4, 1, 0.4] : [0.4, 1, 0.4, 1]
        case .waiting:
            // Waving for attention: arm out, forearm up, the hand rocking side to side under a "?".
            p.armR = Part(x: 15, y: 2, w: 2, h: 1)
            p.extraR = Part(x: 16, y: -0.5, w: 1, h: 2.5)
            p.hand = Part(x: odd ? 16.5 : 15.5, y: -1.5, w: 2, h: 1)
            p.eyes = Pose.openEyes(dx: 0.5, y: 0.7, h: 1)
            p.legs = odd ? [1, 0.4, 1, 0.4] : [0.4, 1, 0.4, 1]
            p.lift = odd ? -0.25 : 0
            p.marks = [Mark(bits: Self.question, x: odd ? 16.9 : 15.9, y: -4, scale: 0.55)]
        case .done:
            // Ta-da: arms flung wide, ^ ^ eyes, a hop.
            p.lift = odd ? 0 : -0.8
            p.armL = Part(x: 0, y: 1, w: 3, h: 1)
            p.armR = Part(x: 15, y: 1, w: 3, h: 1)
            p.extraL = Part(x: 0, y: 0, w: 1, h: 1)
            p.extraR = Part(x: 17, y: 0, w: 1, h: 1)
            p.eyes = Pose.happyEyes
        case .resting:
            // Paused: sitting, legs folded, eyes shifting and a blink now and then.
            p.lift = 1; p.legs = [0, 0, 0, 0]
            p.armL = Part(x: 1, y: 2.5, w: 2, h: 1); p.armR = Part(x: 15, y: 2.5, w: 2, h: 1)
            switch t % 6 {
            case 1: p.eyes = Pose.openEyes(dx: 1, y: 1, h: 1)
            case 3: p.eyes = Pose.openEyes(dx: 0, y: 1.4, h: 0.2)
            case 4: p.eyes = Pose.openEyes(dx: -1, y: 1, h: 1)
            default: break
            }
        case .sleeping:
            // Asleep: slow breathing, z's drifting up, and once in a while one eye peeks open.
            p.lift = odd ? 0.8 : 1.1; p.legs = [0, 0, 0, 0]
            p.armL = Part(x: 2, y: 2.8, w: 1, h: 1); p.armR = Part(x: 15, y: 2.8, w: 1, h: 1)
            p.eyes = Pose.openEyes(dx: 0, y: 1.6, h: 0.3)
            if t % 8 == 5 { p.eyes[1] = Part(x: 12, y: 1, w: 1, h: 0.9) }
            p.marks = [Mark(bits: Self.zed, x: odd ? 17 : 16.3, y: odd ? -1.6 : -0.6, scale: 0.6, opacity: odd ? 0.4 : 0.9),
                       Mark(bits: Self.zed, x: odd ? 15.6 : 15.2, y: odd ? 0.4 : 1.0, scale: 0.4, opacity: odd ? 0.9 : 0.4)]
        }
        return p
    }
}

// MARK: - Hero (the most urgent session)

/// Where the hero's character stands, measured inside the link and drawn outside it.
struct StageKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}

struct Hero: View {
    @Environment(\.widgetRenderingMode) private var mode
    @Environment(\.heroImage) private var heroImage
    @Environment(\.pulseTick) private var tick
    let s: SessionSnapshot
    var compact = false
    /// The small widget: no inner card, the widget background is the card.
    var fullBleed = false
    var othersWorking = 0
    static let smallPx: CGFloat = 2.5
    static let heroPx: CGFloat = 4.5

    var body: some View {
        // The link is the top layer. The card and the character are drawn behind it: anything over a widget
        // link swallows the click, and the flip-book's huge spinning masks can't live inside one.
        link.backgroundPreferenceValue(StageKey.self) { stage in
            ZStack(alignment: .topLeading) {
                card
                GeometryReader { g in
                    if let stage { character(in: g[stage]) }
                }
            }
        }
    }


    @ViewBuilder private var card: some View {
        if !fullBleed {
            let card = RoundedRectangle(cornerRadius: 14, style: .continuous)
            ZStack {
                card.fill(background)
                // The last image in the conversation, faded right back so the text stays the subject.
                // A clear view sets the size, so the filled image can't push the card wider.
                if let heroImage, let ns = NSImage(data: heroImage) {
                    Color.clear
                        .overlay(Image(nsImage: ns).resizable().scaledToFill())
                        .opacity(0.16)
                        .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                        .clipShape(card)
                }
                // The breathing glow: one fixed layer whose opacity glides, since gradients don't interpolate.
                card.fill(LinearGradient(colors: [Pulse.clay.opacity(0.12), Pulse.clay.opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom))
                    .opacity(s.state == .waiting && tick % 2 == 1 ? 1 : 0)
            }
            .animation(Beat.ease, value: tick)
        }
    }

    @ViewBuilder private func character(in r: CGRect) -> some View {
        if compact {
            ClawdLoop(mood: mood, px: Self.smallPx).offset(x: r.minX, y: r.minY)
        } else {
            let w = ClawdSprite.size(px: Self.heroPx).width
            ClawdLoop(mood: mood, px: Self.heroPx, walking: walkingNow)
                .scaleEffect(x: facingLeft ? -1 : 1)
                .animation(Beat.morph, value: facingLeft)
                .offset(x: r.minX + max(0, r.width - w) * standX, y: r.minY)
                .animation(Beat.linear, value: standX)
        }
    }

    private var link: some View {
        OpenLink(url: s.url) {
            VStack(alignment: .leading, spacing: compact ? 5 : 9) {
                chip
                Text(s.title)
                    .font(.system(size: fullBleed ? 14 : compact ? 15 : 19, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let line = body2 {
                    Text(line)
                        .font(.system(size: fullBleed ? 11.5 : compact ? 12 : 14))
                        .foregroundStyle(s.state == .waiting
                                         ? (mode == .fullColor ? AnyShapeStyle(Pulse.clayText) : AnyShapeStyle(.primary))
                                         : AnyShapeStyle(.secondary))
                        .lineLimit(compact ? 2 : 3)
                        .layoutPriority(1)
                }
                Spacer(minLength: 0)
                Group {
                    if !compact {
                        // Standing on the steps bar, over the step it's on.
                        VStack(alignment: .leading, spacing: 1) {
                            // Only a marked-out stage here: the character is drawn over the link, not inside
                            // it, because its spinning flip-book masks would wreck the link's tap area.
                            Color.clear
                                .frame(height: ClawdSprite.size(px: Self.heroPx).height)
                                .anchorPreference(key: StageKey.self, value: .bounds) { $0 }
                            if s.stepsTotal > 0 { StepSegments(s: s) }
                        }
                    } else if s.stepsTotal > 0 && !(fullBleed && s.state == .waiting) {
                        StepSegments(s: s)
                    }
                    HStack {
                        if !compact { Text(s.project.isEmpty ? s.kind.label : s.project); Spacer() }
                        Text(compact ? compactFooter : footer).contentTransition(.numericText())
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .padding(.trailing, compact ? ClawdSprite.size(px: Self.smallPx).width + 6 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                if compact {
                    Color.clear.frame(width: ClawdSprite.size(px: Self.smallPx).width,
                                      height: ClawdSprite.size(px: Self.smallPx).height)
                        .anchorPreference(key: StageKey.self, value: .bounds) { $0 }
                }
            }
            .padding(fullBleed ? 0 : compact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay {
                // Monochrome desktop mode drops the clay; keep "needs you" visible with an outline.
                if s.state == .waiting && mode != .fullColor && !fullBleed {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            // A new state or a new session in the hero morphs in, rather than cutting.
            .animation(Beat.morph, value: s.state)
            .animation(Beat.morph, value: s.id)
        }
    }

    private var chip: some View {
        HStack(spacing: 7) {
            if s.state == .waiting {
                Circle().fill(Pulse.clay).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Pulse.clay.opacity(tick % 2 == 0 ? 0.5 : 0.1), lineWidth: 3)
                        .padding(tick % 2 == 0 ? -2 : -5))
            } else {
                RingMark(s: s, size: 12)
            }
            Text(fullBleed ? chipLabel : "\(chipLabel) · \(s.lastActivity.shortAgo)")
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(chipColor)
        .animation(Beat.ease, value: tick)
    }

    /// Where the character stands along the bar, 0…1. While working or waiting it paces slowly from end
    /// to end, one step a tick; otherwise it stays over the current step.
    private var standX: CGFloat { position(at: tick) }

    /// Working, it walks the bar: five beats across at a steady pace (the trot loops on top), a beat stopped
    /// at the end to turn and look about, five beats back, a beat stopped. Other moods stay on their step.
    private var mood: Mood { s.mood }
    private var walks: Bool { mood == .working }
    private var walkingNow: Bool { walks && position(at: tick) != position(at: tick - 1) }
    private var facingLeft: Bool {
        guard walks else { return false }
        let c = ((tick % 12) + 12) % 12
        return c >= 6
    }

    private func position(at t: Int) -> CGFloat {
        if walks {
            let c = ((t % 12) + 12) % 12
            return c <= 5 ? CGFloat(c) / 5 : c == 6 ? 1 : CGFloat(11 - c) / 5
        }
        guard s.stepsTotal > 1 else { return 0 }
        let i = min(s.stepsDone, s.stepsTotal - 1)
        return CGFloat(i) / CGFloat(s.stepsTotal - 1)
    }

    private var chipLabel: String {
        switch s.state {
        case .waiting: return "Needs you"
        case .running: return "Working"
        case .done: return "Finished"
        case .idle: return s.isPaused ? "Paused" : "Last active"
        }
    }

    private var chipColor: AnyShapeStyle {
        switch s.state {
        case .waiting: return AnyShapeStyle(Pulse.clayLabel)
        case .done: return AnyShapeStyle(Pulse.green)
        default: return AnyShapeStyle(.secondary)
        }
    }

    private var body2: String? {
        switch s.state {
        case .waiting, .running: return s.detail
        default: return s.isPaused ? s.detail ?? "Stopped before finishing its list" : nil
        }
    }

    private var compactFooter: String {
        if fullBleed && s.state == .waiting && othersWorking > 0 { return "+\(othersWorking) working" }
        return s.stepsTotal > 0 ? "\(s.stepsDone) of \(s.stepsTotal) steps" : (s.project.isEmpty ? s.kind.label : s.project)
    }

    private var footer: String {
        let steps = s.stepsTotal > 0 ? "\(s.stepsDone) of \(s.stepsTotal) steps" : nil
        if s.state == .waiting { return [steps, "answer in Claude ›"].compactMap { $0 }.joined(separator: " · ") }
        return steps ?? "open in Claude ›"
    }

    private var background: AnyShapeStyle {
        if s.state == .waiting {
            return AnyShapeStyle(LinearGradient(colors: [Pulse.clay.opacity(0.22), Pulse.clay.opacity(0.07)],
                                                startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(Color.primary.opacity(0.06))
    }
}

// MARK: - List row

struct ListRow: View {
    @Environment(\.widgetRenderingMode) private var mode
    @Environment(\.pulseTick) private var tick
    let s: SessionSnapshot

    private func titleText(withDetail: Bool) -> Text {
        let title = Text(s.title).fontWeight(s.isActive ? .semibold : .regular)
            .foregroundColor(s.isActive || s.state == .done ? .primary : .secondary)
        guard withDetail, let d = s.inlineDetail else { return title }
        return title + Text(" · \(d)").foregroundColor(s.state == .waiting && mode == .fullColor ? Pulse.clayText : .secondary)
    }
    var body: some View {
        OpenLink(url: s.url) {
            HStack(spacing: 9) {
                RingMark(s: s)
                ViewThatFits(in: .horizontal) {
                    titleText(withDetail: true).fixedSize()
                    titleText(withDetail: false)
                }
                .font(.system(size: 12.5))
                .lineLimit(1)
                Spacer(minLength: 6)
                Text(s.trailing)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .layoutPriority(1)
            }
            .padding(.horizontal, 6)
            .frame(maxHeight: 29)
            .background(s.state == .waiting ? Pulse.clay.opacity(tick % 2 == 0 ? 0.13 : 0.24) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if s.state == .waiting && mode != .fullColor {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
                }
            }
            .frame(minHeight: 20, maxHeight: 32)
            .contentShape(Rectangle())
            .animation(Beat.ease, value: tick)
        }
    }
}

struct ListColumn: View {
    let sessions: [SessionSnapshot]   // excludes the hero
    let all: [SessionSnapshot]
    let maxRows: Int

    var body: some View {
        let rows = Array(sessions.prefix(maxRows))
        let split = rows.firstIndex { !$0.isActive } ?? rows.count
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Claude").font(.system(size: 13, weight: .semibold))
                Spacer()
                Summary(all: all)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, s in
                if i == split && split > 0 && split < rows.count {
                    Divider().opacity(0.5).padding(.horizontal, 6).padding(.vertical, 3)
                }
                ListRow(s: s)
            }
            if rows.count < maxRows { Spacer(minLength: 0) }
        }
        // Rows slide to their new places when the order or a state changes.
        .animation(Beat.morph, value: rows.map { "\($0.id)\($0.state)" })
    }
}

struct Summary: View {
    let all: [SessionSnapshot]
    var body: some View {
        let waiting = all.filter { $0.state == .waiting }.count
        let running = all.filter { $0.state == .running }.count
        let need = waiting == 0 ? nil : Text(waiting == 1 ? "1 needs you" : "\(waiting) need you").foregroundColor(Pulse.clayLabel)
        let work = running == 0 ? nil : Text("\(running) working").foregroundColor(.secondary)
        let text: Text = {
            switch (need, work) {
            case let (n?, w?): return n + Text(" · ").foregroundColor(.secondary) + w
            case let (n?, nil): return n
            case let (nil, w?): return w
            default: return Text("all quiet").foregroundColor(.secondary)
            }
        }()
        text.font(.system(size: 11)).contentTransition(.numericText())
    }
}

/// A `Link` in the widget (routed through the app, which opens it in Claude); plain content in the render harness.
struct OpenLink<Content: View>: View {
    let url: URL
    @ViewBuilder let content: Content
    var body: some View {
        #if RENDER_HARNESS
        content
        #else
        Link(destination: PulseLink.wrap(url)) { content }
        #endif
    }
}

// MARK: - Families

struct PulseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry
    var forcedFamily: WidgetFamily? = nil   // for the render harness

    private var smallWaiting: Bool {
        (forcedFamily ?? family) == .systemSmall && ordered(entry.sessions).first?.state == .waiting
    }

    var body: some View {
        Group {
            if entry.sessions.isEmpty {
                EmptyState(error: entry.error, showsCharacter: (forcedFamily ?? family) != .systemSmall)
            } else {
                let list = ordered(entry.sessions)
                switch forcedFamily ?? family {
                case .systemSmall:
                    Hero(s: list[0], compact: true, fullBleed: true,
                         othersWorking: list.dropFirst().filter { $0.state == .running }.count)
                case .systemMedium: medium(list)
                case .systemLarge: large(list)
                default: extraLarge(list)
                }
            }
        }
        .environment(\.pulseTick, entry.tick)
            .environment(\.heroImage, entry.heroImage)
        .containerBackground(for: .widget) {
            if smallWaiting {
                LinearGradient(colors: [Pulse.clay.opacity(0.28), Pulse.clay.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                    .background(Color(nsColor: .windowBackgroundColor))
            } else {
                Color(nsColor: .windowBackgroundColor)
            }
        }
    }

    private func extraLarge(_ list: [SessionSnapshot]) -> some View {
        HStack(spacing: 12) {
            Hero(s: list[0]).frame(width: 290)
            ListColumn(sessions: Array(list.dropFirst()), all: Array(list.dropFirst()), maxRows: 9)
                .padding(.top, 4)
        }
        .padding(-4)
    }

    private func large(_ list: [SessionSnapshot]) -> some View {
        VStack(spacing: 10) {
            Hero(s: list[0], compact: true).frame(height: 138)
            ListColumn(sessions: Array(list.dropFirst()), all: Array(list.dropFirst()), maxRows: 6)
        }
        .padding(-4)
    }

    private func medium(_ list: [SessionSnapshot]) -> some View {
        ListColumn(sessions: list, all: list, maxRows: 3).padding(-2)
    }
}

struct EmptyState: View {
    let error: String?
    var showsCharacter = true
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(error == nil ? "No Claude sessions yet" : "Can't see your sessions")
                .font(.system(size: 15, weight: .semibold))
            Text(error == nil ? "Start one and it shows up here with its progress."
                              : "Keep Working couldn't read Claude's session folder. Open it to check.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            OpenLink(url: URL(string: error == nil ? "claude://code/new" : "claude://code/new")!) {
                Text(error == nil ? "New session in Claude" : "Open Claude")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            // Nothing to do: asleep. Can't read: sitting up, blinking. (No room for it in the small size.)
            if showsCharacter { ClawdLoop(mood: error == nil ? .sleeping : .resting, px: 3) }
        }
    }
}

// MARK: - Widget

struct KeepWorkingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeepWorking", provider: PulseProvider()) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude sessions")
        .description("Your 10 most recent Claude sessions. The one that needs you comes first. Click to open it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#if !RENDER_HARNESS
@main
#endif
struct KeepWorkingBundle: WidgetBundle {
    var body: some Widget { KeepWorkingWidget() }
}
