import Darwin
import Foundation

enum UnixSocketBinder {
    static func bindAndListenStreamSocket(
        atPath path: String,
        listenBacklog: Int32,
        fileMode: mode_t
    ) -> Int32? {
        try? FileManager.default.removeItem(atPath: path)

        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        if descriptor < 0 { return nil }

        guard var address = UnixSocketAddressBuilder.buildSocketAddress(forPath: path) else {
            Darwin.close(descriptor)
            return nil
        }
        let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &address) { addressPointer -> Int32 in
            return addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                return Darwin.bind(descriptor, sockaddrPointer, addressLength)
            }
        }
        if bindResult < 0 {
            Darwin.close(descriptor)
            return nil
        }
        path.withCString { pathCString in
            _ = Darwin.chmod(pathCString, fileMode)
        }
        if Darwin.listen(descriptor, listenBacklog) < 0 {
            Darwin.close(descriptor)
            return nil
        }
        return descriptor
    }
}
