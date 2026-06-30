import Foundation

private final class StreamTerminationState: @unchecked Sendable {
    private let lock = NSLock()
    private var terminated = false

    var isTerminated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminated
    }

    func markTerminated() {
        lock.lock()
        terminated = true
        lock.unlock()
    }
}

final class StreamProbe<Value: Sendable>: Sendable {
    let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation
    private let terminationState: StreamTerminationState

    var isTerminated: Bool {
        terminationState.isTerminated
    }

    init() {
        let streamPair = AsyncStream<Value>.makeStream(of: Value.self)
        let terminationState = StreamTerminationState()
        streamPair.continuation.onTermination = { _ in
            terminationState.markTerminated()
        }
        self.stream = streamPair.stream
        self.continuation = streamPair.continuation
        self.terminationState = terminationState
    }

    func yield(_ value: Value) {
        continuation.yield(value)
    }

    func finish() {
        continuation.finish()
    }
}
