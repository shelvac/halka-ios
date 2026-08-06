import SwiftUI

// Design tokens ported 1:1 from the Claude Design prototype (Saglik App.dc.html).
// The prototype uses Manrope; native builds use the SF system font at matching weights.

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    // Backgrounds
    static let bgApp = Color(hex: 0xF7F4EF)        // screen background
    static let bgSand = Color(hex: 0xECE7DD)       // segmented control track
    static let bgChip = Color(hex: 0xF5F1E8)       // muted chip / delete circle
    static let bgField = Color(hex: 0xF7F4EF)      // inputs on white cards
    static let bgSplashBottom = Color(hex: 0xFBEDE8)

    // Ink
    static let ink = Color(hex: 0x26221B)          // primary text / dark cards
    static let inkSoft = Color(hex: 0x3B372E)
    static let inkBody = Color(hex: 0x4A453B)
    static let inkMid = Color(hex: 0x6B6558)
    static let sub = Color(hex: 0x96907F)          // secondary text
    static let faint = Color(hex: 0xB4AC9C)        // tertiary text
    static let disabledText = Color(hex: 0xA8A093)
    static let hairline = Color(hex: 0xF3EEE5)     // row separators
    static let hairline2 = Color(hex: 0xF0EBE1)    // progress tracks
    static let dashBorder = Color(hex: 0xDDD4C3)
    static let chevron = Color(hex: 0xCFC8BA)

    // Brand — rings
    static let coral = Color(hex: 0xE45C49)        // exercise / primary
    static let coralDark = Color(hex: 0xC74836)
    static let coralBg = Color(hex: 0xFBEDE8)
    static let coralNote = Color(hex: 0xA0665A)
    static let waterBlue = Color(hex: 0x3E9BD6)    // water
    static let blueDark = Color(hex: 0x2E7DB2)
    static let blueBg = Color(hex: 0xE7F1F9)
    static let sleepPurple = Color(hex: 0x7A6FE3)  // sleep
    static let purpleBg = Color(hex: 0xF3EDFB)
    static let green = Color(hex: 0x45A46F)        // nutrition / success
    static let greenDark = Color(hex: 0x2E7D53)
    static let greenBg = Color(hex: 0xE5F3EB)
    static let greenSoft = Color(hex: 0x7FCB9B)

    // Accents
    static let gold = Color(hex: 0xF0C46A)
    static let goldDark = Color(hex: 0xB77A17)
    static let goldBg = Color(hex: 0xFBF1DF)
    static let bronze = Color(hex: 0xC9975B)
    static let brown = Color(hex: 0xB0714E)
    static let avatarPeach = Color(hex: 0xF0DDD1)
    static let warnOrange = Color(hex: 0xC2622E)
    static let warnOrangeBg = Color(hex: 0xFCEAE0)
    static let warnFieldBg = Color(hex: 0xFDF4F1)
    static let warnFieldBorder = Color(hex: 0xE8A79A)
    static let warnDeep = Color(hex: 0x9A4030)

    // BMI band
    static let bmiLow = Color(hex: 0x7CC6E8)
    static let bmiOk = Color(hex: 0x7FCB9B)
    static let bmiHigh = Color(hex: 0xF0C46A)
    static let bmiObese = Color(hex: 0xEE8080)
}

extension Font {
    /// Design-scale font: prototype weight 800 → .heavy, 700 → .bold, 600 → .semibold.
    static func h(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Shared modifiers

struct CardStyle: ViewModifier {
    var radius: CGFloat = 20
    var padding: EdgeInsets? = nil
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.ink.opacity(0.06), radius: 6, y: 2)
    }
}

extension View {
    /// White card with the prototype's soft shadow.
    func card(_ radius: CGFloat = 20) -> some View { modifier(CardStyle(radius: radius)) }

    /// Primary coral CTA button styling.
    func coralButton() -> some View {
        self
            .font(.h(14))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.coral)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.coral.opacity(0.3), radius: 7, y: 4)
    }
}

// MARK: - Small shared components

/// Green circular checkmark used across confirmations.
struct CheckBadge: View {
    var size: CGFloat = 20
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .heavy))
                    .foregroundStyle(.white)
            )
    }
}

/// Round toggle checkbox (meal eaten, supplement taken, workout done).
struct RoundCheck: View {
    var on: Bool
    var size: CGFloat = 22
    var body: some View {
        Circle()
            .fill(on ? Color.green : Color.white)
            .overlay(Circle().strokeBorder(on ? Color.green : Color.dashBorder, lineWidth: 2))
            .overlay {
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
    }
}

/// Initials avatar with palette rotation matching the prototype.
struct InitialsAvatar: View {
    var text: String
    var index: Int = 0
    var size: CGFloat = 44
    static let bg: [Color] = [.blueBg, .coralBg, .greenBg, .purpleBg, .goldBg]
    static let fg: [Color] = [.blueDark, .coralDark, .greenDark, .sleepPurple, .goldDark]
    var body: some View {
        Circle()
            .fill(Self.bg[index % 5])
            .frame(width: size, height: size)
            .overlay(
                Text(text)
                    .font(.h(size * 0.36))
                    .foregroundStyle(Self.fg[index % 5])
            )
    }
}

/// The user's peach "S" avatar.
struct MeAvatar: View {
    var size: CGFloat = 44
    var body: some View {
        Circle()
            .fill(Color.avatarPeach)
            .frame(width: size, height: size)
            .overlay(Text("S").font(.h(size * 0.37)).foregroundStyle(Color.brown))
    }
}

/// Prototype-style status chip ("Normal", "Yüksek"…).
struct StatusChip: View {
    var text: String
    var bg: Color
    var fg: Color
    var minWidth: CGFloat? = nil
    var body: some View {
        Text(text)
            .font(.h(10.5))
            .foregroundStyle(fg)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }
}

/// Colors for a metric status label.
func statusColors(_ status: String) -> (bg: Color, fg: Color) {
    switch status {
    case "Yüksek": return (.goldBg, .goldDark)
    case "Mükemmel", "Sağlıklı", "Normal": return (.greenBg, .greenDark)
    case "Düşük": return (.blueBg, .blueDark)
    case "Hafif": return (.warnOrangeBg, .warnOrange)
    default: return (.bgChip, .sub)
    }
}

/// Back-navigation row: coral chevron + label.
struct BackRow: View {
    var label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                Text(label).font(.h(13))
            }
            .foregroundStyle(Color.coral)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

/// Dashed-border placeholder button ("+ Yeni challenge başlat" etc).
struct DashedAction: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.h(12))
            .foregroundStyle(Color.sub)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.dashBorder, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            )
    }
}

/// Gray image placeholder standing in for the prototype's <image-slot>.
struct ImagePlaceholder: View {
    var label: String
    var body: some View {
        ZStack {
            Rectangle().fill(Color.bgChip)
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.faint)
                Text(label)
                    .font(.h(9, .bold))
                    .foregroundStyle(Color.faint)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
        }
    }
}

/// Spinning progress arc matching the prototype's inline spinner.
struct SpinnerArc: View {
    var size: CGFloat = 20
    @State private var spin = false
    var body: some View {
        Circle()
            .stroke(Color.hairline2, lineWidth: 3)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Color.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
            )
            .frame(width: size, height: size)
            .onAppear { spin = true }
    }
}
