import XCTest
@testable import Redwing

final class FakeWebexClientProvidingTests: XCTestCase {
    func testConcurrentMessageStreamsForSameSpaceShareCachedStream() async throws {
        let fake = FakeWebexClientProviding()

        let streams = try await withThrowingTaskGroup(of: MessagesThreadStreamProviding.self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    try await fake.makeMessagesThreadStream(spaceID: "space-1")
                }
            }

            var streams: [MessagesThreadStreamProviding] = []
            for try await stream in group {
                streams.append(stream)
            }
            return streams
        }

        let streamIDs = Set(streams.map { ObjectIdentifier($0) })
        XCTAssertEqual(streamIDs.count, 1)
        XCTAssertEqual(fake.messagesStreamsBySpaceID.count, 1)
    }
}
