import SwiftUI

struct DormancyArtView: View {
    @ObservedObject var store: DormancyStore
    let sceneID: UUID
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()
                if store.isObserving {
                    TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: !isActive)) { timeline in
                        GardenDrawing(seed: store.record.seed, growth: DormancyStore.growth(for: store.seconds(at: timeline.date)))
                    }
                    .padding(.top, 44)
                    .accessibilityLabel("正在回退的花草园")
                    .transition(.opacity)
                } else {
                    Button {
                        store.observe(scene: sceneID)
                    } label: {
                        VStack(spacing: 24) {
                            SketchLock()
                                .frame(width: min(200, geometry.size.height * 0.4),
                                       height: min(200, geometry.size.height * 0.4))
                            Text("打扰并观察")
                                .font(.system(size: geometry.size.width >= 900 ? 24 : 20, weight: .regular))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isActive)
                    .accessibilityLabel("打扰并观察")
                    .transition(.opacity)
                }

                HStack(alignment: .top) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(growthTime(store.seconds(at: timeline.date)))
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(Color(white: 0.45))
                    }
                    .padding(.top, 13)
                    Spacer(minLength: 12)
                    if store.isObserving {
                        Button("离开") { store.leave() }
                            .font(.system(size: 17))
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(.plain)
                            .disabled(!isActive)
                    }
                }
                .padding(.horizontal, geometry.size.width >= 900 ? 36 : 24)
                .padding(.top, 8)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.isObserving)
        }
        .foregroundStyle(Color(white: 0.2))
        .task(id: isActive && store.isObserving) {
            guard isActive, store.isObserving else { return }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    try Task.checkCancellation()
                    store.checkpoint()
                }
            } catch { return }
        }
    }

    private func growthTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds)) / 60
        return "已经生长\(minutes / 1440)天\(minutes / 60 % 24)小时\(minutes % 60)分"
    }
}

struct DormancySettingsView: View {
    var body: some View {
        ArtSettingsLayout(title: "休眠", introduction: "如上，请你不要打扰它们生长") {
            VStack(alignment: .leading, spacing: 14) {
                Text("上锁后，苗圃将按真实时间生长，30天后将会长成完整的形态。")
                Text("当你观察时，苗圃将以600倍的速度退化，直至归零")
                Text("点击右上角离开后，苗圃将从剩下的时间继续生长")
                Text("观察时翻页或关闭软件，会暂停退化，但是只有点击“离开”才能恢复生长")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SketchLock: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            context.scaleBy(x: scale, y: scale)
            // Several imperfect passes and light hatching suggest graphite on white paper.
            for pass in 0..<3 {
                var pencil = context
                pencil.translateBy(x: CGFloat(pass - 1) * 0.8, y: CGFloat(pass % 2) * 0.7)
                let body = Path(roundedRect: CGRect(x: 46, y: 91, width: 108, height: 80), cornerRadius: 8)
                pencil.fill(body, with: .color(.black.opacity(0.015)))
                pencil.stroke(body, with: .color(.black.opacity(pass == 0 ? 0.36 : 0.13)), lineWidth: 1)
                var shackle = Path()
                shackle.move(to: CGPoint(x: 65, y: 91))
                shackle.addLine(to: CGPoint(x: 65, y: 61))
                shackle.addCurve(to: CGPoint(x: 135, y: 61),
                                 control1: CGPoint(x: 65, y: 14), control2: CGPoint(x: 135, y: 14))
                shackle.addLine(to: CGPoint(x: 135, y: 91))
                pencil.stroke(shackle, with: .color(.black.opacity(0.3)), lineWidth: 1.4)
                var inner = Path()
                inner.move(to: CGPoint(x: 76, y: 91))
                inner.addLine(to: CGPoint(x: 76, y: 62))
                inner.addCurve(to: CGPoint(x: 124, y: 62),
                               control1: CGPoint(x: 76, y: 29), control2: CGPoint(x: 124, y: 29))
                inner.addLine(to: CGPoint(x: 124, y: 91))
                pencil.stroke(inner, with: .color(.black.opacity(0.2)), lineWidth: 0.9)
            }
            for index in 0..<19 {
                let y = CGFloat(index) * 3.5 + 100
                var shading = Path()
                shading.move(to: CGPoint(x: 50, y: y))
                shading.addLine(to: CGPoint(x: 60 + CGFloat(index % 4) * 2, y: y - 6))
                context.stroke(shading, with: .color(.black.opacity(0.1)), lineWidth: 0.65)
            }
            let keyhole = Path(ellipseIn: CGRect(x: 95, y: 119, width: 10, height: 10))
            context.fill(keyhole, with: .color(.black.opacity(0.35)))
            var slot = Path()
            slot.move(to: CGPoint(x: 100, y: 127))
            slot.addLine(to: CGPoint(x: 100, y: 140))
            context.stroke(slot, with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Fixed seeds and continuous growth stages make observation retrace the same garden.
struct GardenDrawing: View {
    let seed: UInt64
    let growth: Double

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 950, size.height / 650)
            let inkScale = max(0.7, scale)
            for index in 0..<72 {
                drawGrass(index, in: &context, size: size, inkScale: inkScale)
            }
            for index in 0..<33 {
                drawFlower(index, in: &context, size: size, inkScale: inkScale)
            }
            if growth > 0 {
                // Sparse soil strokes keep the lower edge open instead of drawing a hard horizon.
                for index in 0..<90 {
                    let x = size.width * (0.055 + random(index, 90) * 0.89)
                    let y = size.height * (0.87 + random(index, 91) * 0.055)
                    var stroke = Path()
                    stroke.move(to: CGPoint(x: x, y: y))
                    stroke.addLine(to: CGPoint(x: x + (2 + random(index, 92) * 9) * inkScale, y: y - inkScale))
                    context.stroke(stroke, with: .color(.black.opacity(0.12 * min(1, growth * 5))), lineWidth: 0.6 * inkScale)
                }
            }
        }
        .background(Color.white)
        .accessibilityHidden(true)
    }

    private func random(_ index: Int, _ channel: Int) -> Double {
        var value = seed &+ UInt64(index + 1) &* 0x9E3779B97F4A7C15 &+ UInt64(channel + 1) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return Double((value ^ (value >> 31)) >> 11) / 9_007_199_254_740_992
    }

    private func stage(from start: Double, to end: Double) -> CGFloat {
        let t = min(1, max(0, (growth - start) / (end - start)))
        return CGFloat(t * t * (3 - 2 * t))
    }

    private func drawGrass(_ index: Int, in context: inout GraphicsContext, size: CGSize, inkScale: CGFloat) {
        let start = random(index, 0) * 0.42
        let amount = stage(from: start, to: min(1, start + 0.4))
        guard amount > 0 else { return }
        let base = CGPoint(x: size.width * (0.05 + (Double(index) + random(index, 1)) / 72 * 0.9),
                           y: size.height * (0.87 + random(index, 2) * 0.04))
        let height = size.height * (0.035 + random(index, 3) * 0.23) * amount
        for blade in 0..<4 {
            let lean = (random(index, 4 + blade) - 0.5) * height * 0.9
            let tip = CGPoint(x: base.x + lean, y: base.y - height * (0.55 + CGFloat(blade) * 0.15))
            var path = Path()
            path.move(to: base)
            path.addQuadCurve(to: tip, control: CGPoint(x: base.x + lean * 0.15, y: base.y - height * 0.63))
            context.stroke(path, with: .color(.black.opacity(0.18 + random(index, 9) * 0.22)),
                           style: StrokeStyle(lineWidth: (0.55 + random(index, 10) * 0.4) * inkScale, lineCap: .round))
        }
    }

    private func drawFlower(_ index: Int, in context: inout GraphicsContext, size: CGSize, inkScale: CGFloat) {
        let start = 0.08 + random(index, 12) * 0.36
        let amount = stage(from: start, to: min(0.92, start + 0.48))
        guard amount > 0 else { return }
        let x = size.width * (0.08 + (Double(index) + random(index, 13) * 0.8) / 33 * 0.84)
        let base = CGPoint(x: x, y: size.height * (0.865 + random(index, 14) * 0.025))
        let height = size.height * (0.22 + random(index, 15) * 0.49) * amount
        let lean = (random(index, 16) - 0.5) * size.width * 0.06 * amount
        let top = CGPoint(x: base.x + lean, y: base.y - height)
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: top, control: CGPoint(x: base.x - lean * 0.5, y: base.y - height * 0.55))
        pencilStroke(stem, in: &context, width: 0.9 * inkScale, opacity: 0.48)

        for leaf in 0..<5 {
            let t = CGFloat(leaf + 1) / 7
            let leafAmount = stage(from: start + Double(leaf) * 0.045, to: min(1, start + 0.37 + Double(leaf) * 0.045))
            let origin = CGPoint(x: base.x - lean * t * (1 - t) + lean * t * t,
                                 y: base.y - height * (1.1 * t - 0.1 * t * t))
            let side: CGFloat = leaf.isMultiple(of: 2) ? -1 : 1
            let length = min(size.width * 0.06, size.height * 0.085) * leafAmount * (0.7 + random(index, 18 + leaf) * 0.5)
            let tip = CGPoint(x: origin.x + side * length, y: origin.y - length * 0.5)
            drawLeaf(from: origin, to: tip, width: length * 0.2, in: &context, inkScale: inkScale)
        }

        let bloom = stage(from: 0.47 + random(index, 26) * 0.25, to: 0.82 + random(index, 27) * 0.18)
        let radius = size.height * (0.012 + random(index, 28) * 0.012) * (0.12 + 0.88 * bloom) * amount
        if index % 3 == 0 {
            drawDaisy(at: top, radius: radius, bloom: bloom, in: &context, inkScale: inkScale)
        } else if index % 3 == 1 {
            drawCup(at: top, radius: radius * 1.3, bloom: bloom, in: &context, inkScale: inkScale)
        } else {
            drawSprig(at: top, radius: radius, bloom: bloom, in: &context, inkScale: inkScale)
        }
    }

    private func pencilStroke(_ path: Path, in context: inout GraphicsContext, width: CGFloat, opacity: Double) {
        context.stroke(path, with: .color(.black.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        var echo = context
        echo.translateBy(x: width * 0.75, y: -width * 0.4)
        echo.stroke(path, with: .color(.black.opacity(opacity * 0.22)), lineWidth: width * 0.65)
    }

    private func drawLeaf(from base: CGPoint, to tip: CGPoint, width: CGFloat, in context: inout GraphicsContext, inkScale: CGFloat) {
        guard width > 0.05 else { return }
        let middle = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let distance = max(1, hypot(tip.x - base.x, tip.y - base.y))
        let normal = CGPoint(x: -(tip.y - base.y) / distance * width, y: (tip.x - base.x) / distance * width)
        var leaf = Path()
        leaf.move(to: base)
        leaf.addQuadCurve(to: tip, control: CGPoint(x: middle.x + normal.x, y: middle.y + normal.y))
        leaf.addQuadCurve(to: base, control: CGPoint(x: middle.x - normal.x, y: middle.y - normal.y))
        context.fill(leaf, with: .color(.black.opacity(0.035)))
        pencilStroke(leaf, in: &context, width: 0.65 * inkScale, opacity: 0.32)
        var vein = Path()
        vein.move(to: base)
        vein.addLine(to: tip)
        context.stroke(vein, with: .color(.black.opacity(0.17)), lineWidth: 0.45 * inkScale)
    }

    private func drawDaisy(at point: CGPoint, radius: CGFloat, bloom: CGFloat, in context: inout GraphicsContext, inkScale: CGFloat) {
        for petal in 0..<9 {
            let angle: Double = Double(petal) / 9 * .pi * 2
            let tip = CGPoint(x: point.x + CGFloat(cos(angle)) * radius, y: point.y + CGFloat(sin(angle)) * radius)
            drawLeaf(from: point, to: tip, width: radius * (0.1 + 0.15 * bloom), in: &context, inkScale: inkScale)
        }
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius * 0.16, y: point.y - radius * 0.16,
                                           width: radius * 0.32, height: radius * 0.32)), with: .color(.black.opacity(0.4)))
    }

    private func drawCup(at point: CGPoint, radius: CGFloat, bloom: CGFloat, in context: inout GraphicsContext, inkScale: CGFloat) {
        for petal in 0..<5 {
            let angle: Double = -.pi / 2 + Double(petal - 2) * (0.15 + Double(bloom) * 0.36)
            let tip = CGPoint(x: point.x + CGFloat(cos(angle)) * radius, y: point.y + CGFloat(sin(angle)) * radius)
            drawLeaf(from: point, to: tip, width: radius * 0.24, in: &context, inkScale: inkScale)
        }
    }

    private func drawSprig(at point: CGPoint, radius: CGFloat, bloom: CGFloat, in context: inout GraphicsContext, inkScale: CGFloat) {
        for bud in 0..<7 {
            let side: CGFloat = bud.isMultiple(of: 2) ? -1 : 1
            let center = CGPoint(x: point.x + side * radius * 0.4 * bloom, y: point.y - CGFloat(bud) * radius * 0.35)
            var twig = Path()
            twig.move(to: CGPoint(x: point.x, y: point.y + radius))
            twig.addLine(to: center)
            context.stroke(twig, with: .color(.black.opacity(0.35)), lineWidth: 0.6 * inkScale)
            let budRadius = radius * (0.12 + 0.12 * bloom)
            let shape = Path(ellipseIn: CGRect(x: center.x - budRadius, y: center.y - budRadius,
                                              width: budRadius * 2, height: budRadius * 2))
            context.fill(shape, with: .color(.black.opacity(0.09)))
            context.stroke(shape, with: .color(.black.opacity(0.4)), lineWidth: 0.6 * inkScale)
        }
    }
}
