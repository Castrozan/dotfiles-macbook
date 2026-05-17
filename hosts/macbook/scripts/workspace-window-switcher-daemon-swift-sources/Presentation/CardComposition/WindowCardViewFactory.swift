import AppKit

struct WindowCardViews {
    let cardView: NSView
    let borderView: NSView
}

final class WindowCardViewFactory {
    private let iconProvider: IconProviding
    private let cardWidth: CGFloat
    private let cardHeight: CGFloat
    private let cardIconSize: CGFloat
    private let cardCornerRadius: CGFloat
    private let selectionBorderWidth: CGFloat
    private let cardIconTopPadding: CGFloat
    private let cardTitleHorizontalInset: CGFloat
    private let cardTitleBottomOffset: CGFloat
    private let cardTitleHeight: CGFloat

    init(
        iconProvider: IconProviding,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        cardIconSize: CGFloat,
        cardCornerRadius: CGFloat,
        selectionBorderWidth: CGFloat,
        cardIconTopPadding: CGFloat,
        cardTitleHorizontalInset: CGFloat,
        cardTitleBottomOffset: CGFloat,
        cardTitleHeight: CGFloat
    ) {
        self.iconProvider = iconProvider
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.cardIconSize = cardIconSize
        self.cardCornerRadius = cardCornerRadius
        self.selectionBorderWidth = selectionBorderWidth
        self.cardIconTopPadding = cardIconTopPadding
        self.cardTitleHorizontalInset = cardTitleHorizontalInset
        self.cardTitleBottomOffset = cardTitleBottomOffset
        self.cardTitleHeight = cardTitleHeight
    }

    func makeCard(
        forWindow window: WorkspaceWindow,
        horizontalOffset: CGFloat,
        verticalOffset: CGFloat
    ) -> WindowCardViews {
        let cardFrame = NSRect(x: horizontalOffset, y: verticalOffset, width: cardWidth, height: cardHeight)
        let cardView = NSView(frame: cardFrame)
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = cardCornerRadius

        let borderView = CardBorderOverlayFactory.makeBorderOverlay(
            width: cardWidth,
            height: cardHeight,
            cornerRadius: cardCornerRadius,
            borderWidth: selectionBorderWidth
        )
        cardView.addSubview(borderView)

        let icon = iconProvider.iconForApplicationName(window.applicationName)
        let iconImageView = CardIconImageViewFactory.makeIconImageView(
            image: icon,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            iconSize: cardIconSize,
            topPadding: cardIconTopPadding
        )
        cardView.addSubview(iconImageView)

        let titleTextField = CardTitleTextFieldFactory.makeTitleTextField(
            windowTitle: window.title,
            cardWidth: cardWidth,
            horizontalInset: cardTitleHorizontalInset,
            bottomOffset: cardTitleBottomOffset,
            height: cardTitleHeight
        )
        cardView.addSubview(titleTextField)

        return WindowCardViews(cardView: cardView, borderView: borderView)
    }
}
