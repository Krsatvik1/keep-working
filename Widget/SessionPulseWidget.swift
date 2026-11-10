import AppKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct PulseEntry: TimelineEntry {
    let date: Date
    let sessions: [SessionSnapshot]
    let error: String?
}

struct PulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, sessions: SessionSnapshot.samples, error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let entry = load()
        let busy = entry.sessions.contains { $0.state == .running }
        // The menu-bar app nudges a reload whenever a session file changes; this is only the fallback.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(busy ? 60 : 300))))
    }

    private func load() -> PulseEntry {
        let sessions = SessionStore.load(limit: 10)
        return PulseEntry(date: .now, sessions: sessions, error: sessions.isEmpty ? SessionStore.lastError : nil)
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
    let s: SessionSnapshot
    var size: CGFloat = 16

    var body: some View {
        let line = size / 8
        let ring = Circle().inset(by: line)
        ZStack {
            switch s.state {
            case .waiting:
                Circle().fill(Pulse.clay).padding(size * 0.22)
                Circle().stroke(Pulse.clay.opacity(0.3), lineWidth: size * 0.18).padding(size * 0.13)
            case .running where s.stepsTotal > 0:
                ring.stroke(Color.primary.opacity(0.16), lineWidth: line)
                ring.trim(from: 0, to: max(0.06, s.progress ?? 0))
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            case .running:
                ring.stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: line, dash: [size / 5, size / 5]))
                ring.trim(from: 0, to: 0.25)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
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
    }
}

/// One segment per step: done ones solid, the current one half, the rest a faint track.
struct StepSegments: View {
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
                        Capsule().fill(i < s.stepsDone ? fill : (i == s.stepsDone && s.state == .running ? fill.opacity(0.45) : Color.primary.opacity(0.14)))
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var fill: Color { s.state == .idle ? Color.secondary : Color.primary }
}

// MARK: - Hero (the most urgent session)

struct Hero: View {
    @Environment(\.widgetRenderingMode) private var mode
    let s: SessionSnapshot
    var compact = false
    /// The small widget: no inner card, the widget background is the card.
    var fullBleed = false
    var othersWorking = 0

    var body: some View {
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
                if s.stepsTotal > 0 && !(fullBleed && s.state == .waiting) {
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
            .padding(fullBleed ? 0 : compact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fullBleed ? AnyShapeStyle(Color.clear) : background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                // Monochrome desktop mode drops the clay; keep "needs you" visible with an outline.
                if s.state == .waiting && mode != .fullColor && !fullBleed {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var chip: some View {
        HStack(spacing: 7) {
            if s.state == .waiting {
                Circle().fill(Pulse.clay).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Pulse.clay.opacity(0.3), lineWidth: 3).padding(-3))
            } else {
                RingMark(s: s, size: 12)
            }
            Text(fullBleed ? chipLabel : "\(chipLabel) · \(s.lastActivity.shortAgo)")
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(chipColor)
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
            return AnyShapeStyle(LinearGradient(colors: [Pulse.clay.opacity(0.24), Pulse.clay.opacity(0.08)],
                                                startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(Color.primary.opacity(0.06))
    }
}

// MARK: - List row

struct ListRow: View {
    @Environment(\.widgetRenderingMode) private var mode
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
            .background(s.state == .waiting ? Pulse.clay.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if s.state == .waiting && mode != .fullColor {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
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
                EmptyState(error: entry.error)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(error == nil ? "No Claude sessions yet" : "Can't see your sessions")
                .font(.system(size: 15, weight: .semibold))
            Text(error == nil ? "Start one and it shows up here with its progress."
                              : "Session Pulse couldn't read Claude's session folder. Open it to check.")
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
    }
}

// MARK: - Widget

struct SessionPulseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SessionPulse", provider: PulseProvider()) { entry in
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
struct SessionPulseBundle: WidgetBundle {
    var body: some Widget { SessionPulseWidget() }
}
