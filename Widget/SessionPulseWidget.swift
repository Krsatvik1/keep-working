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

struct StatusMark: View {
    let state: SessionState
    var body: some View {
        ZStack {
            switch state {
            case .running:
                Circle().fill(Pulse.accent)
                Circle().stroke(Pulse.accent.opacity(0.35), lineWidth: 3).padding(-2.5)
            case .waiting:
                Circle().stroke(Pulse.accent, lineWidth: 1.6)
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
    let value: Double
    let state: SessionState
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.09))
                Capsule().fill(Pulse.color(state).opacity(state == .idle ? 0.55 : 1))
                    .frame(width: max(3, geo.size.width * value))
            }
        }
        .frame(height: 3)
    }
}

extension SessionSnapshot {
    var trailing: String {
        stepsTotal > 0 ? "\(stepsDone)/\(stepsTotal) · \(lastActivity.shortAgo)" : lastActivity.shortAgo
    }

    var subline: String {
        if state == .waiting, let detail { return "Needs you: \(detail)" }
        if state == .running, let detail { return detail }
        if state == .running { return "\(project) · working" }
        return project.isEmpty ? kind.label : "\(project) · \(kind.label)"
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

/// One line per session; a hairline of progress under it when the session keeps a task list.
struct CompactRow: View {
    let s: SessionSnapshot
    var body: some View {
        OpenLink(url: s.url) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    StatusMark(state: s.state)
                    Text(s.title)
                        .font(.system(size: 12, weight: s.state == .idle ? .regular : .medium))
                        .foregroundStyle(s.state == .idle ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(s.trailing)
                        .font(.system(size: 10.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                }
                if let p = s.progress {
                    ProgressTrack(value: p, state: s.state).padding(.leading, 18)
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
            HStack(alignment: .top, spacing: 6) {
                StatusMark(state: s.state).padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(s.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(s.trailing).font(.system(size: 10.5)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Text(s.subline)
                        .font(.system(size: 11))
                        .foregroundStyle(s.state == .waiting ? AnyShapeStyle(Pulse.accent) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                    if let p = s.progress { ProgressTrack(value: p, state: s.state).padding(.top, 1) }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
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
            Group {
                if running + waiting == 0 { Text("all quiet") }
                else {
                    Text([running > 0 ? "\(running) running" : nil, waiting > 0 ? "\(waiting) need you" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(running + waiting > 0 ? AnyShapeStyle(Pulse.accent) : AnyShapeStyle(.secondary))
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
            ForEach(entry.sessions.prefix(4)) { s in
                HStack(spacing: 5) {
                    StatusMark(state: s.state)
                    Text(s.title).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .widgetURL(entry.sessions.first?.url)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 2) {
            Header(sessions: entry.sessions)
            ForEach(entry.sessions.prefix(4)) { CompactRow(s: $0) }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(sessions: entry.sessions).padding(.bottom, 4)
            ForEach(entry.sessions.prefix(10)) { CompactRow(s: $0) }
            if entry.sessions.count < 10 { Spacer(minLength: 0) }
        }
    }

    private var extraLarge: some View {
        let list = Array(entry.sessions.prefix(10))
        let left = Array(list.prefix(5)), right = Array(list.dropFirst(5))
        return VStack(alignment: .leading, spacing: 6) {
            Header(sessions: entry.sessions)
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 0) { ForEach(left) { DetailRow(s: $0) } }
                VStack(spacing: 0) {
                    ForEach(right) { DetailRow(s: $0) }
                    if right.count < 5 { Spacer(minLength: 0) }
                }
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
