import AppKit

final class ApplicationIconCache {
    private var iconCacheByApplicationName: [String: NSImage] = [:]

    func cachedIcon(forApplicationName applicationName: String) -> NSImage? {
        return iconCacheByApplicationName[applicationName]
    }

    func storeIcon(_ icon: NSImage, forApplicationName applicationName: String) {
        iconCacheByApplicationName[applicationName] = icon
    }

    func containsIcon(forApplicationName applicationName: String) -> Bool {
        return iconCacheByApplicationName[applicationName] != nil
    }
}
