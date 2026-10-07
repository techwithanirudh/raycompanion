import SwiftUI

struct StepLayout<Hero: View, Content: View>: View {
    let title: String
    var hint: String?
    @ViewBuilder var hero: Hero
    @ViewBuilder var content: Content

    init(
        title: String,
        hint: String? = nil,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.hint = hint
        self.hero = hero()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            hero.padding(.bottom, 18)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let hint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            content.padding(.top, 20)
        }
    }
}
