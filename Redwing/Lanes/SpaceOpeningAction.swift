@MainActor
struct SpaceOpeningAction {
    let selectSpace: (String) -> Void
    let selectMessages: (String, String) -> Void

    func callAsFunction(_ row: SpaceRowViewModel) {
        selectSpace(row.id)
        selectMessages(row.id, row.title)
    }
}
