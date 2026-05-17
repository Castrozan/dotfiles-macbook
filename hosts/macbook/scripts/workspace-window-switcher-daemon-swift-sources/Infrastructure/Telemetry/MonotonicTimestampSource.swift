import Foundation

struct MonotonicTimestamp {
    let nanoseconds: UInt64

    func millisecondsSince(_ baseline: MonotonicTimestamp) -> Double {
        return Double(nanoseconds &- baseline.nanoseconds) / 1_000_000.0
    }
}

enum MonotonicTimestampSource {
    static func now() -> MonotonicTimestamp {
        return MonotonicTimestamp(nanoseconds: DispatchTime.now().uptimeNanoseconds)
    }
}
