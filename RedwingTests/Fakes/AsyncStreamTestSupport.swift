import Foundation

final class StreamProbe<Value: Sendable>: Sendable {
    let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation

    init() {
        let streamPair = AsyncStream<Value>.makeStream(of: Value.self)
        self.stream = streamPair.stream
        self.continuation = streamPair.continuation
    }

    func yield(_ value: Value) {
        continuation.yield(value)
    }

    func finish() {
        continuation.finish()
    }
}
