import SwiftUI
import UIKit
import Combine

@main
struct OriginalMotivationGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            KeyboardNavigationHost()
                .preferredColorScheme(.light)
        }
    }
}

private struct KeyboardNavigationHost: UIViewControllerRepresentable {
    @Environment(\.scenePhase) private var scenePhase

    func makeUIViewController(context: Context) -> NavigationHostingController {
        NavigationHostingController(scenePhase: scenePhase)
    }

    func updateUIViewController(_ controller: NavigationHostingController, context: Context) {
        controller.updateScenePhase(scenePhase)
    }
}

private final class NavigationHostingController: UIHostingController<ContentView> {
    private let keyboardEvents: PassthroughSubject<UISwipeGestureRecognizer.Direction, Never>

    init(scenePhase: ScenePhase) {
        let events = PassthroughSubject<UISwipeGestureRecognizer.Direction, Never>()
        keyboardEvents = events
        super.init(rootView: ContentView(keyboardEvents: events, scenePhase: scenePhase))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    func updateScenePhase(_ scenePhase: ScenePhase) {
        guard rootView.scenePhase != scenePhase else { return }
        rootView = ContentView(keyboardEvents: keyboardEvents, scenePhase: scenePhase)
    }

    private lazy var navigationCommands: [UIKeyCommand] = {
        [UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow,
         UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow].map { input in
            let command = UIKeyCommand(input: input, modifierFlags: [], action: #selector(navigate(_:)))
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }()

    override var keyCommands: [UIKeyCommand]? {
        let inherited = super.keyCommands ?? []
        return isEditingText ? inherited : inherited + navigationCommands
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(navigate(_:)) { return !isEditingText }
        return super.canPerformAction(action, withSender: sender)
    }

    private var isEditingText: Bool {
        func containsTextResponder(_ view: UIView) -> Bool {
            if view.isFirstResponder && view is UITextInput { return true }
            return view.subviews.contains(where: containsTextResponder)
        }
        return containsTextResponder(view)
    }

    @objc private func navigate(_ command: UIKeyCommand) {
        guard !isEditingText else { return }
        switch command.input {
        case UIKeyCommand.inputLeftArrow: keyboardEvents.send(.left)
        case UIKeyCommand.inputRightArrow: keyboardEvents.send(.right)
        case UIKeyCommand.inputUpArrow: keyboardEvents.send(.up)
        case UIKeyCommand.inputDownArrow: keyboardEvents.send(.down)
        default: break
        }
    }
}
