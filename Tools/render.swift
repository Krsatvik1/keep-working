// Renders the widget families with live data to PNGs, for checking layout without placing the widget.
// swiftc -parse-as-library -D RENDER_HARNESS Shared/SessionStore.swift Widget/SessionPulseWidget.swift Tools/render.swift -o build/render
import SwiftUI
import WidgetKit

@main
struct Render {
    @MainActor static func main() {
        let out = CommandLine.arguments.dropFirst().first ?? "."
        let live = CommandLine.arguments.count < 3 || CommandLine.arguments[2] != "samples"
        let entry = PulseEntry(date: .now, sessions: live ? SessionStore.load(limit: 10) : SessionSnapshot.samples,
                               error: SessionStore.lastError)
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
                    .background(fam == .systemSmall && entry.sessions.contains { $0.state == .waiting }
                                ? AnyShapeStyle(LinearGradient(colors: [Pulse.clay.opacity(0.28), Pulse.clay.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.clear))
                    .background(scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.118) : Color(white: 0.965))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .environment(\.colorScheme, scheme)
                let r = ImageRenderer(content: view); r.scale = 2
                if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(out)/\(name)-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
        }
    }
}
