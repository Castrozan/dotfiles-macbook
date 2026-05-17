import Foundation

protocol PerformanceProfiling {
    func beginNewActivation()
    func markPhase(_ phaseName: String)
    func recordWorkspaceWindowCount(_ count: Int)
    func emitActivationReport()
}
