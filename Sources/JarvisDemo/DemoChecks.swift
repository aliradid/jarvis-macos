import Foundation

@MainActor enum DemoChecks {
    private static var billingExamples: [OrbitSubscription] {
        [("ChatGPT", 25.0, "USD", "Monthly", "Active", 8),
         ("Claude", 30.0, "USD", "Monthly", "Active", 12),
         ("Adobe", 18.0, "EUR", "Monthly", "Active", 18),
         ("Example cloud", 120.0, "USD", "Yearly", "Active", 24),
         ("Example editor", 15.0, "USD", "Monthly", "Trial", 2),
         ("Example storage", 8.0, "USD", "Monthly", "Ending", 5),
         ("Example service", 0.0, "USD", "Unknown", "Needs review", 0),
         ("Example archive", 12.0, "USD", "Monthly", "Archived", -60)].enumerated().map { index, r in
            var s = OrbitSubscription(name: r.0, amount: r.1, currency: r.2, cycle: r.3, date: SampleData.day(r.5), status: r.4)
            s.id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
            s.notes = "Fictional sample record. Amounts do not represent provider pricing or a personal account."
            s.priceKnown = r.4 != "Needs review"; s.dateKnown = r.4 != "Needs review"
            s.dateBasis = "Confirmed"; s.priceBasis = "Confirmed"
            return s
        }
    }
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
        let total = OrbitUsdTotal(billingExamples, rates: SampleData.rates)
        try require(total.complete && abs(total.monthly - 85) < 0.00001, "Trial, ending and review records must not inflate the monthly total.")
        var annual = OrbitSubscription(name: "Annual", amount: 120, cycle: "Yearly")
        try require(annual.monthly == 10, "Annual billing must normalize to monthly.")
        annual.priceKnown = false
        let incomplete = OrbitUsdTotal([annual], rates: SampleData.rates)
        try require(!incomplete.complete && incomplete.missingPrices == 1 && incomplete.monthly == 0, "Unknown prices must be excluded and disclosed.")
        annual.priceKnown = true; annual.currency = "JPY"
        try require(OrbitUsdTotal([annual], rates: SampleData.rates).missingRates == 1, "Missing FX must not be treated as zero cost.")
        let store = SubscriptionStore(items: billingExamples)
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
        let secondStore = SubscriptionStore(items: billingExamples)
        try require(secondStore.items[0].amount == 25, "Demo stores must start from samples, not another session's edits.")
        print("PASS: fixture validation, subscription totals and edits, missing data, cat archiving, analytics windows, RPM and session isolation.")
    }
}
