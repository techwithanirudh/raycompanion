import SwiftUI

/// `Theme`'s palette geometry at the user's Interface Size; `.standard` is `Theme` verbatim.
struct InterfaceMetrics: Equatable, Sendable {
    static let standard = InterfaceMetrics(scale: 1)

    let scale: CGFloat

    var spacing: Spacing { Spacing(scale: scale) }
    var radius: Radius { Radius(scale: scale) }
    var size: Size { Size(scale: scale) }
    var typography: Typography { Typography(scale: scale) }

    /// For a tuned length a surface owns itself, where `Theme` states no token for it.
    func scaled(_ value: CGFloat) -> CGFloat { scaledPoints(value, scale) }

    struct Spacing: Equatable, Sendable {
        let scale: CGFloat

        var xxs: CGFloat { scaledPoints(Theme.Spacing.xxs, scale) }
        var xs: CGFloat { scaledPoints(Theme.Spacing.xs, scale) }
        var sm: CGFloat { scaledPoints(Theme.Spacing.sm, scale) }
        var md: CGFloat { scaledPoints(Theme.Spacing.md, scale) }
        var lg: CGFloat { scaledPoints(Theme.Spacing.lg, scale) }
        var xl: CGFloat { scaledPoints(Theme.Spacing.xl, scale) }
        var dialogInset: CGFloat { scaledPoints(Theme.Spacing.dialogInset, scale) }
        var xxl: CGFloat { scaledPoints(Theme.Spacing.xxl, scale) }
        var sectionHeaderBottom: CGFloat { scaledPoints(Theme.Spacing.sectionHeaderBottom, scale) }
        var sectionSpacing: CGFloat { scaledPoints(Theme.Spacing.sectionSpacing, scale) }
        var chatTranscriptBottom: CGFloat { scaledPoints(Theme.Spacing.chatTranscriptBottom, scale) }
        var chatFollowTailSlack: CGFloat { scaledPoints(Theme.Spacing.chatFollowTailSlack, scale) }
        var chatLine: CGFloat { scaledPoints(Theme.Spacing.chatLine, scale) }
    }

    struct Radius: Equatable, Sendable {
        let scale: CGFloat

        var panel: CGFloat { scaledPoints(Theme.Radius.panel, scale) }
        var row: CGFloat { scaledPoints(Theme.Radius.row, scale) }
        var menu: CGFloat { scaledPoints(Theme.Radius.menu, scale) }
        var menuRow: CGFloat { scaledPoints(Theme.Radius.menuRow, scale) }
        var barControl: CGFloat { scaledPoints(Theme.Radius.barControl, scale) }
        var menuPanel: CGFloat { scaledPoints(Theme.Radius.menuPanel, scale) }
        var dialogSymbol: CGFloat { scaledPoints(Theme.Radius.dialogSymbol, scale) }
        var thumbnail: CGFloat { scaledPoints(Theme.Radius.thumbnail, scale) }
        var attachmentChip: CGFloat { scaledPoints(Theme.Radius.attachmentChip, scale) }
        var keyCap: CGFloat { scaledPoints(Theme.Radius.keyCap, scale) }
        var tooltip: CGFloat { scaledPoints(Theme.Radius.tooltip, scale) }
    }

    struct Size: Equatable, Sendable {
        let scale: CGFloat

        var panelWidth: CGFloat { scaledPoints(Theme.Size.panelWidth, scale) }
        var panelHeight: CGFloat { scaledPoints(Theme.Size.panelHeight, scale) }
        var headerHeight: CGFloat { scaledPoints(Theme.Size.headerHeight, scale) }
        var headerIconSlot: CGFloat { scaledPoints(Theme.Size.headerIconSlot, scale) }
        var searchFieldMinWidth: CGFloat { scaledPoints(Theme.Size.searchFieldMinWidth, scale) }
        var headerPadding: CGFloat { scaledPoints(Theme.Size.headerPadding, scale) }
        /// Derived, not scaled: the compact bar must stay exactly the header in symmetric slack.
        var compactHeight: CGFloat { headerHeight + headerPadding * 2 }
        var bottomBarHeight: CGFloat { scaledPoints(Theme.Size.bottomBarHeight, scale) }
        var barButtonHeight: CGFloat { scaledPoints(Theme.Size.barButtonHeight, scale) }
        var rowIcon: CGFloat { scaledPoints(Theme.Size.rowIcon, scale) }
        var resultRowIcon: CGFloat { scaledPoints(Theme.Size.resultRowIcon, scale) }
        var keyCap: CGFloat { scaledPoints(Theme.Size.keyCap, scale) }
        var compactKeyCap: CGFloat { scaledPoints(Theme.Size.compactKeyCap, scale) }
        var heroKeyCap: CGFloat { scaledPoints(Theme.Size.heroKeyCap, scale) }
        var menuButton: CGFloat { scaledPoints(Theme.Size.menuButton, scale) }

        var menuWidth: CGFloat { scaledPoints(Theme.Size.menuWidth, scale) }
        var actionMenuWidth: CGFloat { scaledPoints(Theme.Size.actionMenuWidth, scale) }
        var clipboardFilterMenuWidth: CGFloat { scaledPoints(Theme.Size.clipboardFilterMenuWidth, scale) }
        var fileSearchFilterMenuWidth: CGFloat { scaledPoints(Theme.Size.fileSearchFilterMenuWidth, scale) }
        var menuIcon: CGFloat { scaledPoints(Theme.Size.menuIcon, scale) }
        var menuBrandIcon: CGFloat { scaledPoints(Theme.Size.menuBrandIcon, scale) }
        var barBrandIcon: CGFloat { scaledPoints(Theme.Size.barBrandIcon, scale) }
        var menuRowSpacing: CGFloat { scaledPoints(Theme.Size.menuRowSpacing, scale) }
        var menuSectionHeader: CGFloat { scaledPoints(Theme.Size.menuSectionHeader, scale) }
        /// Derived like `Theme`'s, so the row cap still counts whole rows at every size.
        var menuRowHeight: CGFloat { menuIcon + Spacing(scale: scale).md * 2 }
        var menuRowsMaxHeight: CGFloat {
            (Theme.Size.menuVisibleRows * (menuRowHeight + menuRowSpacing)).rounded()
        }
        var clipboardListWidth: CGFloat { scaledPoints(Theme.Size.clipboardListWidth, scale) }

        var markdownQuoteBar: CGFloat { scaledPoints(Theme.Size.markdownQuoteBar, scale) }
        var chatMessageAction: CGFloat { scaledPoints(Theme.Size.chatMessageAction, scale) }
        var chatImageThumb: CGFloat { scaledPoints(Theme.Size.chatImageThumb, scale) }
        var chatAttachmentGlyph: CGFloat { scaledPoints(Theme.Size.chatAttachmentGlyph, scale) }
        var chatAttachmentThumb: CGFloat { scaledPoints(Theme.Size.chatAttachmentThumb, scale) }
        var chatAttachmentRemove: CGFloat { scaledPoints(Theme.Size.chatAttachmentRemove, scale) }
        var chatAttachmentInset: CGFloat { scaledPoints(Theme.Size.chatAttachmentInset, scale) }

        var dialogCompactWidth: CGFloat { scaledPoints(Theme.Size.dialogCompactWidth, scale) }
        var dialogButtonHeight: CGFloat {
            menuButton
                - scaledPoints(Theme.Size.menuButton - Theme.Size.dialogButtonHeight, scale)
        }
        var dialogSymbol: CGFloat { scaledPoints(Theme.Size.dialogSymbol, scale) }
        var dialogSymbolContainer: CGFloat {
            scaledPoints(Theme.Size.dialogSymbolContainer, scale)
        }
        var hudMaxWidth: CGFloat { scaledPoints(Theme.Size.hudMaxWidth, scale) }
    }

    /// `NSFont` is the only public source of a text style's size and face.
    struct Typography: Sendable {
        let scale: CGFloat

        var searchFieldSize: CGFloat { scaledPoints(Theme.Typography.searchFieldSize, scale) }
        var searchField: Font {
            scale == 1
                ? Theme.Typography.searchField
                : .system(size: searchFieldSize, weight: .regular)
        }
        /// Isolated because `Theme`'s twin is, not because resolving a font needs main.
        @MainActor var searchFieldNSFont: NSFont {
            scale == 1
                ? Theme.Typography.searchFieldNSFont
                : NSFont.systemFont(ofSize: searchFieldSize, weight: .regular)
        }
        var headerIcon: Font {
            scale == 1
                ? Theme.Typography.headerIcon
                : .system(size: scaledPoints(18, scale), weight: .medium)
        }

        var rowTitle: Font { font(Theme.Typography.rowTitle, .body) }
        var rowTrailing: Font { font(Theme.Typography.rowTrailing, .callout) }
        var sectionHeader: Font { font(Theme.Typography.sectionHeader, .subheadline, .medium) }
        var panelTitle: Font { font(Theme.Typography.panelTitle, .headline) }
        var keyCap: Font { font(Theme.Typography.keyCap, .caption1) }
        var compactKeyCap: Font { font(Theme.Typography.compactKeyCap, .caption2) }
        var heroKeyCap: Font { font(Theme.Typography.heroKeyCap, .body) }
        var bar: Font { font(Theme.Typography.bar, .callout, .medium) }
        var chip: Font { font(Theme.Typography.chip, .callout) }
        @MainActor var chipNSFont: NSFont { scale == 1 ? Theme.Typography.chipNSFont : nsFont(.callout) }
        var disclosure: Font { font(Theme.Typography.disclosure, .caption1, .semibold) }
        var menuRow: Font { font(Theme.Typography.menuRow, .body) }
        var menuShortcut: Font { font(Theme.Typography.menuShortcut, .callout) }
        var menuIcon: Font { font(Theme.Typography.menuIcon, .body) }

        /// The AppKit twin of a text style, for text an `NSTextView` draws beside SwiftUI's own.
        func textNSFont(
            _ style: NSFont.TextStyle, weight: NSFont.Weight? = nil, monospaced: Bool = false
        ) -> NSFont {
            let base = nsFont(style)
            if monospaced { return .monospacedSystemFont(ofSize: base.pointSize, weight: weight ?? .regular) }
            guard let weight else { return base }
            return .systemFont(ofSize: base.pointSize, weight: weight)
        }

        /// Composed like `Theme`'s own: the style carries the face, an explicit weight overrides it.
        private func font(
            _ base: Font, _ style: NSFont.TextStyle, _ weight: Font.Weight? = nil
        )
            -> Font
        {
            guard scale != 1 else { return base }
            let scaled = Font(nsFont(style))
            return weight.map(scaled.weight) ?? scaled
        }

        /// Its own descriptor, so `.headline` stays Bold and `.caption2` Medium rather than lightening.
        private func nsFont(_ style: NSFont.TextStyle) -> NSFont {
            let base = NSFont.preferredFont(forTextStyle: style)
            guard scale != 1 else { return base }
            return NSFont(descriptor: base.fontDescriptor, size: scaledPoints(base.pointSize, scale)) ?? base
        }
    }
}

/// Whole points: a fractional row pitch lands keycap edges and the dissolve mask off-pixel.
private func scaledPoints(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
    scale == 1 ? value : (value * scale).rounded()
}

extension EnvironmentValues {
    /// `.standard` by default, so a shared `DesignSystem` view outside the palette never scales.
    @Entry var metrics = InterfaceMetrics.standard
}
