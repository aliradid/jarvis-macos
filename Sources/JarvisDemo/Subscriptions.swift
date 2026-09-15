import SwiftUI
import AppKit

@MainActor final class SubscriptionStore: ObservableObject {
    @Published private(set) var items: [OrbitSubscription] = []
    @Published var issue: String?
    @Published var loaded = false
    let fx = OrbitExchangeRates()
    init(items: [OrbitSubscription] = SampleData.subscriptions) { self.items = items; loaded = true }
    func load() async {}
    @discardableResult func save(_ item: OrbitSubscription) -> Bool {
        do {
            var next = items
            if let index = next.firstIndex(where: { $0.id == item.id }) { next[index] = item } else { next.append(item) }
            let data = try JSONEncoder().encode(OrbitBackup(subscriptions: next))
            items = try OrbitValidatedBackup(data).subscriptions; issue = nil; return true
        } catch { issue = "Could not save your changes. Existing records were preserved."; return false }
    }
    var totals: String {
        let active = items.filter { $0.status == "Active" && $0.hasPrice && $0.cycle != "Unknown" }
        return Dictionary(grouping: active, by: \.currency).sorted { $0.key < $1.key }.map { currency, rows in
            rows.reduce(0) { $0 + $1.monthly }.formatted(.currency(code: currency))
        }.joined(separator: " + ")
    }
    var upcoming: [OrbitSubscription] {
        items.filter { $0.wantsReminder && (0...30).contains($0.days) }.sorted { $0.nextDate() < $1.nextDate() }
    }
    static func reminders(_ items: [OrbitSubscription], now: Date = Date()) -> [InboxMessage] {
        let today = Calendar.current.startOfDay(for: now)
        return items.compactMap { item in
            guard item.wantsReminder else { return nil }
            let due = item.nextDate(now: now)
            let days = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: due)).day ?? -1
            guard days >= 0 && days <= item.reminder else { return nil }
            let title = item.status == "Ending" ? "Access ends soon" : item.status == "Trial" ? "Trial ending" : item.dateBasis == "Estimated" ? "Estimated renewal" : "Renewal coming up"
            return InboxMessage(id: "subscription:\(item.id.uuidString):\(Int(Calendar.current.startOfDay(for: due).timeIntervalSince1970))", date: now, source: "Subscriptions", title: title,
                detail: "\(item.name) · \(due.formatted(date: .abbreviated, time: .omitted)) · \(item.status == "Ending" ? "Renewal is off" : item.money)", kind: "subscription", path: item.id.uuidString)
        }
    }
}

struct SubscriptionsPage: View {
    @ObservedObject var store: SubscriptionStore
    @ObservedObject var fx: OrbitExchangeRates
    var selectedID: String?
    var initialQuery: String
    var selectionConsumed: () -> Void
    @State private var initialized = false
    @State private var section = "Overview"
    @State private var search = ""
    @State private var editing: OrbitSubscription?
    @State private var sort = "Highest cost"
    @FocusState private var searchFocused: Bool
    private var refresh: Date { Date() }
    var source: [OrbitSubscription] { store.items }
    init(store: SubscriptionStore, selectedID: String? = nil, initialQuery: String = "", selectionConsumed: @escaping () -> Void = {}) {
        self.store = store; self.fx = store.fx; self.selectedID = selectedID
        self.initialQuery = initialQuery; self.selectionConsumed = selectionConsumed
    }
    var live: [OrbitSubscription] { source.filter { $0.isRecurring } }
    var total: OrbitUSDTotal { OrbitUsdTotal(source,rates:fx.rates) }
    var upcoming: [OrbitSubscription] { source.filter { ($0.isRecurring || $0.effectiveStatus == "Ending") && $0.hasDate && ($0.status != "Active" || $0.canProject) && (0...30).contains($0.days) }.sorted { $0.nextDate() < $1.nextDate() } }
    var rows: [OrbitSubscription] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return source.filter { s in
            let match = section == "Archived" ? s.effectiveStatus == "Archived" : section == "Needs review" ? s.status == "Needs review" : section == "Ending" ? s.effectiveStatus == "Ending" : section == "Free trials" ? s.status == "Trial" : s.effectiveStatus != "Archived"
            return match && (query.isEmpty || [s.name,s.category,s.currency,s.notes,s.status].contains { $0.localizedCaseInsensitiveContains(query) })
        }.sorted { a,b in
            if sort == "Highest cost" { return OrbitHigherMonthlyCost(a,b,rates:fx.rates) }
            if sort == "Next date" && section == "Overview" {
                let rank=["Active":0,"Trial":1,"Ending":2,"Needs review":3,"Archived":4]
                if rank[a.effectiveStatus,default:4] != rank[b.effectiveStatus,default:4] { return rank[a.effectiveStatus,default:4] < rank[b.effectiveStatus,default:4] }
            }
            if sort == "Name" { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
            if sort == "Category" && a.category != b.category { return a.category < b.category }
            let ad = a.hasDate ? a.nextDate() : .distantFuture, bd = b.hasDate ? b.nextDate() : .distantFuture
            return ad == bd ? a.name < b.name : ad < bd
        }
    }
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.hexagongrid.fill").foregroundStyle(OrbitAccent)
                        Text("orbit").font(.system(size: 24, weight: .semibold, design: .rounded))
                    }.padding(.top, 8)
                    VStack(spacing: 5) {
                        nav("Overview", "square.grid.2x2")
                        nav("Free trials", "hourglass")
                        nav("Ending", "stop.circle")
                        nav("Needs review", "exclamationmark.circle")
                        nav("Archived", "archivebox")
                    }
                    Spacer()
                    Label("Reminders in Messages", systemImage: "bell").font(.system(size: 11))
                    Label("Stored on this Mac", systemImage: "lock").font(.system(size: 11)).foregroundStyle(OrbitMutedText)
                }.padding(14).frame(width: 165)
                Divider()
                if geometry.size.height < 620 {
                    ScrollView { dashboard(width: geometry.size.width).frame(height: 760) }
                } else {
                    dashboard(width: geometry.size.width)
                }
            }.background(OrbitCanvas).foregroundStyle(OrbitPrimaryText).tint(OrbitAccent).preferredColorScheme(.dark)
        }.environmentObject(fx)
            .sheet(item: $editing, onDismiss: selectionConsumed) { item in
                OrbitEditor(item: item, save: { store.save($0) }, failure: { store.issue ?? "Saving is unavailable." }).environmentObject(fx)
            }
            .onAppear { if !initialized { search = initialQuery; initialized = true }; openSelected() }
            .onChange(of: initialQuery) { search = $0 }
            .onChange(of: selectedID) { _ in openSelected() }
    }
    private func dashboard(width: CGFloat) -> some View {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    metrics
                    HStack(alignment: .top, spacing: 18) {
                        listPanel
                        if width >= 1000 { timeline.frame(width: 260) }
                    }.frame(maxHeight: .infinity)
                    if width < 1000 {
                        DisclosureGroup("Coming up · \(upcoming.count) events in 30 days") {
                            ScrollView(.horizontal) {
                                HStack(spacing: 12) {
                                    ForEach(upcoming) { s in
                                        Button { editing = s } label: {
                                            VStack(alignment: .leading, spacing: 5) {
                                                HStack(spacing: 6) { OrbitServiceLogo(item: s, size: 20); Text(s.name).fontWeight(.medium) }
                                                Text(s.dateLabel).foregroundStyle(OrbitAccent)
                                                Text(fx.timeline(s)).foregroundStyle(OrbitMutedText)
                                            }.font(.system(size: 12)).frame(width: 185, alignment: .leading).padding(12)
                                                .background(OrbitSurface, in: RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle())
                                        }.buttonStyle(JarvisPlainButtonStyle())
                                    }
                                }
                            }.frame(height: 102)
                        }.font(.system(size: 12)).tint(OrbitAccent)
                    }
                    if let issue = store.issue { Text(issue).font(.caption).foregroundStyle(OrbitReviewTint) }
                }.padding(24)
    }
    private func openSelected() { if let selectedID { editing = store.items.first { $0.id.uuidString == selectedID } } }
    private func archive(_ item: OrbitSubscription) { var next = item; next.status = "Archived"; _ = store.save(next) }
    var header: some View {
        HStack {
            VStack(alignment:.leading,spacing:5) { Text(refresh.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()).font(.system(size:10,weight:.medium)).tracking(1.4).foregroundStyle(OrbitMutedText); Text(section == "Overview" ? "Your subscriptions" : section).font(.system(size:26,weight:.semibold)) }
            Spacer()
            Button { editing=OrbitSubscription() } label: { Label("Add subscription",systemImage:"plus").padding(.horizontal,8).padding(.vertical,6) }.buttonStyle(OrbitPrimaryButton()).tint(OrbitAccent).foregroundStyle(.black).keyboardShortcut("n",modifiers:.command).disabled(!store.loaded || store.issue != nil)
        }
    }
    var metrics: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack(spacing:12) {
                metric(total.complete ? "MONTHLY TOTAL · USD + MAD" : "MONTHLY SUBTOTAL · USD + MAD",OrbitUsdMoney(total.monthly),"All currencies combined",secondaryValue:fx.madTotal(total.monthly))
                metric(total.complete ? "YEARLY TOTAL · USD + MAD" : "YEARLY SUBTOTAL · USD + MAD",OrbitUsdMoney(total.monthly*12),"Estimate at displayed FX rates",secondaryValue:fx.madTotal(total.monthly*12))
                metric("ACTIVE & TRIALS","\(live.count)","\(source.filter{$0.status == "Needs review"}.count) need review")
            }
            HStack(spacing:8) {
                Text(fx.status).foregroundStyle(fx.failure != nil || fx.stale ? OrbitReviewTint : OrbitMutedText)
                Button { Task { await fx.refresh(force:true) } } label: {Image(systemName:"arrow.clockwise")}.buttonStyle(JarvisPlainButtonStyle()).disabled(fx.refreshing).accessibilityLabel("Refresh exchange rates").help("Daily reference rates from Frankfurter. Card fees may differ.")
                Spacer()
                if !total.complete { Text("Excluded: \(total.missingPrices) price unknown · \(total.missingCycles) cycle unknown · \(total.missingRates) FX unavailable").foregroundStyle(OrbitReviewTint) }
            }.font(.system(size:11)).fixedSize(horizontal:false,vertical:true)
        }
    }
    var listPanel: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text("\(rows.count) \(rows.count == 1 ? "record" : "records")").font(.system(size:13,weight:.medium)); Spacer(); Picker("Sort",selection:$sort) { ForEach(["Highest cost","Next date","Name","Category"],id:\.self) { Text($0) } }.frame(width:150) }
            if sort == "Highest cost" { Text("Highest monthly cost first · USD + MAD monthly equivalents · unknown costs last").font(.system(size:11)).foregroundStyle(OrbitMutedText) }
            HStack { Image(systemName:"magnifyingglass").foregroundStyle(OrbitMutedText); TextField("Search services, accounts or notes",text:$search).textFieldStyle(.plain).focused($searchFocused); if !search.isEmpty { Button {search=""} label:{Image(systemName:"xmark.circle.fill")}.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Clear search") } }.padding(10).background(OrbitSurface,in:RoundedRectangle(cornerRadius:9))
            if rows.isEmpty {
                VStack(spacing:14) { Image(systemName:"square.stack.3d.up").font(.system(size:30)).foregroundStyle(OrbitAccent); Text(search.isEmpty ? "No records in this view" : "No matching subscriptions").font(.headline); Text(search.isEmpty ? "Add a subscription or choose another view." : "Try a service name, currency or account email.").font(.system(size:12)).foregroundStyle(OrbitMutedText) }.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView { LazyVStack(spacing:0) { Color.clear.frame(height:0).id("top"); ForEach(rows) { s in
                        Button {editing=s} label: { OrbitSubscriptionRow(item:s) }.buttonStyle(JarvisPlainButtonStyle())
                            .contextMenu { Button("Edit details") {editing=s}; if s.status != "Archived" { Button("Archive subscription") {archive(s)} } }
                        Divider().padding(.leading,58)
                    } }.background(OrbitSurface,in:RoundedRectangle(cornerRadius:12)) }
                    .onChange(of:section) { _ in proxy.scrollTo("top") }.onChange(of:search) { _ in proxy.scrollTo("top") }.onChange(of:sort) { _ in proxy.scrollTo("top")}
                }
            }
            Text("Est. = calculated date. Totals exclude trials, ending plans, review records and unknown prices.").font(.system(size:11)).foregroundStyle(OrbitMutedText).fixedSize(horizontal:false,vertical:true)
        }
    }
    var timeline: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Coming up").font(.system(size:15,weight:.semibold)); Spacer(); Image(systemName:"calendar").foregroundStyle(OrbitMutedText) }
            Text("\(upcoming.count) EVENTS · NEXT 30 DAYS").font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(OrbitMutedText)
            if upcoming.isEmpty { Text("Nothing scheduled in the next 30 days.").font(.system(size:12)).foregroundStyle(OrbitMutedText) }
            ScrollView { VStack(spacing:16) { ForEach(upcoming) { s in
                Button {editing=s} label: {
                    HStack(alignment:.top,spacing:12) {
                        VStack(spacing:3) { Text(s.nextDate().formatted(.dateTime.month(.abbreviated)).uppercased()).font(.system(size:10)); Text(s.nextDate().formatted(.dateTime.day())).font(.system(size:22,weight:.medium)) }.foregroundStyle(OrbitAccent).frame(width:34)
                        VStack(alignment:.leading,spacing:5) { HStack(spacing:6) { OrbitServiceLogo(item:s,size:20); Text(s.name).font(.system(size:13,weight:.medium)) }; Text(fx.timeline(s)).font(.system(size:11)).foregroundStyle(OrbitMutedText) }.frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                    }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                }.buttonStyle(JarvisPlainButtonStyle())
            } } }
            Text("Your plans, tracked locally. Cancel or change billing with the provider.").font(.system(size:11)).foregroundStyle(OrbitMutedText).fixedSize(horizontal:false,vertical:true)
        }.padding(18).background(OrbitSurface,in:RoundedRectangle(cornerRadius:13))
    }
    func nav(_ name:String,_ icon:String)->some View {
        let count = source.filter { s in name == "Overview" ? s.effectiveStatus != "Archived" : name == "Free trials" ? s.status == "Trial" : s.effectiveStatus == name }.count
        return Button {section=name; search=""} label: { HStack(spacing:9) {Image(systemName:icon).frame(width:17); Text(name); Spacer(minLength:2); Text("\(count)").font(.system(size:10)).monospacedDigit().foregroundStyle(OrbitMutedText)}.font(.system(size:12,weight:.medium)).padding(.horizontal,10).padding(.vertical,12).foregroundStyle(section == name ? OrbitAccent : OrbitMutedText).background(section == name ? OrbitAccent.opacity(0.10) : .clear,in:RoundedRectangle(cornerRadius:8)) }.buttonStyle(JarvisPlainButtonStyle())
    }
    func metric(_ title:String,_ value:String,_ subtitle:String,secondaryValue:String? = nil)->some View { VStack(alignment:.leading,spacing:14) { Text(title).font(.system(size:10,weight:.semibold)).tracking(1).foregroundStyle(OrbitMutedText); Text(value).font(.system(size:29,weight:.medium,design:.rounded)).lineLimit(1).minimumScaleFactor(0.6); if let secondaryValue { Text(secondaryValue).font(.system(size:17,weight:.medium,design:.rounded)).foregroundStyle(OrbitMutedText).lineLimit(1).minimumScaleFactor(0.6) }; Text(subtitle).font(.system(size:11)).foregroundStyle(OrbitMutedText) }.padding(17).frame(maxWidth:.infinity,alignment:.leading).background(OrbitSurface,in:RoundedRectangle(cornerRadius:13)) }
}
