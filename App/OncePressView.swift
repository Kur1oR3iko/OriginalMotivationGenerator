import SwiftUI

struct OncePressView: View {
    @ObservedObject var store: OncePressStore
    let timeZoneIdentifier: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 24) {
                if let record = store.record {
                    let clock = Clock25.reading(at: record.date, timeZone: record.timeZone)
                    VStack(spacing: 24) {
                        Text(L("于%@按下", civilTime(record)))
                            .font(.system(size: min(max(proxy.size.width * 0.032, 20), 36), weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L("或者说是%@ %@", clock.dateText, clock.timeTextWithSeconds))
                            .font(.system(size: min(max(proxy.size.width * 0.019, 15), 23), weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(store.isMomentVisible ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeIn(duration: 1.1), value: store.isMomentVisible)
                } else {
                    Button {
                        if store.press(timeZone: Clock25.timeZone(for: timeZoneIdentifier)) {
                            AppSoundPlayer.shared.play(.click)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Circle().fill(Color.black).frame(width: 108, height: 108)
                    }
                    .buttonStyle(OnceButtonStyle())
                    .accessibilityLabel(L("只能按一次"))
                    .accessibilityHint(L("按下后按钮将永久消失"))
                    if let error = store.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func civilTime(_ record: OncePressStore.Record) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = L10n.locale
        formatter.timeZone = record.timeZone
        formatter.dateFormat = L("yyyy年M月d日HH时mm分ss秒")
        return formatter.string(from: record.date)
    }
}

private struct OnceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .shadow(color: .black.opacity(0.18), radius: configuration.isPressed ? 1 : 3,
                    y: configuration.isPressed ? 1 : 6)
    }
}

struct ArtIntroductionView: View {
    let title: String
    let introduction: String
    var footnote: String? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 56

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(title)
                        .font(.system(size: proxy.size.width >= 900 ? titleSize : titleSize * 0.75,
                                      weight: .black, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(introduction)
                            .font(.title3)
                            .fixedSize(horizontal: false, vertical: true)
                        if let footnote {
                            Text(footnote)
                                .font(.footnote)
                                .foregroundStyle(Color(white: 0.6))
                        }
                    }
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(.horizontal, proxy.size.width >= 900 ? 48 : 28)
                .padding(.top, 36)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
    }
}
