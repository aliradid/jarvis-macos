import SwiftUI
import AppKit

enum Palette {
    static let background = Color.black
    static let surface = Color(white: 0.065)
    static let muted = Color(white: 0.54)
    static let accent = Color(red: 0.84, green: 0.70, blue: 0.27)
    static let online = Color(red: 0.35, green: 0.78, blue: 0.57)
}

struct JarvisAvatar: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.67, green: 0.48, blue: 1), Color(red: 0.36, green: 0.19, blue: 0.78), Color(red: 0.13, green: 0.08, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(RadialGradient(colors: [.white.opacity(0.52), .clear], center: .topLeading, startRadius: 0, endRadius: g.size.width*0.65)).padding(3)
                HStack(spacing: g.size.width*0.15) {
                    Capsule().fill(Color(white: 0.08)).frame(width: g.size.width*0.10, height: g.size.width*0.26)
                    Capsule().fill(Color(white: 0.08)).frame(width: g.size.width*0.10, height: g.size.width*0.26)
                }.rotationEffect(.degrees(-18))
            }.overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
        }.accessibilityHidden(true)
    }
}


struct BrandIcon: View {
    let name: String
    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: name, withExtension: "png"), let icon = NSImage(contentsOf: url) {
                Image(nsImage: icon).resizable().scaledToFit()
            } else { Text(name).font(.caption2) }
        }.accessibilityHidden(true)
    }
}
