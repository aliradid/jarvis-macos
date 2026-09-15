import Foundation

// Fictional records, created independently of personal exports.
enum SampleData {
    static let now = Date()
    static func day(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: now))! }
    static let rates = [("EUR", 0.9), ("GBP", 0.8), ("MAD", 10.0)].map { OrbitFXRate(date: ytDay(now), base: "USD", quote: $0.0, rate: $0.1) }
    static var subscriptions: [OrbitSubscription] {
        [("ChatGPT", 25.0, "USD", "Monthly", "Active", 8),
         ("Claude", 30.0, "USD", "Monthly", "Active", 12),
         ("Adobe", 18.0, "EUR", "Monthly", "Active", 18),
         ("Example cloud", 120.0, "USD", "Yearly", "Active", 24),
         ("Example editor", 15.0, "USD", "Monthly", "Trial", 2),
         ("Example storage", 8.0, "USD", "Monthly", "Ending", 5),
         ("Example service", 0.0, "USD", "Unknown", "Needs review", 0),
         ("Example archive", 12.0, "USD", "Monthly", "Archived", -60)].enumerated().map { index, r in
            var s = OrbitSubscription(name: r.0, amount: r.1, currency: r.2, cycle: r.3, date: day(r.5), status: r.4)
            s.id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
            s.notes = "Fictional sample record. Amounts do not represent provider pricing or a personal account."
            s.priceKnown = r.4 != "Needs review"; s.dateKnown = r.4 != "Needs review"
            s.dateBasis = "Confirmed"; s.priceBasis = "Confirmed"
            return s
        }
    }
    static var cats: [CatExpense] {
        [("Food", "Cat A", "Food", 120.0), ("Routine visit", "Cat B", "Vet", 200.0), ("Litter", "Cat A", "Litter", 60.0)].map {
            CatExpense(title: $0.0, cat: $0.1, category: $0.2, amount: $0.3, date: now, notes: "Fictional sample expense")
        }
    }
    static var sources: [MissionSource] {
        (0..<4).map { MissionSource(id: "studio-\($0)", name: "Studio \(Character(UnicodeScalar(65+$0)!))", root: "Sample Projects/Studio-\($0)", port: 8080+$0, primaryLanguage: "en") }
    }
    static var browserProfiles: [Tile] {
        (0..<4).map { i in
            let name = "Channel " + String(Character(UnicodeScalar(65+i)!))
            return Tile(id: "chrome-profile:sample-\(i)", kind: .chromeProfile, label: name, detectedLabel: name, subtitle: "Sample Chrome profile", invocation: .openChromeProfile(dir: "Sample Profile \(i)"), customImage: nil, iconSourcePath: nil)
        }
    }
    static var workspace: Config {
        var c = Config()
        for i in 0..<4 {
            let file = FileEntry(id: "artwork-\(i)", path: "Sample Artwork/Design-\(i+1).psd")
            c.files.append(file); c = renamed(c, id: "file:" + file.id, label: "Design \(i+1)")
        }
        for source in sources {
            c.links.append(LinkEntry(id: source.id, url: "http://127.0.0.1:\(source.port)"))
            c = renamed(c, id: "link:" + source.id, label: source.name)
        }
        return c
    }
    static var projects: [MissionProject] {
        [("Sample episode", "review", "Review", "Review the sample draft", false),
         ("Sample tutorial", "finished", "Complete", "Ready", true),
         ("Sample interview", "running", "Editing", "In progress", false)].enumerated().map { i, r in
            MissionProject(id: "project-\(i)", sourceID: "studio-0", source: "Studio A", language: "en", title: r.0, folder: "Sample Projects/Project-\(i)", status: r.1, stage: r.2, detail: r.3, modified: now, video: r.4 ? "Sample Projects/Project-\(i)/video.mp4" : nil, thumbnails: [])
        }
    }
    static var quotas: [AIQuota] {
        [AIQuota(id: "openai:weekly", provider: "openai", window: "Weekly", remaining: 58, reset: day(4)),
         AIQuota(id: "claude:session", provider: "claude", window: "5h", remaining: 82, reset: now.addingTimeInterval(7200)),
         AIQuota(id: "claude:weekly", provider: "claude", window: "Weekly", remaining: 69, reset: day(5))]
    }
    static let machines = [MachineHealth(id: "mac", name: "Sample Mac", subtitle: "Local machine", online: true, memory: "16 GB", load: "1.20", disk: "42%"), MachineHealth(id: "vps", name: "Sample VPS", subtitle: "Remote machine", online: true, memory: "2 / 8 GB", load: "0.45", disk: "28%")]
    static let connections = [ConnectionHealth(id: "tunnel", name: "SSH tunnel", detail: "Sample connection", healthy: true), ConnectionHealth(id: "scout", name: "VPS proxy", detail: "Sample connection", healthy: true), ConnectionHealth(id: "mobile", name: "Mobile proxy", detail: "Sample connection", healthy: true)]
    private static func sampleDays(channel: Int) -> [YouTubeDay] {
        var result: [YouTubeDay] = []
        for index in 0..<30 {
            let views = 1100 + channel * 550 + index * 43 + (index % 5) * 140
            let minutes = 3500 + channel * 500 + index * 90
            let engaged = 900 + channel * 400 + index * 35
            let row = YouTubeDay(day: ytDay(day(index - 32)), views: Double(views), watchMinutes: Double(minutes), gained: Double(10 + index % 9), lost: 2, engagedViews: Double(engaged))
            result.append(row)
        }
        return result
    }
    private static func sampleVideos(channel: Int) -> [YouTubeRecentVideo] {
        var result: [YouTubeRecentVideo] = []
        for index in 0..<4 {
            let id = String(format: "sample%05d", channel * 10 + index)
            let published = day(-10 - index * 4).ISO8601Format()
            let row = YouTubeRecentVideo(id: id, title: "Sample video \(index + 1)", views: Double(8000 + index * 1300), duration: 420, publishedAt: published, first3: Double(2100 + index * 400), first7: Double(4500 + index * 700), fetchedAt: now)
            result.append(row)
        }
        return result
    }
    private static func financialWindow(_ days: [YouTubeDay], count: Int) -> YouTubeFinancialWindow {
        let selected = Array(days.suffix(count))
        let amount = selected.reduce(0.0) { $0 + $1.views * 0.002 }
        let engaged = selected.reduce(0.0) { $0 + ($1.engagedViews ?? 0) }
        return YouTubeFinancialWindow(fromDate: selected.first!.day, through: selected.last!.day, amount: amount, engagedViews: engaged)
    }
    static var youtube: YouTubeSnapshot {
        var channels: [YouTubeChannelSnapshot] = []
        for index in 0..<3 {
            let days = sampleDays(channel: index)
            let recent = sampleVideos(channel: index)
            let revenue = days.map { YouTubeRevenueDay(day: $0.day, amount: $0.views * 0.002) }
            let financials = YouTubeFinancials(last7: financialWindow(days, count: 7), last30: financialWindow(days, count: 30), lifetime: financialWindow(days, count: 30), fetchedAt: now)
            let details = YouTubeDetails(recent: recent, uploadsAt: now, revenue: revenue, revenueAt: now, currency: "USD")
            let name = "Channel " + String(Character(UnicodeScalar(65 + index)!))
            let channel = YouTubeChannelSnapshot(id: "UC" + String(repeating: String(index), count: 22), name: name, fetchedAt: now, startDate: days.first!.day, endDate: days.last!.day, days: days, videos: [], financials: financials, details: details)
            channels.append(channel)
        }
        let video = YouTubeBreakout(id: "sample99999", title: "Sample comparison video", views: 24000, multiplier: 2.4, date: ytDay(day(-7)))
        let competitor = YouTubeCompetitor(id: "UC" + String(repeating: "9", count: 22), name: "Sample comparison channel", fetchedAt: now, videos: [video])
        return YouTubeSnapshot(version: 1, checkedAt: now, channels: channels, competitors: [competitor])
    }
}
