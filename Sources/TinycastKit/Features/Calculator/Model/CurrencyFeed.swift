import Foundation

/// Decodes the rate feeds into one snapshot. Pure, so the harness covers it; the store does the IO.
enum CurrencyFeed {
    /// Only whole snapshots are persisted, so a cached one pricing no coin predates them entirely.
    static func pricesCoins(_ snapshot: CurrencyRates) -> Bool {
        CalcCurrency.cryptoCodes.contains { snapshot.rates[$0] != nil }
    }
}
