import Foundation

enum DaemonStartupSequence {
    static func removeStaleActivationFlagFile(atPath path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
