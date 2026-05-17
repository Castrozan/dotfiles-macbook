import AppKit

enum PanelScreenCentering {
    static func centerOnMainScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let panelFrame = panel.frame
        let centeredX = (screenFrame.size.width - panelFrame.size.width) / 2
        let centeredY = (screenFrame.size.height - panelFrame.size.height) / 2
        panel.setFrameOrigin(NSPoint(x: centeredX, y: centeredY))
    }
}
