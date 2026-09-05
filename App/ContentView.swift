import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("originalMotivationGenerator.v1.autoAdvanceEnabled") private var autoAdvanceEnabled = false
    @AppStorage("originalMotivationGenerator.v1.autoAdvanceInterval") private var autoAdvanceInterval = 5.0
    @State private var phrase = KurioPhraseGenerator.lastPhrase ?? KurioPhraseGenerator.next()
    @State private var showingSettings = false
    @State private var generation = 0

    private var phraseText: String { phrase?.text ?? "全部组合已生成完毕" }

    var body: some View {
        ZStack {
            if showingSettings {
                SettingsView(autoAdvanceEnabled: $autoAdvanceEnabled, interval: $autoAdvanceInterval) {
                    showingSettings = false
                }
                .transition(reduceMotion ? .identity : .move(edge: .top))
            } else {
                phrasePage
                    .transition(reduceMotion ? .identity : .move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color.white.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: showingSettings)
        .background(ThreeFingerSwipe(
            isEnabled: scenePhase == .active,
            direction: showingSettings ? .up : .down
        ) { showingSettings.toggle() })
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
                        .font(.system(size: fontSize, weight: .black, design: .rounded))
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
                .accessibilityAction(named: "打开设置") { showingSettings = true }
            }
        }
        .overlay(alignment: .topTrailing) {
            if ProcessInfo.processInfo.isiOSAppOnMac {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("打开设置")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func generate() {
        phrase = KurioPhraseGenerator.next()
        generation += 1
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
            isRunning: autoAdvanceEnabled && scenePhase == .active && !showingSettings && phrase != nil,
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
