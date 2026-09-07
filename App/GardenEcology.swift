import SwiftUI

enum GardenRandom {
    static func value(seed: UInt64, index: Int, channel: Int) -> Double {
        var value = seed &+ UInt64(index + 1) &* 0x9E3779B97F4A7C15 &+ UInt64(channel + 1) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return Double((value ^ (value >> 31)) >> 11) / 9_007_199_254_740_992
    }
}

struct GardenEcology {
    let seed: UInt64
    let growth: Double
    let habitatSeconds: TimeInterval
    let observationTime: TimeInterval
    let reduceMotion: Bool

    private func random(_ index: Int, _ channel: Int) -> Double {
        GardenRandom.value(seed: seed, index: index, channel: channel)
    }

    private func smooth(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private func stage(_ start: Double, _ end: Double) -> Double {
        min(1, max(0, (growth - start) / (end - start)))
    }

    func drawGround(in context: inout GraphicsContext, size: CGSize, inkScale: CGFloat) {
        guard growth > 0 else { return }
        for index in 0..<7 {
            let amount = stage(0.1 + random(index, 100) * 0.22, 0.6)
            guard amount > 0 else { continue }
            var c = context
            c.opacity = amount
            c.translateBy(x: size.width * (0.1 + random(index, 101) * 0.8),
                          y: size.height * (0.89 + random(index, 102) * 0.045))
            c.scaleBy(x: inkScale, y: inkScale)
            let radius = 7 + random(index, 103) * 12
            var stone = Path()
            stone.move(to: CGPoint(x: -radius, y: 0))
            stone.addCurve(to: CGPoint(x: radius, y: 0), control1: CGPoint(x: -radius * 0.8, y: -radius * 1.05),
                           control2: CGPoint(x: radius * 0.45, y: -radius * 0.9))
            stone.addQuadCurve(to: CGPoint(x: -radius, y: 0), control: CGPoint(x: 0, y: radius * 0.2))
            c.fill(stone, with: .color(.white))
            c.fill(stone, with: .color(.black.opacity(0.025)))
            ink(stone, in: &c, opacity: 0.25)
            for hatch in 0..<4 {
                var p = Path()
                p.move(to: CGPoint(x: radius * 0.3 + Double(hatch) * 2, y: -2))
                p.addLine(to: CGPoint(x: radius * 0.2 + Double(hatch) * 2, y: -6 - Double(hatch % 2)))
                ink(p, in: &c, opacity: 0.1, width: 0.5)
            }
            var moss = c
            moss.opacity *= stage(0.5, 0.93)
            for tuft in 0..<13 {
                let x = (random(index * 13 + tuft, 104) - 0.5) * radius * 2.6
                let y = random(index * 13 + tuft, 105) * 3
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addQuadCurve(to: CGPoint(x: x + 2, y: y - 3 - random(tuft, 106) * 3),
                               control: CGPoint(x: x - 2, y: y - 3))
                ink(p, in: &moss, opacity: 0.22, width: 0.6)
            }
        }

        for index in 0..<22 {
            let amount = stage(0.48 + random(index, 110) * 0.3, 0.99)
            guard amount > 0 else { continue }
            var c = context
            c.opacity = amount
            c.translateBy(x: size.width * (0.07 + random(index, 111) * 0.86),
                          y: size.height * (0.88 + random(index, 112) * 0.07))
            c.rotate(by: .degrees(random(index, 113) * 80 - 40))
            c.scaleBy(x: inkScale, y: inkScale)
            let length = 7 + random(index, 114) * 12
            var leaf = Path()
            leaf.move(to: .zero)
            leaf.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.6, y: -5))
            leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.35, y: 4))
            c.fill(leaf, with: .color(.black.opacity(0.045)))
            ink(leaf, in: &c, opacity: 0.24, width: 0.65)
            var vein = Path()
            vein.move(to: CGPoint(x: -2, y: 0))
            vein.addLine(to: CGPoint(x: length, y: 0))
            ink(vein, in: &c, opacity: 0.18, width: 0.5)
        }

        for index in 0..<8 {
            var c = context
            c.opacity = stage(0.4 + random(index, 120) * 0.2, 0.96)
            c.translateBy(x: size.width * (0.08 + random(index, 121) * 0.84), y: size.height * 0.91)
            c.scaleBy(x: inkScale, y: inkScale)
            var twig = Path()
            twig.move(to: .zero)
            twig.addLines([CGPoint(x: 13, y: -3), CGPoint(x: 29, y: -1), CGPoint(x: 36, y: -4)])
            twig.move(to: CGPoint(x: 13, y: -3))
            twig.addLine(to: CGPoint(x: 18, y: -8))
            ink(twig, in: &c, opacity: 0.22)
        }
        for index in 0..<2 {
            drawWeb(index, in: &context, size: size, inkScale: inkScale)
        }
    }

    private func drawWeb(_ index: Int, in context: inout GraphicsContext, size: CGSize, inkScale: CGFloat) {
        let amount = stage(0.65 + Double(index) * 0.05, 0.98)
        guard amount > 0 else { return }
        var c = context
        c.opacity = amount
        c.translateBy(x: size.width * (index == 0 ? 0.29 : 0.67), y: size.height * 0.78)
        c.scaleBy(x: inkScale, y: inkScale)
        let radius: CGFloat = 21
        var supports = Path()
        supports.move(to: CGPoint(x: -23, y: 30))
        supports.addLine(to: CGPoint(x: -20, y: -15))
        supports.move(to: CGPoint(x: 25, y: 30))
        supports.addLine(to: CGPoint(x: 22, y: -17))
        ink(supports, in: &c, opacity: 0.2)
        var web = Path()
        for spoke in 0..<7 {
            let angle = Double(spoke) / 7 * .pi * 2
            let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            web.move(to: .zero)
            web.addLine(to: CGPoint(x: direction.x * radius, y: direction.y * radius * 0.74))
        }
        for ring in 1...4 {
            for spoke in 0...7 {
                let angle = Double(spoke) / 7 * .pi * 2
                let r = radius * CGFloat(ring) / 4
                let point = CGPoint(x: CGFloat(cos(angle)) * r, y: CGFloat(sin(angle)) * r * 0.74)
                if spoke == 0 { web.move(to: point) } else { web.addLine(to: point) }
            }
        }
        ink(web, in: &c, opacity: 0.13, width: 0.45)
    }

    func drawAnimals(in context: inout GraphicsContext, size: CGSize, inkScale: CGFloat) {
        guard growth > 0 else { return }
        var c = context
        c.opacity = min(1, growth * 720)
        if habitatSeconds >= 30 * 60 { drawAnts(in: &c, size: size, scale: inkScale) }
        if habitatSeconds >= 3 * 3600 { drawSnail(in: &c, size: size, scale: inkScale) }
        if habitatSeconds >= 86_400 { drawButterfly(0, in: &c, size: size, scale: inkScale) }
        if habitatSeconds >= 3 * 86_400 { drawButterfly(1, in: &c, size: size, scale: inkScale) }
        if habitatSeconds >= 7 * 86_400 { drawBird(0, in: &c, size: size, scale: inkScale) }
        if habitatSeconds >= 14 * 86_400 {
            drawBird(1, in: &c, size: size, scale: inkScale)
            drawRabbit(in: &c, size: size, scale: inkScale)
        }
    }

    private func flowerTop(_ target: Int, size: CGSize) -> CGPoint {
        // Choose a plant that actually existed when observation began, and retain that perch.
        let initialGrowth = min(1, max(0, habitatSeconds / (30 * 86_400)))
        let index = GardenPopulation.establishedFlower(near: target, growth: initialGrowth) ?? 13
        let life = GardenPopulation.flower(index: index, growth: growth)
        let amount = life.size
        let base = CGPoint(x: size.width * (0.08 + (Double(index) + random(index, 13) * 0.8) / 33 * 0.84),
                           y: size.height * (0.865 + random(index, 14) * 0.025))
        let height = size.height * (0.22 + random(index, 15) * 0.49) * amount
        let lean = (random(index, 16) - 0.5) * size.width * 0.06 * amount
        let age = index.isMultiple(of: 6) ? life.ageProgress(from: 12, to: 24) : 0
        return CGPoint(x: base.x + lean + height * 0.04 * age, y: base.y - height + height * 0.09 * age)
    }

    private func drawBird(_ index: Int, in context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let departure = 1.25 + Double(index) * 0.65
        let flight = max(0, (observationTime - departure) / 3.2)
        guard flight < 1 else { return }
        let side: CGFloat = index == 0 ? -1 : 1
        let perch = flowerTop(index == 0 ? 12 : 25, size: size)
        var c = context
        c.opacity *= 1 - smooth((flight - 0.65) / 0.35)
        let travel = reduceMotion ? 0 : CGFloat(pow(flight, 1.2))
        c.translateBy(x: perch.x + side * size.width * 0.65 * travel, y: perch.y - size.height * 0.65 * travel)
        c.scaleBy(x: side * scale, y: scale)
        if flight > 0 && !reduceMotion { c.rotate(by: .degrees(-12)) }
        let body = Path(ellipseIn: CGRect(x: -12, y: -15, width: 19, height: 11))
        silhouette(body, in: &c)
        let head = Path(ellipseIn: CGRect(x: 2, y: -21, width: 9, height: 9))
        silhouette(head, in: &c)
        var tail = Path()
        tail.move(to: CGPoint(x: -10, y: -10))
        tail.addLines([CGPoint(x: -22, y: -13), CGPoint(x: -16, y: -5), CGPoint(x: -7, y: -5)])
        silhouette(tail, in: &c)
        var wing = Path()
        wing.move(to: CGPoint(x: -4, y: -11))
        if flight > 0 && !reduceMotion {
            let flap = CGFloat(sin(observationTime * 17))
            let tip = CGPoint(x: -16, y: -16 - flap * 19)
            wing.addQuadCurve(to: tip, control: CGPoint(x: -8, y: tip.y - 4))
            wing.addQuadCurve(to: CGPoint(x: 1, y: -8), control: CGPoint(x: -3, y: tip.y + 7))
        } else {
            wing.addQuadCurve(to: CGPoint(x: -10, y: -6), control: CGPoint(x: -15, y: -16))
            wing.addQuadCurve(to: CGPoint(x: 1, y: -9), control: CGPoint(x: -3, y: -5))
        }
        silhouette(wing, in: &c, opacity: 0.4)
        var beak = Path()
        beak.move(to: CGPoint(x: 10, y: -18))
        beak.addLines([CGPoint(x: 16, y: -15), CGPoint(x: 10, y: -14)])
        ink(beak, in: &c, opacity: 0.48)
        c.fill(Path(ellipseIn: CGRect(x: 7, y: -18.5, width: 1.4, height: 1.4)), with: .color(.black.opacity(0.6)))
        var feet = Path()
        feet.move(to: CGPoint(x: -3, y: -4))
        feet.addLines([CGPoint(x: -1, y: 0), CGPoint(x: 3, y: 0)])
        feet.move(to: CGPoint(x: -7, y: -4))
        feet.addLine(to: CGPoint(x: -5, y: flight == 0 ? 0 : -2))
        ink(feet, in: &c, opacity: 0.4, width: 0.65)
    }

    private func drawButterfly(_ index: Int, in context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let departure = 2.3 + Double(index) * 0.8
        let flight = max(0, (observationTime - departure) / 5)
        guard flight < 1 else { return }
        let base = flowerTop(index == 0 ? 5 : 20, size: size)
        let direction: CGFloat = index == 0 ? 1 : -1
        let travel = reduceMotion ? CGFloat(0) : CGFloat(flight)
        var c = context
        c.opacity *= 1 - smooth((flight - 0.65) / 0.35)
        c.translateBy(x: base.x + direction * size.width * 0.38 * travel + sin(travel * 15) * size.width * 0.025,
                      y: base.y - 5 * scale - size.height * 0.55 * travel + sin(travel * 23) * 8 * scale)
        c.scaleBy(x: scale, y: scale)
        let open: CGFloat = reduceMotion ? 0.7 : 0.25 + 0.75 * abs(CGFloat(sin(observationTime * (flight > 0 ? 14 : 3) + 0.8)))
        for side: CGFloat in [-1, 1] {
            var wing = Path()
            wing.move(to: .zero)
            wing.addCurve(to: CGPoint(x: side * 9 * open, y: -7),
                          control1: CGPoint(x: side * 2 * open, y: -13), control2: CGPoint(x: side * 14 * open, y: -16))
            wing.addQuadCurve(to: CGPoint(x: side * 6 * open, y: 5), control: CGPoint(x: side * 14 * open, y: 4))
            wing.addQuadCurve(to: .zero, control: CGPoint(x: side * 2 * open, y: 8))
            silhouette(wing, in: &c, opacity: 0.38)
            c.stroke(Path(ellipseIn: CGRect(x: side * 6 * open - 1.5, y: -7, width: 3, height: 4)),
                     with: .color(.black.opacity(0.18)), lineWidth: 0.55)
        }
        var body = Path()
        body.move(to: CGPoint(x: 0, y: -6))
        body.addLine(to: CGPoint(x: 0, y: 5))
        body.move(to: CGPoint(x: 0, y: -5))
        body.addQuadCurve(to: CGPoint(x: -3, y: -12), control: CGPoint(x: -1, y: -12))
        body.move(to: CGPoint(x: 0, y: -5))
        body.addQuadCurve(to: CGPoint(x: 3, y: -12), control: CGPoint(x: 1, y: -12))
        ink(body, in: &c, opacity: 0.42, width: 0.8)
    }

    private func drawRabbit(in context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let retreat = smooth((observationTime - 2.6) / 2.2)
        guard retreat < 1 else { return }
        var c = context
        c.translateBy(x: size.width * 0.82, y: size.height * 0.896)
        c.scaleBy(x: scale, y: scale)
        c.clip(to: Path(CGRect(x: -45, y: -80, width: 90, height: 80)))
        if reduceMotion { c.opacity *= 1 - retreat }
        else { c.translateBy(x: 5 * retreat, y: 58 * retreat) }
        let peek = reduceMotion ? 0 : smooth(observationTime / 1.3) * 4
        silhouette(Path(ellipseIn: CGRect(x: -7, y: -22, width: 36, height: 25)), in: &c, opacity: 0.3)
        silhouette(Path(ellipseIn: CGRect(x: -20, y: -30 - peek, width: 22, height: 22)), in: &c, opacity: 0.38)
        for ear in 0..<2 {
            let x = CGFloat(ear) * 8 - 14
            var shape = Path()
            shape.move(to: CGPoint(x: x, y: -27 - peek))
            shape.addCurve(to: CGPoint(x: x + 2, y: -57 - peek),
                           control1: CGPoint(x: x - 8, y: -52 - peek), control2: CGPoint(x: x - 2, y: -64 - peek))
            shape.addQuadCurve(to: CGPoint(x: x + 5, y: -28 - peek), control: CGPoint(x: x + 10, y: -43 - peek))
            silhouette(shape, in: &c, opacity: 0.4)
            var inner = Path()
            inner.move(to: CGPoint(x: x + 2, y: -33 - peek))
            inner.addLine(to: CGPoint(x: x + 2, y: -51 - peek))
            ink(inner, in: &c, opacity: 0.15, width: 0.6)
        }
        c.fill(Path(ellipseIn: CGRect(x: -14, y: -23 - peek, width: 1.5, height: 1.5)), with: .color(.black.opacity(0.48)))
        var whiskers = Path()
        whiskers.move(to: CGPoint(x: -19, y: -17 - peek))
        whiskers.addLine(to: CGPoint(x: -28, y: -19 - peek))
        whiskers.move(to: CGPoint(x: -19, y: -15 - peek))
        whiskers.addLine(to: CGPoint(x: -28, y: -13 - peek))
        ink(whiskers, in: &c, opacity: 0.22, width: 0.45)
    }

    private func drawSnail(in context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let retract = smooth((observationTime - 9) / 4)
        var c = context
        let crawl = reduceMotion ? 0 : min(9, observationTime) * scale * 0.6
        c.translateBy(x: size.width * 0.21 + crawl, y: size.height * 0.925)
        c.scaleBy(x: scale, y: scale)
        var body = Path()
        body.move(to: CGPoint(x: -10, y: 1))
        body.addQuadCurve(to: CGPoint(x: 13 - 7 * retract, y: 1), control: CGPoint(x: 0, y: -5))
        body.addQuadCurve(to: CGPoint(x: -10, y: 1), control: CGPoint(x: 1, y: 5))
        silhouette(body, in: &c, opacity: 0.35)
        let shell = Path(ellipseIn: CGRect(x: -7, y: -12, width: 14, height: 13))
        silhouette(shell, in: &c, opacity: 0.45)
        var spiral = Path()
        for step in 0...55 {
            let angle = Double(step) / 55 * .pi * 4
            let radius = CGFloat(step) / 55 * 5
            let point = CGPoint(x: CGFloat(cos(angle)) * radius, y: -5.5 + CGFloat(sin(angle)) * radius)
            if step == 0 { spiral.move(to: point) } else { spiral.addLine(to: point) }
        }
        ink(spiral, in: &c, opacity: 0.3, width: 0.55)
        var antennae = Path()
        let extensionLength = 1 - retract
        antennae.move(to: CGPoint(x: 9, y: -1))
        antennae.addLine(to: CGPoint(x: 10 + 3 * extensionLength, y: -1 - 9 * extensionLength))
        antennae.move(to: CGPoint(x: 11, y: -1))
        antennae.addLine(to: CGPoint(x: 14 + 3 * extensionLength, y: -1 - 7 * extensionLength))
        ink(antennae, in: &c, opacity: 0.38 * (1 - retract), width: 0.6)
    }

    private func drawAnts(in context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let fade = 1 - smooth((observationTime - 10) / 5)
        guard fade > 0 else { return }
        for ant in 0..<5 {
            var c = context
            c.opacity *= fade
            let travel = reduceMotion ? 0 : observationTime * 1.6
            c.translateBy(x: size.width * 0.44 + (Double(ant) * 15 + travel) * scale,
                          y: size.height * 0.931 + sin(Double(ant) + travel * 0.08) * 2 * scale)
            c.scaleBy(x: scale, y: scale)
            for part in 0..<3 {
                c.fill(Path(ellipseIn: CGRect(x: CGFloat(part) * 1.3, y: -1, width: 1.5, height: 1.3)), with: .color(.black.opacity(0.4)))
            }
            var legs = Path()
            for leg in 0..<3 {
                let x = CGFloat(leg) * 1.3
                legs.move(to: CGPoint(x: x, y: 0))
                legs.addLine(to: CGPoint(x: x - 1, y: 2))
                legs.move(to: CGPoint(x: x, y: 0))
                legs.addLine(to: CGPoint(x: x + 1, y: -2))
            }
            ink(legs, in: &c, opacity: 0.3, width: 0.4)
        }
    }

    private func ink(_ path: Path, in context: inout GraphicsContext, opacity: Double = 0.35, width: CGFloat = 0.75) {
        context.stroke(path, with: .color(.black.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func silhouette(_ path: Path, in context: inout GraphicsContext, opacity: Double = 0.45) {
        context.fill(path, with: .color(.white.opacity(0.94)))
        context.fill(path, with: .color(.black.opacity(0.025)))
        ink(path, in: &context, opacity: opacity)
    }
}
