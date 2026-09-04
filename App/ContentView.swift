import SwiftUI

struct ContentView: View {
    @State private var phrase = KurioPhraseGenerator.lastPhrase ?? KurioPhraseGenerator.next() ?? ""

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { proxy in
                let fontSize = min(max(proxy.size.width * 0.105, 80), 152)
                let horizontalPadding = max(proxy.size.width * 0.04, 24)

                Button(action: generate) {
                    Text(phrase)
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
                .accessibilityLabel("生成原始动机")
                .accessibilityValue(phrase)
            }
        }
    }

    private func generate() {
        phrase = KurioPhraseGenerator.next() ?? "全部组合已生成完毕"
    }
}
