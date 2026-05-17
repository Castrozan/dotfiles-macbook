import Darwin
import Foundation

enum UnixSocketAddressBuilder {
    static func buildSocketAddress(forPath path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytesWithNullTerminator = path.utf8CString
        if pathBytesWithNullTerminator.count > MemoryLayout.size(ofValue: address.sun_path) {
            return nil
        }
        withUnsafeMutablePointer(to: &address.sun_path) { sunPathPointer in
            sunPathPointer.withMemoryRebound(
                to: CChar.self,
                capacity: pathBytesWithNullTerminator.count
            ) { typedDestinationPointer in
                pathBytesWithNullTerminator.withUnsafeBufferPointer { sourceBufferPointer in
                    typedDestinationPointer.update(
                        from: sourceBufferPointer.baseAddress!,
                        count: pathBytesWithNullTerminator.count
                    )
                }
            }
        }
        return address
    }
}
