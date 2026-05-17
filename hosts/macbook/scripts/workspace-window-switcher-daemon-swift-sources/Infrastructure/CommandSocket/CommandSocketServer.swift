import Foundation

final class CommandSocketServer {
    private let acceptLoop: CommandSocketAcceptLoop

    init(acceptLoop: CommandSocketAcceptLoop) {
        self.acceptLoop = acceptLoop
    }

    func startAcceptingConnectionsOnBackgroundThread() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptLoop.runAcceptLoopUntilTerminated()
        }
    }
}
