import SwiftUI

struct DoneLine: View {
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, SetupTheme.Card.inset)
        .frame(height: 30)
        .background(SetupTheme.Card.fill, in: RoundedRectangle(cornerRadius: SetupTheme.Control.radius))
        .overlay(RoundedRectangle(cornerRadius: SetupTheme.Control.radius).strokeBorder(SetupTheme.Card.stroke))
    }
}
