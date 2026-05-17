import Foundation

protocol MruTracking {
    func recordFocusedWindow(_ windowIdentifier: Int)
    func sortWindowsByRecency(_ windows: [WorkspaceWindow]) -> [WorkspaceWindow]
    func removeStaleWindowIdentifiers(currentWindowIdentifiers: Set<Int>)
    var currentlyFocusedWindowIdentifier: Int? { get }
}
