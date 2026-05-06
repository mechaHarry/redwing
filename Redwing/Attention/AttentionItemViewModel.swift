import Foundation

struct AttentionItemViewModel: Identifiable, Equatable {
    let id: String
    let spaceID: String
    let spaceTitle: String
    let sender: String
    let body: String
    let created: Date?
    let reason: String
}
