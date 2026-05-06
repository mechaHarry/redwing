import Foundation

extension AsyncStream {
    func mapped<MappedElement: Sendable>(
        _ transform: @escaping @Sendable (Element) -> MappedElement
    ) -> AsyncStream<MappedElement> {
        AsyncStream<MappedElement> { continuation in
            let task = Task {
                for await element in self {
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    continuation.yield(transform(element))
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
