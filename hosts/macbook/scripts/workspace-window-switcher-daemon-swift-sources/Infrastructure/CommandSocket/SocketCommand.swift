import Foundation

enum SocketCommand: Equatable {
    case next
    case prev
    case commit
    case cancel
    case recordExternalFocus(windowIdentifier: Int)
}
