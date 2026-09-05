import SwiftUI

enum FlowInterval: Double, CaseIterable, Identifiable {
    case halfSecond = 0.5
    case oneSecond = 1
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .halfSecond: return "0.5秒"
        case .oneSecond: return "1秒"
        case .fiveSeconds: return "5秒"
        case .tenSeconds: return "10秒"
        case .thirtySeconds: return "30秒"
        case .oneMinute: return "1分钟"
        case .fiveMinutes: return "5分钟"
        }
    }
}

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 56
    @Binding var autoAdvanceEnabled: Bool
    @Binding var interval: Double

    var body: some View {
        GeometryReader { proxy in
            let wideLayout = proxy.size.width >= 900

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: wideLayout ? 48 : 32) {
                    Text("kurio最新力作（2）")
                        .font(.system(size: wideLayout ? titleSize : titleSize * 0.75,
                                      weight: .black, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if wideLayout {
                        HStack(alignment: .top, spacing: 64) {
                            introduction
                                .frame(maxWidth: .infinity, alignment: .leading)
                            playbackControls
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        introduction
                        playbackControls
                    }

                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(.horizontal, wideLayout ? 48 : 28)
                .padding(.top, 36)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("原始动机生成器")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("这是Kurio的原始动机生成器，每次点击都会从词库中随机拼接成一组全新短语。一共有11390625种可能性。每条短语只会出现一次（如果你设置为一秒一组连续播放，那么大约能连续播放131天），所以点击的时候希望不要太快，以免错过什么。")
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(Color(white: 0.35))
                .fixedSize(horizontal: false, vertical: true)
            Text("注意：原始动机短语不涉及任何具体操作")
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playbackControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle(isOn: $autoAdvanceEnabled) {
                Text("时间的流速")
                    .font(.title2.bold())
            }
            .toggleStyle(.switch)
            .tint(.black)

            Text("切换间隔")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 20)],
                      alignment: .leading, spacing: 12) {
                ForEach(FlowInterval.allCases) { option in
                    intervalButton(option)
                }
            }

            Text("开启后，按所选节奏自动切换。\n点击短语生成下一条，并停止自动切换。查看设置或离开应用时暂停。")
                .font(.subheadline)
                .lineSpacing(5)
                .foregroundStyle(Color(white: 0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func intervalButton(_ option: FlowInterval) -> some View {
        let selected = interval == option.rawValue
        return Button {
            interval = option.rawValue
        } label: {
            HStack(spacing: 8) {
                Text(option.title)
                    .font(.system(.title3, design: .rounded).weight(selected ? .bold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(selected ? Color.black : Color(white: 0.45))
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: selected)
    }
}
