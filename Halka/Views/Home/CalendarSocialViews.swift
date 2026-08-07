import SwiftUI

// MARK: - Calendar (Apple Fitness-style ring history)

struct CalendarPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            calendarCard
            detailCard
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Button { model.showMonth(offset: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.coral)
                }
                .buttonStyle(.plain)

                Text(model.visibleMonthTitle)
                    .font(.h(17))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)

                // İleri düğmesi yalnızca geçmiş bir aydayken anlamlı.
                Button { model.showMonth(offset: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(model.visibleMonthIsCurrent ? Color.chevron : Color.coral)
                }
                .buttonStyle(.plain)
                .disabled(model.visibleMonthIsCurrent)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Demo.dayNamesShort, id: \.self) { day in
                    Text(day)
                        .font(.h(10))
                        .foregroundStyle(Color.faint)
                }
                // Ayın 1'i hangi güne denk geliyorsa o kadar boşluk (pazartesi başlangıçlı).
                ForEach(0..<model.leadingBlanks, id: \.self) { i in
                    Color.clear.frame(minHeight: 52).id("blank-\(i)")
                }
                ForEach(1...model.daysInVisibleMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .card(22)
    }

    private func dayCell(_ day: Int) -> some View {
        let future = model.isFuture(day: day)
        let isToday = model.isToday(day: day)
        let selected = model.selectedCalendarDay == day
        return Button {
            guard !future else { return }
            model.selectedCalendarDay = day
        } label: {
            VStack(spacing: 3) {
                if isToday {
                    Text("\(day)")
                        .font(.h(10.5))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.coral))
                } else {
                    Text("\(day)")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(future ? Color.chevron : Color.inkMid)
                        .frame(height: 20)
                }
                MiniRings(fractions: future ? [0, 0, 0, 0] : model.fractions(forDay: day), size: 30)
            }
            .padding(.top, 5)
            .padding(.bottom, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color(hex: 0xF7F1E6) : .clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(future)
    }

    private var detailCard: some View {
        let day = model.selectedCalendarDay
        let fractions = model.fractions(forDay: day)
        let colors: [Color] = [.coral, .waterBlue, .sleepPurple, .green]
        // Hedefler profile göre değiştiği için metinler de oradan üretilir.
        let goals = RingKind.allCases.map { model.goal(for: $0) }
        let values: [String] = [
            "\(Int((fractions[0] * goals[0]).rounded())) / \(Int(goals[0])) dk",
            "\(Int((fractions[1] * goals[1]).rounded())) / \(Int(goals[1])) ml",
            String(format: "%.1f", fractions[2] * goals[2])
                + String(format: " / %.0f sa", goals[2]),
            "\(Int((fractions[3] * goals[3]).rounded())) / \(Int(goals[3])) kcal"
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(model.dayTitle(forDay: day))
                    .font(.h(14))
                    .foregroundStyle(Color.ink)
                Spacer()
                // US-024: kayıt yoksa bunu açıkça söyle, sıfırları veri gibi gösterme.
                if !model.hasData(forDay: day) {
                    Text("Kayıt yok")
                        .font(.h(10.5))
                        .foregroundStyle(Color.faint)
                }
            }
            VStack(spacing: 10) {
                ForEach(Array(RingKind.allCases.enumerated()), id: \.offset) { i, kind in
                    let done = fractions[i] >= 1
                    HStack(spacing: 10) {
                        Circle().fill(colors[i]).frame(width: 8, height: 8)
                        Text(kind.name)
                            .font(.h(13, .bold))
                            .foregroundStyle(Color.inkMid)
                        Spacer()
                        Text(values[i])
                            .font(.h(13))
                            .foregroundStyle(Color.ink)
                        Text("%\(Int((fractions[i] * 100).rounded()))")
                            .font(.h(11))
                            .foregroundStyle(done ? Color(hex: 0x3E9E6C) : Color.sub)
                            .frame(minWidth: 40)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(done ? Color(hex: 0x3E9E6C).opacity(0.12) : Color.bgChip)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }
}

// MARK: - Social (challenge + leaderboard + friends)

struct SocialPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 12) {
            challengeCard
            leaderboardCard

            HStack(spacing: 8) {
                TextField("Arkadaş kullanıcı adı…", text: $model.friendNameDraft)
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                Button { model.addFriend() } label: {
                    Text("+ Ekle")
                        .font(.h(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(Color.coral)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.coral.opacity(0.3), radius: 6, y: 4)
                }
                .buttonStyle(.plain)
            }

            DashedAction(title: "+ Yeni challenge başlat")
        }
    }

    private var challengeCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AKTİF CHALLENGE")
                        .font(.h(10))
                        .foregroundStyle(Color.gold)
                        .kerning(1.5)
                    Text("2L Su · 7 Gün")
                        .font(.h(16))
                        .foregroundStyle(.white)
                        .padding(.top, 2)
                    Text("3 katılımcı · 2 gün kaldı")
                        .font(.h(11, .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: 5.0 / 7.0)
                        .stroke(Color.waterBlue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 36, height: 36)
            }
            VStack(spacing: 9) {
                ForEach(Demo.challengeRows, id: \.0) { row in
                    HStack(spacing: 10) {
                        Text(row.0)
                            .font(.h(11))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 60, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                Capsule()
                                    .fill(row.0 == "Sen" ? Color.gold : Color.waterBlue)
                                    .frame(width: geo.size.width * CGFloat(row.1) / 7)
                            }
                        }
                        .frame(height: 6)
                        Text("\(row.1)/7")
                            .font(.h(10.5))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var leaderboardCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Liderlik Tablosu")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(model.currentMonthName) · halka puanı")
                    .font(.h(10))
                    .foregroundStyle(Color.sub)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)

            ForEach(Array(model.leaderboard.enumerated()), id: \.element.id) { i, friend in
                let rankColor: Color = i == 0 ? .goldDark : i == 1 ? .sub : i == 2 ? .bronze : .chevron
                HStack(spacing: 11) {
                    Text("\(i + 1)")
                        .font(.h(13))
                        .foregroundStyle(rankColor)
                        .frame(width: 20)
                    InitialsAvatar(text: String(friend.name.prefix(1)).uppercased(), index: i, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(friend.name)
                            .font(.h(13))
                            .foregroundStyle(Color.ink)
                        Text("\(friend.streak) gün seri")
                            .font(.h(10, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text("\(friend.points)")
                        .font(.h(14))
                        .foregroundStyle(Color.ink)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, friend.isMe ? 10 : 0)
                .background(
                    friend.isMe
                        ? AnyView(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.coralBg))
                        : AnyView(Color.clear)
                )
                .overlay(alignment: .top) {
                    if i > 0 && !friend.isMe {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .card(22)
    }
}
