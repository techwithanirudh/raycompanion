import Foundation

/// Installs an extension's dependencies before a build. Only an install from GitHub needs one.
enum ExtensionPackageManager: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case pnpm
    case npm
    case yarn
    case bun

    var id: String { rawValue }
}
