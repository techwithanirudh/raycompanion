import SwiftUI

/// One inline field. `id` keys its focus and value, so two fields may share a title.
struct InlineArgument: Equatable {
    let id: String
    let title: String
    /// Non-empty makes the field chosen from the palette's menu rather than typed.
    var options: [String] = []
    /// Never marked as owed: leaving it empty is an answer.
    var isOptional = false
}

