import Foundation

enum AeroSpaceIpcRequestEncoder {
    static func encodeRequest(arguments: [String]) -> Data? {
        let requestObject: [String: Any] = [
            "args": arguments,
            "stdin": "",
            "windowId": NSNull(),
            "workspace": NSNull(),
        ]
        return try? JSONSerialization.data(withJSONObject: requestObject)
    }
}
