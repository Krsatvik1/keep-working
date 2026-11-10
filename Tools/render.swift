// Renders the widget families to PNGs, for checking layout without placing the widget.
// swiftc -parse-as-library -D RENDER_HARNESS Shared/SessionStore.swift Widget/AfootWidget.swift Tools/render.swift -o build/render
//   ./build/render <outdir>               live data
//   ./build/render <outdir> samples [tick] sample data, at a given animation tick
//   ./build/render <outdir> clawd          every character mood across 8 ticks
import SwiftUI
import WidgetKit

@main
struct Render {
    @MainActor static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let out = args.first ?? "."
        let mode = args.count > 1 ? args[1] : "live"
        if mode == "clawd" { return clawdSheet(out) }
        let tick = args.count > 2 ? Int(args[2]) ?? 0 : 0
        let sessions = mode == "samples" ? SessionSnapshot.samples : SessionStore.load(limit: 10)
        let entry = PulseEntry(date: .now, sessions: sessions, error: SessionStore.lastError, tick: tick)
        for s in entry.sessions { print(s.state.rawValue, s.stepsDone, s.stepsTotal, s.kind.rawValue, s.title, "|", s.detail ?? "", "|", s.url.absoluteString) }
        let sizes: [(String, WidgetFamily, CGSize)] = [("large", .systemLarge, CGSize(width: 344, height: 344)),
                                                       ("xl", .systemExtraLarge, CGSize(width: 714, height: 344)),
                                                       ("medium", .systemMedium, CGSize(width: 344, height: 158)),
                                                       ("small", .systemSmall, CGSize(width: 170, height: 170))]
        for scheme in [ColorScheme.light, .dark] {
            for (name, fam, size) in sizes {
                let view = PulseWidgetView(entry: entry, forcedFamily: fam)
                    .padding(16)
                    .frame(width: size.width, height: size.height)
                    .background(fam == .systemSmall && ordered(entry.sessions).first?.state == .waiting
                                ? AnyShapeStyle(LinearGradient(colors: [Pulse.clay.opacity(0.28), Pulse.clay.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.clear))
                    .background(scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.118) : Color(white: 0.965))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .environment(\.colorScheme, scheme)
                write(view, "\(out)/\(name)-\(scheme == .dark ? "dark" : "light")-t\(tick).png")
            }
        }
    }

    @MainActor static func clawdSheet(_ out: String) {
        let moods: [(String, Mood)] = [("working", .working), ("waiting", .waiting), ("done", .done),
                                       ("resting", .resting), ("sleeping", .sleeping)]
        for scheme in [ColorScheme.light, .dark] {
            let sheet = VStack(alignment: .leading, spacing: 18) {
                ForEach(moods, id: \.0) { name, mood in
                    HStack(spacing: 22) {
                        Text(name).font(.system(size: 13, weight: .semibold)).frame(width: 70, alignment: .leading)
                        ForEach(0..<8, id: \.self) { t in
                            VStack(spacing: 4) {
                                Clawd(mood: mood, tick: t, px: 6)
                                Text("t\(t)").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        Clawd(mood: mood, tick: 0, px: 2.5)
                    }
                }
            }
            .padding(24)
            .background(scheme == .dark ? Color(red: 0.17, green: 0.17, blue: 0.18) : Color(white: 0.93))
            .environment(\.colorScheme, scheme)
            write(sheet, "\(out)/clawd-\(scheme == .dark ? "dark" : "light").png")
        }
    }

    @MainActor static func write<V: View>(_ view: V, _ path: String) {
        let r = ImageRenderer(content: view); r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
