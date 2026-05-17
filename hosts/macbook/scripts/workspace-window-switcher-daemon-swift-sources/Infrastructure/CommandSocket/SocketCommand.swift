import Foundation

enum SocketCommand {
    case next
    case prev
    case commit
    case cancel
    case recordExternalFocus(windowIdentifier: Int)
}
