import AppKit

enum BackgroundContainerViewFactory {
    static func makeBackgroundContainerView(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> NSView {
        let frame = NSRect(x: 0, y: 0, width: width, height: height)
        let visualEffectView = NSVisualEffectView(frame: frame)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        return visualEffectView
    }
}
