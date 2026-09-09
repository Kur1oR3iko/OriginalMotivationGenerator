import SwiftUI
import UIKit

struct DeathClockView: View {
    @ObservedObject var store: DeathClockStore
    let southernHemisphere: Bool
    let isActive: Bool
    let onEditingChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var editingAge: Bool

    var body: some View {
        GeometryReader { geometry in
            let largeLayout = geometry.size.width >= 900 && geometry.size.height >= 500
            ScrollView {
                Group {
                    switch store.stage {
                    case .age:
                        ageQuestion(largeLayout: largeLayout)
                    case .expectancy:
                        expectancyQuestion(height: geometry.size.height, largeLayout: largeLayout)
                    case .result:
                        if let profile = store.profile {
                            if isActive {
                                TimelineView(.periodic(from: .now, by: 60)) { context in
                                    result(profile, now: context.date, largeLayout: largeLayout)
                                }
                            } else {
                                result(profile, now: .now, largeLayout: largeLayout)
                            }
                        }
                    }
                }
                .frame(maxWidth: 1040)
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .opacity(store.contentVisible ? 1 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.contentVisible)
                .allowsHitTesting(!store.isTransitioning)
            }
        }
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
        .background(Color.white.ignoresSafeArea())
        .onChange(of: editingAge) { onEditingChanged($0) }
        .onChange(of: store.stage) { _ in editingAge = false }
        .onDisappear { onEditingChanged(false) }
    }

    private func ageQuestion(largeLayout: Bool) -> some View {
        VStack(spacing: largeLayout ? 38 : 28) {
            Text(L("您今年多少岁了"))
                .font(.system(size: largeLayout ? 48 : 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                TextField(L("年龄"), text: $store.ageText)
                    .font(.system(size: largeLayout ? 68 : 48, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($editingAge)
                    .submitLabel(.continue)
                    .onSubmit(confirmAge)
                    .frame(width: largeLayout ? 240 : 180)
                    .accessibilityLabel(L("当前年龄"))
                Text(L("岁"))
                    .font(.system(size: largeLayout ? 30 : 22, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            if !store.ageText.isEmpty && store.age == nil {
                Text(L("请输入0至8000之间的整数年龄"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button(L("继续"), action: confirmAge)
                .font(.system(size: largeLayout ? 27 : 20, weight: .semibold))
                .frame(minWidth: largeLayout ? 120 : 88, minHeight: largeLayout ? 56 : 44)
                .buttonStyle(.plain)
                .disabled(store.age == nil || store.isTransitioning)
                .opacity(store.age == nil ? 0.3 : 1)
        }
    }

    private func confirmAge() {
        editingAge = false
        onEditingChanged(false)
        store.confirmAge(reduceMotion: reduceMotion)
    }

    private func expectancyQuestion(height: CGFloat, largeLayout: Bool) -> some View {
        VStack(spacing: largeLayout ? 22 : 16) {
            Text(L("您的预期寿命是？"))
                .font(.system(size: largeLayout ? 48 : 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            LifespanWheel(value: $store.expectancy)
                .frame(width: largeLayout ? 360 : 260,
                       height: min(largeLayout ? 300 : 216, max(110, height * (largeLayout ? 0.46 : 0.4))))
                .clipped()
            Button(L("确定")) {
                store.confirmExpectancy(reduceMotion: reduceMotion)
            }
            .font(.system(size: largeLayout ? 27 : 20, weight: .semibold))
            .frame(minWidth: largeLayout ? 120 : 88, minHeight: largeLayout ? 56 : 44)
            .buttonStyle(.plain)
            .disabled(store.isTransitioning)
        }
    }

    @ViewBuilder
    private func result(_ profile: DeathClock.Profile, now: Date, largeLayout: Bool) -> some View {
        switch profile.outcome {
        case .ghost:
            VStack(spacing: largeLayout ? 26 : 18) {
                Text(L("欢迎你，鬼魂先生/女生"))
                    .font(.system(size: largeLayout ? 54 : 38, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("享受接下来额外的人生吧"))
                    .font(.system(size: largeLayout ? 28 : 20))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .ancient:
            Text(L("想不到能在这里遇见你，大蝽。"))
                .font(.system(size: largeLayout ? 54 : 38, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        case .countdown:
            let remaining = DeathClock.remaining(for: profile, at: now, southernHemisphere: southernHemisphere)
            VStack(spacing: largeLayout ? 28 : 18) {
                Text(L("您的一生还剩下："))
                    .font(.system(size: largeLayout ? 31 : 22, weight: .medium))
                Text(L("%ld天", remaining.days))
                    .font(.system(size: largeLayout ? 112 : 76, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .monospacedDigit()
                Text(L("在这段时间你还可以："))
                    .font(.system(size: largeLayout ? 31 : 22, weight: .medium))
                HStack(alignment: .top, spacing: largeLayout ? 140 : 95) {
                    VStack(alignment: .leading, spacing: largeLayout ? 18 : 12) {
                        activity(L("度过%ld个周末", remaining.weekends), largeLayout: largeLayout)
                        activity(L("吃%ld顿早餐", remaining.breakfasts), largeLayout: largeLayout)
                        activity(L("回%ld次老家", remaining.homecomings), largeLayout: largeLayout)
                    }
                    VStack(alignment: .leading, spacing: largeLayout ? 18 : 12) {
                        activity(L("享受%ld个夏天", remaining.summers), largeLayout: largeLayout)
                        activity(L("读%ld本书", remaining.books), largeLayout: largeLayout)
                        Text(L("与那个人再见一定的次数"))
                            .font(.system(size: largeLayout ? 28 : 20))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func activity(_ text: String, largeLayout: Bool) -> some View {
        Text(text)
            .font(.system(size: largeLayout ? 28 : 20))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .multilineTextAlignment(.leading)
    }
}

/// UIPickerView recycles rows instead of instantiating 8,000 SwiftUI labels.
private struct LifespanWheel: UIViewRepresentable {
    @Binding var value: Int

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.accessibilityLabel = L("预期寿命，1至8000岁")
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        if picker.selectedRow(inComponent: 0) != value - 1 {
            picker.selectRow(value - 1, inComponent: 0, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: LifespanWheel
        init(_ parent: LifespanWheel) { self.parent = parent }
        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { 8000 }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 44 }
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { L("%ld岁", row + 1) }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) { parent.value = row + 1 }
    }
}

struct DeathClockSettingsView: View {
    @Binding var southernHemisphere: Bool
    let onRestart: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 56

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(L("死之钟"))
                        .font(.system(size: geometry.size.width >= 900 ? titleSize : titleSize * 0.75, weight: .black, design: .rounded))
                    Text(L("关于活着的其他一些想法"))
                        .font(.title3)
                    Toggle(L("按南半球计算夏天"), isOn: $southernHemisphere)
                        .font(.title2.weight(.medium))
                        .toggleStyle(.switch)
                    Button(L("重新考虑我的生命"), action: onRestart)
                        .font(.title2.weight(.medium))
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.black)
        .tint(.black)
        .background(Color.white.ignoresSafeArea())
    }

}
