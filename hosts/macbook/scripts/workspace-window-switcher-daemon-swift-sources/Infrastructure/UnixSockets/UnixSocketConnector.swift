import Darwin
import Foundation

enum UnixSocketConnector {
    static func connectStreamSocket(toPath path: String, timeoutSeconds: Int) -> Int32? {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        if descriptor < 0 { return nil }

        var sendReceiveTimeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        let timevalLength = socklen_t(MemoryLayout<timeval>.size)
        _ = Darwin.setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &sendReceiveTimeout, timevalLength)
        _ = Darwin.setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &sendReceiveTimeout, timevalLength)

        guard var address = UnixSocketAddressBuilder.buildSocketAddress(forPath: path) else {
            Darwin.close(descriptor)
            return nil
        }
        let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &address) { addressPointer -> Int32 in
            return addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                return Darwin.connect(descriptor, sockaddrPointer, addressLength)
            }
        }
        if connectResult < 0 {
            Darwin.close(descriptor)
            return nil
        }
        return descriptor
    }
}
