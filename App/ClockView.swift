import SwiftUI

struct ClockView: View {
    let showsDate: Bool
    let showsSeconds: Bool
    let timeZoneIdentifier: String
    let isActive: Bool

    var body: some View {
        Group {
            if isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    face(at: context.date)
                        .onChange(of: Int(context.date.timeIntervalSince1970)) { _ in
                            AppSoundPlayer.shared.play(.tick)
                        }
                }
            } else {
                face(at: .now)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onChange(of: isActive) { active in
            if !active { AppSoundPlayer.shared.stop(.tick) }
        }
        .onDisappear { AppSoundPlayer.shared.stop(.tick) }
    }

    private func face(at date: Date) -> some View {
        let reading = Clock25.reading(at: date, timeZone: Clock25.timeZone(for: timeZoneIdentifier))
        return GeometryReader { proxy in
            let size = min(proxy.size.width * (showsSeconds ? 0.155 : 0.23), proxy.size.height * (showsDate ? 0.42 : 0.60), 260)
            VStack(spacing: max(size * 0.07, 12)) {
                Text(showsSeconds ? reading.timeTextWithSeconds : reading.timeText)
                    .font(AppTypography.clockFont(size: size))
                    .tracking(size * 0.02)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .accessibilityLabel("25小时时钟，\(reading.hour)点\(reading.minute)分" + (showsSeconds ? "\(reading.second)秒" : ""))
                if showsDate {
                    Text(reading.dateText)
                        .font(AppTypography.clockFont(size: max(min(size * 0.16, 36), 16)))
                        .tracking(0.5)
                        .foregroundStyle(Color(white: 0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
