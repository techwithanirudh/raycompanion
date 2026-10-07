struct RaycastImportCandidate: Identifiable {
    let installed: InstalledExtension
    let isInstalled: Bool
    var id: String { installed.id }
}
