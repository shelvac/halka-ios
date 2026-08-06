import SwiftUI

/// Nested 4-ring stack (Egzersiz / Su / Uyku / Beslenme).
/// Radii scale as 92/72/52/32 on a 220-unit canvas, matching the prototype.
struct RingStack: View {
    /// Fractions in order: exercise, water, sleep, nutrition (may exceed 1).
    var fractions: [Double]
    var size: CGFloat
    /// Stroke width in canvas units (design default 16 on 220).
    var thickness: CGFloat = 16
    var showTracks = true

    private static let radii: [CGFloat] = [92, 72, 52, 32]
    private static let colors: [Color] = [.coral, .waterBlue, .sleepPurple, .green]
    private static let tracks: [Color] = [
        Color.coral.opacity(0.13), Color.waterBlue.opacity(0.13),
        Color.sleepPurple.opacity(0.13), Color.green.opacity(0.13)
    ]

    var body: some View {
        let scale = size / 220
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let r = Self.radii[i] * scale
                let w = thickness * scale
                if showTracks {
                    Circle()
                        .stroke(Self.tracks[i], lineWidth: w)
                        .frame(width: r * 2, height: r * 2)
                }
                if fractions.indices.contains(i), fractions[i] > 0 {
                    Circle()
                        .trim(from: 0, to: min(fractions[i], 1))
                        .stroke(Self.colors[i], style: StrokeStyle(lineWidth: w, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: r * 2, height: r * 2)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.4), value: fractions)
    }
}

/// Tiny 4-ring glyph used in the week strip and calendar cells.
/// Neutral tracks, rings drawn only when there's progress (empty days stay pale).
struct MiniRings: View {
    var fractions: [Double]
    var size: CGFloat = 34

    private static let radii: [CGFloat] = [18, 14, 10, 6]
    private static let colors: [Color] = [.coral, .waterBlue, .sleepPurple, .green]

    var body: some View {
        let scale = size / 44
        let w = 3.2 * scale
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let r = Self.radii[i] * scale
                Circle()
                    .stroke(Color(hex: 0xF2EDE3), lineWidth: w)
                    .frame(width: r * 2, height: r * 2)
                if fractions.indices.contains(i), fractions[i] > 0 {
                    Circle()
                        .trim(from: 0, to: min(fractions[i], 1))
                        .stroke(Self.colors[i], style: StrokeStyle(lineWidth: w, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: r * 2, height: r * 2)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
