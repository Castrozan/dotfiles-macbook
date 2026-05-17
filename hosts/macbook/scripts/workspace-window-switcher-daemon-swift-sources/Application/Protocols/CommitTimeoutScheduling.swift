import Foundation

protocol CommitTimeoutScheduling {
    func scheduleCommitTimeout(afterSeconds seconds: TimeInterval, onTimeout: @escaping () -> Void)
    func cancelCommitTimeout()
}
