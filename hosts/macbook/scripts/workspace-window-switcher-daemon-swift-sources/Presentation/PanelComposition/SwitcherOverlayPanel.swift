import AppKit

final class SwitcherOverlayPanel: OverlayRendering {
    private let cardViewFactory: WindowCardViewFactory
    private let selectionStyler: CardSelectionStyler
    private let overlayLifecycleObserver: OverlayLifecycleObserving
    private let cardWidth: CGFloat
    private let cardHeight: CGFloat
    private let cardSpacing: CGFloat
    private let overlayPadding: CGFloat
    private let overlayCornerRadius: CGFloat

    private var floatingPanel: NonActivatingFloatingPanel?
    private var backgroundContainerView: NSView?
    private var cardViewsByDisplayIndex: [WindowCardViews] = []

    init(
        cardViewFactory: WindowCardViewFactory,
        selectionStyler: CardSelectionStyler,
        overlayLifecycleObserver: OverlayLifecycleObserving,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        cardSpacing: CGFloat,
        overlayPadding: CGFloat,
        overlayCornerRadius: CGFloat
    ) {
        self.cardViewFactory = cardViewFactory
        self.selectionStyler = selectionStyler
        self.overlayLifecycleObserver = overlayLifecycleObserver
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.cardSpacing = cardSpacing
        self.overlayPadding = overlayPadding
        self.overlayCornerRadius = overlayCornerRadius
    }

    func showWithWindowsAndSelection(_ windows: [WorkspaceWindow], selectedIndex: Int) {
        let panel = NonActivatingFloatingPanelFactory.makeFloatingPanel()
        floatingPanel = panel
        buildOverlayContents(windows: windows, selectedIndex: selectedIndex, panel: panel)
        PanelScreenCentering.centerOnMainScreen(panel)
        overlayLifecycleObserver.overlayBuildCompleted()
        panel.orderFrontRegardless()
        overlayLifecycleObserver.overlayDidBecomeVisible()
    }

    func updateSelectedIndex(_ selectedIndex: Int) {
        for (cardIndex, cardViews) in cardViewsByDisplayIndex.enumerated() {
            selectionStyler.applyStyle(toCardViews: cardViews, isSelected: cardIndex == selectedIndex)
        }
    }

    func hide() {
        if let panel = floatingPanel {
            panel.orderOut(nil)
            panel.close()
        }
        floatingPanel = nil
        backgroundContainerView = nil
        cardViewsByDisplayIndex = []
    }

    private func buildOverlayContents(
        windows: [WorkspaceWindow],
        selectedIndex: Int,
        panel: NonActivatingFloatingPanel
    ) {
        let dimensions = OverlayLayoutCalculator.calculateOverlayDimensions(
            cardCount: windows.count,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            cardSpacing: cardSpacing,
            overlayPadding: overlayPadding
        )
        panel.setFrame(
            NSRect(x: 0, y: 0, width: dimensions.totalWidth, height: dimensions.totalHeight),
            display: false
        )

        let backgroundView = BackgroundContainerViewFactory.makeBackgroundContainerView(
            width: dimensions.totalWidth,
            height: dimensions.totalHeight,
            cornerRadius: overlayCornerRadius
        )
        panel.contentView?.addSubview(backgroundView)
        backgroundContainerView = backgroundView

        for (windowIndex, window) in windows.enumerated() {
            let horizontalOffset = OverlayLayoutCalculator.horizontalOffsetForCard(
                atIndex: windowIndex,
                cardWidth: cardWidth,
                cardSpacing: cardSpacing,
                overlayPadding: overlayPadding
            )
            let cardViews = cardViewFactory.makeCard(
                forWindow: window,
                horizontalOffset: horizontalOffset,
                verticalOffset: overlayPadding
            )
            selectionStyler.applyStyle(toCardViews: cardViews, isSelected: windowIndex == selectedIndex)
            backgroundView.addSubview(cardViews.cardView)
            cardViewsByDisplayIndex.append(cardViews)
        }
    }
}
