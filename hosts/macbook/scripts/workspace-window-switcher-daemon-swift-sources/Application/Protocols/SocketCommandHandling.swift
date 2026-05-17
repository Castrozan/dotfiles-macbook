import Foundation

protocol SocketCommandHandling {
    func handleNextCommand()
    func handlePrevCommand()
    func handleCommitCommand()
    func handleCancelCommand()
    func recordExternallyFocusedWindow(_ windowIdentifier: Int)
}
