import Foundation

protocol OverlayRendering {
    func showWithWindowsAndSelection(_ windows: [WorkspaceWindow], selectedIndex: Int)
    func updateSelectedIndex(_ selectedIndex: Int)
    func hide()
}
