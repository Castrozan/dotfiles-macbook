import Darwin
import Foundation

final class AeroSpaceIpcClient {
    private let socketPathResolver: AeroSpaceSocketPathResolver
    private let connectionTimeoutSeconds: Int

    init(socketPathResolver: AeroSpaceSocketPathResolver, connectionTimeoutSeconds: Int) {
        self.socketPathResolver = socketPathResolver
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
    }

    func sendRequestAndReadResponse(_ requestData: Data) -> Data? {
        guard let socketPath = socketPathResolver.resolveSocketPath() else { return nil }
        guard let descriptor = UnixSocketConnector.connectStreamSocket(
            toPath: socketPath,
            timeoutSeconds: connectionTimeoutSeconds
        ) else {
            socketPathResolver.invalidateCachedSocketPath()
            return nil
        }
        defer { Darwin.close(descriptor) }

        if !writeAllRequestBytes(requestData, toDescriptor: descriptor) {
            socketPathResolver.invalidateCachedSocketPath()
            return nil
        }
        _ = Darwin.shutdown(descriptor, SHUT_WR)
        return readUntilPeerCloses(descriptor: descriptor)
    }

    private func writeAllRequestBytes(_ requestData: Data, toDescriptor descriptor: Int32) -> Bool {
        let bytesWritten = requestData.withUnsafeBytes { rawBufferPointer -> Int in
            return Darwin.send(descriptor, rawBufferPointer.baseAddress, rawBufferPointer.count, 0)
        }
        return bytesWritten == requestData.count
    }

    private func readUntilPeerCloses(descriptor: Int32) -> Data {
        var responseData = Data()
        var readBuffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = readBuffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
                return Darwin.recv(descriptor, bufferPointer.baseAddress, bufferPointer.count, 0)
            }
            if bytesRead <= 0 { break }
            responseData.append(readBuffer, count: bytesRead)
        }
        return responseData
    }
}
