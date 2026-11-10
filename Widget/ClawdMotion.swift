import SwiftUI

// The character as a pure function of wall-clock time.
//
// Every layer of motion (gait, blink, glance, marks) is a loop of its own over real seconds, so it can be
// played two ways: live in Pulse Preview, or on the desktop as a flip-book of frames cut from these loops.
// The walk across the bar is not here: that travel is a plain glide between timeline entries, which the
// desktop widget does play. Loops use uneven lengths so the blink, glance and gait never fall into step.

enum ClawdMotion {
    /// Cells: x across (0…20, body centred on 10), y up from the ground in rows.
    struct Box { var x, y, w, h: Double }
    /// A pixel mark ("?", "z", "+"), placed from the top of the body.
    struct Glyph { var bits: [String]; var x, y, scale: Double; var opacity = 1.0 }
    struct Frame { var solid: [Box] = []; var holes: [Box] = []; var marks: [Glyph] = [] }

    struct Pose {
        var lift = 0.0              // body bottom above its standing height, in rows (−1 = sitting)
        var squash = 0.0            // + wider and shorter, − taller and thinner
        var turn = 1.0              // 1 faces right, −1 left, 0 edge-on
        var shift = 0.0             // body sideways, in cells
        var legs = true
        var feet = [(dx: Double, up: Double)](repeating: (0, 0), count: 4)
        var armL = 0.0, armR = 0.0  // −1 hanging, 0 out, 1 up
        var eyeDX = 0.0, eyeDY = 0.0
        var eyeOpen = 1.0           // 0 shut … 1 open, 1.3 wide
        var happy = false           // ^ ^
        var marks: [Glyph] = []
    }

    static let question = ["0110", "1001", "0001", "0010", "0000", "0010"]
    static let zed = ["1111", "0010", "0100", "1111"]
    static let star = ["010", "111", "010"]

    // MARK: Moods

    /// `walking` only matters while working: on the bar it walks, at either end it stops and looks about.
    static func pose(_ mood: Mood, t: Double, walking: Bool = true, turn: Double = 1) -> Pose {
        var p: Pose
        switch mood {
        case .working: p = walking ? walk(t) : stand(t)
        case .waiting: p = waiting(t)
        case .done: p = celebrate(t)
        case .resting: p = resting(t)
        case .sleeping: p = sleeping(t)
        }
        p.turn *= turn
        return p
    }

    /// Brisk trot: diagonal feet lift high and swing in turn, the body rides up between steps and squashes as a
    /// foot lands, arms swing behind the body's beat, eyes squint on each strike and glance at you once a cycle.
    static let stride = 0.55   // seconds per full cycle; two steps (8 to a 4.4 s loop)
    static func walk(_ t: Double) -> Pose {
        var p = Pose()
        let a = 2 * .pi * t / stride, s = sin(a), c = cos(a)
        let upA = max(0, s) * 1.1, upB = max(0, -s) * 1.1
        p.feet = [(-1.0 * c, upA), (1.0 * c, upB), (-1.0 * c, upA), (1.0 * c, upB)]
        p.lift = 0.6 * abs(s)
        p.squash = 0.12 * cos(2 * a)
        let swing = 0.9 * sin(a - 0.9)          // arms lag the body
        p.armL = -0.25 + swing
        p.armR = -0.25 - swing
        let u = t.truncatingRemainder(dividingBy: 4.4)
        p.eyeDX = 0.7 - 0.7 * (ramp(u, 1.8, 2.0) - ramp(u, 2.6, 2.8))   // a look at you, then back ahead
        p.eyeDY = -0.25 * abs(sin(a - 0.6))
        p.eyeOpen = blink(t, every: 2.2) * (1 - 0.3 * max(0, cos(2 * a)))
        return p
    }

    /// Stopped at the end of the bar: breathing, then leaning out one way with an arm lifted, back, the other way.
    static func stand(_ t: Double) -> Pose {
        var p = Pose()
        let u = t.truncatingRemainder(dividingBy: 4.4)
        let look = ramp(u, 0.3, 0.6) - ramp(u, 1.6, 1.9) - (ramp(u, 2.4, 2.7) - ramp(u, 3.7, 4.0))
        p.squash = 0.06 * sin(2 * .pi * t / 2.2)
        p.eyeDX = 1.0 * look
        p.shift = 1.0 * look
        p.armL = -0.3 + (look < 0 ? 0.5 * -look : 0)
        p.armR = -0.3 + (look > 0 ? 0.5 * look : 0)
        p.eyeOpen = blink(t, every: 2.2)
        return p
    }

    /// Needs you: two big hops at you, then one arm waving hard over its head while it sways and leans, a "?" bobbing.
    static let waitLoop = 2.6
    static func waiting(_ t: Double) -> Pose {
        var p = Pose()
        let u = t.truncatingRemainder(dividingBy: waitLoop)
        if u < 1.3 {
            let (lift, squash, air) = hop(u.truncatingRemainder(dividingBy: 0.65) / 0.65, height: u < 0.65 ? 1.8 : 1.2)
            p.lift = lift; p.squash = squash
            p.armL = air > 0 ? 1.3 : -0.4 + squash * 2
            p.armR = p.armL
        } else {
            let w = sin(2 * .pi * (u - 1.3) / 0.36)
            let sway = sin(2 * .pi * (u - 1.3) / 1.3)
            p.shift = 1.2 * sway
            p.eyeDX = 0.8 * (sway >= 0 ? 1 : -1) * min(1, abs(sway) * 3)
            p.armL = -0.5
            p.armR = 0.3 + 1.1 * max(0, w)
            p.squash = 0.04 * w
            // Settle the arms back to the crouch pose before the loop restarts.
            let settle = ramp(u, waitLoop - 0.25, waitLoop)
            p.armL += (-0.4 - p.armL) * settle
            p.armR += (-0.4 - p.armR) * settle
            p.shift *= 1 - settle
        }
        p.eyeDY = 0.35
        p.eyeOpen = 1.25 * blink(t, every: waitLoop)
        let bob = 0.35 * sin(2 * .pi * t / (waitLoop / 3))
        p.marks = [Glyph(bits: question, x: 16.4, y: 1.2 + bob, scale: 0.6 + 0.06 * sin(2 * .pi * t / (waitLoop / 3)))]
        return p
    }

    /// Done: a crouch, a big jump with a spin, feet tucked and arms flung up, a squashy landing with the arms
    /// coming down, one small hop, a held ^ ^ with arms out.
    static func celebrate(_ t: Double) -> Pose {
        var p = Pose()
        let u = t.truncatingRemainder(dividingBy: 2.0)
        p.happy = true
        if u < 1.1 {
            let v = u / 1.1
            let (lift, squash, air) = hop(v, height: 2.6)
            p.lift = lift; p.squash = squash
            if air > 0 {
                p.armL = 1.4
                let c = cos(2 * .pi * ease(air))
                p.turn = (c < 0 ? -1 : 1) * max(0.45, abs(c))   // a spin that never goes paper-thin
                if abs(c) < 0.6 { p.happy = false; p.eyeOpen = 0.18 }
                p.feet = Array(repeating: (0, lift * 0.4), count: 4)
                let flash = sin(.pi * air)
                p.marks = [Glyph(bits: star, x: 1.5, y: 0.5 + air, scale: 0.6, opacity: flash),
                           Glyph(bits: star, x: 17.5, y: 1.5 + air, scale: 0.5, opacity: flash)]
            } else if v < 0.5 {
                p.armL = -0.8 + 0.6 * ramp(u, 1.85, 2.0)   // (the loop ends with arms at -0.2: meet them)
            } else {
                p.armL = 1.4 - 0.9 * ease((v - 0.75) / 0.25)
            }
            p.armR = p.armL
        } else {
            let k = u - 1.1
            let (lift, squash, _) = hop(min(1, k / 0.5), height: 0.4)
            p.lift = lift; p.squash = squash * 0.6
            p.armL = 0.5 - 0.7 * ramp(u, 1.75, 2.0)        // arms out, held, then down to meet the crouch
            p.armR = p.armL
        }
        return p
    }

    /// Paused: sitting, breathing, leaning to look one way then the other, a blink, and now and then a long stretch.
    static func resting(_ t: Double) -> Pose {
        var p = Pose()
        p.legs = false; p.lift = -1
        p.squash = 0.05 * sin(2 * .pi * t / 3.0)
        p.armL = -0.5; p.armR = -0.5
        let u = t.truncatingRemainder(dividingBy: 9.0)
        p.eyeDX = 1.0 * (ramp(u, 0.2, 0.5) - ramp(u, 2.2, 2.5)) - 1.0 * (ramp(u, 3.4, 3.7) - ramp(u, 5.4, 5.7))
        p.shift = 1.0 * p.eyeDX
        p.eyeOpen = blink(t, every: 4.5)
        let s = ramp(u, 6.3, 6.8) - ramp(u, 8.0, 8.5)   // the stretch
        if s > 0 {
            p.armL = -0.5 + 1.9 * s; p.armR = p.armL
            p.squash -= 0.12 * s
            p.lift = -1 + 0.3 * s
            p.eyeOpen = 1 - 0.85 * s
        }
        return p
    }

    /// Asleep: flattened, slow deep breaths, eyes shut, a stream of z's drifting up and away.
    static func sleeping(_ t: Double) -> Pose {
        var p = Pose()
        p.legs = false; p.lift = -1
        let breath = sin(2 * .pi * t / 4.2)
        p.squash = 0.12 + 0.12 * breath
        p.armL = -0.8; p.armR = -0.8
        p.eyeOpen = 0.2; p.eyeDY = -0.2
        p.marks = (0..<3).map { i in
            let k = (t / 4.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            return Glyph(bits: zed, x: 14.5 + 3 * k + 0.5 * sin(4 * .pi * k), y: 0.3 + 4.5 * k,
                         scale: 0.3 + 0.35 * k, opacity: sin(.pi * k))
        }
        return p
    }

    // MARK: Loops

    /// Every mood's motion repeats exactly after this many seconds (all its inner rhythms divide it), so it
    /// can be cut into a flip-book that loops without a seam.
    static func loop(_ m: Mood) -> Double {
        switch m { case .working: return 4.4; case .waiting: return waitLoop; case .done: return 2.0
                   case .resting: return 9.0; case .sleeping: return 4.2 }
    }
    /// Flip-book frames per second on the desktop: lively moods quicker, lazy ones slower and lighter.
    static func fps(_ m: Mood) -> Double {
        switch m { case .working, .waiting, .done: return 15; case .resting: return 8; case .sleeping: return 10 }
    }

    // MARK: Helpers

    /// One hop over v in 0…1: crouch, airborne arc (stretched), squash on landing. `air` is 0 on the ground.
    static func hop(_ v: Double, height: Double) -> (lift: Double, squash: Double, air: Double) {
        switch v {
        case ..<0.2: return (0, 0.22 * ease(v / 0.2), 0)
        case ..<0.75:
            let k = (v - 0.2) / 0.55
            return (height * 4 * k * (1 - k), -0.14 * abs(2 * k - 1), max(0.0001, k))
        default:
            let k = (v - 0.75) / 0.25
            return (0, 0.25 * sin(.pi * k), 0)
        }
    }

    /// 1 = open; dips to 0 and back over 0.16 s once per `every` seconds.
    static func blink(_ t: Double, every: Double) -> Double {
        let u = t.truncatingRemainder(dividingBy: every)
        return u < 0.16 ? 1 - sin(.pi * u / 0.16) : 1
    }

    static func ease(_ x: Double) -> Double { let x = min(1, max(0, x)); return x * x * (3 - 2 * x) }
    static func ramp(_ u: Double, _ a: Double, _ b: Double) -> Double { ease((u - a) / (b - a)) }

    // MARK: Geometry

    static func frame(_ p: Pose) -> Frame {
        var f = Frame()
        let w = 12 * (1 + p.squash), h = 4 * (1 - p.squash)
        let bottom = 1 + p.lift
        let cx = 10 + p.shift
        let left = cx - w / 2, right = cx + w / 2
        // Everything is drawn facing right, then turned about the body's centre.
        func put(_ b: Box) -> Box {
            let a = cx + (b.x - cx) * p.turn, z = cx + (b.x + b.w - cx) * p.turn
            return Box(x: min(a, z), y: b.y, w: abs(z - a), h: b.h)
        }
        f.solid.append(put(Box(x: left, y: bottom, w: w, h: h)))
        if p.legs {
            for (i, base) in [-4.5, -2.5, 2.5, 4.5].enumerated() {
                let foot = max(p.feet[i].up, bottom - 1.4)      // airborne legs hang
                if bottom - foot > 0.05 {
                    f.solid.append(put(Box(x: cx + base * (1 + p.squash) - 0.5 + p.feet[i].dx, y: foot,
                                           w: 1, h: bottom - foot + 0.1)))
                }
            }
        }
        // Arms: a stub at each side, then two cells out along the arm's angle (−1 hanging … 1 straight up).
        let armY = bottom + h * 0.25
        func arm(_ r: Double, side: Double) -> [Box] {
            // Angle capped short of vertical, so a raised arm reads as a V away from the body, not an ear.
            let a = max(-1.2, min(1.4, r)) * .pi / 180 * 50
            let edge = side < 0 ? left - 1 : right
            return [Box(x: edge, y: armY, w: 1.05, h: 1)] + [1.0, 2.0].map { k in
                Box(x: edge + side * (0.15 + 0.95 * k * cos(a)), y: armY + k * 1.05 * sin(a), w: 1, h: 1)
            }
        }
        f.solid += (arm(p.armL, side: -1) + arm(p.armR, side: 1)).map(put)
        let eyeY = bottom + 2.5 * (1 - p.squash) + p.eyeDY
        for c in [-3.5, 3.5] {
            let ex = cx + c * (1 + p.squash) + p.eyeDX
            if p.happy {
                f.holes += [Box(x: ex - 1.5, y: eyeY - 0.5, w: 1, h: 0.5), Box(x: ex - 0.5, y: eyeY, w: 1, h: 0.5),
                            Box(x: ex + 0.5, y: eyeY - 0.5, w: 1, h: 0.5)]
            } else {
                let eh = max(0.18, p.eyeOpen)
                f.holes.append(Box(x: ex - 0.5, y: eyeY - eh / 2, w: 1, h: eh))
            }
        }
        f.holes = f.holes.map(put)
        f.marks = p.marks.map { var g = $0; g.y += bottom + h; return g }
        return f
    }
}

/// Draws one moment of the character. `t` is wall-clock seconds; quantise it to choose a frame rate.
struct ClawdSprite: View {
    let mood: Mood
    let t: Double
    var px: CGFloat = 6
    var walking = true
    var turn = 1.0

    static let cols: CGFloat = 22, rows: CGFloat = 14
    static func size(px: CGFloat) -> CGSize { CGSize(width: cols * px, height: rows * px * 1.7) }

    var body: some View {
        let f = ClawdMotion.frame(ClawdMotion.pose(mood, t: t, walking: walking, turn: turn))
        let py = px * 1.7
        Canvas { ctx, size in
            let H = size.height
            func rect(_ b: ClawdMotion.Box) -> CGRect {
                CGRect(x: (b.x + 1) * px, y: H - (b.y + b.h) * py, width: b.w * px, height: b.h * py)
            }
            var solid = Path()
            f.solid.forEach { solid.addRect(rect($0)) }
            ctx.fill(solid, with: .style(color))
            // Eyes are holes, so the card shows through.
            var holes = Path()
            f.holes.forEach { holes.addRect(rect($0)) }
            ctx.blendMode = .destinationOut
            ctx.fill(holes, with: .color(.black))
            ctx.blendMode = .normal
            for g in f.marks {
                let unit = px * g.scale
                let top = H - g.y * py - CGFloat(g.bits.count) * unit
                var path = Path()
                for (y, row) in g.bits.enumerated() {
                    for (x, ch) in row.enumerated() where ch == "1" {
                        path.addRect(CGRect(x: (g.x + 1) * px + CGFloat(x) * unit, y: top + CGFloat(y) * unit,
                                            width: unit, height: unit))
                    }
                }
                var c = ctx
                c.opacity = max(0, min(1, g.opacity))
                c.fill(path, with: .style(color))
            }
        }
        .frame(width: Self.cols * px, height: Self.rows * py)
        .accessibilityHidden(true)
    }

    /// Solid ink when `toned` is off, so stacked flip-book frames never add up to a brighter patch; the
    /// flip-book applies the mood's shade once over the whole stack instead.
    var toned = true
    private var color: AnyShapeStyle {
        let ink: Color = mood == .waiting ? Pulse.clay : .primary
        return AnyShapeStyle(ink.opacity(toned ? ClawdSprite.tone(mood) : 1))
    }
    static func tone(_ m: Mood) -> Double {
        switch m { case .waiting: return 1; case .working, .done: return 0.85; case .resting, .sleeping: return 0.45 }
    }
}

// MARK: - Looping on the desktop

/// The character, looping on its own. A widget can't run code, so on the desktop each loop is cut into
/// frames, and macOS's clock-hand rotation (the effect that sweeps an analog clock's second hand) spins a
/// mask that shows one frame at a time. In Pulse Preview, a TimelineView plays the same frames.
struct ClawdLoop: View {
    let mood: Mood
    var px: CGFloat = 5
    var walking = true

    var body: some View {
        let fps = ClawdMotion.fps(mood)
        #if RENDER_HARNESS
        TimelineView(.animation) { tl in
            let t = (tl.date.timeIntervalSinceReferenceDate * fps).rounded(.down) / fps
            ClawdSprite(mood: mood, t: t, px: px, walking: walking)
        }
        #else
        FlipBook(period: ClawdMotion.loop(mood), fps: fps) { t in
            ClawdSprite(mood: mood, t: t, px: px, walking: walking, toned: false)
        }
        .frame(width: ClawdSprite.size(px: px).width, height: ClawdSprite.size(px: px).height)
        .compositingGroup()
        .opacity(ClawdSprite.tone(mood))
        #endif
    }
}

/// Frames stacked up, each masked by a slice of a pie that turns once per loop around a pivot far below.
/// The pivot is so far away that a slice edge crosses the sprite in a sliver of a frame, so it reads as a cut.
struct FlipBook<Frame: View>: View {
    let period: Double
    let fps: Double
    @ViewBuilder let frame: (Double) -> Frame

    var body: some View {
        let n = max(1, Int((period * fps).rounded()))
        if let spin = ClockSpin.modifier(period: period) {
            GeometryReader { g in
                let size = max(g.size.width, g.size.height)
                let pivot = size * 80, radius = pivot + size * 2
                ZStack {
                    ForEach(0..<n, id: \.self) { i in
                        frame(Double(i) / fps).mask {
                            ClockSpin.apply(spin, to: Slice(index: i, count: n).frame(width: radius * 2, height: radius * 2))
                                .frame(width: radius * 2, height: radius * 2)
                                .position(x: g.size.width / 2, y: g.size.height / 2 + pivot)
                        }
                    }
                }
            }
        } else {
            frame(0)   // the effect is gone (a future macOS): hold still rather than break
        }
    }

    /// Frame i's slice, set so it sits over the sprite (straight up from the pivot) while the turn is within
    /// [i, i+1) of n parts. A hair of overlap so no gap ever shows between neighbours.
    private struct Slice: Shape {
        let index: Int, count: Int
        func path(in r: CGRect) -> Path {
            let w = 2 * Double.pi / Double(count), up = -Double.pi / 2, e = 0.002
            var p = Path()
            let c = CGPoint(x: r.midX, y: r.midY)
            p.move(to: c)
            p.addArc(center: c, radius: r.width / 2, startAngle: .radians(up - Double(index + 1) * w - e),
                     endAngle: .radians(up - Double(index) * w + e), clockwise: false)
            p.closeSubpath()
            return p
        }
    }
}

/// WidgetKit's clock-hand rotation, which keeps turning on the desktop with no new timeline entries. It is not
/// in the public SDK, so it is built from its archived form; if a macOS update changes it, this returns nil.
enum ClockSpin {
    static func modifier(period: Double) -> (any ViewModifier)? {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "$s9WidgetKit24_ClockHandRotationEffectVMa")
        else { return nil }
        typealias Accessor = @convention(c) (Int) -> UnsafeRawPointer
        let type = unsafeBitCast(unsafeBitCast(sym, to: Accessor.self)(0), to: Any.Type.self)
        guard let decodable = type as? any Decodable.Type else { return nil }
        let json = #"{"anchor":[0.5,0.5],"honorIdealizedDate":false,"period":\#(period),"timeZone":{"identifier":"GMT"}}"#
        return (try? decode(decodable, Data(json.utf8))) as? any ViewModifier
    }

    static func apply(_ m: any ViewModifier, to v: some View) -> AnyView { wrap(m, v) }

    private static func wrap<M: ViewModifier>(_ m: M, _ v: some View) -> AnyView { AnyView(v.modifier(m)) }
    private static func decode<D: Decodable>(_ t: D.Type, _ d: Data) throws -> D { try JSONDecoder().decode(t, from: d) }
}
