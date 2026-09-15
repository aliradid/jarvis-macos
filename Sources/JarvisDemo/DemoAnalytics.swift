import SwiftUI
import Charts

// Entirely synthetic values, generated independently of the personal app's stores.
struct DemoChannelDay: Identifiable {
    let channel: String
    let day: Int
    let views: Int
    let rpm: Double
    var id: String { "\(channel)-\(day)" }
    var revenue: Double { Double(views) * rpm / 1000 }
}
enum DemoAnalyticsData {
    static let channels = ["Channel A", "Channel B", "Channel C"]
    static let days: [DemoChannelDay] = channels.enumerated().flatMap { index, name in
        (1...30).map { day in
            DemoChannelDay(channel: name, day: day,
                views: 1800 + index * 1100 + day * (85 + index * 14) + (day * 137 + index * 233) % 1600,
                rpm: 1.4 + Double(index) * 0.65 + Double((day * 7 + index * 3) % 12) / 10)
        }
    }
}

struct DemoAnalyticsPage: View {
    var revenue = false
    @State private var channel = "All channels"
    @State private var period = 30
    private var rows: [DemoChannelDay] {
        DemoAnalyticsData.days.filter { $0.day > 30 - period && (channel == "All channels" || $0.channel == channel) }
    }
    private var views: Int { rows.reduce(0) { $0 + $1.views } }
    private var earnings: Double { rows.reduce(0) { $0 + $1.revenue } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(revenue ? "Revenue & RPM" : "YouTube overview").font(.system(size: 19, weight: .semibold))
                Spacer()
                Picker("Channel", selection: $channel) { Text("All channels").tag("All channels"); ForEach(DemoAnalyticsData.channels, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 165)
                Picker("Period", selection: $period) { Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented).labelsHidden().frame(width: 150)
            }
            Text("Fictional channels and generated figures. These are not account reports.").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                metric("Views", value: views.formatted())
                metric("Revenue · USD", value: earnings.formatted(.currency(code: "USD")))
                metric("RPM · USD", value: (views == 0 ? 0 : earnings / Double(views) * 1000).formatted(.currency(code: "USD")))
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(revenue ? "RPM by channel" : "Daily views").font(.system(size: 14, weight: .medium))
                Chart(rows) { row in
                    LineMark(x: .value("Day", row.day), y: .value(revenue ? "RPM" : "Views", revenue ? row.rpm : Double(row.views)))
                        .foregroundStyle(by: .value("Channel", row.channel))
                }.chartForegroundStyleScale(range: [Palette.accent, Color.purple, Palette.online])
                    .chartXAxisLabel("Sample day").chartYAxisLabel(revenue ? "USD per 1,000 views" : "Views")
                    .frame(height: 260)
            }.padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("Channel"); Spacer(); Text("Views").frame(width: 110, alignment: .trailing); Text("Revenue").frame(width: 110, alignment: .trailing); Text("RPM").frame(width: 90, alignment: .trailing) }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                ForEach(DemoAnalyticsData.channels.filter { channel == "All channels" || $0 == channel }, id: \.self) { name in
                    let data = rows.filter { $0.channel == name }
                    let totalViews = data.reduce(0) { $0 + $1.views }
                    let totalRevenue = data.reduce(0) { $0 + $1.revenue }
                    HStack {
                        BrandIcon(name: "youtube").frame(width: 22, height: 18)
                        Text(name); Spacer()
                        Text(totalViews.formatted()).frame(width: 110, alignment: .trailing)
                        Text(totalRevenue, format: .currency(code: "USD")).frame(width: 110, alignment: .trailing)
                        Text(totalRevenue / Double(max(1, totalViews)) * 1000, format: .currency(code: "USD")).frame(width: 90, alignment: .trailing)
                    }.font(.system(size: 12)).monospacedDigit()
                    Divider()
                }
            }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
        }
    }
    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 29, weight: .light)).monospacedDigit()
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct DemoExpense: Identifiable {
    let id = UUID()
    let day: Int
    let title: String
    let category: String
    let amount: Double
}
struct DemoSpendingPage: View {
    var pets = false
    @State private var selected = "All"
    @State private var showEditor = false
    @State private var title = ""
    @State private var amount = ""
    @State private var category = "Software"
    @State private var expenses: [DemoExpense] = [
        .init(day: 2, title: "Creative tools", category: "Software", amount: 24),
        .init(day: 5, title: "Online course", category: "Learning", amount: 35),
        .init(day: 8, title: "Cloud storage", category: "Services", amount: 6),
        .init(day: 12, title: "Development hosting", category: "Services", amount: 10),
        .init(day: 17, title: "Design library", category: "Software", amount: 18),
        .init(day: 22, title: "Reference book", category: "Learning", amount: 22),
        .init(day: 28, title: "Editor renewal", category: "Software", amount: 24)
    ]
    @State private var petExpenses: [DemoExpense] = [
        .init(day: 3, title: "Food", category: "Food", amount: 28),
        .init(day: 10, title: "Supplies", category: "Supplies", amount: 16),
        .init(day: 15, title: "Routine care", category: "Care", amount: 45),
        .init(day: 24, title: "Food", category: "Food", amount: 28)
    ]
    private var categories: [String] { pets ? ["Food", "Supplies", "Care"] : ["Software", "Services", "Learning"] }
    private var rows: [DemoExpense] { (pets ? petExpenses : expenses).filter { selected == "All" || $0.category == selected } }
    private var newAmount: Double? { guard let value = Double(amount), value.isFinite, value > 0, value <= 1000000 else { return nil }; return value }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(pets ? "Pet expenses" : "Subscriptions & expenses").font(.system(size: 19, weight: .semibold))
                Spacer()
                Picker("Category", selection: $selected) { Text("All categories").tag("All"); ForEach(categories, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 160)
                Button("Add expense") { category = categories[0]; showEditor = true }
            }
            Text("Sample records and amounts in EUR. Edits stay in this demo session; these are not provider prices.").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Total · Sample month").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text(rows.reduce(0) { $0 + $1.amount }, format: .currency(code: "EUR")).font(.system(size: 32, weight: .light))
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recorded expenses").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text("\(rows.count)").font(.system(size: 32, weight: .light))
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            }
            Chart(categories, id: \.self) { name in
                BarMark(x: .value("Category", name), y: .value("EUR", rows.filter { $0.category == name }.reduce(0) { $0 + $1.amount }))
                    .foregroundStyle(Palette.accent)
            }.frame(height: 210).padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            VStack(spacing: 14) {
                HStack { Text("Expense"); Spacer(); Text("Category").frame(width: 110, alignment: .leading); Text("EUR").frame(width: 90, alignment: .trailing) }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                ForEach(rows.sorted { $0.day > $1.day }) { expense in
                    HStack { Text("Day \(expense.day)").font(.system(size: 10)).foregroundStyle(Palette.muted).frame(width: 50, alignment: .leading); Text(expense.title); Spacer(); Text(expense.category).foregroundStyle(Palette.muted).frame(width: 110, alignment: .leading); Text(expense.amount, format: .currency(code: "EUR")).frame(width: 90, alignment: .trailing) }.font(.system(size: 12))
                    Divider()
                }
            }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
        }.sheet(isPresented: $showEditor) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add a sample expense").font(.headline)
                TextField("Description", text: $title)
                TextField("Amount in EUR", text: $amount)
                Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                HStack { Button("Cancel") { showEditor = false }; Spacer(); Button("Add") {
                    guard let value = newAmount else { return }
                    let expense = DemoExpense(day: 30, title: title.trimmingCharacters(in: .whitespacesAndNewlines), category: category, amount: value)
                    if pets { petExpenses.append(expense) } else { expenses.append(expense) }
                    title = ""; amount = ""; showEditor = false
                }.disabled(newAmount == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.textFieldStyle(.roundedBorder).padding(24).frame(width: 360).preferredColorScheme(.dark)
        }
    }
}
