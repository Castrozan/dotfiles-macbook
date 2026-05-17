import Foundation

final class ActivationPerformanceProfiler: PerformanceProfiling {
    private let timestampStore: ActivationPhaseTimestampStore
    private let logFileAppender: PerformanceLogFileAppender

    init(timestampStore: ActivationPhaseTimestampStore, logFileAppender: PerformanceLogFileAppender) {
        self.timestampStore = timestampStore
        self.logFileAppender = logFileAppender
    }

    func beginNewActivation() {
        timestampStore.resetForNewActivation()
    }

    func markPhase(_ phaseName: String) {
        timestampStore.recordPhaseTimestampIfActivationStarted(phaseName)
    }

    func recordWorkspaceWindowCount(_ count: Int) {
        timestampStore.setWorkspaceWindowCount(count)
    }

    func emitActivationReport() {
        let snapshot = timestampStore.snapshotAndReset()
        guard let reportLine = PerformanceReportFormatter.formatReportLine(snapshot: snapshot) else {
            return
        }
        logFileAppender.appendLine(reportLine)
    }
}
