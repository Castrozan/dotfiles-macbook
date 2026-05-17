import AppKit

protocol IconProviding {
    func prewarmCacheFromRunningApplications()
    func iconForApplicationName(_ applicationName: String) -> NSImage
}
