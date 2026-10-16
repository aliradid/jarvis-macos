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
        _ = try OrbitValidatedRates(encoder.encode(SampleData.rates))

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

        // Verify live Darwin kernel telemetry reader
        let liveTelemetry = MacTelemetry.capture()
        try require(!liveTelemetry.chipName.isEmpty && liveTelemetry.memoryTotalGB > 0 && liveTelemetry.diskTotalGB > 0, "MacTelemetry.capture() must return valid Darwin kernel metrics.")

        // Verify AI quota windows and dev port catalog
        try require(AIQuotaStore.shared.readings.count == 3, "Demo AIQuotaStore must expose Claude 5h, Claude Weekly, and Codex Weekly windows.")
        try require(InfrastructureStore.shared.devPorts.count == 7 && InfrastructureStore.shared.ollamaModels.count == 4, "InfrastructureStore must expose localhost dev ports and local GGUF models.")

        // Verify direct Jarvis shortcut dispatch
        let targets = [JarvisTarget(id: "dev:cursor", label: "Cursor AI IDE", category: "link", status: "ready", canStart: true)]
        try require(JarvisCommands.direct("open cursor ai ide", targets: targets)?.targetID == "dev:cursor", "JarvisCommands.direct must resolve unambiguous launcher targets.")

        let secondStore = SubscriptionStore(items: billingExamples)
        try require(secondStore.items[0].amount == 25, "Demo stores must start from samples, not another session's edits.")
        print("PASS: fixture validation, subscription totals and edits, missing data, Darwin telemetry, AI quota windows, dev ports, and session isolation.")
    }
}
