public enum RootSearchGate {
    public static func accepts(isRaycast: Bool, hasRootResults: Bool, isSearchField: Bool, hasOverlay: Bool, plainTab: Bool) -> Bool {
        isRaycast && hasRootResults && isSearchField && !hasOverlay && plainTab
    }
}
