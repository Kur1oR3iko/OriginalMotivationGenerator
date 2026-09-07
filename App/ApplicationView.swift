import SwiftUI
import UIKit

struct ApplicationView: View {
    @ObservedObject var store: ApplicationStore
    let isActive: Bool
    let onEditingChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var applicantFocused: Bool
    @StateObject private var editor = ApplicationEditorBridge()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.ignoresSafeArea()
                switch store.stage {
                case .editing:
                    form(in: geometry.size)
                        .transition(.opacity)
                case .waiting, .approved:
                    decision(in: geometry.size)
                        .transition(.opacity)
                case .entered:
                    Color.white
                        .accessibilityLabel("申请已通过，你已进入一张空白页面")
                }
            }
        }
        .foregroundStyle(.black)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: store.stage)
        .onChange(of: applicantFocused) { onEditingChanged($0) }
        .onChange(of: isActive) { active in
            if !active { finishEditing() }
        }
        .task(id: reviewSchedule) {
            guard isActive, store.stage == .waiting, let deadline = store.approvalDate else { return }
            let remaining = max(0, deadline.timeIntervalSinceNow)
            do {
                try await Task.sleep(nanoseconds: UInt64(min(remaining, 5) * 1_000_000_000))
                try Task.checkCancellation()
                store.advance()
            } catch { return }
        }
    }

    private struct ReviewSchedule: Equatable {
        let active: Bool
        let stage: ApplicationStore.Stage
        let deadline: Date?
    }

    private var reviewSchedule: ReviewSchedule {
        ReviewSchedule(active: isActive, stage: store.stage, deadline: store.approvalDate)
    }

    private func form(in size: CGSize) -> some View {
        let wide = size.width >= 900
        let compact = size.height < 400
        return HStack(alignment: .bottom, spacing: wide ? 56 : 28) {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 16 : 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("申请表")
                                .font(AppTypography.displayFont(size: wide ? 60 : 38))
                                .accessibilityAddTraits(.isHeader)
                            Text("进入一张空白页面")
                                .font(.system(size: wide ? 22 : 18))
                        }
                        .padding(.bottom, compact ? 0 : 8)
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("申请人")
                            TextField("你的名字", text: $store.applicant)
                                .font(.system(size: wide ? 24 : 20))
                                .textFieldStyle(.plain)
                                .focused($applicantFocused)
                                .submitLabel(.next)
                                .onSubmit { editor.view?.becomeFirstResponder() }
                                .frame(minHeight: 36)
                                .accessibilityLabel("申请人")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("申请理由")
                            ApplicationTextEditor(text: $store.reason, bridge: editor, fontSize: wide ? 24 : 20) { editing in
                                onEditingChanged(editing)
                                if editing {
                                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                                        scroll.scrollTo("reason", anchor: .bottom)
                                    }
                                }
                            }
                            .frame(height: wide ? 150 : 82)
                            .overlay(alignment: .topLeading) {
                                if store.reason.isEmpty {
                                    Text("为什么想要进去")
                                        .font(.system(size: wide ? 24 : 20))
                                        .foregroundStyle(Color(white: 0.7))
                                        .padding(.top, 6)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .id("reason")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 0)
                Button {
                    finishEditing()
                    if store.submit() { AppSoundPlayer.shared.play(.send) }
                } label: {
                    HStack {
                        Text("提交")
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: wide ? 20 : 17, weight: .medium))
                    .foregroundStyle(store.canSubmit ? .white : Color(white: 0.65))
                    .padding(.horizontal, wide ? 22 : 16)
                    .frame(height: wide ? 64 : 52)
                    .background(store.canSubmit ? .black : Color(white: 0.95))
                }
                .buttonStyle(.plain)
                .disabled(!store.canSubmit)
                .accessibilityLabel("提交申请")
            }
            .frame(width: wide ? 174 : 114)
        }
        .frame(maxWidth: 1000)
        .padding(.horizontal, wide ? 60 : 28)
        .padding(.vertical, compact ? 18 : 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(Color(white: 0.5))
    }

    private func decision(in size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("进入一张空白页面")
                .font(.body).foregroundStyle(.secondary)
            Text(store.stage == .waiting ? "申请已收到" : "申请已通过")
                .font(AppTypography.displayFont(size: size.width >= 900 ? 60 : 38))
                .id(store.stage)
                .transition(.opacity)
                .accessibilityAddTraits(.isHeader)
            if store.stage == .waiting {
                Text("请稍候。")
                    .font(.title3).foregroundStyle(.secondary)
                    .frame(height: 52)
            } else {
                Button { store.enter() } label: {
                    HStack(spacing: 28) {
                        Text("进入")
                        Image(systemName: "arrow.right")
                    }
                    .font(.title3.weight(.medium))
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 780, alignment: .leading)
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func finishEditing() {
        applicantFocused = false
        editor.view?.resignFirstResponder()
        onEditingChanged(false)
    }
}

struct ApplicationSettingsView: View {
    let startAgain: () -> Void

    var body: some View {
        ArtSettingsLayout(title: "申请", introduction: "进入一片空白，也需要被允许吗。") {
            Button("重新申请", action: startAgain)
                .font(.title2.weight(.medium))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
    }
}

@MainActor
private final class ApplicationEditorBridge: ObservableObject {
    weak var view: UITextView?
}

private struct ApplicationTextEditor: UIViewRepresentable {
    @Binding var text: String
    let bridge: ApplicationEditorBridge
    let fontSize: CGFloat
    let onEditingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .white
        view.textColor = .black
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        view.keyboardDismissMode = .interactive
        view.contentInsetAdjustmentBehavior = .never
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.accessibilityLabel = "申请理由"
        let toolbar = UIToolbar()
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                         UIBarButtonItem(title: "完成", style: .done, target: context.coordinator, action: #selector(Coordinator.finishEditing))]
        toolbar.sizeToFit()
        view.inputAccessoryView = toolbar
        bridge.view = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        bridge.view = view
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize), .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
        if view.text != text { view.attributedText = NSAttributedString(string: text, attributes: attributes) }
        view.font = .systemFont(ofSize: fontSize)
        view.typingAttributes = attributes
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ApplicationTextEditor
        init(_ parent: ApplicationTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.onEditingChanged(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onEditingChanged(false) }
        @objc func finishEditing() { parent.bridge.view?.resignFirstResponder() }
    }
}
