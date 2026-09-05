import SwiftUI
import UIKit

/// Observe three-finger swipes without placing a touch-blocking overlay over the phrase button.
struct ThreeFingerSwipe: UIViewRepresentable {
    let isEnabled: Bool
    let direction: UISwipeGestureRecognizer.Direction
    let action: () -> Void

    func makeUIView(context: Context) -> SwipeView {
        SwipeView()
    }

    func updateUIView(_ view: SwipeView, context: Context) {
        view.action = action
        view.swipe.direction = direction
        view.swipe.isEnabled = isEnabled
    }

    static func dismantleUIView(_ view: SwipeView, coordinator: ()) {
        view.detach()
    }

    final class SwipeView: UIView, UIGestureRecognizerDelegate {
        var action: (() -> Void)?
        private weak var observedWindow: UIWindow?
        lazy var swipe: UISwipeGestureRecognizer = {
            let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            recognizer.direction = .down
            recognizer.numberOfTouchesRequired = 3
            recognizer.cancelsTouchesInView = true
            recognizer.delegate = self
            return recognizer
        }()

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            observedWindow = window
            observedWindow?.addGestureRecognizer(swipe)
        }

        func detach() {
            observedWindow?.removeGestureRecognizer(swipe)
            observedWindow = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // The settings ScrollView starts panning before a discrete swipe finishes.
            // Let the three-finger swipe complete even when that scroll pan has already begun.
            guard gestureRecognizer === swipe,
                  let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }

        @objc private func didSwipe() {
            guard swipe.state == .recognized else { return }
            action?()
        }
    }
}
