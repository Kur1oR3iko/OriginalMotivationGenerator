import SwiftUI

struct BreathArtView: View {
    @ObservedObject var store: BreathStore
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var releases: [Release] = []

    private struct Release: Identifiable {
        let id: Int
        let duration: TimeInterval
        let date: Date
    }

    var body: some View {
        GeometryReader { geometry in
            animatedLines
                .overlay(touchSurface)
                .onAppear { updateCapacity(height: geometry.size.height) }
                .onChange(of: geometry.size.height) { height in updateCapacity(height: height) }
        }
        .background(Color.white.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let message = store.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.secondary).padding(20)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("呼吸，已留下\(store.marks.count)条线")
        .accessibilityHint(store.errorMessage ?? "")
        .accessibilityAction(named: "开始吸气", beginInhale)
        .accessibilityAction(named: "结束吸气", endInhale)
        .onAppear { if isActive { BreathHaptics.shared.prepare() } }
        .onChange(of: isActive) { active in
            if active { BreathHaptics.shared.prepare() }
            else { cancelInhale() }
        }
        .task(id: releases.last?.id) {
            do {
                while let first = releases.first {
                    let remaining = max(0, 1 - Date.now.timeIntervalSince(first.date))
                    try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    try Task.checkCancellation()
                    releases.removeAll { Date.now.timeIntervalSince($0.date) >= 1 }
                }
            } catch { return }
        }
    }

    private var animatedLines: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isActive || (store.beganAt == nil && releases.isEmpty))) { timeline in
            // Changing value inputs keep the Canvas drawing even when the finger stays still.
            let duration = store.beganAt.map { max(0, ProcessInfo.processInfo.systemUptime - $0) }
            breathLines(activeDuration: duration, at: timeline.date)
        }
    }

    private var touchSurface: SingleTouchSurface {
        SingleTouchSurface(isEnabled: isActive, began: { _ in beginInhale() }, moved: { _ in },
                           ended: endInhale, cancelled: cancelInhale)
    }

    private func beginInhale() {
        guard isActive, store.beganAt == nil else { return }
        store.begin()
        BreathHaptics.shared.begin()
    }

    private func endInhale() {
        guard isActive, store.beganAt != nil else { return }
        store.end()
        BreathHaptics.shared.release()
        if let mark = store.marks.last {
            releases.append(Release(id: mark.id, duration: mark.duration, date: .now))
        }
    }

    private func cancelInhale() {
        store.cancel()
        BreathHaptics.shared.cancel()
        releases = []
    }

    private func updateCapacity(height: CGFloat) {
        store.resize(capacity: Int(max(12, height - 56) / 12))
    }

    private func breathLines(activeDuration: TimeInterval?, at now: Date) -> some View {
        Canvas { context, size in
            for release in releases {
                let progress = min(1, max(0, now.timeIntervalSince(release.date)))
                drawHalo(context: &context, size: size, duration: release.duration, release: progress)
            }
            if let activeDuration {
                drawHalo(context: &context, size: size, duration: activeDuration, release: nil)
            }

            let reserved = activeDuration == nil ? 0 : 1
            let marks = Array(store.marks.suffix(max(0, store.capacity - reserved)))
            let availableWidth = max(0, size.width - 56)
            for (index, mark) in marks.enumerated() {
                let y = size.height - 28 - CGFloat(index) * 12
                let width = max(4, availableWidth * CGFloat(BreathStore.widthFraction(for: mark.duration)))
                drawLine(context: &context, y: y, width: width, color: Color(white: 0.55))
                if let release = releases.first(where: { $0.id == mark.id }) {
                    let remaining = 1 - min(1, max(0, now.timeIntervalSince(release.date)))
                    let blackWidth = reduceMotion ? width : width * remaining
                    if remaining > 0 {
                        drawLine(context: &context, y: y, width: blackWidth,
                                 color: .black.opacity(reduceMotion ? remaining : 1))
                    }
                }
            }
            if let activeDuration {
                let y = size.height - 28 - CGFloat(marks.count) * 12
                let width = max(4, availableWidth * CGFloat(BreathStore.widthFraction(for: activeDuration)))
                drawLine(context: &context, y: y, width: width, color: .black)
            }
        }
    }

    private func drawLine(context: inout GraphicsContext, y: CGFloat, width: CGFloat, color: Color) {
        guard width > 0 else { return }
        var line = Path()
        line.move(to: CGPoint(x: 28, y: y))
        line.addLine(to: CGPoint(x: 28 + width, y: y))
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawHalo(context: inout GraphicsContext, size: CGSize, duration: TimeInterval, release: Double?) {
        let expansion = reduceMotion ? 0.35 : BreathStore.widthFraction(for: duration * 1.15)
        let remaining = 1 - (release ?? 0)
        guard remaining > 0 else { return }
        let fade = release == nil ? min(1, 0.35 + duration / 0.12) : remaining
        let maximumRadius = min(size.width, size.height) * 0.21
        let radius = (24 + max(0, maximumRadius - 24) * expansion) * (reduceMotion ? 1 : remaining)
        let halo = Path(ellipseIn: CGRect(x: size.width / 2 - radius, y: size.height * 0.46 - radius,
                                        width: radius * 2, height: radius * 2))
        context.fill(halo, with: .color(.black.opacity(0.035 * fade)))
        context.stroke(halo, with: .color(.black.opacity(0.18 * fade)), lineWidth: 1)
    }
}

struct BreathSettingsView: View {
    @ObservedObject var store: BreathStore

    var body: some View {
        ArtSettingsLayout(title: "呼吸", introduction: "吸气时按住屏幕，呼气时松开。") {
            Text("每次呼吸留下一条灰线。新的线向上叠加，满屏时最早的一条离开。")
                .font(.body).foregroundStyle(.secondary)
            Button("舍弃") { store.discard() }
                .font(.title2.weight(.medium))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
    }
}

struct ArtSettingsLayout<Content: View>: View {
    let title: String
    let introduction: String
    @ViewBuilder let content: () -> Content
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 56

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(title)
                        .font(.system(size: geometry.size.width >= 900 ? titleSize : titleSize * 0.75, weight: .black, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text(introduction).font(.title3)
                    content()
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(.horizontal, geometry.size.width >= 900 ? 48 : 28)
                .padding(.top, 36).padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
    }
}
