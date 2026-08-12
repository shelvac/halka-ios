import SwiftUI

// MARK: - Calendar (Apple Fitness-style ring history)

struct CalendarPane: View {
    @Environment(AppModel.self) private var model
    /// Seçili günün antrenman detayı.
    @State private var showWorkouts = false

    var body: some View {
        VStack(spacing: 12) {
            calendarCard
            detailCard
        }
        .sheet(isPresented: $showWorkouts) {
            let day = model.selectedCalendarDay
            WorkoutDaySheet(
                dayTitle: model.dayTitle(forDay: day),
                workouts: model.workouts(forDay: day),
                exerciseMinutes: Int((model.fractions(forDay: day)[0]
                                      * model.goal(for: .exercise)).rounded()),
                exerciseGoal: Int(model.goal(for: .exercise)),
                historyHasWorkouts: !model.hkWorkouts.isEmpty,
                sourceIsHealth: model.hkConnected)
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

    /// 8432 → "8.432"
    private static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var detailCard: some View {
        let day = model.selectedCalendarDay
        let fractions = model.fractions(forDay: day)
        let colors: [Color] = [.coral, .waterBlue, .stepPurple, .green]
        // Hedefler profile göre değiştiği için metinler de oradan üretilir.
        let goals = RingKind.allCases.map { model.goal(for: $0) }
        let values: [String] = zip(RingKind.allCases.indices, RingKind.allCases).map { i, kind in
            let current = Int((fractions[i] * goals[i]).rounded())
            return "\(Self.grouped(current)) / \(Self.grouped(Int(goals[i]))) \(kind.unit)"
        }
        let dayStats = model.stats(forDay: day)
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

            // O gün yapılan antrenmanlar — egzersiz halkasının açıklaması.
            // Ana ekrandakiyle aynı kart; dokununca tam detay açılır.
            let dayWorkouts = model.workouts(forDay: day)
            if !dayWorkouts.isEmpty {
                Button { showWorkouts = true } label: {
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Text("Antrenmanlar")
                                .font(.h(11.5, .bold))
                                .foregroundStyle(Color.sub)
                            Spacer()
                            Text("Detay")
                                .font(.h(10.5, .bold))
                                .foregroundStyle(Color.sub)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color.chevron)
                        }
                        .padding(.bottom, 4)
                        ForEach(Array(dayWorkouts.enumerated()), id: \.element.id) { i, workout in
                            WorkoutRow(workout: workout, compact: true)
                                .padding(.vertical, 7)
                                .overlay(alignment: .top) {
                                    if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                                }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Halka olmayan ölçüler: uyku ve aktif enerji.
            if dayStats.sleep > 0 || dayStats.energy > 0 {
                HStack(spacing: 14) {
                    if dayStats.sleep > 0 {
                        Label(String(format: "%.1f sa uyku", dayStats.sleep),
                              systemImage: "moon.zzz.fill")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.sleepPurple)
                    }
                    if dayStats.energy > 0 {
                        Label("\(Self.grouped(dayStats.energy)) kcal aktif",
                              systemImage: "flame.fill")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.warnOrange)
                    }
                    Spacer(minLength: 0)
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
            // Kod kartı: arkadaşlık kodla kurulur — kodunu paylaşan
            // rızasını göstermiş olur; e-postayla kişi aranamaz.
            myCodeCard

            HStack(spacing: 8) {
                TextField("Arkadaşının kodu (örn. X7K2P9)", text: $model.friendCodeDraft)
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.ink)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                Button { model.submitFriendCode() } label: {
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

            // İsimle arama: bulunan kişiye İSTEK gider, kabul edince
            // eşleşilir — kodun aksine isimde örtük rıza yok, sessiz
            // ekleme/izleme olmasın.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.faint)
                TextField("Ya da isimle ara (en az 3 harf)…", text: $model.friendSearchQuery)
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.ink)
                    .autocorrectionDisabled()
                if !model.friendSearchQuery.isEmpty {
                    Button { model.friendSearchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.chevron)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
            .task(id: model.friendSearchQuery) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await model.searchFriendCandidates()
            }

            if !model.friendSearchResults.isEmpty {
                searchResultsCard
            }

            if let note = model.friendAddNote {
                Text(note)
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.greenDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = model.friendAddError {
                Text(error)
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.coralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !model.friendRequests.isEmpty {
                requestsCard
            }

            friendsCard
        }
        .task { await model.refreshFriends() }
    }

    private var searchResultsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.friendSearchResults.enumerated()), id: \.element.id) { i, result in
                HStack(spacing: 11) {
                    InitialsAvatar(text: String(result.name.prefix(1)).uppercased(),
                                   index: i, size: 32)
                    Text(result.name)
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    switch result.status {
                    case .friend:
                        Text("Arkadaşsınız")
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.greenDark)
                    case .sent:
                        Text("İstek gönderildi")
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.sub)
                    case .incoming, .none:
                        Button { model.sendRequest(to: result) } label: {
                            Text(result.status == .incoming ? "Kabul et" : "İstek Gönder")
                                .font(.h(11, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.coral))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .card(18)
    }

    private var requestsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Arkadaşlık istekleri")
                    .font(.h(14))
                    .foregroundStyle(Color.ink)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            ForEach(Array(model.friendRequests.enumerated()), id: \.element.id) { i, request in
                HStack(spacing: 11) {
                    InitialsAvatar(text: String(request.name.prefix(1)).uppercased(),
                                   index: i, size: 32)
                    Text(request.name)
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Button { model.respondRequest(request, accept: true) } label: {
                        Text("Kabul")
                            .font(.h(11, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.green))
                    }
                    .buttonStyle(.plain)
                    Button { model.respondRequest(request, accept: false) } label: {
                        Text("Reddet")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.sub)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.bgField))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .card(18)
    }

    private var myCodeCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SENİN KODUN")
                    .font(.h(10))
                    .foregroundStyle(Color.gold)
                    .kerning(1.5)
                Text(model.friendCode.isEmpty ? "······" : model.friendCode)
                    .font(.h(22))
                    .foregroundStyle(.white)
                    .kerning(3)
                    .monospacedDigit()
                Text("Arkadaşın bu kodu girince eşleşirsiniz — yalnızca günlük aktivite özetinizi görürsünüz.")
                    .font(.h(10.5, .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(2)
            }
            Spacer()
            if !model.friendCode.isEmpty {
                ShareLink(item: "halka'da arkadaş olalım! Kodum: \(model.friendCode)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var friendsCard: some View {
        if model.friends.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "person.2")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color.chevron)
                Text("Henüz arkadaşın yok")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                Text("Kodunu paylaş ya da arkadaşının kodunu gir — birbirinizin günlük hareketini görüp motive olun.")
                    .font(.h(11.5, .semibold))
                    .foregroundStyle(Color.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .card(20)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("Arkadaşların")
                        .font(.h(15))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text("bugünün özeti")
                        .font(.h(10))
                        .foregroundStyle(Color.sub)
                }
                .padding(.top, 10)
                .padding(.bottom, 4)

                ForEach(Array(model.friends.enumerated()), id: \.element.id) { i, friend in
                    HStack(spacing: 11) {
                        InitialsAvatar(text: String(friend.name.prefix(1)).uppercased(),
                                       index: i, size: 36)
                            .overlay(alignment: .bottomTrailing) {
                                // Bugün uygulamayı açtıysa yeşil nokta.
                                if friend.activeToday {
                                    Circle().fill(Color.green)
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                }
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.name)
                                .font(.h(13))
                                .foregroundStyle(Color.ink)
                            Text(Self.statsLine(friend))
                                .font(.h(10.5, .bold))
                                .foregroundStyle(Color.sub)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            model.removeFriend(friend)
                        } label: {
                            Label("Arkadaşlıktan çıkar", systemImage: "person.badge.minus")
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
            .card(22)
        }
    }

    private static func statsLine(_ friend: FriendOverview) -> String {
        guard friend.activeToday || friend.exerciseMin > 0 || friend.steps > 0
                || friend.waterML > 0 || friend.kcal > 0 else {
            return "Bugün henüz aktivite yok"
        }
        var parts: [String] = []
        if friend.exerciseMin > 0 { parts.append("\(friend.exerciseMin) dk egzersiz") }
        if friend.steps > 0 { parts.append("\(Self.grouped(friend.steps)) adım") }
        if friend.waterML > 0 { parts.append("\(Self.grouped(friend.waterML)) ml su") }
        if friend.kcal > 0 { parts.append("\(Self.grouped(friend.kcal)) kcal") }
        return parts.isEmpty ? "Bugün uygulamayı açtı" : parts.joined(separator: " · ")
    }

    private static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
