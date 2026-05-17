import AppKit

enum CardIconImageViewFactory {
    static func makeIconImageView(
        image: NSImage,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        iconSize: CGFloat,
        topPadding: CGFloat
    ) -> NSImageView {
        let horizontalOffset = (cardWidth - iconSize) / 2
        let verticalOffset = cardHeight - iconSize - topPadding
        let imageView = NSImageView(frame: NSRect(
            x: horizontalOffset,
            y: verticalOffset,
            width: iconSize,
            height: iconSize
        ))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }
}
