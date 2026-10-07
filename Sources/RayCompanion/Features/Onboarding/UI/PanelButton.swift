import SwiftUI

struct PanelButton: View {
    let title: String
    var isWaiting = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isWaiting {
                    ProgressView().controlSize(.small).scaleEffect(0.75)
                }
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isWaiting ? Color.secondary : .primary)
        .background {
            RoundedRectangle(cornerRadius: SetupTheme.Control.radius, style: .continuous)
                .fill(SetupTheme.Card.fill.opacity(isWaiting ? 0.5 : 1))
                .overlay {
                    RoundedRectangle(cornerRadius: SetupTheme.Control.radius, style: .continuous)
                        .strokeBorder(SetupTheme.Card.stroke, lineWidth: 1)
                }
                .brightness(isHovering && !isWaiting ? 0.04 : 0)
        }
        .onHover { isHovering = $0 }
        .disabled(isWaiting)
    }
}
