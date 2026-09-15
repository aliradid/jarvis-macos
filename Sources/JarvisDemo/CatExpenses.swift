import SwiftUI
import AppKit
import UniformTypeIdentifiers

let catCategories = ["Food", "Litter", "Vet", "Medication", "Grooming", "Toys", "Supplies", "Other"]
struct CatExpense: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var cat = ""
    var category = "Food"
    var amount = 0.0
    var currency = "MAD"
    var date = Date()
    var notes = ""
    var archived = false
}
struct CatBackup: Codable { var version = 1; var expenses: [CatExpense] }
func validatedCatBackup(_ data: Data) throws -> CatBackup {
    guard data.count <= 10_000_000 else { throw CocoaError(.fileReadTooLarge) }
    let result = try JSONDecoder().decode(CatBackup.self,from:data)
    guard result.version == 1, Set(result.expenses.map(\.id)).count == result.expenses.count,
          result.expenses.allSatisfy({ !$0.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.amount.isFinite && (0...1_000_000_000).contains($0.amount) && OrbitCurrencies.contains($0.currency) && catCategories.contains($0.category) && $0.date.timeIntervalSince1970.isFinite && $0.date > Date(timeIntervalSince1970:0) && $0.date < Date(timeIntervalSince1970:7_258_118_400) }) else { throw CocoaError(.fileReadCorruptFile) }
    return result
}
@MainActor final class CatStore: ObservableObject {
    @Published var items: [CatExpense] = []
    @Published var error: String?
    @Published var notice = ""
    private(set) var readable = true
    init() { items = SampleData.cats }
    @discardableResult func commit(_ next: [CatExpense]) -> Bool {
        guard readable else { error = "Saving is disabled until the existing cat data can be read.";return false }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            let data = try encoder.encode(CatBackup(expenses:next)); _ = try validatedCatBackup(data)
            items = next;error = nil;return true
        } catch { self.error = "Expense not saved: \(error.localizedDescription)";return false }
    }
    func save(_ item: CatExpense) -> Bool {
        var next = items
        if let index = next.firstIndex(where:{$0.id == item.id}) { next[index] = item } else { next.append(item) }
        if commit(next) { notice = "Saved \(item.title).";return true };return false
    }
    func export() {
        guard let window = NSApp.keyWindow else {return}
        let panel = NSSavePanel();panel.nameFieldStringValue = "Orbit-cats-backup.json";panel.allowedContentTypes = [.json]
        panel.beginSheetModal(for:window) { response in
            guard response == .OK,let url = panel.url else {return}
            do {let enc = JSONEncoder();enc.outputFormatting = [.prettyPrinted,.sortedKeys];try enc.encode(CatBackup(expenses:self.items)).write(to:url,options:.atomic);self.notice = "Cat expenses exported."} catch {self.error = "Export failed: \(error.localizedDescription)"}
        }
    }
    func restore() {
        guard let window = NSApp.keyWindow else {return}
        let panel = NSOpenPanel();panel.allowedContentTypes = [.json];panel.allowsMultipleSelection = false
        panel.beginSheetModal(for:window) { response in
            guard response == .OK,let url = panel.url else {return}
            do {
                let incoming = try validatedCatBackup(Data(contentsOf:url)).expenses
                let ids = Set(self.items.map(\.id));let additions = incoming.filter{!ids.contains($0.id)}
                if additions.isEmpty {self.notice = "No new cat expenses to import."}
                else if self.commit(self.items + additions) {self.notice = "Imported \(additions.count) cat expenses."}
            } catch {self.error = "Invalid cat backup. Existing expenses were kept."}
        }
    }
}
struct CatsView: View {
    @ObservedObject var store: CatStore
    @EnvironmentObject var fx: OrbitExchangeRates
    @State private var month = Calendar.current.dateInterval(of:.month,for:Date())!.start
    @State private var search = ""
    @State private var catFilter = "All cats"
    @State private var archived = false
    @State private var editing: CatExpense?
    @FocusState private var searchFocused: Bool
    var cats: [String] { Array(Set(store.items.map(\.cat).filter{!$0.isEmpty})).sorted() }
    var monthItems: [CatExpense] {
        store.items.filter { $0.archived == archived && Calendar.current.isDate($0.date,equalTo:month,toGranularity:.month) && (catFilter == "All cats" || $0.cat == catFilter) }
    }
    var rows: [CatExpense] {
        monthItems.filter {search.isEmpty || [$0.title,$0.cat,$0.category,$0.notes].contains{$0.localizedCaseInsensitiveContains(search)}}.sorted{$0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date}
    }
    var usd: Double { monthItems.compactMap{OrbitUsdValue($0.amount,currency:$0.currency,rates:fx.rates)}.reduce(0,+) }
    var missing: Int { monthItems.filter{OrbitUsdValue($0.amount,currency:$0.currency,rates:fx.rates) == nil}.count }
    func label(_ item: CatExpense) -> String { item.cat.isEmpty ? "All cats / shared" : item.cat }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                VStack(alignment:.leading,spacing:5) { Text("CARE & EXPENSES").font(.system(size:10,weight:.medium)).tracking(1.4).foregroundStyle(OrbitMutedText);Text("Your cats").font(.system(size:26,weight:.semibold)) }
                Spacer()
                Menu {Button("Export cat expenses…") {store.export()};Button("Import cat expenses…") {store.restore()}} label:{Image(systemName:"externaldrive")}.menuStyle(.borderlessButton).frame(width:30).help("Cat expense backups")
                Button {editing = CatExpense()} label:{Label("Add expense",systemImage:"plus")}.buttonStyle(OrbitPrimaryButton()).keyboardShortcut("n",modifiers:.command).disabled(!store.readable)
            }
            HStack(spacing:12) {
                Button {shift(-1)} label:{Image(systemName:"chevron.left")}.accessibilityLabel("Previous month")
                Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size:16,weight:.semibold)).frame(minWidth:155)
                Button {shift(1)} label:{Image(systemName:"chevron.right")}.accessibilityLabel("Next month")
                Button("This month") {month = Calendar.current.dateInterval(of:.month,for:Date())!.start}
                Spacer()
                Picker("Cat",selection:$catFilter) {Text("All cats").tag("All cats");ForEach(cats,id:\.self){Text($0)}}.frame(maxWidth:210)
            }
            HStack(spacing:12) {
                VStack(alignment:.leading,spacing:10) {
                    Text((archived ? "ARCHIVED " : "") + (missing == 0 ? "MONTH TOTAL" : "MONTH SUBTOTAL")).font(.system(size:10,weight:.semibold)).tracking(1)
                    Text(OrbitUsdMoney(usd)).font(.system(size:29,weight:.medium,design:.rounded))
                    Text(fx.madTotal(usd)).font(.system(size:17)).foregroundStyle(OrbitMutedText)
                    Text("\(monthItems.count) \(monthItems.count == 1 ? "expense" : "expenses") · \(catFilter)").font(.system(size:11)).foregroundStyle(OrbitMutedText)
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(OrbitSurface,in:RoundedRectangle(cornerRadius:13))
                VStack(alignment:.leading,spacing:9) {
                    Text("BY CATEGORY · USD").font(.system(size:10,weight:.semibold)).tracking(1)
                    let groups = catCategories.map {category in (category,monthItems.filter{$0.category == category}.compactMap{OrbitUsdValue($0.amount,currency:$0.currency,rates:fx.rates)}.reduce(0,+))}.filter{$0.1 > 0}.sorted{$0.1 > $1.1}
                    if groups.isEmpty {Text("Your spending breakdown will appear here.").foregroundStyle(OrbitMutedText).font(.system(size:12))}
                    ScrollView {VStack(spacing:7) {ForEach(groups,id:\.0) {category,total in HStack {Text(category);Spacer();Text(OrbitUsdMoney(total)).monospacedDigit()}.font(.system(size:12))}}}.frame(maxHeight:95)
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(OrbitSurface,in:RoundedRectangle(cornerRadius:13))
            }
            HStack {Text(fx.status).foregroundStyle(OrbitMutedText);if missing > 0 {Text("\(missing) expenses excluded: FX unavailable").foregroundStyle(OrbitReviewTint)};Spacer()}.font(.system(size:11))
            HStack {
                HStack {Image(systemName:"magnifyingglass").foregroundStyle(OrbitMutedText);TextField("Search cat expenses",text:$search).textFieldStyle(.plain).focused($searchFocused)}.padding(10).background(OrbitSurface,in:RoundedRectangle(cornerRadius:9))
                Toggle("Archived",isOn:$archived).toggleStyle(.checkbox).font(.system(size:12))
            }
            if rows.isEmpty {
                VStack(spacing:12) {Image(systemName:"pawprint.fill").font(.system(size:36)).foregroundStyle(OrbitAccent);Text(search.isEmpty ? "No expenses this month" : "No matching expenses").font(.headline);Text("Track food, litter, vet care and everything else your cats need.").font(.system(size:12)).foregroundStyle(OrbitMutedText);if search.isEmpty && !archived {Button("Add your first expense") {editing = CatExpense()}.buttonStyle(OrbitPrimaryButton()).disabled(!store.readable)}}.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {LazyVStack(spacing:0) {ForEach(rows) {item in
                    Button {editing = item} label:{HStack(spacing:12) {
                        Image(systemName:"pawprint.fill").foregroundStyle(OrbitAccent).frame(width:36,height:36).background(OrbitAccent.opacity(0.08),in:RoundedRectangle(cornerRadius:9))
                        VStack(alignment:.leading,spacing:5) {Text(item.title).font(.system(size:14,weight:.semibold));Text(label(item) + " · " + item.category + " · " + item.date.formatted(.dateTime.day().month(.abbreviated))).font(.system(size:11)).foregroundStyle(OrbitMutedText)}
                        Spacer()
                        VStack(alignment:.trailing,spacing:5) {Text(OrbitUsdValue(item.amount,currency:item.currency,rates:fx.rates).map(OrbitUsdMoney) ?? "USD unavailable").font(.system(size:14,weight:.medium));Text(OrbitMadValue(item.amount,currency:item.currency,rates:fx.rates).map(OrbitMadMoney) ?? "MAD unavailable").font(.system(size:11)).foregroundStyle(OrbitMutedText)}
                        Image(systemName:"chevron.right").font(.system(size:10)).foregroundStyle(OrbitMutedText)
                    }.padding(14).contentShape(Rectangle())}.buttonStyle(.plain)
                    Divider().padding(.leading,62)
                }}}.background(OrbitSurface,in:RoundedRectangle(cornerRadius:12))
            }
            HStack {Text(store.notice.isEmpty ? "Actual expenses for the selected month. Separate from subscription estimates." : store.notice);Spacer()}.font(.system(size:11)).foregroundStyle(OrbitMutedText)
        }.padding(24)
        .sheet(item:$editing) {item in CatExpenseEditor(item:item,store:store).environmentObject(fx)}
        .alert("Cat expenses",isPresented:Binding(get:{store.error != nil && editing == nil},set:{if !$0 {store.error = nil}})) {Button("OK") {store.error = nil}} message:{Text(store.error ?? "")}
        .background(Button("") {searchFocused = true}.keyboardShortcut("f",modifiers:.command).hidden())
    }
    func shift(_ offset: Int) { month = Calendar.current.date(byAdding:.month,value:offset,to:month)! }
}
struct CatExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var fx: OrbitExchangeRates
    @ObservedObject var store: CatStore
    @State var item: CatExpense
    @State private var amount = ""
    @State private var original: CatExpense?
    @State private var discard = false
    @State private var failure: String?
    init(item: CatExpense,store: CatStore) { _item = State(initialValue:item);self.store = store }
    var parsed: Double? {OrbitParsePrice(amount)}
    var valid: Bool {!item.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && parsed != nil}
    var dirty: Bool {guard let original else {return false};return item != original || parsed != original.amount}
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {Text(original?.title.isEmpty == false ? "Edit cat expense" : "New cat expense").font(.system(size:22,weight:.semibold));Spacer();Button {close()} label:{Image(systemName:"xmark")}.buttonStyle(.plain).accessibilityLabel("Close expense editor").keyboardShortcut(.cancelAction)}
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    field("Expense") {TextField("e.g. Food for September",text:$item.title).textFieldStyle(.roundedBorder).accessibilityLabel("Expense title")}
                    field("Cat name (optional)") {TextField("Leave blank for shared expenses",text:$item.cat).textFieldStyle(.roundedBorder).accessibilityLabel("Cat name")}
                    HStack {field("Category") {Picker("Category",selection:$item.category) {ForEach(catCategories,id:\.self){Text($0)}}.labelsHidden()};field("Date paid") {DatePicker("Date paid",selection:$item.date,in:Date(timeIntervalSince1970:1)...Date(timeIntervalSince1970:7_258_118_399),displayedComponents:.date).labelsHidden()}}
                    HStack {field("Amount paid") {TextField("0.00",text:$amount).textFieldStyle(.roundedBorder).accessibilityLabel("Amount paid")};field("Currency") {Picker("Currency",selection:$item.currency) {ForEach(OrbitCurrencies,id:\.self){Text($0)}}.labelsHidden()}}
                    if let value = parsed {Text((OrbitUsdValue(value,currency:item.currency,rates:fx.rates).map(OrbitUsdMoney) ?? "USD unavailable") + " · " + (OrbitMadValue(value,currency:item.currency,rates:fx.rates).map(OrbitMadMoney) ?? "MAD unavailable")).font(.system(size:12)).foregroundStyle(OrbitAccent)}
                    field("Notes") {TextEditor(text:$item.notes).font(.system(size:13)).scrollContentBackground(.hidden).frame(minHeight:100).padding(8).background(OrbitSurface,in:RoundedRectangle(cornerRadius:8)).accessibilityLabel("Expense notes")}
                    if original?.title.isEmpty == false {Toggle("Archive this expense",isOn:$item.archived).help("Archived expenses are kept in history and excluded from normal totals.")}
                }.padding(.vertical,4)
            }
            if let failure {Text(failure).foregroundStyle(OrbitErrorTint).font(.system(size:12))}
            if !valid {Text("Enter a title and a valid non-negative amount.").font(.system(size:11)).foregroundStyle(OrbitMutedText)}
            HStack {Spacer();Button("Cancel") {close()};Button("Save expense") {save()}.buttonStyle(OrbitPrimaryButton()).disabled(!valid).keyboardShortcut("s",modifiers:.command)}
        }.padding(24).frame(width:550,height:min(650,(NSScreen.main?.visibleFrame.height ?? 850)-100)).background(OrbitCanvas).foregroundStyle(OrbitPrimaryText).tint(OrbitAccent).preferredColorScheme(.dark)
        .onAppear {original = item;let f = NumberFormatter();f.numberStyle = .decimal;f.usesGroupingSeparator = false;f.maximumFractionDigits = 8;amount = f.string(from:NSNumber(value:item.amount)) ?? "0"}
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("Discard unsaved expense?",isPresented:$discard,titleVisibility:.visible) {Button("Discard changes",role:.destructive) {dismiss()};Button("Keep editing",role:.cancel) {}}
    }
    func field<C:View>(_ name: String,@ViewBuilder content:()->C)->some View {VStack(alignment:.leading,spacing:7) {Text(name).font(.system(size:12)).foregroundStyle(OrbitMutedText);content()}.frame(maxWidth:.infinity,alignment:.leading)}
    func close() {if dirty {discard = true}else{dismiss()}}
    func save() {guard valid,let value = parsed else {return};item.amount = value;item.title = item.title.trimmingCharacters(in:.whitespacesAndNewlines);item.cat = item.cat.trimmingCharacters(in:.whitespacesAndNewlines);if store.save(item) {dismiss()}else{failure = store.error}}
}
