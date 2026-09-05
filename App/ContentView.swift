import SwiftUI
import UIKit
import Combine

enum AppTypography {
    static func displayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func clockFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
}

@MainActor
struct ContentView: View {
    let keyboardEvents: PassthroughSubject<UISwipeGestureRecognizer.Direction, Never>
    let scenePhase: ScenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("originalMotivationGenerator.v1.autoAdvanceEnabled") private var autoAdvanceEnabled = false
    @AppStorage("originalMotivationGenerator.v1.autoAdvanceInterval") private var autoAdvanceInterval = 5.0
    @AppStorage("originalMotivationGenerator.v1.clockShowsDate") private var clockShowsDate = true
    @AppStorage("originalMotivationGenerator.v1.clockShowsSeconds") private var clockShowsSeconds = false
    @AppStorage("originalMotivationGenerator.v1.clockTimeZone") private var clockTimeZone = "system"
    @State private var phrase = KurioPhraseGenerator.lastPhrase ?? KurioPhraseGenerator.next()
    @State private var showingSettings = false
    @State private var selectedPage: ArtPage = .phrase
    @State private var horizontalStep = 1
    @State private var showsPageIndicator = false
    @State private var indicatorPulse = 0
    @StateObject private var onceStore = OncePressStore.shared
    @StateObject private var letterDraft = LetterDraft()
    @State private var turnAxis: Axis = .vertical
    @State private var pageTravel: CGFloat = 0
    @State private var isTurningPage = false
    @State private var isEditingText = false
    @State private var generation = 0

    private var phraseText: String { phrase?.text ?? "全部组合已生成完毕" }

    var body: some View {
        GeometryReader { proxy in
            let horizontal = turnAxis == .horizontal
            let neighborSettings = horizontal ? showingSettings : !showingSettings
            let previousPage = horizontal ? selectedPage.offset(by: -1) : selectedPage
            let nextPage = horizontal ? selectedPage.offset(by: 1) : selectedPage
            // Horizontal neighbors wrap across all artworks; vertical neighbors open the matching settings.
            ZStack {
                page(settings: neighborSettings, feature: previousPage)
                    .offset(x: horizontal ? -proxy.size.width : 0,
                            y: horizontal ? 0 : -proxy.size.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                page(settings: showingSettings, feature: selectedPage)
                page(settings: neighborSettings, feature: nextPage)
                    .offset(x: horizontal ? proxy.size.width : 0,
                            y: horizontal ? 0 : proxy.size.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .offset(x: horizontal ? pageTravel * proxy.size.width : 0,
                    y: horizontal ? 0 : pageTravel * proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color.white.ignoresSafeArea())
        .allowsHitTesting(!isTurningPage)
        .background(ThreeFingerSwipe(isEnabled: scenePhase == .active && !isTurningPage, action: turnPage))
        .onReceive(keyboardEvents) { direction in
            guard scenePhase == .active && !isEditingText else { return }
            turnPage(direction)
        }
        .overlay(alignment: .bottom) { pageIndicator }
        .task(id: indicatorPulse) {
            guard indicatorPulse > 0 else { return }
            do {
                try await Task.sleep(nanoseconds: 1_800_000_000)
                try Task.checkCancellation()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { showsPageIndicator = false }
            } catch {
                return
            }
        }
        .accessibilityAction(named: "下一页") { turnPage(.up) }
        .accessibilityAction(named: "上一页") { turnPage(.down) }
        .accessibilityAction(named: "下一个功能") { turnPage(.left) }
        .accessibilityAction(named: "上一个功能") { turnPage(.right) }
        .task(id: isTurningPage) {
            guard isTurningPage else { return }
            do {
                try await Task.sleep(nanoseconds: 240_000_000)
                try Task.checkCancellation()
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if turnAxis == .horizontal {
                        selectedPage = selectedPage.offset(by: horizontalStep)
                    } else {
                        showingSettings.toggle()
                    }
                    pageTravel = 0
                    isTurningPage = false
                }
            } catch {
                return
            }
        }
        .task(id: playbackSchedule) {
            guard playbackSchedule.isRunning else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(playbackSchedule.interval * 1_000_000_000))
                try Task.checkCancellation()
                generate()
            } catch is CancellationError {
                // Cancel pending work when playback stops, settings change, or the scene becomes inactive.
            } catch {
                return
            }
        }
    }

    private var pageIndicator: some View {
        let current = isTurningPage && turnAxis == .horizontal ? selectedPage.offset(by: horizontalStep) : selectedPage
        return HStack(spacing: 9) {
            ForEach(ArtPage.allCases) { page in
                Circle()
                    .fill(page == current ? Color.black : Color(white: 0.75))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, 12)
        .opacity(showsPageIndicator ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第\(current.rawValue + 1)页，共\(ArtPage.allCases.count)页，\(current.title)")
        .accessibilityHidden(!showsPageIndicator)
    }

    @ViewBuilder
    private func page(settings: Bool, feature: ArtPage) -> some View {
        Group {
            switch (feature, settings) {
            case (.phrase, false):
                phrasePage
            case (.phrase, true):
                SettingsView(autoAdvanceEnabled: $autoAdvanceEnabled, interval: $autoAdvanceInterval)
            case (.clock, false):
                ClockView(showsDate: clockShowsDate, showsSeconds: clockShowsSeconds, timeZoneIdentifier: clockTimeZone,
                          isActive: selectedPage == .clock && !showingSettings && !isTurningPage && scenePhase == .active)
            case (.clock, true):
                ClockSettingsView(showsDate: $clockShowsDate, showsSeconds: $clockShowsSeconds, timeZoneIdentifier: $clockTimeZone) { editing in
                    if selectedPage == .clock && showingSettings { isEditingText = editing }
                }
            case (.once, false):
                OncePressView(store: onceStore, timeZoneIdentifier: clockTimeZone)
            case (.once, true):
                ArtIntroductionView(title: "只能按一次", introduction: "要按下试试吗，你只有一次机会。", footnote: "也许你已经按过了")
            case (.letter, false):
                LetterView(draft: letterDraft) { editing in
                    if selectedPage == .letter && !showingSettings { isEditingText = editing }
                }
            case (.letter, true):
                ArtIntroductionView(title: "信", introduction: "你知道的，很遗憾，这封信并没能发出去")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(alignment: .topTrailing) {
            if ProcessInfo.processInfo.isiOSAppOnMac && (settings || feature == .phrase || feature == .clock) {
                HStack(spacing: 0) {
                    Button { turnPage(.left) } label: {
                        Image(systemName: feature.offset(by: 1).symbol)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("切换到\(feature.offset(by: 1).title)")
                    .keyboardShortcut(.rightArrow, modifiers: .command)

                    Button { turnPage(.up) } label: {
                        Image(systemName: settings ? "house" : "gearshape")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(settings ? "切换到主页" : "打开设置")
                    .keyboardShortcut(",", modifiers: .command)
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .padding(8)
                .disabled(settings != showingSettings || feature != selectedPage || isTurningPage)
            }
        }
    }

    private func turnPage(_ direction: UISwipeGestureRecognizer.Direction) {
        guard !isTurningPage else { return }
        if isEditingText {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            isEditingText = false
        }
        let horizontal = direction == .left || direction == .right
        if horizontal {
            horizontalStep = direction == .left ? 1 : -1
            indicatorPulse += 1
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { showsPageIndicator = true }
        }
        guard !reduceMotion else {
            if horizontal {
                selectedPage = selectedPage.offset(by: horizontalStep)
            } else {
                showingSettings.toggle()
            }
            return
        }
        turnAxis = horizontal ? .horizontal : .vertical
        isTurningPage = true
        withAnimation(.easeOut(duration: 0.24)) {
            pageTravel = direction == .up || direction == .left ? -1 : 1
        }
    }

    private var phrasePage: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { proxy in
                let horizontalPadding = max(proxy.size.width * 0.04, 24)
                let fontSize = fittedFontSize(in: proxy.size, padding: horizontalPadding)

                Button(action: generateManually) {
                    Group {
                        if let phrase {
                            HStack(spacing: 0) {
                                animatedWord(phrase.verb, movesUp: true)
                                animatedWord(phrase.adjective, movesUp: false)
                                Text("的")
                                animatedWord(phrase.noun, movesUp: true)
                            }
                        } else {
                            Text(phraseText)
                        }
                    }
                        .font(AppTypography.displayFont(size: fontSize))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.25)
                        .allowsTightening(true)
                        .padding(.horizontal, horizontalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("生成原始动机")
                .accessibilityValue(phraseText)
                .accessibilityAction(named: "打开设置") { turnPage(.up) }
            }
        }
    }

    private func generate() {
        phrase = KurioPhraseGenerator.next()
        generation += 1
        if phrase != nil { AppSoundPlayer.shared.play(.page) }
    }

    private func generateManually() {
        autoAdvanceEnabled = false
        generate()
    }

    private struct PlaybackSchedule: Equatable {
        let isRunning: Bool
        let interval: Double
        let generation: Int
    }

    private var playbackSchedule: PlaybackSchedule {
        PlaybackSchedule(
            isRunning: autoAdvanceEnabled && scenePhase == .active && !showingSettings && selectedPage == .phrase && !isTurningPage && phrase != nil,
            interval: (FlowInterval(rawValue: autoAdvanceInterval) ?? .fiveSeconds).rawValue,
            generation: generation
        )
    }

    private func animatedWord(_ word: String, movesUp: Bool) -> some View {
        ZStack {
            Text(word)
                .fixedSize()
                .id(phraseText)
                .transition(reduceMotion ? .identity : .asymmetric(
                    insertion: .move(edge: movesUp ? .bottom : .top).combined(with: .opacity),
                    removal: .move(edge: movesUp ? .top : .bottom).combined(with: .opacity)
                ))
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: phraseText)
    }

    private func fittedFontSize(in size: CGSize, padding: CGFloat) -> CGFloat {
        // Measure the entire phrase so all three words shrink together in narrow Mac windows.
        let preferredSize = min(max(size.width * 0.105, 80), 152)
        let systemFont = UIFont.systemFont(ofSize: preferredSize, weight: .black)
        let descriptor = systemFont.fontDescriptor.withDesign(.rounded) ?? systemFont.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: preferredSize)
        let textWidth = (phraseText as NSString).size(withAttributes: [.font: font]).width
        let widthScale = max(size.width - 2 * padding, 1) / max(textWidth, 1)
        let heightScale = max(size.height - 24, 1) / font.lineHeight
        return preferredSize * min(1, widthScale, heightScale)
    }
}
