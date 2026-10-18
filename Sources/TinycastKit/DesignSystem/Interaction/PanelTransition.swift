import AppKit
import SwiftUI

// How every borderless surface arrives and leaves, so a dialog and a HUD read alike.

extension NSWindow {
    /// Fades the whole window, shadow included; `order` runs while still invisible.
    func fadeIn(duration: TimeInterval, order: () -> Void) {
        alphaValue = 0
        order()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        } completionHandler: { [weak self] in
            // AppKit runs the handler on the main thread; the parameter just isn't typed for it.
            MainActor.assumeIsolated {
                // The shadow is cached from the frame it was first drawn at, scaled down.
                self?.invalidateShadow()
            }
        }
    }

    /// Safe to interrupt — the handler checks opacity — and `done` runs once it is off screen.
    func fadeOut(duration: TimeInterval, done: (@MainActor () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.alphaValue == 0 else { return }
                self.orderOut(nil)
                done?()
            }
        }
    }

    /// Snaps back to full opacity, replacing any running fade on the same key path.
    func cancelFade() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            animator().alphaValue = 1
        }
    }
}

