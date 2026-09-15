import SwiftUI
import AppKit
import UserNotifications
import UniformTypeIdentifiers

// OLED palette: black OrbitCanvas, low-luminance surfaces, softened text and accents.
let OrbitCanvas = Color.black
let OrbitSurface = Color(white:0.045)
let OrbitPrimaryText = Color(white:0.82)
let OrbitMutedText = Color(white:0.57)
let OrbitAccent = Color(red:0.57, green:0.72, blue:0.40)
let OrbitReviewTint = Color(red:0.78, green:0.57, blue:0.32)
let OrbitEndingTint = Color(red:0.74, green:0.66, blue:0.38)
let OrbitCloudTint = Color(red:0.39, green:0.66, blue:0.71)
let OrbitErrorTint = Color(red:0.84, green:0.40, blue:0.38)
let OrbitCategories = ["Entertainment", "Software", "Cloud & storage", "Health", "Learning", "Utilities", "Other"]
let OrbitCurrencies = ["USD", "EUR", "GBP", "MAD", "CAD", "AUD", "CHF", "JPY", "AED", "INR", "TRY", "VND"]
struct OrbitSubscription: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var amount: Double = 0
    var currency = "USD"
    var cycle = "Monthly"
    var date = Calendar.current.startOfDay(for: Date())
    var category = "Software"
    var status = "Active"
    var website = ""
    var notes = ""
    var reminder = 3
    var remindersEnabled: Bool?
    var priceBasis: String?
    var priceKnown: Bool?
    var dateKnown: Bool?
    var dateBasis: String?
    var evidenceURL: String?
    var importKey: String?
    var hasPrice: Bool { priceKnown != false }
    var hasDate: Bool { dateKnown != false }
    var isRecurring: Bool { status == "Active" || status == "Trial" }
    var effectiveStatus: String { status == "Ending" && hasDate && days < 0 ? "Archived" : status }
    var statusLabel: String { status == "Needs review" ? "REVIEW" : status == "Ending" ? (days < 0 ? "ENDED" : "ENDING") : status == "Trial" ? "TRIAL" : status == "Archived" ? "ARCHIVED" : !hasDate ? "ACTIVE" : days == 0 ? "TODAY" : "IN \(days) DAYS" }
    var dateLabel: String {
        guard hasDate else {return "Date unknown"}
        let next=nextDate()
        let showYear = ["Archived","Needs review"].contains(status) || Calendar.current.component(.year,from:next) != Calendar.current.component(.year,from:Date())
        let label = showYear ? next.formatted(.dateTime.day().month(.abbreviated).year()) : next.formatted(.dateTime.month(.abbreviated).day())
        return (dateBasis == "Estimated" ? "Est. " : "") + label
    }
    var timelineDetail: String { status == "Ending" ? "Access ends · no renewal" : status == "Trial" ? (days < 0 ? "Trial ended · review status" : "Trial ends · \(money)") : (dateBasis == "Estimated" ? "Estimated · " : "") + money }
    var canProject: Bool { hasDate && cycle != "Unknown" && ["Confirmed", "Estimated"].contains(dateBasis ?? "Confirmed") }
    var wantsReminder: Bool { remindersEnabled != false && hasDate && (status == "Ending" || status == "Trial" || (status == "Active" && canProject)) }
    var monthly: Double { (hasPrice ? amount : 0) / (cycle == "Every 4 weeks" ? 336.0 / 365.0 : cycle == "Every 30 days" ? 360.0 / 365.0 : cycle == "Unknown" ? Double.infinity : cycle == "Yearly" ? 12 : cycle == "Quarterly" ? 3 : cycle == "Weekly" ? 12.0 / 52.0 : 1) }
    func occurrence(_ index: Int) -> Date {
        Calendar.current.date(byAdding: (cycle == "Weekly" || cycle == "Every 30 days" || cycle == "Every 4 weeks") ? .day : .month, value: index * (cycle == "Every 4 weeks" ? 28 : cycle == "Every 30 days" ? 30 : cycle == "Weekly" ? 7 : cycle == "Yearly" ? 12 : cycle == "Quarterly" ? 3 : 1), to: date)!
    }
    func nextDate(now: Date = Date()) -> Date {
        if status != "Active" || !canProject { return date }
        let today = Calendar.current.startOfDay(for: now)
        var i = 0
        while occurrence(i) < today && i < 12000 { i += 1 }
        return occurrence(i)
    }
    var days: Int { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: nextDate())).day ?? 0 }
    var money: String { hasPrice ? amount.formatted(.currency(code:currency)) : "Price unknown" }
}
let OrbitBillingCycles = ["Monthly", "Yearly", "Quarterly", "Weekly", "Every 30 days", "Every 4 weeks", "Unknown"]
let OrbitPlanStatuses = ["Active", "Trial", "Ending", "Needs review", "Archived"]
let OrbitDateBases = ["Confirmed", "Estimated", "Last due", "Trial ended", "Access ended", "Billing issue", "Invoice due", "Canceled", "Access evidence"]
let OrbitPriceBases = ["Confirmed", "Quoted renewal", "Last known", "Last invoice", "Last confirmed", "Last bank debit"]
func OrbitParsePrice(_ input: String, separator: String = Locale.current.decimalSeparator ?? ".") -> Double? {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: separator, with: ".")
    guard text.range(of: "^[0-9]+(?:\\.[0-9]{1,8})?$", options: .regularExpression) != nil,
          let value = Double(text), value.isFinite, (0...1_000_000_000).contains(value) else { return nil }
    return value
}
func OrbitProviderURL(_ text: String) -> URL? {
    guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty else { return nil }
    return url
}
struct OrbitBackup: Codable { var version = 1; var subscriptions: [OrbitSubscription] }
func OrbitValidatedBackup(_ data: Data) throws -> OrbitBackup {
    guard data.count <= 10_000_000 else { throw CocoaError(.fileReadTooLarge) }
    let backup = try JSONDecoder().decode(OrbitBackup.self, from: data)
    guard backup.version == 1, Set(backup.subscriptions.map(\.id)).count == backup.subscriptions.count,
          backup.subscriptions.allSatisfy({ s in
              !s.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.amount.isFinite && (0...1_000_000_000).contains(s.amount)
              && OrbitCategories.contains(s.category) && OrbitCurrencies.contains(s.currency) && OrbitBillingCycles.contains(s.cycle) && OrbitPlanStatuses.contains(s.status)
              && (0...30).contains(s.reminder) && s.date.timeIntervalSince1970.isFinite
              && s.date > Date(timeIntervalSince1970: 0) && s.date < Date(timeIntervalSince1970: 7_258_118_400)
          }) else { throw CocoaError(.fileReadCorruptFile) }
    return backup
}
func OrbitMergeSubscriptions(_ existing: [OrbitSubscription], _ incoming: [OrbitSubscription]) -> [OrbitSubscription] {
    var result = existing
    var ids = Set(existing.map(\.id))
    var keys = Set(existing.compactMap(\.importKey))
    for s in incoming {
        guard !ids.contains(s.id), s.importKey == nil || !keys.contains(s.importKey!) else { continue }
        result.append(s); ids.insert(s.id); if let key = s.importKey { keys.insert(key) }
    }
    return result
}
struct OrbitPlannedReminder { let fire: Date; let due: Date; let item: OrbitSubscription; let index: Int }
func OrbitPlanReminders(_ items: [OrbitSubscription], now: Date = Date()) -> [OrbitPlannedReminder] {
    var result: [OrbitPlannedReminder] = []
    for s in items where s.wantsReminder {
        let next = s.nextDate(now: now)
        var first = 0
        if s.status == "Active" { while s.occurrence(first) < next && first < 12000 { first += 1 } }
        for i in 0..<(s.status == "Active" ? 12 : 1) {
            let due = s.status == "Active" ? s.occurrence(first + i) : next
            guard let day = Calendar.current.date(byAdding: .day, value: -s.reminder, to: due),
                  let fire = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day), fire > now else { continue }
            result.append(OrbitPlannedReminder(fire: fire, due: due, item: s, index: i))
        }
    }
    return Array(result.sorted { $0.fire < $1.fire }.prefix(60))
}
struct OrbitFXRate: Codable {
    let date: String
    let base: String
    let quote: String
    let rate: Double // Units of quote currency per 1 USD.
}
func OrbitValidatedRates(_ data: Data) throws -> [OrbitFXRate] {
    let rows = try JSONDecoder().decode([OrbitFXRate].self, from: data)
    guard !rows.isEmpty, Set(rows.map(\.quote)).count == rows.count,
          rows.allSatisfy({ $0.base == "USD" && $0.rate.isFinite && $0.rate > 0 && $0.date.range(of:"^20[0-9]{2}-[0-9]{2}-[0-9]{2}$",options:.regularExpression) != nil }) else { throw CocoaError(.fileReadCorruptFile) }
    return rows
}
func OrbitUsdValue(_ amount: Double, currency: String, rates: [OrbitFXRate]) -> Double? {
    guard amount.isFinite && amount >= 0 else { return nil }
    if currency == "USD" { return amount }
    guard let rate = rates.first(where: { $0.quote == currency && $0.base == "USD" }), rate.rate.isFinite && rate.rate > 0 else { return nil }
    let value = amount / rate.rate
    return value.isFinite ? value : nil
}
func OrbitUsdMoney(_ amount: Double) -> String { amount.formatted(.currency(code:"USD").locale(Locale(identifier:"en_US"))) }
func OrbitMadValue(_ amount: Double, currency: String, rates: [OrbitFXRate]) -> Double? {
    guard amount.isFinite && amount >= 0 else { return nil }
    if currency == "MAD" { return amount }
    guard let usd = OrbitUsdValue(amount,currency:currency,rates:rates),
          let rate = rates.first(where:{$0.base == "USD" && $0.quote == "MAD"}), rate.rate.isFinite && rate.rate > 0 else { return nil }
    let value = usd * rate.rate
    return value.isFinite ? value : nil
}
func OrbitMadMoney(_ amount: Double) -> String { "MAD " + amount.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier:"en_US"))) }
struct OrbitUSDTotal {
    var monthly = 0.0
    var missingPrices = 0
    var missingCycles = 0
    var missingRates = 0
    var complete: Bool { missingPrices + missingCycles + missingRates == 0 }
}
func OrbitUsdTotal(_ items: [OrbitSubscription], rates: [OrbitFXRate]) -> OrbitUSDTotal {
    var result = OrbitUSDTotal()
    for item in items where item.status == "Active" {
        guard item.hasPrice else { result.missingPrices += 1; continue }
        guard item.cycle != "Unknown" else { result.missingCycles += 1; continue }
        guard let value = OrbitUsdValue(item.monthly,currency:item.currency,rates:rates) else { result.missingRates += 1; continue }
        result.monthly += value
    }
    return result
}
func OrbitHigherMonthlyCost(_ a: OrbitSubscription, _ b: OrbitSubscription, rates: [OrbitFXRate]) -> Bool {
    let av = a.hasPrice && a.cycle != "Unknown" ? OrbitUsdValue(a.monthly,currency:a.currency,rates:rates) : nil
    let bv = b.hasPrice && b.cycle != "Unknown" ? OrbitUsdValue(b.monthly,currency:b.currency,rates:rates) : nil
    if let av, let bv, av != bv { return av > bv }
    if (av != nil) != (bv != nil) { return av != nil }
    let names = a.name.localizedStandardCompare(b.name)
    return names == .orderedSame ? a.id.uuidString < b.id.uuidString : names == .orderedAscending
}
@MainActor final class OrbitExchangeRates: ObservableObject {
    @Published var rates: [OrbitFXRate] = []
    @Published var refreshing = false
    @Published var failure: String?
    init() { rates = SampleData.rates }
    var dateLabel: String {
        let dates = rates.map(\.date).sorted()
        guard let first = dates.first, let last = dates.last else { return "Rates unavailable" }
        return first == last ? first : "\(first) – \(last)"
    }
    var stale: Bool {
        guard let oldest = rates.map(\.date).min(), let date = ISO8601DateFormatter().date(from:oldest + "T00:00:00Z") else { return true }
        return Date().timeIntervalSince(date) > 7 * 86400
    }
    var status: String { (failure != nil ? "Offline · saved rates" : stale ? "Older saved rates" : "Sample FX rates") + " · " + dateLabel }
    func money(_ item: OrbitSubscription) -> String {
        guard item.hasPrice else { return "Price unknown" }
        guard let value = OrbitUsdValue(item.amount,currency:item.currency,rates:rates) else { return "USD rate unavailable" }
        return (item.currency == "USD" ? "" : "≈ ") + OrbitUsdMoney(value)
    }
    func mad(_ item: OrbitSubscription) -> String {
        guard item.hasPrice else { return "" }
        guard let value = OrbitMadValue(item.amount,currency:item.currency,rates:rates) else { return "MAD rate unavailable" }
        return (item.currency == "MAD" ? "" : "≈ ") + OrbitMadMoney(value)
    }
    func madTotal(_ usd: Double) -> String {
        guard let value = OrbitMadValue(usd,currency:"USD",rates:rates) else { return "MAD rate unavailable" }
        return "≈ " + OrbitMadMoney(value)
    }
    func dualMoney(_ item: OrbitSubscription) -> String { money(item) + (item.hasPrice ? " · " + mad(item) : "") }
    func timeline(_ item: OrbitSubscription) -> String {
        if item.status == "Ending" { return "Access ends · no renewal" }
        if item.status == "Trial" { return item.days < 0 ? "Trial ended · review status" : "Trial ends · " + dualMoney(item) }
        return (item.dateBasis == "Estimated" ? "Estimated · " : "") + dualMoney(item)
    }
    func refresh(force: Bool = false) async { rates = SampleData.rates; failure = nil }
}


struct OrbitPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size:13,weight:.semibold)).foregroundStyle(enabled ? Color.black : OrbitMutedText)
            .padding(.horizontal,16).frame(minHeight:38)
            .background(enabled ? OrbitAccent.opacity(configuration.isPressed ? 0.75 : 1) : Color.white.opacity(0.08),in:RoundedRectangle(cornerRadius:9))
            .contentShape(Rectangle())
    }
}
// Local provider artwork; no network requests or subscription data leave the app.
let OrbitBrandNames: [(String,String)] = [
    ("chatgpt","openai"),
    ("claude","anthropic"),
    ("youtube","youtube"),
    ("adobe","adobe"),
    ("amazon","amazon"),
    ("apple music","applemusic"),
    ("bevel","bevel"),
    ("canva","canva"),
    ("capcut","capcut"),
    ("cleanmymac","cleanmymac"),
    ("datacamp","datacamp"),
    ("elevenlabs","elevenlabs"),
    ("godaddy","godaddy"),
    ("hiface","hiface"),
    ("hypeproxy","hypeproxy"),
    ("icloud","icloud"),
    ("iproyal","iproyal"),
    ("kimi","kimi"),
    ("kindle","kindle"),
    ("muzz","muzz"),
    ("netflix","netflix"),
    ("nexlev","nexlev"),
    ("nindohost","nindohost"),
    ("nindomail","nindomail"),
    ("nodemaven","nodemaven"),
    ("opal","opal"),
    ("orange","orange"),
    ("petrosky","petrosky"),
    ("shopify","shopify"),
    ("skool","skool"),
    ("spotify","spotify"),
    ("surfshark","surfshark"),
    ("swimsuccess","swimsuccess"),
    ("tapo","tapo"),
    ("whoop","whoop"),
    ("zwift","zwift"),
    ("cfg bank","cfg"),
    ("google ai","google"),
    ("chess.com","chess"),
    ("x premium","x"),
    ("personality.co","personality"),
]
func OrbitBrandKey(_ name: String) -> String? {
    let normalized = name.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
    return OrbitBrandNames.first(where:{normalized.hasPrefix($0.0)})?.1
}
struct OrbitServiceLogo: View {
    let item: OrbitSubscription
    var size: CGFloat = 44
    private static let images: [String:NSImage] = Dictionary(uniqueKeysWithValues:Set(OrbitBrandNames.map{$0.1}).compactMap { key in
        guard let url = Bundle.module.url(forResource:key,withExtension:"png"), let image = NSImage(contentsOf:url) else { return nil }
        return (key,image)
    })
    var body: some View {
        let key = OrbitBrandKey(item.name)
        Group {
            if let key, let image = Self.images[key] {
                Image(nsImage:image).resizable().interpolation(.high).scaledToFit().padding(size * 0.07)
            } else {
                Text(String(item.name.prefix(1))).font(.system(size:size * 0.45,weight:.semibold)).foregroundStyle(OrbitAccent)
            }
        }.frame(width:size,height:size)
            .background(Color(white:0.075),in:RoundedRectangle(cornerRadius:size * 0.23))
            .clipShape(RoundedRectangle(cornerRadius:size * 0.23))
            .accessibilityHidden(true)
    }
}

struct OrbitSubscriptionRow: View {
    @EnvironmentObject var fx: OrbitExchangeRates
    let item: OrbitSubscription
    var monthlyItem: OrbitSubscription {
        var copy = item
        copy.amount = item.monthly
        return copy
    }
    var knownMonthly: Bool { item.hasPrice && item.cycle != "Unknown" }
    var billingLabel: String {
        guard item.hasPrice else { return item.cycle }
        let period = ["Monthly":"month","Yearly":"year","Quarterly":"quarter","Weekly":"week","Every 4 weeks":"4 weeks","Every 30 days":"30 days"][item.cycle] ?? "unknown cycle"
        let original = item.currency == "USD" ? OrbitUsdMoney(item.amount) : item.money
        return "Billed " + original + " / " + period
    }
    var statusColor: Color {
        switch item.effectiveStatus {
        case "Active": return OrbitAccent
        case "Trial": return OrbitCloudTint
        case "Ending": return OrbitEndingTint
        case "Needs review": return OrbitReviewTint
        default: return OrbitMutedText
        }
    }
    var body: some View {
        HStack(alignment:.center,spacing:12) {
            OrbitServiceLogo(item:item)
            HStack(alignment:.top,spacing:16) {
                VStack(alignment:.leading,spacing:5) {
                    Text(item.name).font(.system(size:14,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                    Text(item.category).font(.system(size:11)).foregroundStyle(OrbitMutedText)
                    HStack(alignment:.firstTextBaseline,spacing:6) {
                        Text(item.effectiveStatus).foregroundStyle(statusColor).fixedSize()
                        Text("·").foregroundStyle(OrbitMutedText)
                        Text(item.hasDate ? (item.dateBasis != nil && item.dateBasis != "Confirmed" && item.dateBasis != "Estimated" ? item.dateBasis! + ": " : "") + item.dateLabel : "Date not set").foregroundStyle(OrbitMutedText)
                    }.font(.system(size:11)).fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.trailing,spacing:5) {
                    Text(knownMonthly ? fx.money(monthlyItem) + "/mo" : item.hasPrice ? "Cycle unknown" : "Price unknown").font(.system(size:14,weight:.medium)).fixedSize()
                    if knownMonthly { Text(fx.mad(monthlyItem) + "/mo").font(.system(size:11)).foregroundStyle(OrbitMutedText).fixedSize() }
                    Text(billingLabel).font(.system(size:11)).foregroundStyle(OrbitMutedText).multilineTextAlignment(.trailing).fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:200,alignment:.trailing)
                    .help(!item.hasPrice ? "Original price is not confirmed" : "Original charge: " + item.money + " · " + fx.dateLabel)
            }
            Image(systemName:"chevron.right").font(.system(size:10)).foregroundStyle(OrbitMutedText)
        }.padding(.horizontal,14).padding(.vertical,12).contentShape(Rectangle())
    }
}

struct OrbitEditor: View {
    @EnvironmentObject var fx: OrbitExchangeRates
    @Environment(\.dismiss) private var dismiss
    @State var item: OrbitSubscription
    @State private var amount = ""
    @State private var error: String?
    @State private var original: OrbitSubscription?
    @State private var discard = false
    @State private var tab = "Details"
    let save: (OrbitSubscription)->Bool
    let failure: ()->String
    var parsedAmount: Double? { OrbitParsePrice(amount) }
    var validURL: Bool { OrbitProviderURL(item.website) != nil }
    var valid: Bool { !item.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && (!item.hasPrice || parsedAmount != nil) && (item.website.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || validURL) }
    var dirty: Bool { guard let original else {return false}; return item != original || (item.hasPrice && parsedAmount != original.amount) }
    var dateTitle: String {
        if item.status == "Ending" { return "Access ends" }
        if item.status == "Trial" { return "Trial ends" }
        if let basis=item.dateBasis, !["Confirmed","Estimated"].contains(basis) {return basis == "Invoice due" ? "Invoice date" : basis + " date"}
        return "Billing date / anchor"
    }
    var statusExplanation: String {
        switch item.status {
        case "Active": return "Included in estimates when price and billing cycle are known."
        case "Trial": return "Trial end stays fixed until you confirm conversion or cancellation. Excluded from spending estimates."
        case "Ending": return "Renewal is off. Track the final day of access; no further spend is projected."
        case "Needs review": return "Excluded from spending and reminders. Keep the last documented date until you confirm the plan."
        default: return "Kept in your history. Excluded from spending and reminders."
        }
    }
    var body: some View {
        VStack(spacing:0) {
            HStack(alignment:.top) {
                if !item.name.isEmpty { OrbitServiceLogo(item:item,size:42) }
                VStack(alignment:.leading,spacing:5) { Text(original?.name.isEmpty == false ? "Subscription details" : "New subscription").font(.system(size:22,weight:.semibold)); Text(item.name.isEmpty ? "Keep the cost and timing in one place." : item.name).font(.system(size:13)).foregroundStyle(OrbitMutedText).lineLimit(2) }
                Spacer(); Button { close() } label: {Image(systemName:"xmark").frame(width:28,height:28)}.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Close editor").keyboardShortcut(.cancelAction)
            }.padding(24)
            Picker("Editor section",selection:$tab) { Text("Details").tag("Details"); Text("Notes & source").tag("Notes & source") }.pickerStyle(.segmented).labelsHidden().padding(.horizontal,24).padding(.bottom,16)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    if tab == "Details" { details } else { evidence }
                }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
            }.frame(maxHeight:.infinity)
            Divider()
            VStack(alignment:.leading,spacing:12) {
                if let error { Text(error).font(.system(size:12)).foregroundStyle(OrbitErrorTint).fixedSize(horizontal:false,vertical:true) }
                if !valid { Text(item.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Enter a service name to save." : item.hasPrice && parsedAmount == nil ? "Correct the price in Details to save." : "Correct the provider URL in Notes & source to save.").font(.system(size:11)).foregroundStyle(OrbitReviewTint) }
                HStack {
                    if original?.name.isEmpty == false && item.status != "Archived" {
                        Button("Archive") { item.status="Archived" }.buttonStyle(.bordered).help("Marks the record archived. Save to apply; does not cancel with the provider.")
                    }
                    Spacer()
                    Button("Cancel") { close() }.buttonStyle(.bordered).controlSize(.large)
                    Button("Save changes") { submit() }.buttonStyle(OrbitPrimaryButton()).tint(OrbitAccent).foregroundStyle(.black).controlSize(.large).disabled(!valid).keyboardShortcut("s",modifiers:.command)
                }
            }.padding(.horizontal,24).padding(.vertical,18)
        }.frame(width:620,height:min(680,(NSScreen.main?.visibleFrame.height ?? 900)-100)).background(OrbitCanvas).foregroundStyle(OrbitPrimaryText).tint(OrbitAccent).preferredColorScheme(.dark)
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("Discard unsaved changes?",isPresented:$discard,titleVisibility:.visible) { Button("Discard changes",role:.destructive) {dismiss()}; Button("Keep editing",role:.cancel) {} }
        .onAppear {
            original=item
            let f=NumberFormatter();f.numberStyle = .decimal;f.usesGroupingSeparator=false;f.maximumFractionDigits=8
            amount=f.string(from:NSNumber(value:item.amount)) ?? "0"
        }
        .onChange(of:item.status) { status in
            if status == "Active", let basis=item.dateBasis, !["Confirmed","Estimated"].contains(basis) { item.dateKnown=false;item.dateBasis="Confirmed" }
        }
    }
    var details: some View {
        VStack(alignment:.leading,spacing:22) {
            field("Service name") { TextField("e.g. Netflix",text:$item.name).textFieldStyle(.roundedBorder).controlSize(.large).accessibilityLabel("Service name") }
            HStack(alignment:.top,spacing:16) {
                field("Status") { Picker("Status",selection:$item.status) {ForEach(OrbitPlanStatuses,id:\.self){Text($0)}}.labelsHidden().frame(maxWidth:.infinity).accessibilityLabel("Status") }
                field("Category") { Picker("Category",selection:$item.category) {ForEach(OrbitCategories,id:\.self){Text($0)}}.labelsHidden().frame(maxWidth:.infinity).accessibilityLabel("Category") }
            }
            Text(statusExplanation).font(.system(size:12)).foregroundStyle(OrbitMutedText).fixedSize(horizontal:false,vertical:true)
            Divider()
            HStack { Text("Cost").font(.system(size:15,weight:.semibold));Spacer();Toggle("Price available",isOn:Binding(get:{item.hasPrice},set:{item.priceKnown=$0})).toggleStyle(.switch).controlSize(.small) }
            if item.hasPrice {
                HStack(alignment:.top,spacing:16) {
                    field("Original price per billing cycle") {TextField("0.00",text:$amount).textFieldStyle(.roundedBorder).controlSize(.large).accessibilityLabel("Price per billing cycle")}
                    field("Billed currency") {Picker("Currency",selection:$item.currency) {ForEach(OrbitCurrencies,id:\.self){Text($0)}}.labelsHidden().accessibilityLabel("Currency")}.frame(width:120)
                }
                if parsedAmount == nil {Text("Enter a non-negative amount, for example 19.99 or 19,99. Don't include a currency symbol.").font(.system(size:11)).foregroundStyle(OrbitReviewTint)}
                if let value = parsedAmount, let usd = OrbitUsdValue(value,currency:item.currency,rates:fx.rates) {
                    Text("Per billing cycle: " + OrbitUsdMoney(usd) + " · " + (OrbitMadValue(value,currency:item.currency,rates:fx.rates).map(OrbitMadMoney) ?? "MAD rate unavailable")).font(.system(size:12)).foregroundStyle(OrbitAccent)
                }
                Text("Enter the provider’s original currency. Jarvis shows USD and MAD equivalents using available exchange rates.").font(.system(size:11)).foregroundStyle(OrbitMutedText)
                field("Price basis") {Picker("Price basis",selection:Binding(get:{item.priceBasis ?? "Confirmed"},set:{item.priceBasis=$0})) {ForEach(OrbitPriceBases,id:\.self){Text($0)}}.labelsHidden().accessibilityLabel("Price basis")}
            } else {Text("Shown as price not set and excluded from spending totals.").font(.system(size:12)).foregroundStyle(OrbitMutedText)}
            field("Billing cycle") {Picker("Billing cycle",selection:$item.cycle) {ForEach(OrbitBillingCycles,id:\.self){Text($0)}}.labelsHidden().accessibilityLabel("Billing cycle")}
            Divider()
            HStack {Text("Timing").font(.system(size:15,weight:.semibold));Spacer();Toggle("Date available",isOn:Binding(get:{item.hasDate},set:{item.dateKnown=$0})).toggleStyle(.switch).controlSize(.small)}
            if item.hasDate {
                HStack(alignment:.top,spacing:16) {
                    field(dateTitle) { DatePicker(dateTitle,selection:$item.date,in:Date(timeIntervalSince1970:86400)...Date(timeIntervalSince1970:7_258_032_000),displayedComponents:.date).labelsHidden().datePickerStyle(.field).accessibilityLabel(dateTitle) }
                    field("Date basis") {Picker("Date basis",selection:Binding(get:{item.dateBasis ?? "Confirmed"},set:{item.dateBasis=$0})) {ForEach(item.status == "Active" ? ["Confirmed","Estimated"] : OrbitDateBases,id:\.self){Text($0)}}.labelsHidden().accessibilityLabel("Date basis")}
                }
                if item.status == "Active" && item.cycle != "Unknown" {Text("Next occurrence: \(item.dateLabel). Monthly and yearly dates retain the original billing day.").font(.system(size:12)).foregroundStyle(OrbitMutedText)}
            } else {Text("No date is projected until you enter one.").font(.system(size:12)).foregroundStyle(OrbitMutedText)}
            HStack {Toggle("Reminder for this plan",isOn:Binding(get:{item.wantsReminder},set:{item.remindersEnabled=$0})).toggleStyle(.switch).controlSize(.small);Spacer()}.disabled(!item.hasDate || !["Active","Trial","Ending"].contains(item.status) || (item.status == "Active" && !item.canProject))
            if item.wantsReminder {field("Remind me") {Picker("Remind me",selection:$item.reminder) {ForEach(0...30,id:\.self) {n in Text(n == 0 ? "On the day" : "\(n) days before").tag(n)}}.labelsHidden().accessibilityLabel("Remind me")}}
            Text("Reminders appear in Jarvis Messages while Jarvis is running, and catch up when it reopens. Historical review dates do not trigger alerts.").font(.system(size:11)).foregroundStyle(OrbitMutedText).fixedSize(horizontal:false,vertical:true)
        }
    }
    var evidence: some View {
        VStack(alignment:.leading,spacing:18) {
            field("Provider website") { TextField("https://…",text:$item.website).textFieldStyle(.roundedBorder).controlSize(.large).accessibilityLabel("Provider website") }
            if !item.website.isEmpty && !validURL { Text("Enter a full https:// or http:// address.").font(.system(size:12)).foregroundStyle(OrbitReviewTint) }
            HStack {
                if let link=item.evidenceURL,let url=URL(string:link), ["http","https"].contains(url.scheme ?? "") || (url.isFileURL && url.pathExtension.lowercased()=="pdf") {
                    Button(url.isFileURL ? "Open source PDF" : "Open source email") { open(url) }.buttonStyle(.bordered).controlSize(.large)
                }
                if let url=OrbitProviderURL(item.website) { Button("Open provider") {open(url)}.buttonStyle(.bordered).controlSize(.large) }
                Spacer()
            }
            field("Notes & evidence") {
                TextEditor(text:$item.notes).font(.system(size:13)).scrollContentBackground(.hidden).padding(10).frame(minHeight:270).background(OrbitSurface,in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(.white.opacity(0.10))).accessibilityLabel("Notes and evidence")
            }
            Text("Keep receipts, account details and assumptions here. Opening a source or provider does not change your subscription.").font(.system(size:12)).foregroundStyle(OrbitMutedText)
        }
    }
    func field<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {VStack(alignment:.leading,spacing:8) {Text(title).font(.system(size:12,weight:.medium)).foregroundStyle(OrbitMutedText);content()}.frame(maxWidth:.infinity,alignment:.leading)}
    func close() { if dirty {discard=true} else {dismiss()} }
    func open(_ url:URL) {
        if url.isFileURL && !FileManager.default.fileExists(atPath:url.path) {error="The source PDF was moved or is unavailable.";return}
        if !NSWorkspace.shared.open(url) {error="Could not open this source."}
    }
    func submit() {
        guard valid else {return}
        item.name=item.name.trimmingCharacters(in:.whitespacesAndNewlines)
        item.website=item.website.trimmingCharacters(in:.whitespacesAndNewlines)
        if item.hasPrice,let number=parsedAmount {item.amount=number}
        if save(item) {dismiss()} else {error=failure()}
    }
}
