import Foundation

protocol WindowProviding {
    func getFocusedWorkspaceWindows() -> [WorkspaceWindow]
    func getFocusedWindowIdentifier() -> Int?
}
