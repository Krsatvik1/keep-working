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

// MARK: - Palette

enum Pulse {
    static let accent = Color(red: 0.85, green: 0.47, blue: 0.34)   // Claude clay
    static let done = Color(red: 0.36, green: 0.62, blue: 0.42)

    static func color(_ state: SessionState) -> Color {
        switch state {
        case .running: return accent
        case .waiting: return accent
        case .done: return done
        case .idle: return .secondary
        }
    }
}

// MARK: - Pieces

/// Clay is reserved for "needs you"; running is an open arc, so the four marks differ by shape in greyscale too.
struct StatusMark: View {
    let state: SessionState
    var body: some View {
        ZStack {
            switch state {
            case .waiting:
                Circle().fill(Pulse.accent)
                Circle().stroke(Pulse.accent.opacity(0.25), lineWidth: 2.5).padding(-2)
            case .running:
                Circle().trim(from: 0, to: 0.72)
                    .stroke(Color.primary.opacity(0.8), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            case .done:
                Image(systemName: "checkmark").font(.system(size: 7.5, weight: .heavy)).foregroundStyle(Pulse.done)
            case .idle:
                Circle().fill(Color.secondary.opacity(0.45)).padding(1.5)
            }
        }
        .frame(width: 8, height: 8)
        .frame(width: 12)
    }
}

struct ProgressTrack: View {
    @Environment(\.colorScheme) private var scheme
    let value: Double
    let state: SessionState
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08))
                Capsule().fill(state == .waiting ? Pulse.accent : Color.primary.opacity(state == .running ? 0.55 : 0.35))
                    .frame(width: max(2, geo.size.width * value))
            }
        }
        .frame(height: 2)
    }
}

extension SessionSnapshot {
    var trailing: String {
        stepsTotal > 0 ? "\(stepsDone)/\(stepsTotal) · \(lastActivity.shortAgo)" : lastActivity.shortAgo
    }

    /// A bar only while a list is part-way done; "7/7" in the trailing text already says finished.
    var partialProgress: Double? {
        stepsTotal > 0 && stepsDone < stepsTotal ? progress : nil
    }

    var subline: String {
        if state == .waiting, let detail { return "Needs you: \(detail)" }
        if state == .running, let detail { return detail }
        if kind == .code { return project.isEmpty ? "Code" : project }
        return project.isEmpty ? kind.label : "\(project) · \(kind.label)"
    }

    var isQuiet: Bool { state == .idle }
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

/// One line per session; a hairline of progress hangs under the title when a task list is part-way done.
struct CompactRow: View {
    let s: SessionSnapshot
    var body: some View {
        OpenLink(url: s.url) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                StatusMark(state: s.state)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3.5 }
                Text(s.title)
                    .font(.system(size: 12, weight: s.isQuiet ? .regular : .medium))
                    .foregroundStyle(s.isQuiet ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(s.trailing)
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
            }
            .overlay(alignment: .bottomLeading) {
                if let p = s.partialProgress {
                    ProgressTrack(value: p, state: s.state).padding(.leading, 18).offset(y: 6)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
}

/// Two lines per session: title, then the current step / the question / the project.
struct DetailRow: View {
    let s: SessionSnapshot
    var body: some View {
        OpenLink(url: s.url) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                StatusMark(state: s.state)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3.5 }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(s.title)
                            .font(.system(size: 12.5, weight: s.isQuiet ? .regular : .medium))
                            .foregroundStyle(s.isQuiet ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(s.trailing).font(.system(size: 10.5)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Text(s.subline)
                        .font(.system(size: 11))
                        .foregroundStyle(s.state == .waiting ? AnyShapeStyle(Pulse.accent) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                    if let p = s.partialProgress { ProgressTrack(value: p, state: s.state).padding(.top, 2) }
                }
            }
            .frame(height: 54, alignment: .top)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
}

struct Header: View {
    let sessions: [SessionSnapshot]
    var body: some View {
        let running = sessions.filter { $0.state == .running }.count
        let waiting = sessions.filter { $0.state == .waiting }.count
        HStack(alignment: .firstTextBaseline) {
            Text("Claude sessions").font(.system(size: 13, weight: .semibold))
            Spacer()
            summary(running: running, waiting: waiting).font(.system(size: 11))
        }
    }

    private func summary(running: Int, waiting: Int) -> Text {
        let need = waiting == 0 ? nil : Text(waiting == 1 ? "1 needs you" : "\(waiting) need you").foregroundColor(Pulse.accent)
        let run = running == 0 ? nil : Text("\(running) running").foregroundColor(.secondary)
        switch (need, run) {
        case let (n?, r?): return n + Text(" · ").foregroundColor(.secondary) + r
        case let (n?, nil): return n
        case let (nil, r?): return r
        default: return Text("all quiet").foregroundColor(.secondary)
        }
    }
}

/// A `Link` in the widget; plain content in the render harness (ImageRenderer can't draw links).
struct OpenLink<Content: View>: View {
    let url: URL
    @ViewBuilder let content: Content
    var body: some View {
        #if RENDER_HARNESS
        content
        #else
        Link(destination: url) { content }
        #endif
    }
}

// MARK: - Families

struct PulseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry
    var forcedFamily: WidgetFamily? = nil   // for the render harness

    /// The 10 most recent sessions, with the ones that need you first and running ones next.
    private var ordered: [SessionSnapshot] {
        let rank: [SessionState: Int] = [.waiting: 0, .running: 1, .done: 2, .idle: 2]
        return entry.sessions.sorted {
            let (a, b) = (rank[$0.state] ?? 3, rank[$1.state] ?? 3)
            return a != b ? a < b : $0.lastActivity > $1.lastActivity
        }
    }

    var body: some View {
        Group {
            if entry.sessions.isEmpty {
                VStack(spacing: 6) {
                    Text("No sessions yet").font(.system(size: 13, weight: .medium))
                    if let e = entry.error { Text(e).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch forcedFamily ?? family {
                case .systemSmall: small
                case .systemMedium: medium
                case .systemExtraLarge: extraLarge
                default: large
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(sessions: entry.sessions)
            Spacer(minLength: 4)
            ForEach(ordered.prefix(4)) { s in
                HStack(spacing: 5) {
                    StatusMark(state: s.state)
                    Text(s.title).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .widgetURL(ordered.first?.url)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 2) {
            Header(sessions: entry.sessions)
            ForEach(ordered.prefix(4)) { CompactRow(s: $0) }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(sessions: entry.sessions).padding(.bottom, 8)
            ForEach(ordered.prefix(10)) { CompactRow(s: $0) }
            if entry.sessions.count < 10 { Spacer(minLength: 0) }
        }
    }

    private var extraLarge: some View {
        let list = Array(ordered.prefix(10))
        let left = Array(list.prefix(5)), right = Array(list.dropFirst(5))
        return VStack(alignment: .leading, spacing: 6) {
            Header(sessions: entry.sessions)
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 0) { ForEach(left) { DetailRow(s: $0) } }.frame(maxWidth: .infinity, alignment: .top)
                VStack(spacing: 0) {
                    ForEach(right) { DetailRow(s: $0) }
                    if right.count < 5 { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

// MARK: - Widget

struct SessionPulseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SessionPulse", provider: PulseProvider()) { entry in
            PulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude sessions")
        .description("Your 10 most recent Claude Code and Cowork sessions, with task progress. Click one to open it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#if !RENDER_HARNESS
@main
#endif
struct SessionPulseBundle: WidgetBundle {
    var body: some Widget { SessionPulseWidget() }
}
