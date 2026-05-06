import Foundation

struct RedwingEnvironment {
    var now: @Sendable () -> Date = { Date() }

    static let live = RedwingEnvironment()
}
