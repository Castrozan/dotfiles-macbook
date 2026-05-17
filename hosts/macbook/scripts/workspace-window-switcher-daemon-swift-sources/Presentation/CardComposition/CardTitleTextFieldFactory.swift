import AppKit

enum CardTitleTextFieldFactory {
    static func makeTitleTextField(
        windowTitle: String,
        cardWidth: CGFloat,
        horizontalInset: CGFloat,
        bottomOffset: CGFloat,
        height: CGFloat
    ) -> NSTextField {
        let titleFrame = NSRect(
            x: horizontalInset,
            y: bottomOffset,
            width: cardWidth - horizontalInset * 2,
            height: height
        )
        let textField = NSTextField(frame: titleFrame)
        textField.stringValue = windowTitle
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.alignment = .center
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 2
        return textField
    }
}
