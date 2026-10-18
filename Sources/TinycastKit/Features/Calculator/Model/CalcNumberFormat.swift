import Foundation

/// Whether the calculator follows the Mac's number format or always reads and writes English.
enum CalcNumberStyle: String, CaseIterable, Identifiable, Sendable {
    case system
    case english

    var id: String { rawValue }
}

/// Separators the user writes; the engine only reads English. See docs/features/calculator.md.
struct CalcNumberFormat: Equatable, Sendable {
    let decimalSeparator: Unicode.Scalar
    /// nil when numbers are written without grouping.
    let groupingSeparator: Unicode.Scalar?

    static let english = CalcNumberFormat(decimal: ".", grouping: ",")

    /// Separators macOS offers that can never be mistaken for calculator syntax.
    private static let groupingScalars: Set<Unicode.Scalar> = [
        ".", ",", "'", "\u{2019}", "\u{00A0}", "\u{202F}", "\u{2009}"
    ]

    private init(decimal: Unicode.Scalar, grouping: Unicode.Scalar?) {
        decimalSeparator = decimal
        groupingSeparator = grouping
    }

    /// nil for a decimal separator canonical syntax can't express, such as the Arabic `٫`.
    init?(decimalSeparator: String, groupingSeparator: String?) {
        guard let decimal = Self.single(decimalSeparator), decimal == "." || decimal == "," else {
            return nil
        }
        let grouping = groupingSeparator.flatMap(Self.single).flatMap {
            $0 != decimal && Self.groupingScalars.contains($0) ? $0 : nil
        }
        self.init(decimal: decimal, grouping: grouping)
    }

    private static func single(_ text: String) -> Unicode.Scalar? {
        let scalars = text.unicodeScalars
        return scalars.count == 1 ? scalars.first : nil
    }

    private var usesDecimalComma: Bool { decimalSeparator == "," }

    // MARK: - Input

    /// The query in canonical syntax, or nil when a number in it has no single reading.
    func canonical(_ query: String) -> String? {
        guard self != .english else { return query }
        let scalars = Array(query.unicodeScalars)
        var output = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if usesDecimalComma, scalar == ";" {
                // Spaced, so the canonical comma can never be read as grouping between two digits.
                output.append(contentsOf: ", ".unicodeScalars)
                index += 1
                continue
            }
            guard startsNumber(scalars, at: index, decimal: decimalSeparator) else {
                output.append(scalar)
                index += 1
                continue
            }
            let end = numberEnd(
                scalars, from: index, decimal: decimalSeparator, grouping: groupingSeparator)
            let run = scalars[index..<end]
            if Self.isClockFragment(scalars, run: index..<end) {
                output.append(contentsOf: run)
            } else {
                guard let number = canonicalNumber(run) else { return nil }
                output.append(contentsOf: number)
            }
            index = end
        }
        return String(output)
    }

    private func canonicalNumber(_ run: ArraySlice<Unicode.Scalar>) -> [Unicode.Scalar]? {
        let parts = run.split(separator: decimalSeparator, omittingEmptySubsequences: false)
        // Where the dot is the decimal, `19.2.27` is a date exactly as English reads it.
        if parts.count > 2 {
            return !usesDecimalComma && !run.contains(where: isGrouping) ? Array(run) : nil
        }
        if parts.count == 2, parts[1].contains(where: isGrouping) { return nil }
        let groups = parts[0].split(
            omittingEmptySubsequences: false, whereSeparator: isGrouping)
        if groups.count > 1, !Self.isValidGrouping(groups) {
            // A dotted date's dots are grouping dots here, and no valid grouping has short groups.
            let isDottedDate = groupingSeparator == "." && parts.count == 1 && groups.count > 2
            return isDottedDate ? Array(run) : nil
        }
        var number = groups.flatMap { $0 }
        if parts.count == 2 {
            number.append(".")
            number.append(contentsOf: parts[1])
        }
        return number
    }

    private func isGrouping(_ scalar: Unicode.Scalar) -> Bool { scalar == groupingSeparator }

    // MARK: - Scanning

    /// A digit, or a decimal separator leading one (`,5`) that no digit precedes.
    private func startsNumber(
        _ scalars: [Unicode.Scalar], at index: Int, decimal: Unicode.Scalar
    ) -> Bool {
        let scalar = scalars[index]
        if Self.isDigit(scalar) { return true }
        guard scalar == decimal, index + 1 < scalars.count, Self.isDigit(scalars[index + 1]) else {
            return false
        }
        return index == 0 || !Self.isDigit(scalars[index - 1])
    }

    /// Digits and the separators between them; a trailing decimal stays, so `2,` still answers.
    private func numberEnd(
        _ scalars: [Unicode.Scalar], from start: Int, decimal: Unicode.Scalar,
        grouping: Unicode.Scalar?
    ) -> Int {
        var end = start
        while end < scalars.count {
            let scalar = scalars[end]
            if Self.isDigit(scalar) {
                end += 1
                continue
            }
            guard scalar == decimal || scalar == grouping else { break }
            let next = end + 1
            if next < scalars.count, Self.isDigit(scalars[next]) {
                end = next
            } else {
                if scalar == decimal, next == scalars.count, end > start { end = next }
                break
            }
        }
        return end
    }

    /// `00:18:00.123` belongs to a clock, whose fractional seconds are always written with a dot.
    private static func isClockFragment(_ scalars: [Unicode.Scalar], run: Range<Int>) -> Bool {
        (run.lowerBound > 0 && scalars[run.lowerBound - 1] == ":")
            || (run.upperBound < scalars.count && scalars[run.upperBound] == ":")
    }

    private static func isValidGrouping(_ groups: [ArraySlice<Unicode.Scalar>]) -> Bool {
        guard let first = groups.first, (1...3).contains(first.count) else { return false }
        return groups.dropFirst().allSatisfy { $0.count == 3 }
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool { (48...57).contains(scalar.value) }
}
