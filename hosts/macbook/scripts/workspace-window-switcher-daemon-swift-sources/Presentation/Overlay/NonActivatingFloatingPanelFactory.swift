import AppKit

enum NonActivatingFloatingPanelFactory {
    static func makeFloatingPanel() -> NonActivatingFloatingPanel {
        let initialContentFrame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = NonActivatingFloatingPanel(
            contentRect: initialContentFrame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.alphaValue = 1.0
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        return panel
    }
}
