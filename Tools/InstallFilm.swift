// The install walkthrough for the download page: a stock Mac desktop where a pointer drags Keep Working into
// Applications, gets past Gatekeeper in Privacy & Security, and drops the widget onto the desktop.
// Every window is redrawn here in dark mode, laid out from screenshots of the real ones; the widget is the
// real view. Rendered by Tools/install-film.sh, frames drawn by FilmMain.
import AppKit
import SwiftUI
import WidgetKit

enum InstallFilm {
    static let length = 24.5
}

// MARK: - Look

private enum Dark {
    static let window = Color(white: 0.155)
    static let sidebar = Color(white: 0.205)
    static let panel = Color(white: 0.215)
    static let card = Color(white: 0.20)
    static let line = Color.white.opacity(0.09)
    static let text = Color.white.opacity(0.92)
    static let dim = Color.white.opacity(0.55)
    static let blue = Color(red: 0.04, green: 0.47, blue: 0.98)
    static let button = Color.white.opacity(0.13)
}

private enum Icons {
    static func file(_ path: String) -> NSImage { NSWorkspace.shared.icon(forFile: path) }
    static let app = NSImage(contentsOfFile: "App/Resources/AppIcon.icns") ?? NSImage()
    static let applications = file("/Applications")
    static let downloads = file(NSHomeDirectory() + "/Downloads")
    static let privacy = file("/System/Library/ExtensionKit/Extensions/SecurityPrivacyExtension.appex")
    static let caution = NSImage(contentsOfFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionBadgeIcon.icns") ?? NSImage()
    static let apps: [(String, NSImage)] = [
        ("App Store", "/System/Applications/App Store.app"), ("Keep Working", ""), ("Mail", "/System/Applications/Mail.app"),
        ("Maps", "/System/Applications/Maps.app"), ("Music", "/System/Applications/Music.app"), ("Notes", "/System/Applications/Notes.app"),
        ("Safari", "/Applications/Safari.app"), ("System Settings", "/System/Applications/System Settings.app"),
    ].map { ($0.0, $0.1.isEmpty ? app : file($0.1)) }
    static let drawer: [(String, NSImage)] = [
        ("Clock", "/System/Applications/Clock.app"), ("Contacts", "/System/Applications/Contacts.app"),
        ("Find My", "/System/Applications/FindMy.app"), ("Home", "/System/Applications/Home.app"),
        ("Journal", "/System/Applications/Journal.app"), ("Keep Working", ""), ("Notes", "/System/Applications/Notes.app"),
        ("Photos", "/System/Applications/Photos.app"), ("Podcasts", "/System/Applications/Podcasts.app"),
        ("Reminders", "/System/Applications/Reminders.app"), ("Safari", "/Applications/Safari.app"),
    ].map { ($0.0, $0.1.isEmpty ? app : file($0.1)) }
}

private func img(_ i: NSImage, _ side: CGFloat) -> some View {
    Image(nsImage: i).resizable().interpolation(.high).frame(width: side, height: side)
}

private func trafficLights(dim: Bool = false) -> some View {
    HStack(spacing: 8) {
        ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
            Circle().fill(dim ? Color.white.opacity(0.2) : $0).frame(width: 12, height: 12)
        }
    }
}

/// A window's frame: rounded, hairline edge, soft shadow, grouped first so the shadow comes from the outline.
private extension View {
    func macWindow(_ r: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        return self.clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.13), lineWidth: 0.8))
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
    }
    /// Pops in from `k` = 0 to 1, a little scale and a fade, like macOS opening a window or an alert.
    func popIn(_ k: Double, from: Double = 0.92) -> some View {
        self.scaleEffect(from + (1 - from) * k).opacity(min(1, k * 1.6))
    }
}

// MARK: - The Gatekeeper dial

/// The safe-dial icon macOS puts on its security alerts, redrawn.
private struct DialIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
            Circle().fill(RadialGradient(colors: [Color(white: 0.55), Color(white: 0.28)], center: .center, startRadius: 2, endRadius: 22))
                .frame(width: 40, height: 40)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<48 {
                    let a = Double(i) / 48 * 2 * .pi, long = i % 4 == 0
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * 15, y: c.y + sin(a) * 15))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * (long ? 19.5 : 18), y: c.y + sin(a) * (long ? 19.5 : 18)))
                    ctx.stroke(p, with: .color(.white.opacity(0.75)), lineWidth: 0.8)
                }
            }
            .frame(width: 44, height: 44)
            Circle().fill(RadialGradient(colors: [Color(white: 0.85), Color(white: 0.5)], center: .topLeading, startRadius: 1, endRadius: 16))
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Color(white: 0.45)).frame(width: 3, height: 3)
                    .offset(x: i % 2 == 0 ? -23 : 23, y: i < 2 ? -23 : 23)
            }
        }
        .frame(width: 56, height: 56)
        .overlay(alignment: .bottomTrailing) { img(Icons.caution, 30).offset(x: 9, y: 7) }
    }
}

// MARK: - The film

struct InstallFrame: View {
    let t: Double

    // Desktop points (MacDesktop is 1440 x 900).
    static let finder = CGRect(x: 340, y: 170, width: 760, height: 440)
    static let settings = CGRect(x: 300, y: 110, width: 780, height: 540)
    static let gallery = CGRect(x: 280, y: 449, width: 840, height: 451)
    static let dialogCenter = CGPoint(x: 720, y: 400)
    static let sheetCenter = CGPoint(x: 690, y: 330)
    static let menuAt = CGPoint(x: 900, y: 560)
    static let slot = CGPoint(x: 24, y: 46)                   // where the widget lands
    static let medium = CGSize(width: 344, height: 164)
    static let xl = CGSize(width: 704, height: 344)
    static let previewScale = 0.6
    static var mediumPreview: CGRect {
        CGRect(x: gallery.minX + 250 + 98 + 28, y: gallery.minY + 104, width: medium.width * previewScale, height: medium.height * previewScale)
    }

    private static let stageY = 480.0
    /// Camera keys: (time, scale, desktop point held at the stage's middle).
    private static let keys: [(Double, Double, Double, Double)] = [
        (0, 1.0417, 720, 440), (0.6, 1.0417, 720, 440), (1.4, 1.34, 720, 390), (4.7, 1.34, 720, 390),
        (5.2, 1.6, 720, 400), (6.7, 1.6, 720, 400), (7.3, 1.34, 720, 390), (7.5, 1.34, 720, 390),
        (8.1, 1.8, 540, 270), (8.75, 1.8, 540, 270),
        (9.5, 1.42, 700, 370), (14.2, 1.42, 700, 370), (14.85, 1.75, 900, 560), (16.3, 1.75, 900, 560),
        (16.9, 1.45, 700, 496), (17.75, 1.45, 700, 496), (18.7, 1.0417, 720, 440), (20.7, 1.0417, 720, 440),
        (21.6, 1.5, 640, 320), (23.7, 1.5, 640, 320), (24.5, 1.0417, 720, 440),
    ]
    /// Where the pointer is: eased between these (time, desktop point).
    private static let path: [(Double, CGPoint)] = [
        (0.0, CGPoint(x: 1120, y: 760)), (1.4, CGPoint(x: 605, y: 290)), (1.8, CGPoint(x: 605, y: 290)),
        (3.0, CGPoint(x: 432, y: 291)), (4.0, CGPoint(x: 432, y: 291)), (4.45, CGPoint(x: 730, y: 290)),
        (5.8, CGPoint(x: 730, y: 290)), (6.45, CGPoint(x: 662, y: 492)), (6.7, CGPoint(x: 662, y: 492)),
        (7.05, CGPoint(x: 364, y: 194)), (7.3, CGPoint(x: 364, y: 194)),
        (7.85, CGPoint(x: 21, y: 13)), (8.15, CGPoint(x: 21, y: 13)), (8.6, CGPoint(x: 86, y: 74)),
        (9.4, CGPoint(x: 86, y: 74)), (10.7, CGPoint(x: 987, y: 392)), (11.2, CGPoint(x: 987, y: 392)),
        (11.75, CGPoint(x: 690, y: 447)), (12.35, CGPoint(x: 690, y: 447)), (12.9, CGPoint(x: 900, y: 590)),
        (13.6, CGPoint(x: 900, y: 590)), (13.95, CGPoint(x: 324, y: 134)), (14.15, CGPoint(x: 324, y: 134)),
        (14.85, CGPoint(x: 900, y: 560)), (15.2, CGPoint(x: 900, y: 560)), (15.8, CGPoint(x: 1000, y: 705)),
        (16.4, CGPoint(x: 1000, y: 705)), (17.15, CGPoint(x: 582, y: 813)), (17.7, CGPoint(x: 582, y: 813)),
        (19.0, CGPoint(x: 376, y: 218)), (19.4, CGPoint(x: 376, y: 218)), (20.0, CGPoint(x: 1068, y: 876)),
        (20.4, CGPoint(x: 1068, y: 876)), (21.3, CGPoint(x: 1180, y: 700)),
    ]
    /// Clicks: time, and whether it's a right-click.
    private static let clicks: [(Double, Bool)] = [
        (1.8, false), (3.55, false), (4.55, false), (4.72, false), (6.6, false), (7.15, false), (8.0, false), (8.75, false),
        (11.0, false), (12.1, false), (14.05, false), (15.0, true), (16.2, false), (17.6, false), (20.2, false),
    ]
    /// Mouse held down (drags).
    private static let holds: [(Double, Double)] = [(1.8, 3.0), (17.6, 19.0)]

    private static let captions: [(Double, Double, String, String)] = [
        (0.3, 4.9, "1", "Drag it into Applications, then open it."),
        (4.9, 7.6, "2", "macOS stops it once. Click Done."),
        (7.6, 12.4, "3", "Privacy & Security: Open Anyway."),
        (12.4, 14.6, "3", "Then Touch ID."),
        (14.6, 16.9, "4", "Right-click the desktop: Edit Widgets."),
        (16.9, 18.6, "4", "Pick a size."),
        (18.6, 20.9, "4", "Drag it onto the desktop."),
        (20.9, 24.2, "", "That's it."),
    ]

    // MARK: Body

    var body: some View {
        ZStack {
            LinearGradient(colors: [FilmFrame.paperTop, FilmFrame.paperBottom], startPoint: .top, endPoint: .bottom)
            desktop
            caption
        }
        .frame(width: Script.size.width, height: Script.size.height)
        .clipped()
    }

    private var camera: (s: Double, fx: Double, fy: Double) {
        let keys = Self.keys
        guard let j = keys.firstIndex(where: { $0.0 > t }) else { let l = keys.last!; return (l.1, l.2, l.3) }
        guard j > 0 else { let f = keys[0]; return (f.1, f.2, f.3) }
        let a = keys[j - 1], b = keys[j], k = ease((t - a.0) / (b.0 - a.0))
        return (a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k, a.3 + (b.3 - a.3) * k)
    }

    private var pointer: CGPoint {
        let p = Self.path
        guard let j = p.firstIndex(where: { $0.0 > t }) else { return p.last!.1 }
        guard j > 0 else { return p[0].1 }
        let a = p[j - 1], b = p[j], k = ease((t - a.0) / (b.0 - a.0))
        return CGPoint(x: a.1.x + (b.1.x - a.1.x) * k, y: a.1.y + (b.1.y - a.1.y) * k)
    }

    private var desktop: some View {
        let c = camera, size = MacDesktop.size
        return ZStack(alignment: .topLeading) {
            MacDesktop()
            placedWidget
            if t >= 0.35 && t < 7.33 { finder }
            if t >= 4.85 && t < 6.78 { gatekeeper }
            if t >= 8.0 && t < 8.8 { appleMenu }
            if t >= 8.75 && t < 14.27 { settings }
            if t >= 14.95 && t < 16.35 { contextMenu }
            if t >= 16.25 && t < 20.75 { galleryPanel }
            dragGhosts
            cursor
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .padding(10)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 40, y: 22)
        .scaleEffect(c.s)
        .position(x: 960 + (size.width / 2 - c.fx) * c.s, y: Self.stageY + (size.height / 2 - c.fy) * c.s)
    }

    // MARK: Finder

    private var finder: some View {
        let f = Self.finder
        let k = ramp(t, 0.35, 0.7) * (1 - ramp(t, 7.18, 7.33))
        let inApps = t >= 3.62
        let dropping = t >= 2.6 && t < 3.62
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                trafficLights().padding(.leading, 18).padding(.top, 18)
                Text("Favourites").font(.system(size: 11, weight: .semibold)).foregroundStyle(Dark.dim)
                    .padding(.leading, 18).padding(.top, 22).padding(.bottom, 6)
                ForEach(Array(["Recents", "Applications", "Desktop", "Documents", "Downloads"].enumerated()), id: \.offset) { i, name in
                    let symbols = ["clock", "app.dashed", "menubar.dock.rectangle", "doc", "arrow.down.circle"]
                    let selected = (i == 4 && !inApps) || (i == 1 && inApps)
                    let target = i == 1 && dropping
                    HStack(spacing: 8) {
                        Image(systemName: i == 1 ? "a.square" : symbols[i]).font(.system(size: 13, weight: .regular))
                            .foregroundStyle(selected || target ? Color.white : Dark.blue).frame(width: 18)
                        Text(name).font(.system(size: 13)).foregroundStyle(Dark.text)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(target ? Dark.blue : selected ? Color.white.opacity(0.12) : .clear)
                    )
                    .padding(.horizontal, 8)
                }
                Spacer()
            }
            .frame(width: 180)
            .background(Dark.sidebar)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "chevron.left").foregroundStyle(Dark.dim)
                    Image(systemName: "chevron.right").foregroundStyle(Dark.dim.opacity(0.5))
                    Text(inApps ? "Applications" : "Downloads").font(.system(size: 15, weight: .bold)).foregroundStyle(Dark.text)
                    Spacer()
                    Image(systemName: "square.grid.2x2").foregroundStyle(Dark.dim)
                    Image(systemName: "magnifyingglass").foregroundStyle(Dark.dim)
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 20).frame(height: 52)
                Rectangle().fill(Dark.line).frame(height: 1)
                if inApps { appsGrid } else { downloadsGrid }
                Spacer()
            }
            .background(Dark.window)
        }
        .frame(width: f.width, height: f.height)
        .macWindow()
        .popIn(k)
        .offset(x: f.minX, y: f.minY)
    }

    private func gridItem(_ name: String, _ icon: NSImage, selected: Bool) -> some View {
        VStack(spacing: 6) {
            img(icon, 64)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.white.opacity(0.14) : .clear))
            Text(name).font(.system(size: 12)).foregroundStyle(Dark.text)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Dark.blue : .clear))
                .lineLimit(1)
        }
        .frame(width: 120, height: 112)
    }

    private var downloadsGrid: some View {
        HStack(spacing: 0) { gridItem("Keep Working", Icons.app, selected: t >= 1.8); Spacer() }
            .padding(.leading, 25).padding(.top, 16)
    }

    private var appsGrid: some View {
        let selected = t >= 4.55
        let opening = ramp(t, 4.72, 4.95) * (1 - ramp(t, 4.95, 5.2))
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { col in
                        let i = row * 4 + col
                        gridItem(Icons.apps[i].0, Icons.apps[i].1, selected: i == 1 && selected)
                            .scaleEffect(i == 1 ? 1 + 0.08 * opening : 1)
                    }
                }
            }
        }
        .padding(.leading, 25).padding(.top, 16)
    }

    // MARK: Gatekeeper

    private var gatekeeper: some View {
        let k = ramp(t, 4.85, 5.15) * (1 - ramp(t, 6.66, 6.78))
        let pressed = t >= 6.6 && t < 6.7
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                DialIcon()
                Spacer()
                Circle().fill(Dark.button).frame(width: 24, height: 24)
                    .overlay(Text("?").font(.system(size: 14, weight: .medium)).foregroundStyle(Dark.text))
            }
            Text("“Keep Working” Not Opened").font(.system(size: 14, weight: .bold)).foregroundStyle(Dark.text)
                .padding(.top, 18)
            Text("Apple could not verify “Keep Working” is free of malware that may harm your Mac or compromise your privacy.")
                .font(.system(size: 12.5)).foregroundStyle(Dark.text.opacity(0.85)).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                pill("Done", fill: pressed ? Color.white.opacity(0.26) : Dark.button)
                pill("Move to Bin", fill: Dark.button)
            }
        }
        .padding(20)
        .frame(width: 280, height: 270)
        .background(Dark.panel.opacity(0.97))
        .macWindow(24)
        .popIn(k, from: 0.86)
        .position(Self.dialogCenter)
    }

    private func pill(_ title: String, fill: Color, text: Color = Dark.text, height: CGFloat = 32) -> some View {
        Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(text)
            .frame(maxWidth: .infinity).frame(height: height)
            .background(Capsule().fill(fill))
    }

    // MARK: Apple menu

    private var appleMenu: some View {
        let k = ramp(t, 8.0, 8.08) * (1 - ramp(t, 8.72, 8.8))
        let hover = t >= 8.5
        let rows: [String?] = ["About This Mac", nil, "System Settings…", "App Store", nil, "Recent Items", nil, "Force Quit…", nil, "Sleep", "Restart…", "Shut Down…", nil, "Lock Screen", "Log Out…"]
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.18)).frame(width: 30, height: 22).offset(x: 6, y: 2)
            menu(rows, width: 230, highlighted: hover ? 2 : nil).offset(x: 8, y: 27)
        }
        .opacity(k)
    }

    private func menu(_ rows: [String?], width: CGFloat, highlighted: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if let row {
                    HStack {
                        Text(row).font(.system(size: 13)).foregroundStyle(Dark.text)
                        Spacer()
                        if row == "Group Stacks By" || row == "Recent Items" { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Dark.dim) }
                    }
                    .padding(.horizontal, 12).frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(i == highlighted ? Dark.blue : .clear))
                } else {
                    Rectangle().fill(Dark.line).frame(height: 1).padding(.horizontal, 12).padding(.vertical, 4)
                }
            }
        }
        .padding(5)
        .frame(width: width)
        .background(Color(white: 0.17).opacity(0.97))
        .macWindow(10)
    }

    // MARK: System Settings

    private var settings: some View {
        let s = Self.settings
        let k = ramp(t, 8.75, 9.15) * (1 - ramp(t, 14.12, 14.27))
        let scroll = 110 * ramp(t, 9.5, 10.5)
        let approved = t >= 13.7
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                trafficLights().padding(.leading, 18).padding(.top, 18)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12))
                    Text("Search").font(.system(size: 13))
                    Spacer()
                }
                .foregroundStyle(Dark.dim).padding(.horizontal, 10).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 8)
                ForEach(Array(Self.sidebarRows.enumerated()), id: \.offset) { i, row in
                    if let row {
                        HStack(spacing: 9) {
                            Group {
                                if row.0 == "Privacy & Security" { img(Icons.privacy, 22) } else {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(row.2).frame(width: 21, height: 21)
                                        .overlay(Image(systemName: row.1).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white))
                                }
                            }
                            Text(row.0).font(.system(size: 13)).foregroundStyle(Dark.text)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7).fill(row.0 == "Privacy & Security" ? Dark.blue : .clear))
                        .padding(.horizontal, 10)
                    } else { Spacer().frame(height: 12) }
                }
                Spacer()
            }
            .frame(width: 230)
            .background(Dark.sidebar)
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "chevron.left").foregroundStyle(Dark.dim)
                    Image(systemName: "chevron.right").foregroundStyle(Dark.dim.opacity(0.5))
                    Text("Privacy & Security").font(.system(size: 15, weight: .bold)).foregroundStyle(Dark.text)
                    Spacer()
                }
                .font(.system(size: 14, weight: .medium)).padding(.horizontal, 20).frame(height: 52)
                // An overlay pins the tall content to the top; a frame would centre its overflow.
                Color.clear
                    .overlay(alignment: .top) { settingsContent(approved: approved).offset(y: -scroll) }
                    .clipped()
            }
            .background(Dark.window)
        }
        .frame(width: s.width, height: s.height)
        .macWindow()
        .overlay { if t >= 11.0 && t < 12.4 { confirmSheet } }
        .overlay { if t >= 12.4 && t < 13.8 { touchIDSheet } }
        .popIn(k)
        .offset(x: s.minX, y: s.minY)
    }

    private static let sidebarRows: [(String, String, Color)?] = [
        ("Notifications", "bell.badge.fill", .red), ("Sound", "speaker.wave.2.fill", Color(red: 0.95, green: 0.25, blue: 0.4)),
        ("Focus", "moon.fill", .indigo), ("Screen Time", "hourglass", .purple), nil,
        ("Lock Screen", "lock.fill", Color(white: 0.1)), ("Privacy & Security", "", .blue),
        ("Touch ID & Password", "touchid", Color(red: 0.95, green: 0.3, blue: 0.35)), ("Users & Groups", "person.2.fill", .blue), nil,
        ("Game Center", "gamecontroller.fill", .pink), ("iCloud", "icloud.fill", Color(red: 0.25, green: 0.6, blue: 1)),
        ("Internet Accounts", "at", .blue), ("Wallet & Apple Pay", "wallet.pass.fill", Color(white: 0.2)),
    ]

    private func row(_ title: String, _ symbol: String?, _ tint: Color = .blue, value: String? = nil, chevron: Bool = true) -> some View {
        HStack(spacing: 10) {
            if let symbol {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(white: 0.11)).frame(width: 24, height: 24)
                    .overlay(Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint))
            }
            Text(title).font(.system(size: 13)).foregroundStyle(Dark.text)
            Spacer()
            if let value { Text(value).font(.system(size: 13)).foregroundStyle(Dark.dim) }
            if chevron { Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Dark.dim) }
        }
        .padding(.horizontal, 14).frame(height: 44)
    }

    private func group<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Dark.card))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Dark.line, lineWidth: 0.8))
    }

    /// Fixed heights, so the Open Anyway button lands where the pointer goes: card top at 308 before the scroll.
    private func settingsContent(approved: Bool) -> some View {
        let pressed = t >= 11.0 && t < 11.15
        return VStack(alignment: .leading, spacing: 0) {
            group {
                row("Location Services", "location.fill", value: "On")
                Rectangle().fill(Dark.line).frame(height: 1).padding(.leading, 48)
                row("Analytics & Improvements", "chart.bar.fill")
                Rectangle().fill(Dark.line).frame(height: 1).padding(.leading, 48)
                row("Apple Advertising", "megaphone.fill")
            }
            .frame(height: 132)
            Spacer().frame(height: 16)
            group { row("Apple Intelligence Report", "sparkles", .orange, value: "On") }.frame(height: 44)
            Spacer().frame(height: 30)
            Text("Security").font(.system(size: 13, weight: .bold)).foregroundStyle(Dark.text).frame(height: 24).padding(.leading, 4)
            Spacer().frame(height: 8)
            group {
                HStack {
                    Text("Allow applications from").font(.system(size: 13)).foregroundStyle(Dark.text)
                    Spacer()
                    Text("App Store & Known Developers").font(.system(size: 13)).foregroundStyle(Dark.text)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Dark.dim)
                }
                .padding(.horizontal, 14).frame(height: 44)
            }
            .frame(height: 44)
            Spacer().frame(height: 10)
            if approved {
                Color.clear.frame(height: 0)
            } else {
                group {
                    HStack {
                        Text("“Keep Working” was blocked to protect your Mac.").font(.system(size: 13)).foregroundStyle(Dark.text)
                        Spacer()
                        Text("Open Anyway").font(.system(size: 13, weight: .medium)).foregroundStyle(Dark.text)
                            .fixedSize().frame(width: 118, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(pressed ? Color.white.opacity(0.28) : Dark.button))
                    }
                    .padding(.horizontal, 14).frame(height: 44)
                    Text("Apple could not verify “Keep Working” is free of malware that may harm your Mac or compromise your privacy.")
                        .font(.system(size: 11.5)).foregroundStyle(Dark.dim).lineSpacing(1.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).frame(height: 46, alignment: .top)
                }
                .frame(height: 90)
                Spacer().frame(height: 10)
            }
            group {
                row("FileVault", "lock.shield.fill", Color(white: 0.85), value: "Off")
                Rectangle().fill(Dark.line).frame(height: 1).padding(.leading, 48)
                row("Accessories", "cable.connector", Color(white: 0.85), value: "Ask")
                Rectangle().fill(Dark.line).frame(height: 1).padding(.leading, 48)
                row("Background Security Improvements", "shield.lefthalf.filled", .blue)
            }
            .frame(height: 132)
            Spacer().frame(height: 16)
            group { row("Lockdown Mode", "hand.raised.fill", .blue, value: "Off") }.frame(height: 44)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 10)
        .frame(width: Self.settings.width - 230, height: 900, alignment: .top)
    }

    private var confirmSheet: some View {
        let k = ramp(t, 11.0, 11.28) * (1 - ramp(t, 12.28, 12.4))
        let pressed = t >= 12.1 && t < 12.35
        return VStack(alignment: .leading, spacing: 0) {
            DialIcon()
            Text("Open “Keep Working”?").font(.system(size: 14, weight: .bold)).foregroundStyle(Dark.text).padding(.top, 16)
            Text("Apple is not able to verify that it is free from malware that could harm your Mac or compromise your privacy. Don’t open this unless you are certain it is from a trustworthy source.")
                .font(.system(size: 12.5)).foregroundStyle(Dark.text.opacity(0.85)).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            Spacer(minLength: 12)
            VStack(spacing: 8) {
                pill("Move to Bin", fill: Dark.blue, text: .white)
                pill("Open Anyway", fill: pressed ? Color.white.opacity(0.28) : Dark.button)
                pill("Done", fill: Dark.button)
            }
        }
        .padding(20)
        .frame(width: 290, height: 366)
        .background(Dark.panel.opacity(0.98))
        .macWindow(24)
        .popIn(k, from: 0.88)
        .position(x: Self.sheetCenter.x - Self.settings.minX, y: Self.sheetCenter.y - Self.settings.minY + 10)
    }

    private var touchIDSheet: some View {
        let k = ramp(t, 12.42, 12.68) * (1 - ramp(t, 13.62, 13.8))
        let scan = ramp(t, 12.85, 13.5)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle().fill(Color.white).frame(width: 52, height: 52)
                Image(systemName: "touchid").font(.system(size: 38, weight: .regular))
                    .foregroundStyle(Color(red: 1, green: 0.3, blue: 0.35))
                Circle().trim(from: 0, to: scan).stroke(Color(red: 0.2, green: 0.8, blue: 0.4), lineWidth: 3)
                    .rotationEffect(.degrees(-90)).frame(width: 58, height: 58)
            }
            .overlay(alignment: .bottomTrailing) { img(Icons.privacy, 22).offset(x: 6, y: 4) }
            Text("You are attempting to open an app that may cause harm to your Mac or compromise your privacy")
                .font(.system(size: 13.5, weight: .bold)).foregroundStyle(Dark.text)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            Text("Touch ID or enter an administrator’s name and password to continue with Privacy & Security.")
                .font(.system(size: 12.5)).foregroundStyle(Dark.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
            Spacer(minLength: 12)
            VStack(spacing: 8) {
                pill("Use Password…", fill: Dark.button)
                pill("Cancel", fill: Dark.button)
            }
        }
        .padding(20)
        .frame(width: 290, height: 330)
        .background(Dark.panel.opacity(0.98))
        .macWindow(24)
        .popIn(k, from: 0.88)
        .position(x: Self.sheetCenter.x - Self.settings.minX, y: Self.sheetCenter.y - Self.settings.minY)
    }

    // MARK: Desktop menu and the widget gallery

    private var contextMenu: some View {
        let k = ramp(t, 15.0, 15.08) * (1 - ramp(t, 16.25, 16.35))
        let rows: [String?] = ["Ask Siri", nil, "New Folder", "Paste Item", nil, "Get Info", "Change Wallpaper…", "Edit Widgets…", nil, "Use Stacks", "Group Stacks By", "Show View Options"]
        // The highlight follows the pointer down the menu.
        let y = pointer.y - Self.menuAt.y - 5
        var hi: Int? = nil
        var top = 0.0
        for (i, r) in rows.enumerated() {
            let h = r == nil ? 9.0 : 22.0
            if r != nil && t > 15.25 && y >= top && y < top + h { hi = i }
            top += h
        }
        return menu(rows, width: 210, highlighted: hi)
            .opacity(k)
            .offset(x: Self.menuAt.x + 2, y: Self.menuAt.y)
    }

    /// The widget gallery as macOS Sonoma draws it: a vibrant panel over the bottom of the screen (it covers
    /// the Dock), apps on the left, the widget's sizes on the right with a caption under each, and a bar
    /// with "Drag a widget…" and Done. Laid out from a screenshot of the real one.
    private var galleryPanel: some View {
        let g = Self.gallery
        let k = ramp(t, 16.3, 16.75) * (1 - ramp(t, 20.25, 20.6))
        let film = FilmFrame(t: 5)
        let left = 196.0
        let hover = t >= 17.15 && t < 17.7
        return ZStack(alignment: .topLeading) {
            // The vibrancy: the wallpaper behind, blurred and lifted.
            if let w = Self.wallpaper {
                Image(nsImage: w).resizable().interpolation(.high).scaledToFill()
                    .frame(width: MacDesktop.size.width, height: MacDesktop.size.height).clipped()
                    .offset(x: -g.minX, y: -g.minY)
                    .frame(width: g.width, height: g.height, alignment: .topLeading).clipped()
                    .blur(radius: 26, opaque: true)
                    .saturation(1.25)
                    .overlay(Color.white.opacity(0.10))
            }
            // Apps
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                    Text("Search Widgets").font(.system(size: 12))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.75)).padding(.horizontal, 8).frame(height: 23)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 0.6))
                .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 4)
                ForEach(Array(Icons.drawer.enumerated()), id: \.offset) { i, app in
                    HStack(spacing: 8) {
                        img(app.1, 22)
                        Text(app.0).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 7).frame(height: 33)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(app.0 == "Keep Working" ? Color.white.opacity(0.2) : .clear))
                    .padding(.horizontal, 10)
                }
            }
            .frame(width: left, height: g.height - 49, alignment: .top).clipped()
            Rectangle().fill(Color.white.opacity(0.14)).frame(width: 0.8, height: g.height).offset(x: left)
            // Sizes
            Text("Keep Working").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                .offset(x: left + 17, y: 10)
            ForEach(Array(Self.drawerSizes.enumerated()), id: \.offset) { i, w in
                let lifted = w.family == .systemExtraLarge && t >= 17.6 && t < 19.05
                film.chrome(w.size) { film.content(w.family, w.size) }
                    .scaleEffect(w.scale, anchor: .topLeading)
                    .frame(width: w.size.width * w.scale, height: w.size.height * w.scale, alignment: .topLeading)
                    .opacity(lifted ? 0.3 : 1)
                    .offset(x: w.at.x - g.minX, y: w.at.y - g.minY)
                if w.family != .systemExtraLarge {
                    VStack(spacing: 2) {
                        Text("Claude sessions").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        Text("Your latest Claude sessions.")
                            .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).lineSpacing(1)
                    }
                    .frame(width: 210)
                    .position(x: w.captionCenterX - g.minX, y: w.captionTop - g.minY + 14)
                }
            }
            if hover {
                let xl = Self.drawerSizes[3]
                Circle().fill(Color(red: 0.2, green: 0.78, blue: 0.35)).frame(width: 14, height: 14)
                    .overlay(Image(systemName: "plus").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white))
                    .position(x: xl.at.x - g.minX + 4, y: xl.at.y - g.minY + 4)
                Text("Claude sessions – Extra Large").font(.system(size: 10.5)).foregroundStyle(.white)
                    .padding(.horizontal, 6).frame(height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.15).opacity(0.95)))
                    .offset(x: xl.at.x - g.minX + 85, y: xl.at.y - g.minY + 56)
            }
            // Scroll bars
            Capsule().fill(Color.white.opacity(0.55)).frame(width: 4.5, height: 330).offset(x: g.width - 10, y: 14)
            Capsule().fill(Color.white.opacity(0.35)).frame(width: 4.5, height: 260).offset(x: left - 9, y: 60)
            // The bar along the bottom
            HStack {
                Text("Drag a widget to place it on the desktop…").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("Done").font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 68, height: 25)
                    .background(Capsule().fill(t >= 20.2 && t < 20.35 ? Color(red: 0.0, green: 0.38, blue: 0.85) : Dark.blue))
            }
            .padding(.horizontal, 16).frame(width: g.width, height: 49)
            .background(Color.black.opacity(0.16))
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.8) }
            .offset(y: g.height - 49)
        }
        .frame(width: g.width, height: g.height, alignment: .topLeading)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8))
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 20, y: -4)
        .offset(x: g.minX, y: g.minY + 140 * (1 - k))
        .opacity(min(1, k * 2))
    }

    private static let wallpaper = NSImage(contentsOfFile: "build/film-assets/wallpaper.jpg")

    /// The four sizes in the drawer, in desktop points, at the scale the real drawer shows each one.
    struct DrawerSize { let family: WidgetFamily; let size: CGSize; let scale: Double; let at: CGPoint; let captionCenterX: Double; let captionTop: Double }
    static var drawerSizes: [DrawerSize] {
        let g = gallery, x0 = g.minX + 196, mid = g.minY + 137, cap = g.minY + 241
        func centred(_ f: WidgetFamily, _ size: CGSize, _ scale: Double, _ cx: Double) -> DrawerSize {
            DrawerSize(family: f, size: size, scale: scale,
                       at: CGPoint(x: x0 + cx - size.width * scale / 2, y: mid - size.height * scale / 2),
                       captionCenterX: x0 + cx, captionTop: cap)
        }
        return [
            centred(.systemSmall, CGSize(width: 164, height: 164), 0.51, 105),
            centred(.systemMedium, CGSize(width: 344, height: 164), 0.51, 315),
            centred(.systemLarge, CGSize(width: 344, height: 344), 0.46, 525),
            DrawerSize(family: .systemExtraLarge, size: CGSize(width: 704, height: 344), scale: 0.256,
                       at: CGPoint(x: x0 + 16, y: g.minY + 320), captionCenterX: x0 + 106, captionTop: g.minY + 418),
        ]
    }

    // MARK: Drags, the placed widget, the pointer

    @ViewBuilder private var dragGhosts: some View {
        // The app icon, carried from Downloads to the sidebar's Applications.
        if t >= 1.85 && t < 3.25 {
            let shrink = ramp(t, 3.0, 3.25)
            img(Icons.app, 64).opacity(0.75 * (1 - shrink)).scaleEffect(1 - 0.6 * shrink)
                .position(x: pointer.x - 4, y: pointer.y + 2)
        }
        // The medium widget, carried out of the gallery onto the desktop, growing to full size on the way.
        if t >= 17.6 && t < 19.0 {
            let film = FilmFrame(t: 5)
            let grow = ramp(t, 17.7, 18.9)
            let s = 0.256 + (1 - 0.256) * grow
            film.chrome(Self.xl) { film.content(.systemExtraLarge, Self.xl) }
                .scaleEffect(s)
                .opacity(0.9)
                .position(x: pointer.x, y: pointer.y)
        }
    }

    @ViewBuilder private var placedWidget: some View {
        if t >= 19.0 {
            // It drops into its slot with a small settle, then runs on its own clock.
            let x = min(1, max(0, (t - 19.0) / 0.35)), back = 1 + 2.3 * pow(x - 1, 3) + 1.3 * pow(x - 1, 2)
            let film = FilmFrame(t: 5 + (t - 19.0))
            film.chrome(Self.xl) { film.content(.systemExtraLarge, Self.xl) }
                .scaleEffect(0.96 + 0.04 * back)
                .offset(x: Self.slot.x, y: Self.slot.y)
        }
    }

    @ViewBuilder private var cursor: some View {
        let p = pointer
        let held = Self.holds.contains { t >= $0.0 && t < $0.1 }
        let fade = 1 - ramp(t, 21.0, 21.4)
        ZStack {
            ForEach(Array(Self.clicks.enumerated()), id: \.offset) { _, c in
                let since = t - c.0
                if since >= 0 && since < 0.4 {
                    let g = ease(since / 0.4)
                    Circle().strokeBorder((c.1 ? FilmFrame.paperTop : Color.white).opacity(0.9 * (1 - g)), lineWidth: 2)
                        .frame(width: 10 + 44 * g, height: 10 + 44 * g).position(p)
                }
            }
            CursorArrow().fill(Color.black)
                .overlay(CursorArrow().stroke(Color.white, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round)))
                .frame(width: 13, height: 20)
                .scaleEffect(1.25 * (held || Self.clicks.contains { t - $0.0 >= 0 && t - $0.0 < 0.12 } ? 0.88 : 1), anchor: .topLeading)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .position(x: p.x + 6.5, y: p.y + 10)
        }
        .opacity(fade)
    }

    private struct CursorArrow: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4.5, 13), (7.5, 20), (10, 19), (7, 12.5), (13, 12.5)]
            p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
            p.closeSubpath()
            return p
        }
    }

    // MARK: Captions

    @ViewBuilder private var caption: some View {
        ForEach(Array(Self.captions.enumerated()), id: \.offset) { _, c in
            if t >= c.0 && t < c.1 {
                let inK = ramp(t, c.0, c.0 + 0.14)
                HStack(spacing: 18) {
                    if !c.2.isEmpty { Text(c.2).foregroundStyle(Pulse.clay) }
                    Text(c.3).foregroundStyle(FilmFrame.paperTop)
                }
                .font(.system(size: 40, weight: .semibold)).tracking(-0.6)
                .padding(.horizontal, 34).frame(height: 84)
                .background(FilmFrame.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
                .opacity(inK * (1 - ramp(t, c.1 - 0.12, c.1)))
                .position(x: 960, y: (c.0 >= 16.9 && c.0 < 18.6 ? 76 : 1012) + 8 * (1 - inK))
            }
        }
    }
}

// MARK: - Render

extension InstallFilm {
    /// `--install out.mp4 [from to]` renders the film; `--install-still t out.png` one frame.
    @MainActor static func run(_ args: [String]) {
        if args.first == "--install-still", args.count >= 3, let t = Double(args[1]) {
            // Drawn onto an opaque bitmap first, as the video's frames are: the renderer's own image keeps
            // alpha that turns into a grey veil when written straight to a PNG.
            guard let raw = FilmMain.render(InstallFrame(t: t)) else { fatalError("no frame") }
            let ctx = CGContext(data: nil, width: raw.width, height: raw.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            ctx.draw(raw, in: CGRect(x: 0, y: 0, width: raw.width, height: raw.height))
            let cg = ctx.makeImage()!
            try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
            return
        }
        guard args.count >= 2 else { print("usage: --install out.mp4 [from to]"); return }
        let out = args[1]
        let from = args.count > 3 ? Double(args[2]) ?? 0 : 0, to = args.count > 3 ? Double(args[3]) ?? length : length
        let w = Int(Script.size.width), h = Int(Script.size.height), fps = Script.fps
        let ffmpeg = Process()
        ffmpeg.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        ffmpeg.arguments = ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(w)x\(h)",
                            "-r", "\(fps)", "-i", "-", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "16",
                            "-pix_fmt", "yuv420p", "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
                            "-movflags", "+faststart", out]
        let pipe = Pipe()
        ffmpeg.standardInput = pipe
        try! ffmpeg.run()
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!
        var n = 0
        for i in Int(from * Double(fps))..<Int(to * Double(fps)) {
            autoreleasepool {
                guard let cg = FilmMain.render(InstallFrame(t: Double(i) / Double(fps))) else { return }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                pipe.fileHandleForWriting.write(Data(bytesNoCopy: ctx.data!, count: w * h * 4, deallocator: .none))
                n += 1
                if n % 240 == 0 { print("frame \(n)"); fflush(stdout) }
            }
        }
        try? pipe.fileHandleForWriting.close()
        ffmpeg.waitUntilExit()
        print("wrote \(out), \(n) frames")
    }
}
