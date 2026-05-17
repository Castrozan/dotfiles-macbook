import AppKit

enum CardBorderOverlayFactory {
    static func makeBorderOverlay(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        borderWidth: CGFloat
    ) -> NSView {
        let borderView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        borderView.wantsLayer = true
        borderView.layer?.cornerRadius = cornerRadius
        borderView.layer?.borderWidth = borderWidth
        return borderView
    }
}
