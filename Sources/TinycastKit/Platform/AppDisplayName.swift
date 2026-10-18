import Foundation

/// A blank `CFBundleDisplayName` must read as absent: it draws as nothing and matches nothing.
enum AppDisplayName {
    /// The Info.plist value as a name, or nil when it is absent, not a string, or blank.
    static func named(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Bundle {
    /// The channel-aware display name, from the generated Info.plist.
    var appDisplayName: String {
        infoName("CFBundleDisplayName") ?? infoName("CFBundleName") ?? "Tinycast"
    }

    /// The name a bundle declares for itself. Not what Finder shows — LaunchServices ignores a
    /// `CFBundleDisplayName` that disagrees with the file name, so the launcher labels rows by that.
    var installedAppName: String {
        infoName("CFBundleDisplayName") ?? infoName("CFBundleName")
            ?? bundleURL.deletingPathExtension().lastPathComponent
    }

    /// Localized: `object(forInfoDictionaryKey:)` consults `InfoPlist.strings`.
    private func infoName(_ key: String) -> String? {
        AppDisplayName.named(object(forInfoDictionaryKey: key))
    }
}
