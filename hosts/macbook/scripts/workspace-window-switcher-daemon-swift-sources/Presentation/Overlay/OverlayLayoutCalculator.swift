import CoreGraphics

struct OverlayLayoutDimensions {
    let totalWidth: CGFloat
    let totalHeight: CGFloat
}

enum OverlayLayoutCalculator {
    static func calculateOverlayDimensions(
        cardCount: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        cardSpacing: CGFloat,
        overlayPadding: CGFloat
    ) -> OverlayLayoutDimensions {
        let cardCountFloat = CGFloat(cardCount)
        let totalWidth = overlayPadding * 2
            + cardCountFloat * cardWidth
            + max(0, cardCountFloat - 1) * cardSpacing
        let totalHeight = overlayPadding * 2 + cardHeight
        return OverlayLayoutDimensions(totalWidth: totalWidth, totalHeight: totalHeight)
    }

    static func horizontalOffsetForCard(
        atIndex index: Int,
        cardWidth: CGFloat,
        cardSpacing: CGFloat,
        overlayPadding: CGFloat
    ) -> CGFloat {
        return overlayPadding + CGFloat(index) * (cardWidth + cardSpacing)
    }
}
