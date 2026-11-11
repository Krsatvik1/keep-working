import Foundation
import ImageIO
import UniformTypeIdentifiers
import os

// MARK: - Model

enum SessionKind: String, Codable, Sendable { case code, cowork, terminal }

enum SessionState: String, Codable, Sendable {
    case running   // a turn is in progress right now
    case waiting   // the last turn ended on a question for you
    case done      // the last turn wrapped up its task list
    case idle      // nothing in flight
}

struct SessionSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let project: String
    let kind: SessionKind
    let state: SessionState
    let lastActivity: Date
    let stepsDone: Int
    let stepsTotal: Int
    /// The step in progress, or the question the session is waiting on you for.
    let detail: String?
    let url: URL
    /// The session's transcript file, when there is one (for its last image).
    var transcript: String? = nil

    var progress: Double? {
        stepsTotal > 0 ? min(1, Double(stepsDone) / Double(stepsTotal)) : nil
    }
}

// MARK: - Store

/// Reads Claude's local session files. Read-only: never writes anywhere under ~/.claude or the app's support folder.
enum SessionStore {
    private static let fm = FileManager.default

    /// The real home folder, even inside the widget's sandbox (where NSHomeDirectory points at the container).
    static var home: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return fm.homeDirectoryForCurrentUser
    }

    static var claudeDir: URL { home.appendingPathComponent(".claude", isDirectory: true) }
    static var appSupport: URL { home.appendingPathComponent("Library/Application Support/Claude", isDirectory: true) }

    /// Folders worth watching for changes (used by the menu-bar app to nudge the widget).
    static var watchedPaths: [String] {
        [claudeDir.appendingPathComponent("projects").path,
         claudeDir.appendingPathComponent("sessions").path,
         appSupport.appendingPathComponent("claude-code-sessions").path,
         appSupport.appendingPathComponent("local-agent-mode-sessions").path]
    }

    static var lastError: String?

    static func load(limit: Int = 10) -> [SessionSnapshot] {
        lastError = nil
        let live = liveStatuses()
        let transcripts = transcriptIndex()
        var claimed = Set<String>()
        var out: [SessionSnapshot] = []

        // 1. Claude Code sessions in the desktop app
        let desktopFiles = sessionFiles(under: appSupport.appendingPathComponent("claude-code-sessions"))
        if desktopFiles.isEmpty && !fm.isReadableFile(atPath: appSupport.path) {
            lastError = "Can't read the Claude app folder"
        }
        for file in desktopFiles.prefix(limit * 3) {
            autoreleasepool {
                guard let head = readHead(file.url, bytes: 24_000),
                      let sid = field("sessionId", in: head),
                      boolField("isArchived", in: head) != true else { return }
                let cli = field("cliSessionId", in: head)
                if let cli { claimed.insert(cli) }
                for prior in priorIds(file.url) { claimed.insert(prior) }

                let cwd = field("cwd", in: head) ?? ""
                var last = numberField("lastActivityAt", in: head).map { Date(timeIntervalSince1970: $0 / 1000) } ?? file.mtime
                var info = TranscriptInfo()
                if let cli, let t = transcripts[cli] {
                    info = analyze(t.url)
                    last = max(last, t.mtime)
                }
                let status = live[sid] ?? cli.flatMap { live[$0] }
                let title = nonEmpty(field("title", in: head)) ?? info.title ?? (cwd as NSString).lastPathComponent
                var snap = snapshot(id: sid, title: title, cwd: cwd, kind: .code, live: status, info: info, last: last,
                                    url: URL(string: "claude://code/continue?session=\(sid)")!)
                snap.transcript = cli.flatMap { transcripts[$0]?.url.path }
                out.append(snap)
            }
        }

        // 2. Cowork tasks
        for file in sessionFiles(under: appSupport.appendingPathComponent("local-agent-mode-sessions")).prefix(limit) {
            autoreleasepool {
                guard let head = readHead(file.url, bytes: 24_000),
                      let sid = field("sessionId", in: head),
                      boolField("isArchived", in: head) != true else { return }
                let last = numberField("lastActivityAt", in: head).map { Date(timeIntervalSince1970: $0 / 1000) } ?? file.mtime
                out.append(SessionSnapshot(id: sid, title: nonEmpty(field("title", in: head)) ?? "Cowork task",
                                           project: "Cowork", kind: .cowork, state: .idle, lastActivity: last,
                                           stepsDone: 0, stepsTotal: 0, detail: nil,
                                           url: URL(string: "claude://cowork/\(sid)")!))
            }
        }

        // 3. Terminal sessions (claude in a shell), newest first, skipping ones the desktop app owns
        let terminal = transcripts.filter { !claimed.contains($0.key) }
            .sorted { $0.value.mtime > $1.value.mtime }
            .prefix(limit * 2)
        for (uuid, t) in terminal {
            autoreleasepool {
                guard let head = readHead(t.url, bytes: 32_000),
                      head.contains("\"entrypoint\":\"cli\"") else { return }
                var info = analyze(t.url)
                if info.title == nil { info.title = firstPrompt(in: head) }
                let cwd = field("cwd", in: head) ?? ""
                var snap = snapshot(id: uuid, title: info.title ?? "Terminal session", cwd: cwd, kind: .terminal,
                                    live: live[uuid], info: info, last: t.mtime,
                                    url: URL(string: "claude://resume?session=\(uuid)")!)
                snap.transcript = t.url.path
                out.append(snap)
            }
        }

        saveScans()
        let process = ProcessInfo.processInfo.processName
        Logger(subsystem: "xyz.krsatvik.KeepWorking", category: "store")
            .info("\(process, privacy: .public) loaded \(out.count) sessions, error: \(lastError ?? "none", privacy: .public)")
        return Array(out.sorted { $0.lastActivity > $1.lastActivity }.prefix(limit))
    }

    private static func snapshot(id: String, title: String, cwd: String, kind: SessionKind, live: String?,
                                 info: TranscriptInfo, last: Date, url: URL) -> SessionSnapshot {
        let state: SessionState
        if live == "busy" { state = .running }
        else if info.ask != nil { state = .waiting }
        else if info.wrapped { state = .done }
        else { state = .idle }
        let detail = state == .waiting ? info.ask : info.current
        return SessionSnapshot(id: id, title: clean(title), project: (cwd as NSString).lastPathComponent,
                               kind: kind, state: state, lastActivity: last,
                               stepsDone: info.done, stepsTotal: info.total, detail: detail.map(clean), url: url)
    }

    // MARK: Live status (~/.claude/sessions/<pid>.json)

    /// Maps both the CLI session uuid and the desktop `local_…` id to "busy" / "idle", for processes still alive.
    private static func liveStatuses() -> [String: String] {
        let dir = claudeDir.appendingPathComponent("sessions")
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [:] }
        var map: [String: String] = [:]
        for name in names where name.hasSuffix(".json") {
            guard let data = fm.contents(atPath: dir.appendingPathComponent(name).path),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = obj["pid"] as? Int32, let status = obj["status"] as? String else { continue }
            guard kill(pid, 0) == 0 || errno == EPERM else { continue }   // stale file from a dead process
            if let s = obj["sessionId"] as? String { map[s] = status }
            if let h = obj["hostSessionId"] as? String { map[h] = status }
        }
        return map
    }

    // MARK: Files

    private struct FileRef { let url: URL; let mtime: Date }

    /// `local_*.json` two levels under `root`, newest first.
    private static func sessionFiles(under root: URL) -> [FileRef] {
        var refs: [FileRef] = []
        for account in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            for space in (try? fm.contentsOfDirectory(at: account, includingPropertiesForKeys: nil)) ?? [] {
                let files = (try? fm.contentsOfDirectory(at: space, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
                for f in files where f.lastPathComponent.hasPrefix("local_") && f.pathExtension == "json" {
                    refs.append(FileRef(url: f, mtime: mtime(f)))
                }
            }
        }
        return refs.sorted { $0.mtime > $1.mtime }
    }

    /// Every top-level transcript in ~/.claude/projects, keyed by session uuid.
    private static func transcriptIndex() -> [String: FileRef] {
        let root = claudeDir.appendingPathComponent("projects")
        var index: [String: FileRef] = [:]
        for project in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            let files = (try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for f in files where f.pathExtension == "jsonl" {
                let ref = FileRef(url: f, mtime: mtime(f))
                let key = f.deletingPathExtension().lastPathComponent
                if let existing = index[key], existing.mtime > ref.mtime { continue }
                index[key] = ref
            }
        }
        return index
    }

    private static func mtime(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static func readHead(_ url: URL, bytes: Int) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let data = try? h.read(upToCount: bytes) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// `priorCliSessionIds` sits deep in a large file, so find it without parsing the whole thing.
    private static func priorIds(_ url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let key = "\"priorCliSessionIds\":[".data(using: .utf8),
              let r = data.range(of: key),
              let end = data[r.upperBound...].firstIndex(of: UInt8(ascii: "]")) else { return [] }
        let body = String(decoding: data[r.upperBound..<end], as: UTF8.self)
        return body.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }.filter { !$0.isEmpty }
    }

    // MARK: Light field extraction from a JSON prefix

    private static func field(_ key: String, in text: String) -> String? {
        let pattern = "\"\(key)\":\"((?:[^\"\\\\]|\\\\.)*)\""
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        let raw = "\"" + text[r] + "\""
        return (try? JSONSerialization.jsonObject(with: Data(raw.utf8), options: .fragmentsAllowed)) as? String
    }

    private static func numberField(_ key: String, in text: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: "\"\(key)\":\"?([0-9.]+)"),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return Double(text[r])
    }

    private static func boolField(_ key: String, in text: String) -> Bool? {
        if text.contains("\"\(key)\":true") { return true }
        if text.contains("\"\(key)\":false") { return false }
        return nil
    }

    private static func firstPrompt(in head: String) -> String? {
        for line in head.split(separator: "\n") where line.contains("\"type\":\"user\"") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  obj["isMeta"] as? Bool != true,
                  let text = promptText(obj) else { continue }
            return text
        }
        return nil
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    private static func clean(_ s: String) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > 140 ? String(flat.prefix(140)) + "…" : flat
    }

    // MARK: Transcript analysis (task-list progress)

    struct PlanItem: Codable { var text: String; var status: String }

    struct TranscriptInfo: Codable {
        var items: [PlanItem] = []
        var wrapped = false
        var ask: String?
        var title: String?
        var total: Int { items.count }
        var done: Int { items.filter { $0.status == "completed" }.count }
        var current: String? { items.first { $0.status == "in_progress" }?.text }
    }

    /// How far each transcript has been read, so a refresh only reads what was appended since.
    private struct ScanState: Codable { var offset: UInt64; var info: TranscriptInfo }
    private static var scans: [String: ScanState] = loadScans()
    private static var scansDirty = false

    private static var scanCacheURL: URL? {
        fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("session-pulse-scans.json")
    }

    private static func loadScans() -> [String: ScanState] {
        guard let url = scanCacheURL, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: ScanState].self, from: data) else { return [:] }
        return decoded
    }

    static func saveScans() {
        guard scansDirty, let url = scanCacheURL, let data = try? JSONEncoder().encode(scans) else { return }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        scansDirty = false
    }

    private static let markers = ["update_plan", "wrap_up", "TodoWrite", "\"type\":\"user\"", "-title\""]
        .map { Data($0.utf8) }

    /// Replays task-list tool calls. The first read starts at most `firstReadBytes` from the end
    /// (a list older than that belongs to a long-finished task); later reads pick up where the last one stopped.
    static func analyze(_ url: URL, firstReadBytes: UInt64 = 24 << 20) -> TranscriptInfo {
        guard let h = try? FileHandle(forReadingFrom: url), let size = try? h.seekToEnd() else { return TranscriptInfo() }
        defer { try? h.close() }
        var state = scans[url.path] ?? ScanState(offset: size > firstReadBytes ? size - firstReadBytes : 0, info: TranscriptInfo())
        if size < state.offset { state = ScanState(offset: 0, info: TranscriptInfo()) }   // rewritten
        guard size > state.offset else { return state.info }

        let skipFirstLine = scans[url.path] == nil && state.offset > 0   // landed mid-line
        try? h.seek(toOffset: state.offset)
        var carry = Data()
        var consumed = state.offset
        var dropping = skipFirstLine
        while true {
            let chunk: Data
            do { guard let c = try h.read(upToCount: 4 << 20), !c.isEmpty else { break }; chunk = c } catch { break }
            autoreleasepool {
                var buf = carry
                buf.append(chunk)
                var hits: [Range<Int>] = []
                var lineStart = 0
                buf.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                    guard let base = raw.baseAddress else { return }
                    let count = raw.count
                    while lineStart < count, let nlPtr = memchr(base + lineStart, 0x0A, count - lineStart) {
                        let nl = base.distance(to: nlPtr)
                        consumed += UInt64(nl - lineStart + 1)
                        defer { lineStart = nl + 1 }
                        if dropping { dropping = false; continue }
                        let len = nl - lineStart
                        if markers.contains(where: { m in m.withUnsafeBytes { memmem(base + lineStart, len, $0.baseAddress, m.count) != nil } }) {
                            hits.append(lineStart..<nl)
                        }
                    }
                }
                for r in hits {
                    if let obj = try? JSONSerialization.jsonObject(with: buf.subdata(in: r)) as? [String: Any] {
                        apply(obj, to: &state.info)
                    }
                }
                carry = buf.subdata(in: lineStart..<buf.count)
            }
        }
        state.offset = consumed   // an unfinished last line is read again next time
        scans[url.path] = state
        scansDirty = true
        return state.info
    }

    private static func apply(_ obj: [String: Any], to info: inout TranscriptInfo) {
        switch obj["type"] as? String {
        case "custom-title":
            if let t = nonEmpty(obj["customTitle"] as? String) { info.title = t }
        case "ai-title":
            if let t = nonEmpty(obj["aiTitle"] as? String) { info.title = t }
        case "user":
            // A new prompt from the person starts a new task: drop a finished list and any answered question.
            guard obj["isMeta"] as? Bool != true, promptText(obj) != nil else { return }
            info.ask = nil
            if info.wrapped { info.items = []; info.wrapped = false }
        case "assistant":
            guard let content = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]] else { return }
            for block in content where block["type"] as? String == "tool_use" {
                let name = block["name"] as? String ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                if name.hasSuffix("update_plan") { applyPlan(input, to: &info) }
                else if name.hasSuffix("wrap_up") {
                    for i in info.items.indices { info.items[i].status = "completed" }
                    info.wrapped = true
                    info.ask = nonEmpty(input["ask"] as? String)
                } else if name == "TodoWrite", let todos = input["todos"] as? [[String: Any]] {
                    info.items = todos.map { PlanItem(text: $0["content"] as? String ?? "", status: $0["status"] as? String ?? "pending") }
                    info.wrapped = !info.items.isEmpty && info.items.allSatisfy { $0.status == "completed" }
                }
            }
        default: break
        }
    }

    private static func applyPlan(_ input: [String: Any], to info: inout TranscriptInfo) {
        if let items = input["items"] as? [[String: Any]] {
            info.items = items.map { PlanItem(text: $0["content"] as? String ?? "", status: $0["status"] as? String ?? "pending") }
            info.wrapped = false
            info.ask = nil
            return
        }
        if input["advance"] as? Bool == true {
            if let i = info.items.firstIndex(where: { $0.status == "in_progress" }) { info.items[i].status = "completed" }
            if let j = info.items.firstIndex(where: { $0.status == "pending" }) { info.items[j].status = "in_progress" }
        }
        for n in input["done"] as? [Int] ?? [] where n >= 1 && n <= info.items.count {
            info.items[n - 1].status = "completed"
        }
        if let n = input["start"] as? Int, n >= 1, n <= info.items.count {
            info.items[n - 1].status = "in_progress"
        }
    }

    /// The person's own words in a user record, or nil for tool results and injected context.
    private static func promptText(_ obj: [String: Any]) -> String? {
        let content = (obj["message"] as? [String: Any])?["content"]
        var text: String?
        if let s = content as? String { text = s }
        else if let blocks = content as? [[String: Any]] {
            if blocks.contains(where: { $0["type"] as? String == "tool_result" }) { return nil }
            text = blocks.first { $0["type"] as? String == "text" }?["text"] as? String
        }
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, !t.hasPrefix("<") else { return nil }
        return t
    }
}

// MARK: - Links

/// On macOS a widget click opens the widget's own app with the URL, not the URL itself,
/// so widget links are wrapped as keepworking://open?to=<claude://…> and the app forwards them.
enum PulseLink {
    static func wrap(_ target: URL) -> URL {
        var c = URLComponents()
        c.scheme = "keepworking"
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "to", value: target.absoluteString)]
        return c.url ?? target
    }

    /// The claude:// link inside a wrapped URL; only claude:// targets are forwarded.
    static func unwrap(_ url: URL) -> URL? {
        guard url.scheme == "keepworking",
              let to = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "to" })?.value,
              let target = URL(string: to), target.scheme == "claude" else { return nil }
        return target
    }
}

// MARK: - What the widget shows

extension SessionSnapshot {
    /// Only what the widget draws, minus the "2m" ages: a change to anything else (a transcript written again,
    /// the exact time of the last write) must not reload it, since every reload redraws the widget from scratch.
    /// The ages are refreshed by the app's once-a-minute timer instead: ten sessions each tick over at a
    /// different second, which alone reloaded the widget every few seconds.
    var shownKey: String {
        "\(id)|\(title)|\(project)|\(kind)|\(state)|\(stepsDone)/\(stepsTotal)|\(detail ?? "")"
    }
}

// MARK: - Last image


extension SessionStore {
    /// The last image in a transcript (pasted by you or read by Claude), shrunk to a small JPEG. Reads from the
    /// end of the file backwards, at most 32 MB, so a long session stays cheap. Nil when there is none.
    static func lastImage(transcript path: String, maxPixels: Int = 520) -> Data? {
        guard let h = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        guard size > 0 else { return nil }
        let marker = Data("\"type\":\"base64\"".utf8), dataKey = Data("\"data\":\"".utf8), quote = UInt8(ascii: "\"")
        var window: UInt64 = 4 << 20
        while true {
            let start = size > window ? size - window : 0
            try? h.seek(toOffset: start)
            guard let buf = try? h.readToEnd() else { return nil }
            if let m = buf.range(of: marker, options: .backwards),
               let d = buf.range(of: dataKey, in: m.upperBound..<min(buf.endIndex, m.upperBound + 200)) {
                var b64: Data
                if let q = buf[d.upperBound...].firstIndex(of: quote) {
                    b64 = buf[d.upperBound..<q]
                } else { return nil }
                b64 = Data(b64.filter { $0 != UInt8(ascii: "\\") })
                guard let raw = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { return nil }
                return thumbnail(raw, maxPixels: maxPixels)
            }
            if start == 0 || window >= 32 << 20 { return nil }
            window *= 2
        }
    }

    private static func thumbnail(_ raw: Data, maxPixels: Int) -> Data? {
        guard let src = CGImageSourceCreateWithData(raw as CFData, nil),
              let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                  kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dst, img, [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
        return CGImageDestinationFinalize(dst) ? out as Data : nil
    }
}

// MARK: - Formatting

extension Date {
    /// "now", "4m", "2h", "3d"
    var shortAgo: String {
        let s = max(0, Date().timeIntervalSince(self))
        switch s {
        case ..<60: return "now"
        case ..<3600: return "\(Int(s / 60))m"
        case ..<86_400: return "\(Int(s / 3600))h"
        default: return "\(Int(s / 86_400))d"
        }
    }
}

extension SessionSnapshot {
    /// Placeholder and render-harness data: obviously sample sessions, one per state.
    static let samples: [SessionSnapshot] = {
        func make(_ id: String, _ title: String, _ project: String, _ kind: SessionKind, _ state: SessionState,
                  ago: TimeInterval, done: Int = 0, total: Int = 0, detail: String? = nil) -> SessionSnapshot {
            SessionSnapshot(id: id, title: title, project: project, kind: kind, state: state,
                            lastActivity: Date().addingTimeInterval(-ago), stepsDone: done, stepsTotal: total,
                            detail: detail, url: URL(string: "claude://code/new")!)
        }
        return [
            make("1", "Sample: onboarding flow", "acme-app", .code, .waiting, ago: 120, done: 5, total: 5,
                 detail: "Merge the migration now, or wait for review?"),
            make("2", "Sample: billing refactor", "acme-api", .code, .running, ago: 5, done: 2, total: 4,
                 detail: "Move invoices to the new ledger"),
            make("3", "Sample: flaky login test", "acme-app", .code, .running, ago: 60),
            make("4", "Sample: release notes", "acme-docs", .code, .done, ago: 3100, done: 3, total: 3),
            make("5", "Sample: search ranking", "acme-api", .code, .idle, ago: 400, done: 2, total: 5),
            make("6", "Sample: pricing page copy", "acme-site", .code, .idle, ago: 4000),
            make("7", "Sample: CI cache cleanup", "infra", .terminal, .idle, ago: 9000),
            make("8", "Sample: research brief", "Cowork", .cowork, .idle, ago: 90_000),
            make("9", "Sample: design tokens", "acme-site", .code, .idle, ago: 12_000),
            make("10", "Sample: analytics events", "acme-app", .code, .idle, ago: 20_000),
        ]
    }()
}
