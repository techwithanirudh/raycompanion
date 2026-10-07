import Foundation

struct SnippetEditRequest: Identifiable {
    let id = UUID()
    let record: StoredSnippet?
}
