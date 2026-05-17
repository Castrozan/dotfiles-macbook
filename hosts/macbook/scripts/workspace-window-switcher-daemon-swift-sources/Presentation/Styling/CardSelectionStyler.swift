import AppKit

final class CardSelectionStyler {
    private let titleFontSize: CGFloat

    init(titleFontSize: CGFloat) {
        self.titleFontSize = titleFontSize
    }

    func applyStyle(toCardViews cardViews: WindowCardViews, isSelected: Bool) {
        applyBackgroundColor(toCardView: cardViews.cardView, isSelected: isSelected)
        applyBorderColor(toBorderView: cardViews.borderView, isSelected: isSelected)
        applyTitleStyle(toCardView: cardViews.cardView, isSelected: isSelected)
    }

    private func applyBackgroundColor(toCardView cardView: NSView, isSelected: Bool) {
        if isSelected {
            cardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        } else {
            cardView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        }
    }

    private func applyBorderColor(toBorderView borderView: NSView, isSelected: Bool) {
        if isSelected {
            borderView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        } else {
            borderView.layer?.borderColor = NSColor.clear.cgColor
        }
    }

    private func applyTitleStyle(toCardView cardView: NSView, isSelected: Bool) {
        let textAlpha: CGFloat = isSelected ? 1.0 : 0.6
        let fontWeight: NSFont.Weight = isSelected ? .medium : .regular
        for subview in cardView.subviews {
            if let textField = subview as? NSTextField {
                textField.textColor = NSColor.white.withAlphaComponent(textAlpha)
                textField.font = NSFont.systemFont(ofSize: titleFontSize, weight: fontWeight)
            }
        }
    }
}
