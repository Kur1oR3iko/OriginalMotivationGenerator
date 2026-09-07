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
            ScrollView {
                Group {
                    switch store.stage {
                    case .age:
                        ageQuestion
                    case .expectancy:
                        expectancyQuestion(height: geometry.size.height)
                    case .result:
                        if let profile = store.profile {
                            if isActive {
                                TimelineView(.periodic(from: .now, by: 60)) { context in
                                    result(profile, now: context.date)
                                }
                            } else {
                                result(profile, now: .now)
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

    private var ageQuestion: some View {
        VStack(spacing: 28) {
            Text("您今年多少岁了")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                TextField("年龄", text: $store.ageText)
                    .font(.system(size: 48, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($editingAge)
                    .submitLabel(.continue)
                    .onSubmit(confirmAge)
                    .frame(width: 180)
                    .accessibilityLabel("当前年龄")
                Text("岁").font(.title2).foregroundStyle(.secondary)
            }
            if !store.ageText.isEmpty && store.age == nil {
                Text("请输入0至8000之间的整数年龄")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("继续", action: confirmAge)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 88, minHeight: 44)
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

    private func expectancyQuestion(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text("您的预期寿命是？")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            LifespanWheel(value: $store.expectancy)
                .frame(width: 260, height: min(216, max(110, height * 0.4)))
                .clipped()
            Button("确定") {
                store.confirmExpectancy(reduceMotion: reduceMotion)
            }
            .font(.title3.weight(.semibold))
            .frame(minWidth: 88, minHeight: 44)
            .buttonStyle(.plain)
            .disabled(store.isTransitioning)
        }
    }

    @ViewBuilder
    private func result(_ profile: DeathClock.Profile, now: Date) -> some View {
        switch profile.outcome {
        case .ghost:
            VStack(spacing: 18) {
                Text("欢迎你，鬼魂先生/女生")
                    .font(.system(size: 38, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("享受接下来额外的人生吧")
                    .font(.title3)
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .ancient:
            Text("想不到能在这里遇见你，大蝽。")
                .font(.system(size: 38, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        case .countdown:
            let remaining = DeathClock.remaining(for: profile, at: now, southernHemisphere: southernHemisphere)
            VStack(spacing: 18) {
                Text("您的一生还剩下：").font(.title2.weight(.medium))
                Text("\(String(remaining.days))天")
                    .font(.system(size: 76, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .monospacedDigit()
                Text("在这段时间你还可以：").font(.title2.weight(.medium))
                HStack(alignment: .top, spacing: 95) {
                    VStack(alignment: .leading, spacing: 12) {
                        activity("度过", remaining.weekends, "个周末")
                        activity("吃", remaining.breakfasts, "顿早餐")
                        activity("回", remaining.homecomings, "次老家")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        activity("享受", remaining.summers, "个夏天")
                        activity("读", remaining.books, "本书")
                        Text("与那个人再见一定的次数")
                            .font(.title3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func activity(_ verb: String, _ count: Int, _ unit: String) -> some View {
        (Text(verb) + Text(String(count)).fontWeight(.semibold) + Text(unit))
            .font(.title3)
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
        picker.accessibilityLabel = "预期寿命，1至8000岁"
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
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { "\(row + 1)岁" }
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
                    Text("死之钟")
                        .font(.system(size: geometry.size.width >= 900 ? titleSize : titleSize * 0.75, weight: .black, design: .rounded))
                    Text("关于活着的其他一些想法")
                        .font(.title3)
                    Toggle("按南半球计算夏天", isOn: $southernHemisphere)
                        .font(.title2.weight(.medium))
                        .toggleStyle(.switch)
                    Button("重新考虑我的生命", action: onRestart)
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
