import AppKit
import UniformTypeIdentifiers

enum RunningApplicationIconResolver {
    static func resolveIconFromRunningApplications(applicationName: String) -> NSImage {
        let workspace = NSWorkspace.shared
        for runningApplication in workspace.runningApplications {
            if runningApplication.localizedName == applicationName, let icon = runningApplication.icon {
                return icon
            }
        }
        return workspace.icon(for: UTType.application)
    }
}
