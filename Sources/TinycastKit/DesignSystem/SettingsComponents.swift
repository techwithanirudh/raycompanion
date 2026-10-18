import AppKit
import SwiftUI

// The few pieces more than one Settings pane or editor needs; everything else stays feature-owned.

/// The Settings sidebar tile, shared with the matching feature switches.
struct SettingsTabIcon: View {
    let systemImage: String
    let tint: Color
    var size = Theme.Size.settingsSidebarGlyph + Theme.Spacing.xs * 2

    var body: some View {
        let scale = size / (Theme.Size.settingsSidebarGlyph + Theme.Spacing.xs * 2)
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .frame(
                width: Theme.Size.settingsSidebarGlyph * scale,
                height: Theme.Size.settingsSidebarGlyph * scale
            )
            .foregroundStyle(tint)
            .padding(Theme.Spacing.xs * scale)
            .background(
                tint.opacity(0.1),
                in: RoundedRectangle(
                    cornerRadius: Theme.Radius.thumbnail * scale, style: .continuous))
    }
}

struct SettingsFeatureToggleLabel: View {
    let anchor: SettingsAnchor
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            SettingsTabIcon(
                systemImage: anchor.tab.systemImage, tint: .accentColor,
                size: Theme.Size.settingsRowIcon * 1.5)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                SettingsRowTitle(anchor, title)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Not `LabeledContent`: its selectable text field eats the taps a `ShortcutRecorder` needs.
struct SettingsRow<Icon: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    var subtitleLineLimit = 1
    var alignment: VerticalAlignment = .center
    var labelOpacity = 1.0
    /// Set when a search result points at this row, so its title can carry the pulse.
    var anchor: SettingsAnchor?
    @ViewBuilder var icon: Icon
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: alignment, spacing: Theme.Spacing.lg) {
            icon.opacity(labelOpacity)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Group {
                    if let anchor {
                        SettingsRowTitle(anchor, title)
                    } else {
                        Text(title)
                    }
                }
                .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(subtitleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .truncationMode(.middle)
                        .help(subtitle)
                }
            }
            .opacity(labelOpacity)
            Spacer(minLength: Theme.Spacing.lg)
            trailing
        }
    }
}

enum SettingsListMetrics {
    static let iconSize = Theme.Size.settingsRowIcon + Theme.Spacing.xs
}

extension SettingsRow where Icon == EmptyView {
    init(
        title: String, subtitle: String? = nil, subtitleLineLimit: Int = 1,
        alignment: VerticalAlignment = .center,
        labelOpacity: Double = 1, anchor: SettingsAnchor? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: title, subtitle: subtitle, subtitleLineLimit: subtitleLineLimit,
            alignment: alignment, labelOpacity: labelOpacity,
            anchor: anchor, icon: { EmptyView() },
            trailing: trailing)
    }
}

extension View {
    /// Dims as well as disables; `.disabled` alone leaves the title at full strength.
    func settingsEnabled(_ isEnabled: Bool) -> some View {
        disabled(!isEnabled).opacity(isEnabled ? 1 : 0.45)
    }

    func settingsEditorTextField() -> some View {
        modifier(SettingsEditorTextField())
    }

    func settingsEditorTextArea(height: CGFloat) -> some View {
        modifier(SettingsEditorTextArea(height: height))
    }

    /// `controlsOnGlass: false` draws the glass behind, so a control keeps its accent colour.
    func settingsEditorPanelSurface(controlsOnGlass: Bool = true) -> some View {
        modifier(SettingsEditorPanelSurface(controlsOnGlass: controlsOnGlass))
    }
}

struct SettingsEditorHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.panelTitle)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsEditorField<Content: View>: View {
    let title: String
    var labelFont: Font?
    @ViewBuilder var content: Content

    init(
        _ title: String, labelFont: Font? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.labelFont = labelFont
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.lg) {
            Text(title).font(labelFont)
            Spacer(minLength: Theme.Spacing.lg)
            content
                .labelsHidden()
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct SettingsEditorTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(height: Theme.Size.dialogButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .fill(Theme.Colors.controlSurface))
    }
}

private struct SettingsEditorTextArea: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .padding(Theme.Spacing.sm)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .fill(Theme.Colors.controlSurface))
    }
}

private struct SettingsEditorPanelSurface: ViewModifier {
    let controlsOnGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
        // In front of the glass: a glass fill is hit-testable and would hide a handle behind it.
        let draggable = content.background(WindowDragBackground())
        if controlsOnGlass {
            draggable
                .background(Theme.Colors.panelScrim, in: shape)
                .glassEffect(.regular, in: shape)
        } else {
            draggable.background {
                shape.fill(Theme.Colors.panelScrim).glassEffect(.regular, in: shape)
            }
        }
    }
}

/// The filter row above a long list, shaped like a search field rather than a form text field.
struct SettingsFilterField: View {
    let prompt: String
    @Binding var query: String
    /// The plain field has no bezel: without this only the glyphs are a target.
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            // `prompt:` + `labelsHidden`, or the form makes the placeholder a left-column heading.
            TextField("", text: $query, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($focused)
                .pointerStyle(.horizontalText)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }
}
