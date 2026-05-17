import Foundation

final class AeroSpaceSocketPathResolver {
    private var cachedSocketPath: String?

    func resolveSocketPath() -> String? {
        if cachedSocketPath == nil {
            cachedSocketPath = findSocketPathOnDisk()
        }
        return cachedSocketPath
    }

    func invalidateCachedSocketPath() {
        cachedSocketPath = nil
    }

    private func findSocketPathOnDisk() -> String? {
        let username = ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
        let expectedSocketPath = "/tmp/bobko.aerospace-\(username).sock"
        if FileManager.default.fileExists(atPath: expectedSocketPath) {
            return expectedSocketPath
        }
        guard let directoryEntries = try? FileManager.default.contentsOfDirectory(atPath: "/tmp") else {
            return nil
        }
        let matchingFileName = directoryEntries.first { fileName in
            fileName.hasPrefix("bobko.aerospace-") && fileName.hasSuffix(".sock")
        }
        guard let matchedFileName = matchingFileName else { return nil }
        return "/tmp/\(matchedFileName)"
    }
}
