@MainActor
struct SpaceOpeningAction {
    let selectSpace: (String) -> Void
    let selectMessages: (String, String) async -> Void

    func callAsFunction(_ row: SpaceRowViewModel) async {
        selectSpace(row.id)
        await selectMessages(row.id, row.title)
    }
}
