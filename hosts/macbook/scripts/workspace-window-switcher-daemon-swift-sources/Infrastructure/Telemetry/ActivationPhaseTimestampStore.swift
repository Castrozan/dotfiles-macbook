import Foundation

struct ActivationPhaseTimestampSnapshot {
    let timestampsByPhaseName: [String: MonotonicTimestamp]
    let workspaceWindowCount: Int
}

final class ActivationPhaseTimestampStore {
    private let lock = NSLock()
    private var timestampsByPhaseName: [String: MonotonicTimestamp] = [:]
    private var workspaceWindowCount: Int = 0

    func resetForNewActivation() {
        lock.lock()
        timestampsByPhaseName = [:]
        workspaceWindowCount = 0
        timestampsByPhaseName["begin"] = MonotonicTimestampSource.now()
        lock.unlock()
    }

    func recordPhaseTimestampIfActivationStarted(_ phaseName: String) {
        lock.lock()
        if timestampsByPhaseName["begin"] != nil {
            timestampsByPhaseName[phaseName] = MonotonicTimestampSource.now()
        }
        lock.unlock()
    }

    func setWorkspaceWindowCount(_ count: Int) {
        lock.lock()
        workspaceWindowCount = count
        lock.unlock()
    }

    func snapshotAndReset() -> ActivationPhaseTimestampSnapshot {
        lock.lock()
        let snapshot = ActivationPhaseTimestampSnapshot(
            timestampsByPhaseName: timestampsByPhaseName,
            workspaceWindowCount: workspaceWindowCount
        )
        timestampsByPhaseName = [:]
        workspaceWindowCount = 0
        lock.unlock()
        return snapshot
    }
}
