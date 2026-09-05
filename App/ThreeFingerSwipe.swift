import SwiftUI
import UIKit

/// Observe three-finger swipes without placing a touch-blocking overlay over the phrase button.
struct ThreeFingerSwipe: UIViewRepresentable {
    let isEnabled: Bool
    let action: (UISwipeGestureRecognizer.Direction) -> Void

    func makeUIView(context: Context) -> SwipeView {
        SwipeView()
    }

    func updateUIView(_ view: SwipeView, context: Context) {
        view.action = action
        view.swipes.forEach { $0.isEnabled = isEnabled }
    }

    static func dismantleUIView(_ view: SwipeView, coordinator: ()) {
        view.detach()
    }

    final class SwipeView: UIView, UIGestureRecognizerDelegate {
        var action: ((UISwipeGestureRecognizer.Direction) -> Void)?
        private weak var observedWindow: UIWindow?
        lazy var swipes: [UISwipeGestureRecognizer] = {
            // Separate recognizers preserve which direction actually triggered the page turn.
            [UISwipeGestureRecognizer.Direction.up, .down, .left, .right].map { direction in
                let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe(_:)))
                recognizer.direction = direction
                recognizer.numberOfTouchesRequired = 3
                recognizer.cancelsTouchesInView = true
                recognizer.delegate = self
                return recognizer
            }
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
            swipes.forEach { observedWindow?.addGestureRecognizer($0) }
        }

        func detach() {
            swipes.forEach { observedWindow?.removeGestureRecognizer($0) }
            observedWindow = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // The settings ScrollView starts panning before a discrete swipe finishes.
            // Let the three-finger swipe complete even when that scroll pan has already begun.
            guard swipes.contains(where: { $0 === gestureRecognizer }),
                  let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }

        @objc private func didSwipe(_ recognizer: UISwipeGestureRecognizer) {
            guard recognizer.state == .recognized else { return }
            action?(recognizer.direction)
        }
    }
}
