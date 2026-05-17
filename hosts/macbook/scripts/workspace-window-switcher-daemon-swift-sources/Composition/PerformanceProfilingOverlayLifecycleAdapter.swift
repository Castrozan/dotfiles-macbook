import Foundation

final class PerformanceProfilingOverlayLifecycleAdapter: OverlayLifecycleObserving {
    private let performanceProfiler: PerformanceProfiling

    init(performanceProfiler: PerformanceProfiling) {
        self.performanceProfiler = performanceProfiler
    }

    func overlayBuildCompleted() {
        performanceProfiler.markPhase("overlay_build_done")
    }

    func overlayDidBecomeVisible() {
        performanceProfiler.markPhase("overlay_visible")
    }
}
