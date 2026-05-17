import Foundation

final class SocketCommandMainThreadDispatcher {
    private let commandHandler: SocketCommandHandling

    init(commandHandler: SocketCommandHandling) {
        self.commandHandler = commandHandler
    }

    func dispatchOnMainThread(_ command: SocketCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.executeCommandOnMainThread(command)
        }
    }

    private func executeCommandOnMainThread(_ command: SocketCommand) {
        switch command {
        case .next:
            commandHandler.handleNextCommand()
        case .prev:
            commandHandler.handlePrevCommand()
        case .commit:
            commandHandler.handleCommitCommand()
        case .cancel:
            commandHandler.handleCancelCommand()
        case .recordExternalFocus(let windowIdentifier):
            commandHandler.recordExternallyFocusedWindow(windowIdentifier)
        }
    }
}
