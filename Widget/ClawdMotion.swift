import SwiftUI

// The character as a pure function of wall-clock time.
//
// Every layer of motion (gait, blink, glance, marks) is a loop of its own over real seconds, so it can be
// played two ways: live in Keep Working Preview, or on the desktop as a flip-book of frames cut from these loops.
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
        /// Things it holds (a magnifier, a camera), in cells from the body's centre and rows from its bottom.
        /// Over the body a prop is cut out, so it shows as an outline; off the body it is solid.
        var props: [Box] = []
        /// Always cut out, wherever they fall (a camera's lens).
        var cuts: [Box] = []
        /// The right eye drawn bigger (seen through a lens), centred here, in the same body-relative units.
        var bigEye: (x: Double, y: Double, w: Double, h: Double)? = nil
    }

    static let question = ["0110", "1001", "0001", "0010", "0000", "0010"]
    static let zed = ["1111", "0010", "0100", "1111"]
    static let star = ["010", "111", "010"]

    // MARK: Moods

    /// `walking` only matters while working: on the bar it walks, at either end it stops and looks about.
    /// `turn` is the way it faces: 1 right, −1 left.
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
    // Every loop repeats on the 2 s beat, and every one is in a calm key pose exactly on each beat: feet down,
    // arms low, eyes ahead, no blink. The desktop can only swap one animation for another on a beat, so a swap
    // (walking to standing at the end of the bar, any mood to the snapshot and back) is a cut between two key
    // poses that match, never a jump from mid-stride.
    static let stride = 0.5    // seconds per full cycle; two steps, four to a beat
    /// `amount` scales the whole gait, 0 standing … 1 full trot, so the walk can ease in and out.
    static func walk(_ t: Double, amount k: Double = 1) -> Pose {
        var p = Pose()
        let a = 2 * .pi * t / stride, s = sin(a), c = cos(a)
        let upA = max(0, s) * 1.1 * k, upB = max(0, -s) * 1.1 * k
        p.feet = [(-1.0 * c * k, upA), (1.0 * c * k, upB), (-1.0 * c * k, upA), (1.0 * c * k, upB)]
        p.lift = 0.6 * abs(s) * k
        p.squash = 0.12 * cos(2 * a) * k
        let swing = 0.9 * sin(a) * k
        p.armL = -0.3 + 0.05 * k + swing
        p.armR = -0.3 + 0.05 * k - swing
        let u = t.truncatingRemainder(dividingBy: 4.0)
        p.eyeDX = (0.7 - 0.7 * (ramp(u, 0.6, 0.8) - ramp(u, 1.2, 1.4))) * k   // a look at you, then back ahead
        p.eyeDY = -0.25 * abs(sin(a - 0.6)) * k
        p.eyeOpen = blink(t, every: 4.0, at: 3.0) * (1 - 0.3 * max(0, cos(2 * a)) * k)
        return p
    }

    /// Stopped at the end of the bar: breathing, then leaning out one way with an arm lifted, back, the other way.
    static func stand(_ t: Double) -> Pose {
        var p = Pose()
        let u = t.truncatingRemainder(dividingBy: 4.0)
        let look = ramp(u, 0.3, 0.6) - ramp(u, 1.4, 1.7) - (ramp(u, 2.3, 2.6) - ramp(u, 3.4, 3.7))
        p.squash = 0.06 * sin(2 * .pi * t / 2.0)
        p.eyeDX = 1.0 * look
        p.shift = 1.0 * look
        p.armL = -0.3 + (look < 0 ? 0.5 * -look : 0)
        p.armR = -0.3 + (look > 0 ? 0.5 * look : 0)
        p.eyeOpen = blink(t, every: 4.0, at: 1.0)
        return p
    }

    /// Needs you: a big hop at you, then one arm waving hard over its head while it sways and leans, a "?"
    /// bobbing; settled back to the key pose by the end of each beat.
    static let waitLoop = 2.0
    static func waiting(_ t: Double) -> Pose {
        var p = Pose()
        let u = t.truncatingRemainder(dividingBy: waitLoop)
        if u < 0.65 {
            let (lift, squash, air) = hop(u / 0.65, height: 1.6)
            p.lift = lift; p.squash = squash
            p.armL = air > 0 ? 1.3 : -0.3 + squash * 2
            p.armR = p.armL
        } else {
            let w = sin(2 * .pi * (u - 0.65) / 0.36)
            let sway = sin(2 * .pi * (u - 0.65) / 1.1)
            let settle = ramp(u, 1.7, 1.95)
            p.shift = 1.2 * sway * (1 - settle)
            p.eyeDX = 0.8 * (sway >= 0 ? 1 : -1) * min(1, abs(sway) * 3) * (1 - settle)
            p.armL = -0.5 + 0.2 * settle
            p.armR = (0.3 + 1.1 * max(0, w)) * (1 - settle) - 0.3 * settle
            p.squash = 0.04 * w * (1 - settle)
        }
        p.eyeDY = 0.35
        p.eyeOpen = 1.25 * blink(t, every: 2.0, at: 1.3)
        let bob = 0.35 * sin(2 * .pi * t / (waitLoop / 2))
        p.marks = [Glyph(bits: question, x: 16.4, y: 1.2 + bob, scale: 0.6 + 0.06 * sin(2 * .pi * t / (waitLoop / 2)))]
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
                p.armL = -0.3 - 0.5 * ramp(u, 0.0, 0.2)    // from the key pose down into the crouch
            } else {
                p.armL = 1.4 - 0.9 * ease((v - 0.75) / 0.25)
            }
            p.armR = p.armL
        } else {
            let k = u - 1.1
            let (lift, squash, _) = hop(min(1, k / 0.5), height: 0.4)
            p.lift = lift; p.squash = squash * 0.6
            p.armL = 0.5 - 0.8 * ramp(u, 1.75, 2.0)        // arms out, held, then back to the key pose
            p.armR = p.armL
        }
        return p
    }

    /// Paused: sitting, breathing, leaning to look one way then the other, a blink, and now and then a long stretch.
    static func resting(_ t: Double) -> Pose {
        var p = Pose()
        p.legs = false; p.lift = -1
        p.squash = 0.05 * sin(2 * .pi * t / 2.0)
        p.armL = -0.5; p.armR = -0.5
        let u = t.truncatingRemainder(dividingBy: 8.0)
        p.eyeDX = 1.0 * (ramp(u, 0.3, 0.6) - ramp(u, 1.4, 1.7)) - 1.0 * (ramp(u, 2.3, 2.6) - ramp(u, 3.4, 3.7))
        p.shift = 1.0 * p.eyeDX
        p.eyeOpen = blink(t, every: 8.0, at: 5.0)
        let s = ramp(u, 6.2, 6.6) - ramp(u, 7.4, 7.8)   // the stretch
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
        let breath = sin(2 * .pi * t / 4.0)
        p.squash = 0.12 + 0.12 * breath
        p.armL = -0.8; p.armR = -0.8
        p.eyeOpen = 0.2; p.eyeDY = -0.2
        p.marks = (0..<3).map { i in
            let k = (t / 4.0 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            return Glyph(bits: zed, x: 14.5 + 3 * k + 0.5 * sin(4 * .pi * k), y: 0.3 + 4.5 * k,
                         scale: 0.3 + 0.35 * k, opacity: sin(.pi * k))
        }
        return p
    }

    // MARK: The walk along the bar

    /// The whole walk as one loop of the walk's own time `w`: across the bar, a pause to turn round, back, a
    /// pause to turn round. Where it is, the way it faces and its stride all come from `w`, so the desktop can
    /// play the lot as a single flip-book on the clock. Nothing about it depends on when the widget is
    /// updated, which is what used to make it jump.
    enum Walk {
        static let cross = 7.0, rest = 1.0
        static let cycle = 2 * (cross + rest)
        static let fps = 12.0
        private static let accel = 0.6

        /// How far across (0 left … 1 right), the way it faces (1 right … −1 left, in between mid-turn) and
        /// how hard it is walking (0 standing … 1 full stride).
        static func state(_ w0: Double) -> (x: Double, turn: Double, amount: Double) {
            var w = w0.truncatingRemainder(dividingBy: cycle)
            if w < 0 { w += cycle }
            let back = w >= cross + rest
            let u = back ? w - cross - rest : w
            var s = 1.0, amount = 0.0, turn = 1.0
            if u < cross {
                // Eases up to speed and back down, so it never starts or stops dead.
                let vmax = 1 / (cross - accel)
                if u < accel { s = vmax * u * u / (2 * accel); amount = u / accel }
                else if u > cross - accel { let r = cross - u; s = 1 - vmax * r * r / (2 * accel); amount = r / accel }
                else { s = vmax * (u - accel / 2); amount = 1 }
            } else {
                // At the end of the bar: a breath, then round to face the other way (never paper-thin).
                let c = cos(.pi * ease((u - cross - 0.2) / 0.5))
                turn = (c < 0 ? -1 : 1) * max(0.35, abs(c))
            }
            return back ? (1 - s, -turn, amount) : (s, turn, amount)
        }

        /// The pose at `w` on a bar `travel` points long, with cells `px` wide. The stride follows the ground
        /// covered, not the clock, so the feet stay planted as it speeds up and slows down.
        static func pose(_ w0: Double, travel: Double, px: Double) -> Pose {
            var w = w0.truncatingRemainder(dividingBy: cycle)
            if w < 0 { w += cycle }
            let st = state(w)
            let along = w >= cross + rest ? 1 - st.x : st.x
            var p = walk(along * travel / (4 * px) * stride, amount: st.amount)
            p.turn = st.turn
            p.eyeOpen = blink(w, every: cycle / 2, at: 3.0) * (st.amount > 0 ? 1 : 1.1)
            return p
        }
    }

    // MARK: Acts: reacting to a new image

    /// One-off reactions when a new image arrives behind the hero. Each runs `actLength` seconds from a neutral
    /// stand and ends in one, so it can cut in from any mood and hand back to it.
    enum Act: String, CaseIterable { case magnify, lookUp, snapshot }
    static let actLength = 6.0
    static let bang = ["1", "1", "1", "0", "1"]
    /// A lens ring, 5 square pixels across (a pixel is 1 cell wide and 1/1.7 row tall).
    static let ring = ["01110", "10001", "10001", "10001", "01110"]

    static func act(_ a: Act, t: Double) -> Pose {
        switch a {
        case .magnify: return magnify(t)
        case .lookUp: return lookUp(t)
        case .snapshot: return snapshot(t)
        }
    }

    /// Square-pixel bits as body-relative boxes, bottom-left at (x, y).
    static func bits(_ rows: [String], x: Double, y: Double) -> [Box] {
        let ph = 1 / 1.7
        var out: [Box] = []
        for (j, row) in rows.enumerated() {
            for (i, ch) in row.enumerated() where ch == "1" {
                out.append(Box(x: x + Double(i), y: y + Double(rows.count - 1 - j) * ph, w: 1, h: ph))
            }
        }
        return out
    }

    /// A: it glances up at the image, raises a magnifying glass to its right eye (the eye swells in the lens),
    /// scans across the picture, lowers it, and gives a pleased nod.
    static func magnify(_ t: Double) -> Pose {
        var p = Pose()
        p.squash = 0.04 * sin(2 * .pi * t / 1.5)
        let raise = ramp(t, 0.5, 1.0) - ramp(t, 4.9, 5.4)
        let scanOn = ramp(t, 1.0, 1.3) - ramp(t, 4.6, 4.9)
        let scan = sin(2 * .pi * (t - 1.0) / 1.8) * scanOn
        let glance = ramp(t, 0.1, 0.4) * (1 - raise)
        p.eyeDY = 0.4 * glance
        p.eyeDX = -0.6 * glance + 0.6 * scan
        p.shift = 0.9 * scan
        p.armL = -0.3
        p.armR = -0.3 + 0.9 * raise
        if raise > 0.02 {
            // The lens slides in from the lower right onto the right eye; its handle runs out to the hand.
            let lx = 3.5 + p.eyeDX + (1 - raise) * 6, ly = 2.5 - (1 - raise) * 2.5
            let ph = 1 / 1.7
            p.props = bits(ring, x: lx - 2.5, y: ly - 2.5 * ph)
                + [Box(x: lx + 2.4, y: ly - 0.35, w: 1, h: 0.6), Box(x: lx + 3.3, y: ly - 0.55, w: 1, h: 0.6)]
            if raise > 0.6 { p.bigEye = (x: lx, y: ly, w: 1.8, h: 1.5) }
        }
        let nod = ramp(t, 5.3, 5.5) - ramp(t, 5.8, 6.0)
        if nod > 0 { p.happy = true; p.lift = 0.3 * sin(.pi * nod) }
        p.eyeOpen = blink(t, every: 3.0)
        return p
    }

    /// B: a "!" and a startled hop, then it looks up at the picture and reads it line by line, eyes sweeping
    /// left to right and dropping a line each time, and ends with two nods.
    static func lookUp(_ t: Double) -> Pose {
        var p = Pose()
        if t < 0.6 {
            let (lift, squash, air) = hop(t / 0.6, height: 1.1)
            p.lift = lift; p.squash = squash
            p.armL = air > 0 ? 1.0 : -0.3; p.armR = p.armL
        } else {
            p.armL = -0.3; p.armR = -0.3
            p.squash = 0.03 * sin(2 * .pi * t / 1.5)
        }
        let bangOn = ramp(t, 0.0, 0.12) - ramp(t, 1.1, 1.4)
        if bangOn > 0 {
            p.marks = [Glyph(bits: bang, x: 9.6, y: 0.8 + 0.6 * bangOn, scale: 0.7, opacity: bangOn)]
        }
        let up = ramp(t, 0.5, 0.8) - ramp(t, 4.9, 5.2)
        p.eyeOpen = t < 1.2 ? 1.3 : blink(t, every: 2.4)
        p.eyeDY = 0.5 * up
        if t >= 0.6 { p.squash -= 0.08 * up; p.lift += 0.25 * up }   // stretches up to look
        if t >= 1.2 && t < 4.8 {
            let line = floor((t - 1.2) / 1.2), u = (t - 1.2) - line * 1.2
            p.eyeDX = u < 1.0 ? -0.9 + 1.8 * ease(u / 1.0) : 0.9 - 1.8 * ease((u - 1.0) / 0.2)
            p.eyeDY -= 0.18 * line
            p.shift = 0.8 * p.eyeDX
            if u >= 1.0 { p.lift -= 0.25 * sin(.pi * (u - 1.0) / 0.2) }   // a little dip at each new line
        }
        let nods = ramp(t, 5.0, 5.1) - ramp(t, 5.8, 5.9)
        if nods > 0 { p.squash += 0.12 * abs(sin(2 * .pi * (t - 5.0) / 0.8)) * nods }
        return p
    }

    /// C: it holds a little camera up beside its head, the flash goes, it lowers the camera and admires the
    /// picture with ^ ^ eyes and a couple of happy bounces. The first and last second are plain standing: the
    /// desktop shows a scheduled change about a second late, and this way a start that is early or late by up
    /// to a second cuts nothing off.
    static let flashAt = 1.5
    static func snapshot(_ t: Double) -> Pose {
        var p = Pose()
        let raise = ramp(t, 1.0, 1.45) - ramp(t, 1.9, 2.4)
        p.armL = -0.3 + 0.9 * raise
        p.armR = -0.3 + 1.5 * raise
        if raise > 0.02 {
            // Held up in the right hand, beside the head: body, a viewfinder bump, a lens cut through.
            let cy = 3.6 - (1 - raise) * 2.5, cxp = 4.8
            p.props = [Box(x: cxp, y: cy, w: 4, h: 1.7), Box(x: cxp + 0.4, y: cy + 1.7, w: 1.2, h: 0.4)]
            p.cuts = [Box(x: cxp + 1.5, y: cy + 0.45, w: 1, h: 0.8)]
            p.eyeDX = 0.7 * raise; p.eyeDY = 0.3 * raise
        }
        if t > flashAt + 0.02 && t < flashAt + 0.35 {
            let k = (t - flashAt - 0.02) / 0.33
            p.marks = [Glyph(bits: star, x: 15.6 - 0.9 * k, y: 0.1 - 0.4 * k, scale: 1.0 + 0.8 * k, opacity: 1 - k)]
            p.eyeOpen = 0.25
        } else {
            p.eyeOpen = blink(t, every: 6.0, at: 0.5)
        }
        let admire = ramp(t, 2.4, 2.6) - ramp(t, 4.6, 4.95)
        if admire > 0 {
            p.happy = admire > 0.5
            let b = sin(2 * .pi * (t - 2.4) / 0.7)
            p.lift = 0.5 * abs(b) * admire
            p.squash = 0.06 * cos(4 * .pi * (t - 2.4) / 0.7) * admire
            p.armL = (0.6 + 0.5 * b) * admire - 0.3 * (1 - admire)
            p.armR = (0.6 - 0.5 * b) * admire - 0.3 * (1 - admire)
        }
        return p
    }

    // MARK: Loops

    /// Every mood's motion repeats exactly after this many seconds (all its inner rhythms divide it), so it
    /// can be cut into a flip-book that loops without a seam.
    static func loop(_ m: Mood) -> Double {
        switch m { case .working: return 4.0; case .waiting: return waitLoop; case .done: return 2.0
                   case .resting: return 8.0; case .sleeping: return 4.0 }
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

    /// 1 = open; dips to 0 and back over 0.16 s once per `every` seconds, `at` seconds into each cycle (kept
    /// off the beat, so a swap never lands on a closed eye).
    static func blink(_ t: Double, every: Double, at: Double = 1.0) -> Double {
        var u = (t - at).truncatingRemainder(dividingBy: every)
        if u < 0 { u += every }
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
        if let e = p.bigEye {
            f.holes.removeLast()   // the right eye, replaced by its magnified self
            f.holes.append(Box(x: cx + e.x - e.w / 2, y: bottom + e.y - e.h / 2, w: e.w, h: e.h))
        }
        for b in p.props {
            let abs = Box(x: cx + b.x, y: bottom + b.y, w: b.w, h: b.h)
            let mx = abs.x + abs.w / 2, my = abs.y + abs.h / 2
            if mx > left && mx < right && my > bottom && my < bottom + h { f.holes.append(abs) } else { f.solid.append(put(abs)) }
        }
        f.holes += p.cuts.map { Box(x: cx + $0.x, y: bottom + $0.y, w: $0.w, h: $0.h) }
        f.holes = f.holes.map(put)
        f.marks = p.marks.map { var g = $0; g.y += bottom + h; return g }
        return f
    }
}

/// Draws one moment of the character. `t` is wall-clock seconds; quantise it to choose a frame rate.
struct ClawdSprite: View {
    @Environment(\.dimmed) private var dimmed
    let mood: Mood
    let t: Double
    var px: CGFloat = 6
    var walking = true
    var turn = 1.0
    /// When set, `t` is seconds into this one-off act instead of the mood's loop.
    var act: ClawdMotion.Act? = nil
    /// Draw exactly this pose (the walk along the bar supplies its own).
    var pose: ClawdMotion.Pose? = nil

    static let cols: CGFloat = 22, rows: CGFloat = 14
    static func size(px: CGFloat) -> CGSize { CGSize(width: cols * px, height: rows * px * 1.7) }

    var body: some View {
        let f = ClawdMotion.frame(pose ?? act.map { var p = ClawdMotion.act($0, t: t); p.turn *= turn; return p }
            ?? ClawdMotion.pose(mood, t: t, walking: walking, turn: turn))
        let py = px * 1.7
        if dimmed {
            // The dimmed desktop doesn't draw a Canvas at all, so the same pixels go in as shapes instead.
            let H = Self.rows * py
            ZStack(alignment: .topLeading) {
                SpriteShape(frame: f, px: px, height: H).fill(color)
                ForEach(Array(f.marks.enumerated()), id: \.offset) { _, g in
                    MarkShape(glyph: g, px: px, height: H).fill(color).opacity(max(0, min(1, g.opacity)))
                }
            }
            .frame(width: Self.cols * px, height: H)
            .accessibilityHidden(true)
        } else {
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
    }

    /// The body with its eye holes cut out, as one shape.
    private struct SpriteShape: Shape {
        let frame: ClawdMotion.Frame, px: CGFloat, height: CGFloat
        func path(in r: CGRect) -> Path {
            let py = px * 1.7
            func rect(_ b: ClawdMotion.Box) -> Path {
                Path(CGRect(x: (b.x + 1) * px, y: height - (b.y + b.h) * py, width: b.w * px, height: b.h * py))
            }
            var solid = Path()
            for b in frame.solid { solid = solid.union(rect(b)) }
            for h in frame.holes { solid = solid.subtracting(rect(h)) }
            return solid
        }
    }

    /// A mark (the "?", the z's, the sparkles) as a shape.
    private struct MarkShape: Shape {
        let glyph: ClawdMotion.Glyph, px: CGFloat, height: CGFloat
        func path(in r: CGRect) -> Path {
            let py = px * 1.7, unit = px * glyph.scale
            let top = height - glyph.y * py - CGFloat(glyph.bits.count) * unit
            var path = Path()
            for (y, row) in glyph.bits.enumerated() {
                for (x, ch) in row.enumerated() where ch == "1" {
                    path.addRect(CGRect(x: (glyph.x + 1) * px + CGFloat(x) * unit, y: top + CGFloat(y) * unit, width: unit, height: unit))
                }
            }
            return path
        }
    }

    /// Solid ink when `toned` is off, so stacked flip-book frames never add up to a brighter patch; the
    /// flip-book applies the mood's shade once over the whole stack instead.
    var toned = true
    private var color: AnyShapeStyle {
        // Dimmed, macOS turns colour into translucent white: solid white keeps the character crisp.
        let ink: Color = dimmed ? .white : mood == .waiting ? Pulse.clay : .primary
        return AnyShapeStyle(ink.opacity(toned ? ClawdSprite.tone(mood, dimmed: dimmed) : 1))
    }
    static func tone(_ m: Mood, dimmed: Bool = false) -> Double {
        if dimmed { return m == .resting || m == .sleeping ? 0.75 : 1 }
        switch m { case .waiting: return 1; case .working, .done: return 0.85; case .resting, .sleeping: return 0.45 }
    }
}

// MARK: - Looping on the desktop

/// The character, looping on its own. A widget can't run code, so on the desktop each loop is cut into
/// frames, and macOS's clock-hand rotation (the effect that sweeps an analog clock's second hand) spins a
/// mask that shows one frame at a time. In Keep Working Preview, a TimelineView plays the same frames.
struct ClawdLoop: View {
    let mood: Mood
    var px: CGFloat = 5
    var walking = true
    /// A one-off act in place of the mood's loop (it plays once: the timeline swaps it out when it ends).
    var act: ClawdMotion.Act? = nil
    /// The way it faces, drawn into the frames. (Mirroring the flip-book instead would also mirror the spin
    /// that shows its frames.)
    var facing = 1.0

    @Environment(\.filmTime) private var film
    @Environment(\.dimmed) private var dimmed

    var body: some View {
        let fps = act == nil ? ClawdMotion.fps(mood) : 15
        let period = act == nil ? ClawdMotion.loop(mood) : ClawdMotion.actLength
        #if RENDER_HARNESS
        if let film {
            // The film's clock, cut to the flip-book's frame rate, exactly as the desktop shows it.
            let t = (film * fps).rounded(.down) / fps
            sprite(act == nil ? t : t.truncatingRemainder(dividingBy: period), toned: true)
        } else {
            TimelineView(.animation) { tl in
                let t = (tl.date.timeIntervalSince1970 * fps).rounded(.down) / fps
                sprite(act == nil ? t : t.truncatingRemainder(dividingBy: period), toned: true)
            }
        }
        #else
        // Dimmed, the frames are drawn as shapes (ClawdSprite switches itself): the dimmed desktop skips a Canvas.
        FlipBook(period: period, fps: fps) { t in sprite(t, toned: false) }
        .frame(width: ClawdSprite.size(px: px).width, height: ClawdSprite.size(px: px).height)
        .compositingGroup()
        .opacity(ClawdSprite.tone(mood, dimmed: dimmed))
        #endif
    }

    private func sprite(_ t: Double, toned: Bool) -> ClawdSprite {
        ClawdSprite(mood: mood, t: t, px: px, walking: walking, turn: facing, act: act, toned: toned)
    }
}

/// The hero walking its bar: the whole walk, travel included, as one flip-book on the clock. Every update of
/// the widget draws this same loop, so an update changes nothing on screen, however often they come.
struct WalkerBook: View {
    /// The walk's time is the clock's minus this.
    let offset: Double
    /// The bar it walks, in points.
    let width: CGFloat
    var px: CGFloat = 4.5

    @Environment(\.filmTime) private var film
    @Environment(\.dimmed) private var dimmed

    var body: some View {
        let fps = ClawdMotion.Walk.fps
        #if RENDER_HARNESS
        if let film {
            strip((film * fps).rounded(.down) / fps - offset, toned: true)
        } else {
            TimelineView(.animation) { tl in
                strip((tl.date.timeIntervalSince1970 * fps).rounded(.down) / fps - offset, toned: true)
            }
        }
        #else
        FlipBook(period: ClawdMotion.Walk.cycle, fps: fps) { t in strip(t - offset, toned: false) }
            .frame(width: width, height: ClawdSprite.size(px: px).height)
            .compositingGroup()
            .opacity(ClawdSprite.tone(.working, dimmed: dimmed))
        #endif
    }

    private func strip(_ w: Double, toned: Bool) -> some View {
        let size = ClawdSprite.size(px: px)
        let travel = max(0, width - size.width)
        return ClawdSprite(mood: .working, t: 0, px: px, pose: ClawdMotion.Walk.pose(w, travel: travel, px: px), toned: toned)
            .offset(x: travel * ClawdMotion.Walk.state(w).x)
            .frame(width: width, height: size.height, alignment: .topLeading)
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
                let pivot = size * max(80, period * 12), radius = pivot + size * 2
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
    /// [i, i+1) of n parts. Neighbours overlap by half a point at the sprite, no more: the desktop draws white
    /// content with an adding blend, so any wider overlap glows as a bright band mid-change.
    private struct Slice: Shape {
        let index: Int, count: Int
        func path(in r: CGRect) -> Path {
            let w = 2 * Double.pi / Double(count), up = -Double.pi / 2, e = 0.25 / Double(r.width / 2)
            var p = Path()
            let c = CGPoint(x: r.midX, y: r.midY)
            p.move(to: c)
            // Measured on the desktop (a readout of frame numbers beside a live clock): laid out this way the
            // frames play forwards, and frame 0 starts when the clock is a whole multiple of the period.
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
