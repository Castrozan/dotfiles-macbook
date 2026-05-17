import AppKit

final class ApplicationIconProvider: IconProviding {
    private let iconCache: ApplicationIconCache

    init(iconCache: ApplicationIconCache) {
        self.iconCache = iconCache
    }

    func prewarmCacheFromRunningApplications() {
        let workspace = NSWorkspace.shared
        for runningApplication in workspace.runningApplications {
            guard let applicationName = runningApplication.localizedName else { continue }
            if iconCache.containsIcon(forApplicationName: applicationName) { continue }
            if let icon = runningApplication.icon {
                iconCache.storeIcon(icon, forApplicationName: applicationName)
            }
        }
    }

    func iconForApplicationName(_ applicationName: String) -> NSImage {
        if let cachedIcon = iconCache.cachedIcon(forApplicationName: applicationName) {
            return cachedIcon
        }
        let resolvedIcon = RunningApplicationIconResolver.resolveIconFromRunningApplications(
            applicationName: applicationName
        )
        iconCache.storeIcon(resolvedIcon, forApplicationName: applicationName)
        return resolvedIcon
    }
}
