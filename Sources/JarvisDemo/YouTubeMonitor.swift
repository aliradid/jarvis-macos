import SwiftUI
import Charts

struct YouTubeDay: Codable, Identifiable {
    var day: String
    var views: Double
    var watchMinutes: Double
    var gained: Double
    var lost: Double
    var engagedViews: Double? = nil
    var id: String { day }
}
struct YouTubeVideo: Codable, Identifiable {
    var id: String
    var title: String
    var views: Double
}
struct YouTubeChannelSnapshot: Codable, Identifiable {
    var id: String
    var name: String
    var fetchedAt: Date
    var startDate: String
    var endDate: String
    var days: [YouTubeDay]
    var videos: [YouTubeVideo]
    var issue: String?
    var financials: YouTubeFinancials? = nil
    var details: YouTubeDetails? = nil
    var views: Double { days.reduce(0) { $0 + $1.views } }
    var hours: Double { days.reduce(0) { $0 + $1.watchMinutes } / 60 }
    var subscribers: Double { days.reduce(0) { $0 + $1.gained - $1.lost } }
    var dataThrough: String { days.map(\.day).max() ?? "Unavailable" }
}
struct YouTubeSnapshot: Codable {
    var version: Int
    var checkedAt: Date
    var channels: [YouTubeChannelSnapshot]
    var issue: String?
    var competitors: [YouTubeCompetitor]? = nil
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 2_000_000 else { throw CocoaError(.fileReadTooLarge) }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(Self.self, from: data)
        guard value.version == 1, value.channels.count <= 20, Set(value.channels.map(\.id)).count == value.channels.count,
              value.channels.allSatisfy({ c in
                  c.id.range(of: "^UC[A-Za-z0-9_-]{22}$", options: .regularExpression) != nil && c.name.count <= 200 && c.days.count <= 366 && c.videos.count <= 20 && Set(c.days.map(\.day)).count == c.days.count && c.days.allSatisfy { d in
                      d.day.range(of: "^20[0-9]{2}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil && [d.views,d.watchMinutes,d.gained,d.lost,d.engagedViews ?? 0].allSatisfy { $0.isFinite && $0 >= 0 }
                  } && c.videos.allSatisfy { $0.id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil && $0.views.isFinite && $0.views >= 0 && $0.title.count <= 1000 }
              }) else { throw CocoaError(.fileReadCorruptFile) }
        guard value.channels.allSatisfy({ ($0.details?.valid ?? true) && ($0.financials?.valid ?? true) }), (value.competitors ?? []).count <= 12,
              Set((value.competitors ?? []).map(\.id)).count == (value.competitors ?? []).count,
              (value.competitors ?? []).allSatisfy({ $0.valid }) else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
}
@MainActor final class YouTubeMonitorStore: ObservableObject {
    @Published var snapshot: YouTubeSnapshot?
    @Published var issue: String?
    init() { snapshot = SampleData.youtube }
    func reload() async { snapshot = SampleData.youtube; issue = nil }
}


struct YouTubeRecentVideo: Codable, Identifiable {
    var id: String
    var title: String
    var views: Double
    var duration: Int
    var publishedAt: String?
    var first3: Double?
    var first7: Double?
    var fetchedAt: Date?
    var issue: String?
    var lengthGroup: String { duration > 180 ? "Over 3 min" : duration > 0 ? "Up to 3 min" : "Unknown length" }
    func measured(_ age: Int) -> Double? { age == 3 ? first3 : first7 }
    var valid: Bool { ytVideoID(id) && title.count <= 1000 && duration >= 0 && duration < 86400 && [views, first3 ?? 0, first7 ?? 0].allSatisfy { $0.isFinite && $0 >= 0 } }
}
struct YouTubeRevenueDay: Codable, Identifiable {
    var day: String
    var amount: Double
    var id: String { day }
}
struct YouTubeDetails: Codable {
    var recent: [YouTubeRecentVideo]?
    var uploadsAt: Date?
    var uploadsIssue: String?
    var revenue: [YouTubeRevenueDay]?
    var revenueAt: Date?
    var revenueIssue: String?
    var currency: String?
    var valid: Bool {
        let videos = recent ?? [], days = revenue ?? []
        return videos.count <= 20 && Set(videos.map(\.id)).count == videos.count && videos.allSatisfy(\.valid)
            && days.count <= 366 && Set(days.map(\.day)).count == days.count && days.allSatisfy { ytDate($0.day) != nil && $0.amount.isFinite && $0.amount >= 0 }
            && (currency == nil || currency!.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil)
    }
}
struct YouTubeBreakout: Codable, Identifiable {
    var id: String
    var title: String
    var views: Double
    var multiplier: Double
    var date: String
}
struct YouTubeCompetitor: Codable, Identifiable {
    var id: String
    var name: String
    var fetchedAt: Date
    var videos: [YouTubeBreakout]
    var issue: String?
    var valid: Bool { id.range(of: "^UC[A-Za-z0-9_-]{22}$", options: .regularExpression) != nil && name.count <= 200 && videos.count <= 10 && Set(videos.map(\.id)).count == videos.count && videos.allSatisfy { ytVideoID($0.id) && $0.title.count <= 1000 && [$0.views,$0.multiplier].allSatisfy { $0.isFinite && $0 >= 0 } } }
}
private func ytVideoID(_ id: String) -> Bool { id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil }
private let ytDayFormatter: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f
}()
func ytDate(_ day: String) -> Date? { guard day.count == 10 else { return nil }; return ytDayFormatter.date(from: day) }
func ytDay(_ date: Date) -> String { ytDayFormatter.string(from: date) }
func ytMedian(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }; let s = values.sorted(), m = s.count / 2
    return s.count.isMultiple(of: 2) ? (s[m-1] + s[m]) / 2 : s[m]
}
struct YouTubeWeek {
    var current: Double
    var previous: Double
    var change: Double? { previous > 0 ? (current / previous - 1) * 100 : nil }
}
extension YouTubeChannelSnapshot {
    func week(through: String) -> YouTubeWeek? {
        guard let end = ytDate(through) else { return nil }
        let indexed = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0.views) })
        let dates = (0..<14).map { ytDay(end.addingTimeInterval(Double(-$0) * 86400)) }
        guard dates.allSatisfy({ indexed[$0] != nil }) else { return nil }
        return YouTubeWeek(current: dates.prefix(7).reduce(0) { $0 + indexed[$1]! }, previous: dates.suffix(7).reduce(0) { $0 + indexed[$1]! })
    }
    func benchmark(_ video: YouTubeRecentVideo, age: Int) -> (median: Double, count: Int)? {
        guard video.duration > 0 else { return nil }
        let peers = (details?.recent ?? []).filter { $0.id != video.id && $0.lengthGroup == video.lengthGroup && $0.issue == nil }.compactMap { $0.measured(age) }
        guard peers.count >= 3, let median = ytMedian(peers), median > 0 else { return nil }
        return (median, peers.count)
    }
    var revenueLastWeek: (rpm: Double?, from: String, through: String)? {
        let revenue = Dictionary(uniqueKeysWithValues: (details?.revenue ?? []).map { ($0.day, $0.amount) })
        let views = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0.views) })
        guard let lastRevenue = revenue.keys.max(), let lastViews = views.keys.max(),
              let end = ytDate(min(lastRevenue, lastViews)) else { return nil }
        let dates = (0..<7).map { ytDay(end.addingTimeInterval(Double(-$0) * 86400)) }
        guard dates.allSatisfy({ revenue[$0] != nil && views[$0] != nil }) else { return nil }
        let totalRevenue = dates.reduce(0) { $0 + revenue[$1]! }
        let engaged = engagedByDay
        let totalEngaged = dates.allSatisfy { engaged[$0] != nil } ? dates.reduce(0) { $0 + engaged[$1]! } : 0
        return (totalEngaged > 0 ? totalRevenue / totalEngaged * 1000 : nil, dates[6], dates[0])
    }
    private var engagedByDay: [String: Double] {
        Dictionary(uniqueKeysWithValues: days.compactMap { d in d.engagedViews.map { (d.day, $0) } })
    }
    var revenueMatched: (amount: Double, rpm: Double?, from: String, through: String, count: Int)? {
        let revenue = details?.revenue ?? []
        let indexed = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0.views) })
        let matched = revenue.filter { indexed[$0.day] != nil }.sorted { $0.day < $1.day }
        guard let first = matched.first, let last = matched.last else { return nil }
        let amount = matched.reduce(0) { $0 + $1.amount }
        let engaged = engagedByDay
        let totalEngaged = matched.allSatisfy { engaged[$0.day] != nil } ? matched.reduce(0) { $0 + engaged[$1.day]! } : 0
        return (amount, totalEngaged > 0 ? amount / totalEngaged * 1000 : nil, first.day, last.day, matched.count)
    }
}
struct YouTubeFinding: Identifiable {
    var id: String
    var channel: String
    var title: String
    var explanation: String
    var url: URL
}
func ytFindings(_ snapshot: YouTubeSnapshot, now: Date) -> [YouTubeFinding] {
    let end = snapshot.channels.compactMap { $0.days.map(\.day).max() }.min() ?? ""
    var findings: [YouTubeFinding] = []
    for c in snapshot.channels {
        let url = URL(string: "https://example.com/channel/" + c.id)!
        if now.timeIntervalSince(c.fetchedAt) > 8 * 3600 || c.issue != nil {
            findings.append(.init(id:c.id+"stale",channel:c.name,title:"Report needs a refresh",explanation:"Showing saved analytics. Check the Nexlev connection and scheduled refresh in Codex.",url:URL(string:"https://dashboard.nexlev.io/analytics")!))
        }
        if let change = c.week(through:end)?.change, change <= -20 {
            findings.append(.init(id:c.id+"views",channel:c.name,title:"Views down \(Int(abs(change)))%",explanation:"Last 7 reported days versus the previous 7. Review recent uploads and traffic in Studio.",url:url))
        }
        if c.details?.uploadsIssue == nil, let newest = c.details?.recent?.compactMap(\.publishedAt).max(), let date = ISO8601DateFormatter().date(from:newest), let fetched = c.details?.uploadsAt, now.timeIntervalSince(fetched) < 8*3600, now.timeIntervalSince(date) > 7*86400 {
            findings.append(.init(id:c.id+"gap",channel:c.name,title:"No upload for \(Int(now.timeIntervalSince(date)/86400)) days",explanation:"Latest public upload in the returned list. Check whether the publishing pause is intentional.",url:url))
        }
        if let video = c.details?.recent?.first(where: { v in
            guard v.issue == nil, let views = v.first7, let base = c.benchmark(v,age:7) else { return false }; return views < base.median * 0.5
        }) {
            findings.append(.init(id:c.id+"video",channel:c.name,title:"A video is below its peers",explanation:video.title + " · Below half the median at 7 complete days. Review its topic and packaging.",url:URL(string:"https://example.com/video/"+video.id)!))
        }
    }
    return findings
}

struct YouTubeMonitorPage: View {
    @ObservedObject var store: YouTubeMonitorStore
    var revenueOnly = false
    var referenceDate: Date = Date()
    @State private var section = "Overview"
    @State private var age = 7
    @State private var bestFirst = false
    @State private var watchedOnly = false
    @State private var revenueDetailsOpen = false
    @State private var hiddenCompetitors = ""
    private var activeSection: String { revenueOnly ? "Revenue" : section }
    private let sections = ["Overview", "Videos", "What’s working", "Competitors"]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let issue = store.issue ?? store.snapshot?.issue { Text(issue).font(.callout).foregroundStyle(OLED.offline) }
            if let snapshot = store.snapshot, !snapshot.channels.isEmpty {
                if !revenueOnly {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) { ForEach(sections, id: \.self) { name in
                        Button { section = name } label: {
                            Text(name).font(.system(size: 12, weight: activeSection == name ? .semibold : .regular)).padding(.horizontal, 13).padding(.vertical, 9)
                                .foregroundStyle(activeSection == name ? OLED.accent : OLED.muted)
                                .background(activeSection == name ? OLED.accent.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(JarvisPlainButtonStyle()).accessibilityAddTraits(activeSection == name ? .isSelected : [])
                    } }
                }
                }
                if activeSection == "Overview" { overview(snapshot) }
                else if activeSection == "Competitors" { competitors(snapshot) }
                else if activeSection == "Revenue" {
                    YouTubeComparisonChart(channels: snapshot.channels)
                    revenueSummary(snapshot.channels)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(snapshot.channels) { c in
                            VStack(alignment: .leading, spacing: 14) {
                                Text(c.name).font(.system(size: 20, weight: .semibold))
                                if activeSection == "Videos" { recentVideos(c) }
                                else if activeSection == "What’s working" { working(c) }

                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                Divider()
                Text("Nexlev / YouTube Analytics · Fictional sample report. Reload restores the sample data. Analytics can arrive several days late.")
                    .font(.system(size: 10)).foregroundStyle(OLED.muted).fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment:.leading, spacing:10) { Text("Your channels will appear here").font(.headline); Text("Connect your channels in Nexlev, then let the scheduled report finish.").foregroundStyle(OLED.muted); Link("Connect in Nexlev",destination:URL(string:"https://dashboard.nexlev.io/analytics")!) }.padding(.vertical,30)
            }
        }.foregroundStyle(OLED.text)
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment:.leading, spacing:5) {
                Text(revenueOnly ? "Revenue" : "YouTube").font(.system(size:25,weight:.semibold))
                if let s = store.snapshot { Text("Checked \(s.checkedAt.formatted(date:.abbreviated,time:.shortened))").font(.caption).foregroundStyle(referenceDate.timeIntervalSince(s.checkedAt)>30*3600 ? OLED.offline : OLED.muted) }
            }
            Spacer()
            Link(destination:URL(string:"https://dashboard.nexlev.io/analytics")!) { Label("Nexlev",systemImage:"arrow.up.right") }.font(.caption)
            Button { Task { await store.reload() } } label: { Image(systemName:"arrow.clockwise").padding(5) }.buttonStyle(JarvisPlainButtonStyle()).help("Reload saved report").accessibilityLabel("Reload saved YouTube report")
        }
    }
    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment:.leading,spacing:5) { Text(text).font(.system(size:16,weight:.semibold)); Text(subtitle).font(.system(size:11)).foregroundStyle(OLED.muted).fixedSize(horizontal:false,vertical:true) }
    }
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment:.leading,spacing:6) { Text(label).font(.caption).foregroundStyle(OLED.muted); Text(value).font(.system(size:23,weight:.medium)).monospacedDigit() }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private func count(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private func delta(_ value: Double?) -> String { guard let value else { return "—" }; return (value >= 0 ? "+" : "") + value.formatted(.number.precision(.fractionLength(1))) + "%" }
    private func overview(_ s: YouTubeSnapshot) -> some View {
        let end = s.channels.compactMap { $0.days.map(\.day).max() }.min() ?? ""
        return ViewThatFits(in:.horizontal) {
            HStack(alignment:.top,spacing:24) { overviewMain(s,end:end).frame(minWidth:420); attention(s).frame(width:225) }
            VStack(alignment:.leading,spacing:24) { overviewMain(s,end:end); attention(s) }
        }
    }
    private func overviewMain(_ s: YouTubeSnapshot, end: String) -> some View {
        let weeks = s.channels.compactMap { $0.week(through:end) }
        let total = weeks.reduce(0) { $0 + $1.current }, previous = weeks.reduce(0) { $0 + $1.previous }
        return VStack(alignment:.leading,spacing:20) {
            HStack(spacing:20) {
                stat("Views · last 7 reported days",weeks.count == s.channels.count ? count(total) : "Incomplete")
                stat("Versus previous 7",weeks.count == s.channels.count && previous > 0 ? delta((total/previous-1)*100) : "—")
            }
            title("Your channels", "Same 7-day window ending \(end.isEmpty ? "—" : end). Select a channel to inspect its videos.")
            Grid(alignment:.leading,horizontalSpacing:14,verticalSpacing:13) {
                GridRow { Text("CHANNEL"); Text("VIEWS"); Text("CHANGE") }.font(.system(size:10)).foregroundStyle(OLED.muted)
                ForEach(s.channels) { c in
                    GridRow {
                        Button { section = "Videos" } label: { HStack(spacing:7) { Circle().fill(color(c,s)).frame(width:6,height:6); Text(c.name).font(.system(size:12,weight:.medium)); Image(systemName:"chevron.right").font(.system(size:9)) } }.buttonStyle(JarvisPlainButtonStyle())
                        Text(c.week(through:end).map { count($0.current) } ?? "—").monospacedDigit()
                        Text(delta(c.week(through:end)?.change)).monospacedDigit().foregroundStyle((c.week(through:end)?.change ?? 0) < 0 ? OLED.offline : OLED.online)
                    }.font(.system(size:12))
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            Divider()
            title("Daily momentum", "Views across all channels · last 14 reported days")
            Chart {
                ForEach(s.channels) { c in
                    ForEach(c.days.filter { d in guard let e = ytDate(end), let date = ytDate(d.day) else { return false }; return date <= e && date > e.addingTimeInterval(-14*86400) }) { d in
                        LineMark(x:.value("Day",d.day),y:.value("Views",d.views),series:.value("Channel",c.name)).foregroundStyle(color(c,s)).lineStyle(StrokeStyle(lineWidth:2))
                    }
                }
            }.chartXAxis(.hidden).chartYAxis { AxisMarks(position:.leading) }.frame(height:160)
            HStack { Text(ytDate(end).map { ytDay($0.addingTimeInterval(-13*86400)) } ?? ""); Spacer(); Text(end) }.font(.caption2).foregroundStyle(OLED.muted)
            Text("A dash means insufficient matching days, or a zero comparison baseline.").font(.caption).foregroundStyle(OLED.muted)
        }.padding(18).background(OLED.surface,in:RoundedRectangle(cornerRadius:12))
    }
    private func color(_ c: YouTubeChannelSnapshot, _ s: YouTubeSnapshot) -> Color {
        let colors: [Color] = [OLED.accent,Color(red:0.55,green:0.65,blue:1),OLED.online,Color(red:0.94,green:0.53,blue:0.66)]
        return colors[(s.channels.firstIndex(where: { $0.id == c.id }) ?? 0) % colors.count]
    }
    private func attention(_ s: YouTubeSnapshot) -> some View {
        let findings = ytFindings(s,now:referenceDate)
        return VStack(alignment:.leading,spacing:14) {
            HStack { Text("Needs attention").font(.system(size:15,weight:.semibold)); Spacer(); Text("\(findings.count)").foregroundStyle(OLED.accent).monospacedDigit() }
            if findings.isEmpty { Label("No alerts in this report",systemImage:"checkmark.circle").font(.callout).foregroundStyle(OLED.online); Text("Checks cover view drops, upload gaps and videos below their peers.").font(.caption).foregroundStyle(OLED.muted) }
            ForEach(findings) { f in
                VStack(alignment:.leading,spacing:6) {
                    Text(f.channel).font(.caption).foregroundStyle(OLED.muted)
                    Text(f.title).font(.system(size:13,weight:.semibold)).foregroundStyle(OLED.offline)
                    Text(f.explanation).font(.system(size:11)).foregroundStyle(OLED.muted).fixedSize(horizontal:false,vertical:true)
                    Link("Review ↗",destination:f.url).font(.caption)
                }
                Divider()
            }
        }.padding(.top,4)
    }
    private func thumbnail(_ id: String) -> some View {
        Rectangle().fill(OLED.border).overlay(Image(systemName:"play.rectangle").foregroundStyle(OLED.muted))
            .frame(width:88,height:50).clipped().clipShape(RoundedRectangle(cornerRadius:5)).accessibilityHidden(true)
    }
    @ViewBuilder private func recentVideos(_ c: YouTubeChannelSnapshot) -> some View {
        let videos = (c.details?.recent ?? []).sorted { a,b in bestFirst ? (a.measured(age) ?? -1) > (b.measured(age) ?? -1) : (a.publishedAt ?? "") > (b.publishedAt ?? "") }
        title("How your uploads start", "First \(age) complete Pacific calendar days after publication. Compared with other measured uploads of the same length group in this channel.")
        HStack { Picker("Compare at",selection:$age) { Text("3 days").tag(3); Text("7 days").tag(7) }.pickerStyle(.segmented).labelsHidden().frame(width:150); Spacer(); Toggle("Highest views first",isOn:$bestFirst).toggleStyle(.checkbox).font(.caption) }
        if let issue = c.details?.uploadsIssue { Text(issue).font(.caption).foregroundStyle(OLED.offline) }
        if videos.isEmpty { Text("Recent-video analytics have not arrived yet.").foregroundStyle(OLED.muted) }
        LazyVStack(spacing:0) {
            ForEach(videos) { v in
                HStack(spacing:12) {
                    Link(destination:URL(string:"https://example.com/video/"+v.id)!) { thumbnail(v.id) }.buttonStyle(JarvisPlainButtonStyle())
                    VStack(alignment:.leading,spacing:5) {
                        Link(v.title,destination:URL(string:"https://example.com/video/"+v.id)!).font(.system(size:12,weight:.medium)).lineLimit(2)
                        Text((v.publishedAt.map { String($0.prefix(10)) } ?? "Date unavailable") + " · " + v.lengthGroup).font(.system(size:10)).foregroundStyle(OLED.muted)
                        if let issue = v.issue { Text(issue).font(.caption2).foregroundStyle(OLED.offline) }
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    VStack(alignment:.trailing,spacing:5) {
                        Text(v.measured(age).map(count) ?? "Pending").font(.system(size:15,weight:.medium)).monospacedDigit()
                        if let views = v.measured(age), let base = c.benchmark(v,age:age) {
                            Text(String(format:"%.1f× peers",views/base.median)).font(.caption).foregroundStyle(views >= base.median ? OLED.online : OLED.offline).help("Median of \(base.count) other measured uploads: \(count(base.median)) views")
                        } else { Text(v.measured(age) == nil ? "Window incomplete" : "Needs 3 peers").font(.system(size:10)).foregroundStyle(OLED.muted) }
                    }.frame(width:115,alignment:.trailing)
                }.padding(.vertical,12)
                Divider()
            }
        }
        Text("Latest 20 returned uploads. ‘Pending’ means some daily rows are missing or the video is too new. Length groups are not YouTube Shorts classifications. Peer comparisons are descriptive, not a prediction.").font(.caption).foregroundStyle(OLED.muted)
    }
    private struct Topic: Identifiable { var name: String; var values: [Double]; var id: String { name }; var median: Double { ytMedian(values) ?? 0 } }
    private func topics(_ c: YouTubeChannelSnapshot) -> [Topic] {
        let names = ["Marquez","Martin","Bagnaia","Bezzecchi","Quartararo","Bulega","Toprak","Ducati","Yamaha","Aprilia","Honda","KTM"]
        return names.compactMap { name in
            let values = (c.details?.recent ?? []).filter { $0.title.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"en_US_POSIX")).contains(name.lowercased()) && $0.issue == nil }.compactMap { v -> Double? in guard let views=v.first7, let base=c.benchmark(v,age:7) else { return nil }; return views/base.median }
            return values.count >= 3 ? Topic(name:name,values:values) : nil
        }.sorted { $0.median > $1.median }
    }
    @ViewBuilder private func working(_ c: YouTubeChannelSnapshot) -> some View {
        let grouped = topics(c)
        title("What’s working", "Topic signals from the latest measured uploads · seven complete days · this channel only")
        Text("Titles are grouped by rider or manufacturer names. Videos can belong to several topics. These are small-sample associations, not proof that a topic caused more views.").font(.caption).foregroundStyle(OLED.muted)
        if grouped.isEmpty { Text("Not enough comparable videos yet. A topic needs at least 3 measured uploads, each with 3 peers.").foregroundStyle(OLED.muted).padding(.vertical,16) }
        ForEach(grouped) { t in
            HStack { Text(t.name).font(.system(size:14,weight:.medium)).frame(width:115,alignment:.leading); Text("\(t.values.count) videos").font(.caption).foregroundStyle(OLED.muted); Spacer(); Text(String(format:"%.2f× peer median",t.median)).monospacedDigit().foregroundStyle(t.median>=1 ? OLED.online : OLED.offline) }.padding(.vertical,9)
            Divider()
        }
        title("Length groups", "Median seven-day views. Upload length is a useful comparison group, not a content-format diagnosis.")
        ForEach(["Up to 3 min","Over 3 min"],id:\.self) { group in
            let values = (c.details?.recent ?? []).filter { $0.lengthGroup == group && $0.issue == nil }.compactMap(\.first7)
            HStack { Text(group); Spacer(); Text("\(values.count) measured").foregroundStyle(OLED.muted); Text(values.count >= 3 ? count(ytMedian(values)!) + " views" : "Needs 3 videos").monospacedDigit() }.font(.system(size:12)).padding(.vertical,8)
        }
    }
    private func revenueSummary(_ channels: [YouTubeChannelSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Revenue & RPM").font(.system(size: 18, weight: .semibold)); Spacer(); Text("USD").font(.caption).foregroundStyle(OLED.muted) }
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                    GridRow {
                        Text("Channel").frame(maxWidth: .infinity, alignment: .leading)
                        Text("RPM\nLast 7 days").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("RPM\nLast 30 days").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("RPM\nLifetime").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Revenue\nLast 30 days").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Revenue\nLifetime").frame(maxWidth: .infinity, alignment: .trailing)
                    }.font(.caption).foregroundStyle(OLED.muted)
                    ForEach(Array(channels.enumerated()), id: \.element.id) { index, c in
                        Divider().gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            HStack(spacing: 7) {
                                Circle().fill([Color.yellow, .cyan, .pink][index % 3]).frame(width: 6, height: 6)
                                Text(c.name).fontWeight(.medium)
                            }
                            Text(financialNumber(c.financials?.last7?.rpm)).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(financialNumber(c.financials?.last30?.rpm)).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(financialNumber(c.financials?.lifetime?.rpm)).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(financialNumber(c.financials?.last30?.amount)).frame(maxWidth: .infinity, alignment: .trailing)
                            Text(financialNumber(c.financials?.lifetime?.amount)).frame(maxWidth: .infinity, alignment: .trailing)
                        }.font(.system(size: 14)).monospacedDigit()
                    }
                }.frame(minWidth: max(600, geometry.size.width)).padding(.bottom, 3)
            }
            }.frame(height: CGFloat(channels.count) * 45 + 40)
            DisclosureGroup("Dates & calculation", isExpanded: $revenueDetailsOpen) {
                VStack(alignment: .leading, spacing: 7) {
            ForEach(channels) { c in
                if let f = c.financials {
                    let last30 = f.last30.map { "\($0.fromDate) – \($0.through)" } ?? "Unavailable"
                    let lifetime = f.lifetime.map { "\($0.fromDate) – \($0.through)" } ?? "Unavailable"
                    Text("\(c.name) · 30 days: \(last30) · Lifetime: \(lifetime)")
                        .font(.system(size: 10)).foregroundStyle(OLED.muted)
                    Text("Updated \(f.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(referenceDate.timeIntervalSince(f.fetchedAt) > 30*3600 ? OLED.offline : OLED.muted)
                }
            }
            Text("RPM = revenue ÷ engaged views × 1,000. Windows end on the latest reported day. Revenue is estimated and reported in US dollars by Nexlev. A dash means unavailable data.")
                .font(.caption).foregroundStyle(OLED.muted)
                }.padding(.top, 8)
            }.font(.caption).foregroundStyle(OLED.muted)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 12))
    }
    private func financialNumber(_ value: Double?) -> String {
        ytMoney(value)
    }
    private func isWatched(_ id: String) -> Bool { !hiddenCompetitors.split(separator:",").contains(Substring(id)) }
    private func toggleWatch(_ id: String) { var ids = Set(hiddenCompetitors.split(separator:",").map(String.init)); if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }; hiddenCompetitors = ids.sorted().joined(separator:",") }
    @ViewBuilder private func competitors(_ s: YouTubeSnapshot) -> some View {
        title("Competitor watchlist", "Sample Nexlev suggestions. Choose which channels to watch; inspect their breakout topics and packaging.")
        Toggle("Show watched channels only",isOn:$watchedOnly).toggleStyle(.checkbox).font(.caption)
        Text("Multipliers are Nexlev’s public lifetime views / channel average. They are not age-adjusted and must not be compared with your private three-day or seven-day scores.").font(.caption).foregroundStyle(OLED.muted)
        let entries = (s.competitors ?? []).filter { !watchedOnly || isWatched($0.id) }
        if entries.isEmpty { Text("No channels in this view. Turn off the filter to choose from Nexlev’s suggestions.").foregroundStyle(OLED.muted) }
        ForEach(entries) { c in
            VStack(alignment:.leading,spacing:12) {
                HStack { Link(c.name,destination:URL(string:"https://example.com/channel/"+c.id)!).font(.system(size:15,weight:.semibold)); Spacer(); Button { toggleWatch(c.id) } label: { Label(isWatched(c.id) ? "Watching" : "Watch",systemImage:isWatched(c.id) ? "checkmark" : "plus") }.font(.caption) }
                Text("Checked \(c.fetchedAt.formatted(date:.abbreviated,time:.shortened)) · Up to 30 uploads sampled").font(.caption2).foregroundStyle(referenceDate.timeIntervalSince(c.fetchedAt)>24*3600 ? OLED.offline : OLED.muted)
                if let issue = c.issue { Text(issue).font(.caption).foregroundStyle(OLED.offline) }
                if c.videos.isEmpty { Text("No videos above 2× returned in this sample.").font(.caption).foregroundStyle(OLED.muted) }
                ForEach(c.videos.prefix(3)) { v in
                    Link(destination:URL(string:"https://example.com/video/"+v.id)!) {
                        HStack(spacing:12) { thumbnail(v.id); VStack(alignment:.leading,spacing:4) { Text(v.title).font(.system(size:12)).lineLimit(2); Text("\(v.date) · \(count(v.views)) public views").font(.caption2).foregroundStyle(OLED.muted) }.frame(maxWidth:.infinity,alignment:.leading); Text(String(format:"%.1f×",v.multiplier)).font(.system(size:18,weight:.medium)).foregroundStyle(OLED.accent) }
                    }.buttonStyle(JarvisPlainButtonStyle())
                }
            }.padding(16).background(OLED.surface,in:RoundedRectangle(cornerRadius:12))
        }
    }
}

struct YouTubeRPMPoint: Identifiable {
    var day: String
    var date: Date
    var value: Double
    var kind: String
    var segment: Int
    var id: String { kind + day }
}
extension YouTubeChannelSnapshot {
    var rpmTrend: [YouTubeRPMPoint] {
        let revenue = Dictionary(uniqueKeysWithValues: (details?.revenue ?? []).map { ($0.day,$0.amount) })
        let engaged = Dictionary(uniqueKeysWithValues: days.compactMap { d in d.engagedViews.map { (d.day,$0) } })
        var points: [YouTubeRPMPoint] = []
        var previous: Date?
        var segment = 0
        for day in revenue.keys.sorted() {
            guard let date = ytDate(day), let total = engaged[day], total > 0 else { continue }
            if let previous, date.timeIntervalSince(previous) > 86400 { segment += 1 }
            points.append(.init(day:day,date:date,value:revenue[day]! / total * 1000,kind:"Daily",segment:segment))
            previous = date
        }
        if let latest = points.last?.date {
            let start = latest.addingTimeInterval(-6 * 86400)
            points += points.filter { $0.date >= start }.map {
                var point = $0
                point.kind = "Last 7 days"
                return point
            }
        }
        return points
    }
}
struct YouTubeRPMChart: View {
    let points: [YouTubeRPMPoint]
    @State private var hoveredDay: String?
    private var selected: [YouTubeRPMPoint] { points.filter { $0.day == hoveredDay && $0.kind == "Daily" } }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("RPM evolution").font(.system(size:16,weight:.semibold))
                Spacer()
                Label("Daily",systemImage:"circle.fill").foregroundStyle(OLED.muted)
                Label("Last 7 days",systemImage:"circle.fill").foregroundStyle(OLED.accent)
            }.font(.caption)
            if points.isEmpty {
                Text("No RPM trend yet. Daily revenue and engaged views are needed.").font(.callout).foregroundStyle(OLED.muted).padding(.vertical,30)
            } else {
                HStack(spacing:16) {
                    if let day = hoveredDay, !selected.isEmpty {
                        Text(day)
                        ForEach(selected) { p in Text(p.kind + ": " + p.value.formatted(.number.precision(.fractionLength(2)))).foregroundStyle(p.kind == "Daily" ? OLED.muted : OLED.accent) }
                    } else { Text("Move over the graph to inspect a date.").foregroundStyle(OLED.muted) }
                }.font(.system(size:11)).monospacedDigit().frame(height:18,alignment:.leading)
                Chart {
                    ForEach(points) { p in
                        LineMark(x:.value("Date",p.date),y:.value("RPM",p.value),series:.value("Series",p.kind + String(p.segment)))
                            .foregroundStyle(p.kind == "Daily" ? OLED.muted : OLED.accent)
                            .lineStyle(StrokeStyle(lineWidth:p.kind == "Daily" ? 1 : 2.5))
                        PointMark(x:.value("Date",p.date),y:.value("RPM",p.value))
                            .foregroundStyle(p.kind == "Daily" ? OLED.muted : OLED.accent).symbolSize(p.kind == "Daily" ? 9 : 12)
                            .accessibilityLabel(p.kind + " RPM, " + p.day).accessibilityValue(p.value.formatted(.number.precision(.fractionLength(2))))
                    }
                    if let date = selected.first?.date { RuleMark(x:.value("Selected date",date)).foregroundStyle(OLED.muted.opacity(0.5)).lineStyle(StrokeStyle(dash:[3,3])) }
                }
                .chartXAxis { AxisMarks(values:.automatic(desiredCount:5)) { _ in AxisGridLine(); AxisValueLabel(format:.dateTime.month(.abbreviated).day()) } }
                .chartYAxis { AxisMarks(position:.leading) }
                .chartYScale(domain:.automatic(includesZero:true))
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(Color.clear).contentShape(Rectangle()).onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let plot = geometry[proxy.plotAreaFrame]
                                guard plot.contains(location), let date: Date = proxy.value(atX:location.x-plot.minX) else { hoveredDay=nil; return }
                                hoveredDay = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.day
                            case .ended: hoveredDay=nil
                            }
                        }
                    }
                }.frame(height:210).environment(\.timeZone,TimeZone(secondsFromGMT:0)!)
            }
            Text("Daily RPM based on engaged views. Yellow highlights the last seven reported calendar days of the same line. Missing data leaves gaps.").font(.caption).foregroundStyle(OLED.muted)
        }
    }
}

struct YouTubeComparisonChart: View {
    let channels: [YouTubeChannelSnapshot]
    @State private var hoveredDay: String?
    private let colors: [Color] = [.yellow, .cyan, .pink]
    private var dates: [Date] { channels.flatMap { $0.rpmTrend.filter { $0.kind == "Daily" }.map(\.date) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily RPM").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(hoveredDay ?? "Last 7 days in bold").font(.caption).foregroundStyle(OLED.muted)
            }
            HStack(spacing: 28) {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                    let point = hoveredDay.flatMap { day in channel.rpmTrend.first { $0.kind == "Daily" && $0.day == day } } ?? (hoveredDay == nil ? channel.rpmTrend.last : nil)
                    HStack(spacing: 7) {
                        Circle().fill(colors[index % colors.count]).frame(width: 6, height: 6)
                        Text(channel.name).foregroundStyle(OLED.muted)
                        Text(ytMoney(point?.value)).fontWeight(.semibold).foregroundStyle(colors[index % colors.count])
                    }
                }
            }.font(.system(size: 12)).monospacedDigit()
            Chart {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                    ForEach(channel.rpmTrend) { point in
                        LineMark(x: .value("Date", point.date), y: .value("RPM", point.value), series: .value("Channel", channel.id + point.kind + String(point.segment)))
                            .foregroundStyle(colors[index % colors.count].opacity(point.kind == "Daily" ? 0.75 : 1))
                            .lineStyle(StrokeStyle(lineWidth: point.kind == "Daily" ? 1.5 : 2.5, lineCap: .round, lineJoin: .round))
                        if point.kind == "Daily" && (point.day == hoveredDay || (hoveredDay == nil && point.day == channel.rpmTrend.last?.day)) {
                            PointMark(x: .value("Date", point.date), y: .value("RPM", point.value))
                                .foregroundStyle(colors[index % colors.count]).symbolSize(25)
                                .accessibilityLabel(channel.name + " RPM, " + point.day)
                                .accessibilityValue(point.value.formatted(.number.precision(.fractionLength(2))))
                        }
                    }
                }
                if let day = hoveredDay, let date = ytDate(day) {
                    RuleMark(x: .value("Date", date)).foregroundStyle(OLED.muted.opacity(0.5)).lineStyle(StrokeStyle(dash: [3, 3]))
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(OLED.muted.opacity(0.2)); AxisValueLabel { if let amount = value.as(Double.self) { Text(amount.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")).precision(.fractionLength(0)))) } } } }
            .chartYScale(domain: .automatic(includesZero: true))
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(Color.clear).contentShape(Rectangle()).onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let plot = geometry[proxy.plotAreaFrame]
                            guard plot.contains(location), let date: Date = proxy.value(atX: location.x - plot.minX) else { hoveredDay = nil; return }
                            hoveredDay = dates.min { abs($0.timeIntervalSince(date)) < abs($1.timeIntervalSince(date)) }.map(ytDay)
                        case .ended: hoveredDay = nil
                        }
                    }
                }
            }
            .frame(height: 200).environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        }.padding(18).background(OLED.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct YouTubeFinancialWindow: Codable {
    var fromDate: String
    var through: String
    var amount: Double
    var engagedViews: Double?
    var rpm: Double? { engagedViews.flatMap { $0 > 0 ? amount / $0 * 1000 : nil } }
    var valid: Bool {
        ytDate(fromDate) != nil && ytDate(through) != nil && fromDate <= through
        && amount.isFinite && amount >= 0 && (engagedViews == nil || (engagedViews!.isFinite && engagedViews! >= 0))
    }
}
struct YouTubeFinancials: Codable {
    var last7: YouTubeFinancialWindow?
    var last30: YouTubeFinancialWindow?
    var lifetime: YouTubeFinancialWindow?
    var fetchedAt: Date
    var valid: Bool { [last7, last30, lifetime].compactMap { $0 }.allSatisfy(\.valid) }
}

// Nexlev documents get_my_revenue_report amounts as USD.
private func ytMoney(_ value: Double?) -> String {
    value.map { $0.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")).precision(.fractionLength(2))) } ?? "—"
}
