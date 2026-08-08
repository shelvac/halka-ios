import SwiftUI

/// AI Koç chat: greeting + plan cards, quick chips, weekly workout/meal flows.
struct CoachView: View {
    @Environment(AppModel.self) private var model
    /// Plan sihirbazı (US-030).
    @State private var showWizard = false

    private let quickChips = ["Haftalık antrenman planı", "Haftalık besin planı", "Motivasyon lazım"]

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.messages) { message in
                                CoachMessageView(message: message)
                            }
                            if model.coachTyping {
                                TypingIndicator()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Quick chips
                        FlowChips(items: quickChips) { chip in
                            model.sendCoachMessage(chip)
                        }
                        .padding(.top, 14)

                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
                .onChange(of: model.messages.count) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .sheet(isPresented: $showWizard) { PlanWizardView() }
                .onChange(of: model.coachTyping) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            // Composer
            HStack(spacing: 8) {
                TextField("Koçuna yaz…", text: $model.coachDraft)
                    .font(.h(13.5, .semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(.white.opacity(0.96))
                    .clipShape(Capsule())
                    .shadow(color: Color.ink.opacity(0.1), radius: 9, y: 4)
                    .onSubmit { model.sendCoachMessage(model.coachDraft) }
                Button { model.sendCoachMessage(model.coachDraft) } label: {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color.coral.opacity(0.35), radius: 7, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 78)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.coralBg)
                .frame(width: 44, height: 44)
                .overlay(
                    ZStack {
                        Circle().stroke(Color.coral, lineWidth: 2).frame(width: 19, height: 19)
                        Circle().fill(Color.coral).frame(width: 7, height: 7)
                    }
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Koç")
                    .font(.h(22))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.5)
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Tartı + halka verilerine bağlı")
                        .font(.h(11, .bold))
                        .foregroundStyle(Color.sub)
                }
            }
            Spacer()
            // Sihirbaz koçun içinden açılıyor: plan kurma isteğinin doğal yeri.
            Button { showWizard = true } label: {
                Text("Planım")
                    .font(.h(12, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.coral))
                    .shadow(color: Color.coral.opacity(0.3), radius: 5, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Message rendering

struct CoachMessageView: View {
    @Environment(AppModel.self) private var model
    var message: CoachMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.h(13.5, .semibold))
                    .foregroundStyle(.white)
                    .lineSpacing(3)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(Color.coral)
                    .clipShape(BubbleShape(userSide: true))
            }
        case .coach:
            coachBubble(message.text)
        case .ask:
            VStack(alignment: .leading, spacing: 8) {
                coachBubble(message.text)
                FlowChips(items: message.options, style: .coralSoft) { option in
                    model.sendCoachMessage(option)
                }
            }
        case .plan:
            planCard
        case .week:
            weekCard
        case .menu:
            menuCard
        }
    }

    private func coachBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.h(13.5, .semibold))
                .foregroundStyle(Color.inkSoft)
                .lineSpacing(4)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(BubbleShape(userSide: false))
                .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
            Spacer(minLength: 40)
        }
    }

    private var cardHeader: some View {
        HStack {
            Text(message.title).font(.h(14)).foregroundStyle(Color.ink)
            Spacer()
            Text("Sana özel")
                .font(.h(10))
                .foregroundStyle(Color.coralDark)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.coralBg))
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(message.planRows.enumerated()), id: \.element.id) { i, row in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill([Color.green, Color.coral, Color.waterBlue][i % 3])
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.title).font(.h(12.5)).foregroundStyle(Color.inkSoft)
                            Text(row.detail)
                                .font(.h(11.5, .semibold))
                                .foregroundStyle(Color.sub)
                                .lineSpacing(2)
                        }
                    }
                }
            }
            Text("Tartı verilerin ve bugünkü halkaların temel alındı")
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader
            VStack(spacing: 2) {
                ForEach(message.weekDays) { day in
                    HStack(spacing: 10) {
                        Text(day.day)
                            .font(.h(9.5))
                            .foregroundStyle(day.rest ? Color.faint : Color.coralDark)
                            .frame(width: 30, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(day.rest ? Color.bgChip : Color.coralBg)
                            )
                        Text(day.title)
                            .font(.h(11.5, day.rest ? .semibold : .bold))
                            .foregroundStyle(day.rest ? Color.faint : Color.inkSoft)
                        Spacer()
                        Text(day.meta)
                            .font(.h(10.5))
                            .foregroundStyle(Color.sub)
                    }
                    .padding(.vertical, 6)
                }
            }
            Text(message.note)
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
                .lineSpacing(2)
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            cardHeader
            ForEach(Array(message.menuDays.enumerated()), id: \.element.id) { i, day in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(day.day)
                            .font(.h(9.5))
                            .foregroundStyle(Color.coralDark)
                            .frame(width: 34, height: 22)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.coralBg))
                        Spacer()
                        Text(day.kcal).font(.h(10.5)).foregroundStyle(Color.sub)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(day.meals) { meal in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(meal.time)
                                    .font(.h(10))
                                    .foregroundStyle(Color.coral)
                                    .frame(width: 34, alignment: .leading)
                                Text(meal.label)
                                    .font(.h(10))
                                    .foregroundStyle(Color.faint)
                                    .frame(width: 36, alignment: .leading)
                                Text(meal.food)
                                    .font(.h(11.5, .semibold))
                                    .foregroundStyle(Color.inkSoft)
                                    .lineSpacing(2)
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
            }
            Text(message.note)
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
                .lineSpacing(2)
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }
}

struct TypingIndicator: View {
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Circle().fill(Color.chevron).frame(width: 6, height: 6)
                Circle().fill(Color.faint).frame(width: 6, height: 6)
                Circle().fill(Color.sub).frame(width: 6, height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.white)
            .clipShape(BubbleShape(userSide: false))
            .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
            Spacer()
        }
    }
}

/// Chat bubble with one squared-off corner, like the prototype.
struct BubbleShape: Shape {
    var userSide: Bool
    func path(in rect: CGRect) -> Path {
        let radii = RectangleCornerRadii(
            topLeading: 18,
            bottomLeading: userSide ? 18 : 4,
            bottomTrailing: userSide ? 4 : 18,
            topTrailing: 18)
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}

/// Wrapping chip row.
struct FlowChips: View {
    enum Style { case outline, coralSoft }
    var items: [String]
    var style: Style = .outline
    var action: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 7) {
            ForEach(items, id: \.self) { item in
                Button { action(item) } label: {
                    Text(item)
                        .font(.h(12, style == .outline ? .bold : .heavy))
                        .foregroundStyle(style == .outline ? Color.inkMid : Color.coralDark)
                        .padding(.horizontal, 13)
                        .padding(.vertical, style == .outline ? 9 : 8)
                        .background(
                            Capsule().fill(style == .outline ? Color.white : Color.coralBg)
                        )
                        .overlay {
                            if style == .outline {
                                Capsule().strokeBorder(Color(hex: 0xEAE3D6), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal left-aligned wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
