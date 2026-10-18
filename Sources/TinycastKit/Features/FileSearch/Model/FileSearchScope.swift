import Foundation
import UniformTypeIdentifiers

enum FileSearchScope {
    /// Stored tilde-abbreviated, so a settings backup stays portable between machines.
    static let defaultScopes = ["~"]

    struct Candidate: Sendable {
        let url: URL
        let isDirectory: Bool
        let isHidden: Bool
        let isPackage: Bool
        /// Resolved from disk, so the home-root branch classifies exactly as Spotlight does.
        let contentType: UTType?

        var isApplication: Bool { contentType?.conforms(to: .application) == true }
    }

    struct Selection: Sendable {
        let directories: [URL]
        let rootItems: [Candidate]
    }

    static func select(_ candidates: [Candidate]) -> Selection {
        var directories: [URL] = []
        var rootItems: [Candidate] = []
        for candidate in candidates
        where !candidate.isHidden && !candidate.isApplication
            && candidate.url.lastPathComponent.caseInsensitiveCompare("Library") != .orderedSame
        {
            rootItems.append(candidate)
            if candidate.isDirectory && !candidate.isPackage {
                directories.append(candidate.url)
            }
        }
        return Selection(directories: directories, rootItems: rootItems)
    }

    static func expand(_ scope: String, homeDirectory: URL) -> URL {
        guard scope.hasPrefix("~") else {
            return URL(fileURLWithPath: scope, isDirectory: true).standardizedFileURL
        }
        let relative = String(scope.dropFirst()).trimmingPrefix("/")
        guard !relative.isEmpty else { return homeDirectory.standardizedFileURL }
        return homeDirectory.appending(path: relative, directoryHint: .isDirectory)
            .standardizedFileURL
    }

    static func roots(for scopes: [String], homeDirectory: URL) -> [URL] {
        var seen = Set<String>()
        let expanded = scopes.map { expand($0, homeDirectory: homeDirectory) }
        return expanded.filter { seen.insert($0.path).inserted }
    }
}
