import Darwin
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
        case .next: commandHandler.handleNextCommand()
        case .prev: commandHandler.handlePrevCommand()
        case .commit: commandHandler.handleCommitCommand()
        case .cancel: commandHandler.handleCancelCommand()
        case .recordExternalFocus(let windowIdentifier):
            commandHandler.recordExternallyFocusedWindow(windowIdentifier)
        }
    }
}

final class CommandSocketServer {
    private let socketPath: String
    private let listenBacklog: Int32
    private let socketFileMode: mode_t
    private let clientReadBufferSize: Int
    private let clientReadTimeoutMicroseconds: Int32
    private let onCommandReceived: (String) -> Void

    init(
        socketPath: String,
        listenBacklog: Int32,
        socketFileMode: mode_t,
        clientReadBufferSize: Int,
        clientReadTimeoutMicroseconds: Int32,
        onCommandReceived: @escaping (String) -> Void
    ) {
        self.socketPath = socketPath
        self.listenBacklog = listenBacklog
        self.socketFileMode = socketFileMode
        self.clientReadBufferSize = clientReadBufferSize
        self.clientReadTimeoutMicroseconds = clientReadTimeoutMicroseconds
        self.onCommandReceived = onCommandReceived
    }

    func startAcceptingConnectionsOnBackgroundThread() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runAcceptLoopUntilTerminated()
        }
    }

    private func runAcceptLoopUntilTerminated() {
        guard let serverDescriptor = UnixSocketBinder.bindAndListenStreamSocket(
            atPath: socketPath,
            listenBacklog: listenBacklog,
            fileMode: socketFileMode
        ) else { return }

        while true {
            let clientDescriptor = Darwin.accept(serverDescriptor, nil, nil)
            if clientDescriptor < 0 { continue }
            configureClientReceiveTimeout(clientDescriptor: clientDescriptor)
            readAndForwardClientCommand(clientDescriptor: clientDescriptor)
        }
    }

    private func configureClientReceiveTimeout(clientDescriptor: Int32) {
        var clientReceiveTimeout = timeval(tv_sec: 0, tv_usec: clientReadTimeoutMicroseconds)
        let timevalLength = socklen_t(MemoryLayout<timeval>.size)
        _ = Darwin.setsockopt(clientDescriptor, SOL_SOCKET, SO_RCVTIMEO, &clientReceiveTimeout, timevalLength)
    }

    private func readAndForwardClientCommand(clientDescriptor: Int32) {
        var readBuffer = [UInt8](repeating: 0, count: clientReadBufferSize)
        let bytesRead = readBuffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
            return Darwin.recv(clientDescriptor, bufferPointer.baseAddress, bufferPointer.count, 0)
        }
        Darwin.close(clientDescriptor)
        if bytesRead <= 0 { return }
        let receivedData = Data(readBuffer.prefix(bytesRead))
        guard let receivedString = String(data: receivedData, encoding: .utf8) else { return }
        let trimmedCommand = receivedString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCommand.isEmpty { return }
        onCommandReceived(trimmedCommand)
    }
}
