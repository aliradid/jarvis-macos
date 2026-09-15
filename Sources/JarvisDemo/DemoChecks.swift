import Foundation

@MainActor enum DemoChecks {
    static func run() throws {
        func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw LaunchpadError(message: message) }
        }
        let encoder = JSONEncoder()
        _ = try OrbitValidatedBackup(encoder.encode(OrbitBackup(subscriptions: SampleData.subscriptions)))
        _ = try validatedCatBackup(encoder.encode(CatBackup(expenses: SampleData.cats)))
        _ = try OrbitValidatedRates(encoder.encode(SampleData.rates))
        encoder.dateEncodingStrategy = .iso8601
        _ = try YouTubeSnapshot.decode(encoder.encode(SampleData.youtube))
        let total = OrbitUsdTotal(SampleData.subscriptions, rates: SampleData.rates)
        try require(total.complete && abs(total.monthly - 85) < 0.00001, "Trial, ending and review records must not inflate the monthly total.")
        var annual = OrbitSubscription(name: "Annual", amount: 120, cycle: "Yearly")
        try require(annual.monthly == 10, "Annual billing must normalize to monthly.")
        annual.priceKnown = false
        let incomplete = OrbitUsdTotal([annual], rates: SampleData.rates)
        try require(!incomplete.complete && incomplete.missingPrices == 1 && incomplete.monthly == 0, "Unknown prices must be excluded and disclosed.")
        annual.priceKnown = true; annual.currency = "JPY"
        try require(OrbitUsdTotal([annual], rates: SampleData.rates).missingRates == 1, "Missing FX must not be treated as zero cost.")
        let store = SubscriptionStore()
        let initialCount = store.items.count
        var edited = store.items[0]; edited.amount += 10
        try require(store.save(edited), "Editing a sample subscription should succeed.")
        try require(store.items.count == initialCount && abs(OrbitUsdTotal(store.items, rates: store.fx.rates).monthly - 95) < 0.00001, "Editing must replace the record and recalculate totals.")
        edited.amount = -1
        try require(!store.save(edited) && store.items[0].amount == 35, "Invalid edits must preserve the last valid state.")
        let catStore = CatStore(); var cat = catStore.items[0]; cat.archived = true
        try require(catStore.save(cat) && catStore.items.count == 3 && catStore.items[0].archived, "Cat archiving must preserve its record.")
        let channel = SampleData.youtube.channels[0]
        try require(channel.week(through: channel.endDate) != nil, "Matching daily windows must produce a comparison.")
        try require(abs((channel.financials?.last7?.rpm ?? 0) - channel.financials!.last7!.amount / channel.financials!.last7!.engagedViews! * 1000) < 0.000001, "RPM must use engaged views.")
        let secondStore = SubscriptionStore()
        try require(secondStore.items[0].amount == 25, "Demo stores must start from samples, not another session's edits.")
        print("PASS: fixture validation, subscription totals and edits, missing data, cat archiving, analytics windows, RPM and session isolation.")
    }
}
