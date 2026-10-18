import Foundation

/// The cacheless exchange-rate fetcher. See docs/features/calculator.md#exchange-rates.
@MainActor
@Observable
final class CurrencyRateStore {
    /// The newest snapshot, nil until the first one lands.
    private(set) var rates: CurrencyRates?

    private let fileURL: URL
    /// Drives the schedule: a partial snapshot answers, but only a whole one resets the clock.
    @ObservationIgnored private var completedAt: Date?

    init() {
        fileURL = AppPaths.caches().appendingPathComponent("currency-rates.json")
        guard let data = try? Data(contentsOf: fileURL),
            let cached = try? JSONDecoder().decode(CurrencyRates.self, from: data)
        else { return }
        rates = cached
        // A cache from before coins existed still prices fiat, but has to be replaced at once.
        if CurrencyFeed.pricesCoins(cached) { completedAt = cached.fetchedAt }
    }
}
