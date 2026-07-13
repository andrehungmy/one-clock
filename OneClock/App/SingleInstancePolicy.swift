import Foundation

struct AppInstanceIdentity: Equatable {
    let processIdentifier: pid_t
    let launchDate: Date?
}

enum SingleInstancePolicy {
    static func primaryProcessIdentifier(in instances: [AppInstanceIdentity]) -> pid_t? {
        instances.min(by: launchedBefore)?.processIdentifier
    }

    private static func launchedBefore(_ lhs: AppInstanceIdentity, _ rhs: AppInstanceIdentity) -> Bool {
        switch (lhs.launchDate, rhs.launchDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            lhsDate < rhsDate
        case (_?, nil):
            true
        case (nil, _?):
            false
        default:
            lhs.processIdentifier < rhs.processIdentifier
        }
    }
}
