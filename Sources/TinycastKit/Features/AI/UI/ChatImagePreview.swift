import AppKit
import SwiftUI

struct ChatImagePreview: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var resetID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") { resetID = UUID() }
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(12)
            Divider()
            ImageZoom(image: image)
                .id(resetID)
        }
        .background(PopupEscapeHandler(onClose: onClose))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
        .shadow(radius: 16, y: 5)
    }
}

private struct ImageZoom: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> ImageScrollView {
        let view = ImageScrollView()
        view.imageView.image = image
        return view
    }

    func updateNSView(_ view: ImageScrollView, context: Context) {
        view.imageView.image = image
    }
}

private final class ImageScrollView: NSScrollView {
    let imageView = NSImageView()
    private var viewportSize = NSSize.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        scrollerStyle = .overlay
        allowsMagnification = true
        minMagnification = 1
        maxMagnification = 5
        imageView.imageScaling = .scaleProportionallyUpOrDown
        documentView = imageView
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleClick.numberOfClicksRequired = 2
        imageView.addGestureRecognizer(doubleClick)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let size = contentSize
        guard size.width > 0, size.height > 0, size != viewportSize else { return }
        viewportSize = size
        magnification = 1
        imageView.frame = NSRect(origin: .zero, size: size)
    }

    @objc private func toggleZoom(_ gesture: NSClickGestureRecognizer) {
        setMagnification(magnification > 1 ? 1 : 2, centeredAt: gesture.location(in: imageView))
    }
}

private struct PopupEscapeHandler: NSViewRepresentable {
    let onClose: () -> Void

    @MainActor final class Coordinator {
        var monitor: Any?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            if event.keyCode == 53, event.window === view?.window {
                onClose()
                return nil
            }
            return event
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }
}
