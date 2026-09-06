import SwiftUI
import UIKit

struct LetterLine: Identifiable {
    let id: Int
    let text: String
    let image: UIImage
    let height: CGFloat
}

@MainActor
final class LetterDraft: ObservableObject {
    @Published var recipient = ""
    @Published var text = ""
    @Published private(set) var isSending = false
    @Published private(set) var lines: [LetterLine] = []
    @Published private(set) var visibleLineCount = 0
    @Published private(set) var recipientVisible = true
    private var dissolution: Task<Void, Never>?

    func send(lines: [LetterLine]) {
        guard !isSending, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !lines.isEmpty else { return }
        self.lines = lines
        visibleLineCount = lines.count
        recipientVisible = true
        text = ""
        isSending = true
        AppSoundPlayer.shared.play(.send)
        dissolution = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                let step = 0.65
                for remaining in stride(from: lines.count - 1, through: 0, by: -1) {
                    try Task.checkCancellation()
                    visibleLineCount = remaining
                    try await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                }
                try await Task.sleep(nanoseconds: 750_000_000)
                recipientVisible = false
                try await Task.sleep(nanoseconds: 900_000_000)
                recipient = ""
                self.lines = []
                isSending = false
                recipientVisible = true
                dissolution = nil
            } catch {
                return
            }
        }
    }
}

struct LetterView: View {
    @ObservedObject var draft: LetterDraft
    let onEditingChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var recipientFocused: Bool
    @StateObject private var editor = LetterEditorBridge()

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 400
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text("收信人")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    TextField("姓名", text: $draft.recipient)
                        .font(.title3)
                        .textFieldStyle(.plain)
                        .focused($recipientFocused)
                        .submitLabel(.next)
                        .onSubmit { editor.view?.becomeFirstResponder() }
                        .disabled(draft.isSending)
                        .accessibilityLabel("收信人")
                        .opacity(draft.recipientVisible ? 1 : 0)
                        .blur(radius: draft.recipientVisible || reduceMotion ? 0 : 4)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: draft.recipientVisible)
                }
                .padding(.bottom, compact ? 8 : 20)
                Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
                    .accessibilityHidden(true)

                Group {
                    if draft.isSending {
                        dissolvingText
                    } else {
                        LetterTextEditor(text: $draft.text, bridge: editor, onEditingChanged: onEditingChanged)
                            .overlay(alignment: .topLeading) {
                                if draft.text.isEmpty {
                                    Text("文本")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color(white: 0.65))
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                            }
                    }
                }
                .padding(.top, compact ? 8 : 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        let lines = editor.snapshot()
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        recipientFocused = false
                        onEditingChanged(false)
                        draft.send(lines: lines)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(white: 0.8) : .black))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.isSending || draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("发送")
                    .padding(.bottom, compact ? 8 : 16)
                    .padding(.trailing, compact ? 8 : 12)
                }
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, compact ? 24 : 36)
            .padding(.top, compact ? 12 : 36)
            .padding(.bottom, compact ? 16 : 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.black)
            .background(Color.white.ignoresSafeArea())
            .onChange(of: recipientFocused) { onEditingChanged($0) }
            .onDisappear { onEditingChanged(false) }
        }
    }

    private var dissolvingText: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(draft.lines) { line in
                        let visible = line.id < draft.visibleLineCount
                        Image(uiImage: line.image)
                            .frame(height: line.height, alignment: .topLeading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(visible ? 1 : 0)
                            .blur(radius: visible || reduceMotion ? 0 : 6)
                            .offset(x: visible || reduceMotion ? 0 : 18)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.75), value: visible)
                            .accessibilityLabel(line.text)
                            .accessibilityHidden(!visible)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                if let last = draft.lines.last { scroll.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: draft.visibleLineCount) { count in
                guard count > 0 else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                    scroll.scrollTo(count - 1, anchor: .bottom)
                }
            }
        }
    }
}

@MainActor
private final class LetterEditorBridge: ObservableObject {
    weak var view: UITextView?

    func snapshot() -> [LetterLine] {
        guard let view, view.bounds.width > 0 else { return [] }
        view.layoutIfNeeded()
        let layout = view.layoutManager
        layout.ensureLayout(for: view.textContainer)
        var lines: [LetterLine] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { rect, used, _, glyphRange, _ in
            let format = UIGraphicsImageRendererFormat()
            format.scale = view.window?.screen.scale ?? UIScreen.main.scale
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: max(ceil(used.width), 1), height: max(ceil(used.height), 1)), format: format)
            let image = renderer.image { _ in
                layout.drawGlyphs(forGlyphRange: glyphRange, at: CGPoint(x: -used.minX, y: -used.minY))
            }
            let characters = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let text = (view.text as NSString).substring(with: characters)
            lines.append(LetterLine(id: lines.count, text: text, image: image, height: rect.height))
        }
        return lines
    }
}

private struct LetterTextEditor: UIViewRepresentable {
    @Binding var text: String
    let bridge: LetterEditorBridge
    let onEditingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .white
        view.textColor = .black
        view.font = .systemFont(ofSize: 22)
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.keyboardDismissMode = .interactive
        view.contentInsetAdjustmentBehavior = .never
        view.delegate = context.coordinator
        view.accessibilityLabel = "文本"
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
        paragraph.lineSpacing = 6
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 22), .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
        if view.text != text { view.attributedText = NSAttributedString(string: text, attributes: attributes) }
        view.typingAttributes = attributes
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LetterTextEditor
        init(_ parent: LetterTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.onEditingChanged(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onEditingChanged(false) }
        @objc func finishEditing() { parent.bridge.view?.resignFirstResponder() }
    }
}
