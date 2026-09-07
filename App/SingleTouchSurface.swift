import SwiftUI
import UIKit

/// Raw touches allow the window's three-finger navigation to cancel a drawing/hold cleanly.
struct SingleTouchSurface: UIViewRepresentable {
    let isEnabled: Bool
    let began: (CGPoint) -> Void
    let moved: (CGPoint) -> Void
    let ended: () -> Void
    let cancelled: () -> Void

    func makeUIView(context: Context) -> TouchView { TouchView() }
    func updateUIView(_ view: TouchView, context: Context) {
        view.actions = self
        view.isUserInteractionEnabled = isEnabled
    }

    final class TouchView: UIView {
        var actions: SingleTouchSurface?
        private var activeTouch: UITouch?
        private var blocked = false

        init() {
            super.init(frame: .zero)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
            isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            let liveTouches = (event?.allTouches ?? touches).filter { $0.phase != .ended && $0.phase != .cancelled }
            guard !blocked, liveTouches.count == 1, activeTouch == nil, let touch = touches.first else {
                activeTouch = nil
                blocked = true
                actions?.cancelled()
                return
            }
            activeTouch = touch
            actions?.began(touch.location(in: self))
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard !blocked, let touch = activeTouch, touches.contains(touch) else { return }
            actions?.moved(touch.location(in: self))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            if !blocked, let touch = activeTouch, touches.contains(touch) {
                actions?.moved(touch.location(in: self))
                activeTouch = nil
                actions?.ended()
            }
            if event?.allTouches?.allSatisfy({ $0.phase == .ended || $0.phase == .cancelled }) != false {
                blocked = false
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            activeTouch = nil
            blocked = false
            actions?.cancelled()
        }
    }
}
