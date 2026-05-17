import Foundation

enum PerformanceReportFormatter {
    static let phaseNamesInReportOrder: [String] = [
        "worker_started",
        "ipc_workspace_done",
        "ipc_focus_done",
        "main_callback",
        "mru_sort_done",
        "overlay_build_done",
        "overlay_visible",
    ]

    static func formatReportLine(snapshot: ActivationPhaseTimestampSnapshot) -> String? {
        guard let baselineTimestamp = snapshot.timestampsByPhaseName["begin"] else { return nil }
        var lineParts: [String] = ["windows=\(snapshot.workspaceWindowCount)"]
        for phaseName in phaseNamesInReportOrder {
            if let phaseTimestamp = snapshot.timestampsByPhaseName[phaseName] {
                let milliseconds = phaseTimestamp.millisecondsSince(baselineTimestamp)
                lineParts.append("\(phaseName)=\(String(format: "%.3f", milliseconds))")
            }
        }
        return lineParts.joined(separator: " ") + "\n"
    }
}
