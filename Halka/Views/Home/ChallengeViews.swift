import SwiftUI

// MARK: - Challenge kartları + liderlik tablosu (0034)
//
// Eski demo tasarımın gerçek veriyle yeniden doğuşu: koyu challenge kartı
// (katılımcı çubukları) ve aylık "halka puanı" liderlik tablosu.

/// Aktif / biten challenge kartı — koyu zemin, kişi başı ilerleme çubuğu.
struct ChallengeCard: View {
    @Environment(AppModel.self) private var model
    var challenge: ChallengeOverview

    private var joined: [ChallengeMemberOverview] {
        challenge.members.filter { $0.status == "katildi" }
    }
    private var myProgress: Double {
        guard challenge.daysTotal > 0,
              let me = joined.first(where: { $0.isMe }) else { return 0 }
        return Double(me.daysDone) / Double(challenge.daysTotal)
    }
    private var subtitle: String {
        if challenge.isFinished {
            let best = joined.map(\.daysDone).max() ?? 0
            let winners = joined.filter { $0.daysDone == best && best > 0 }
            if winners.contains(where: { $0.isMe }) {
                return winners.count > 1 ? "Bitti — ortak zafer! 🏆" : "Bitti — kazandın! 🏆"
            }
            return winners.isEmpty ? "Bitti" : "Bitti — kazanan: \(winners[0].name)"
        }
        return "\(joined.count) katılımcı · \(challenge.daysLeft) gün kaldı"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.isFinished ? "BİTEN CHALLENGE" : "AKTİF CHALLENGE")
                        .font(.h(10))
                        .foregroundStyle(Color.gold)
                        .kerning(1.5)
                    Text(challenge.title)
                        .font(.h(18))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.h(10.5, .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: myProgress)
                        .stroke(Color.gold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 34, height: 34)
            }

            VStack(spacing: 8) {
                ForEach(joined) { member in
                    HStack(spacing: 10) {
                        Text(member.isMe ? "Sen" : member.name)
                            .font(.h(11, .bold))
                            .foregroundStyle(.white.opacity(member.isMe ? 1 : 0.75))
                            .frame(width: 64, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                Capsule()
                                    .fill(member.isMe ? Color.gold : Color.blueDark)
                                    .frame(width: geo.size.width
                                        * (challenge.daysTotal > 0
                                           ? Double(member.daysDone) / Double(challenge.daysTotal)
                                           : 0))
                            }
                        }
                        .frame(height: 7)
                        Text("\(member.daysDone)/\(challenge.daysTotal)")
                            .font(.h(10.5, .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            if !challenge.isFinished {
                Button(role: .destructive) {
                    model.respondChallenge(challenge, accept: false)
                } label: {
                    Label("Challenge'dan ayrıl", systemImage: "flag.slash")
                }
            }
        }
    }
}

/// Bana gelen challenge daveti — kabul/ret (rıza ilkesi: arkadaş isteğiyle aynı).
struct ChallengeInviteCard: View {
    @Environment(AppModel.self) private var model
    var challenge: ChallengeOverview

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                Text("Challenge daveti — \(challenge.daysLeft) gün")
                    .font(.h(10.5, .bold))
                    .foregroundStyle(Color.sub)
            }
            Spacer()
            Button { model.respondChallenge(challenge, accept: true) } label: {
                Text("Katıl")
                    .font(.h(11.5))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.coral)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button { model.respondChallenge(challenge, accept: false) } label: {
                Text("Reddet")
                    .font(.h(11.5))
                    .foregroundStyle(Color.sub)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .card(18)
    }
}

/// Aylık halka puanı liderlik tablosu.
struct LeaderboardCard: View {
    @Environment(AppModel.self) private var model

    private static var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "LLLL"
        return f.string(from: Date()).capitalized(with: Locale(identifier: "tr_TR"))
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.gold
        case 2: return Color.coral
        case 3: return Color.greenDark
        default: return Color.faint
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Liderlik Tablosu")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(Self.monthLabel) · halka puanı")
                    .font(.h(10))
                    .foregroundStyle(Color.sub)
            }
            .padding(.top, 12)
            .padding(.bottom, 6)
            .padding(.horizontal, 18)

            ForEach(Array(model.leaderboard.enumerated()), id: \.element.id) { i, row in
                HStack(spacing: 11) {
                    Text("\(i + 1)")
                        .font(.h(13))
                        .foregroundStyle(rankColor(i + 1))
                        .frame(width: 16)
                        .monospacedDigit()
                    InitialsAvatar(text: String(row.name.prefix(1)).uppercased(),
                                   index: i, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.isMe ? "Sen" : row.name)
                            .font(.h(13))
                            .foregroundStyle(Color.ink)
                        Text(row.streak > 0 ? "\(row.streak) gün seri" : "seri yok")
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text("\(row.points)")
                        .font(.h(15))
                        .foregroundStyle(Color.ink)
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(row.isMe ? Color.coralBg : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 6)
            }
        }
        .padding(.bottom, 8)
        .card(22)
    }
}

// MARK: - Challenge kurma

struct ChallengeCreateSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ChallengeKind = .su
    @State private var target = ChallengeKind.su.defaultTarget
    @State private var days = 7
    @State private var selected: Set<UUID> = []
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(kind.autoTitle(target: target, days: days))
                        .font(.h(20))
                        .foregroundStyle(Color.ink)

                    Picker("Tür", selection: $kind) {
                        ForEach(ChallengeKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, new in target = new.defaultTarget }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("GÜNLÜK HEDEF")
                            .font(.h(10))
                            .foregroundStyle(Color.faint)
                            .kerning(1.2)
                        HStack {
                            Button { target = max(kind.targetStep, target - kind.targetStep) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.chevron)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Text("\(target) \(kind.unit)")
                                .font(.h(17))
                                .foregroundStyle(Color.ink)
                                .monospacedDigit()
                            Spacer()
                            Button { target = min(100000, target + kind.targetStep) } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.coral)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .card(16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SÜRE")
                            .font(.h(10))
                            .foregroundStyle(Color.faint)
                            .kerning(1.2)
                        HStack(spacing: 8) {
                            ForEach([7, 14, 21], id: \.self) { d in
                                Button { days = d } label: {
                                    Text("\(d) gün")
                                        .font(.h(12, .bold))
                                        .foregroundStyle(days == d ? .white : Color.ink)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(days == d ? Color.ink : Color.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ARKADAŞLARINI DAVET ET")
                            .font(.h(10))
                            .foregroundStyle(Color.faint)
                            .kerning(1.2)
                        if model.friends.isEmpty {
                            Text("Önce bir arkadaş eklemelisin — challenge tek başına olmaz.")
                                .font(.h(11.5, .semibold))
                                .foregroundStyle(Color.sub)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(model.friends.enumerated()), id: \.element.id) { i, friend in
                                    Button {
                                        if selected.contains(friend.id) { selected.remove(friend.id) }
                                        else { selected.insert(friend.id) }
                                    } label: {
                                        HStack(spacing: 11) {
                                            InitialsAvatar(text: String(friend.name.prefix(1)).uppercased(),
                                                           index: i, size: 32)
                                            Text(friend.name)
                                                .font(.h(13))
                                                .foregroundStyle(Color.ink)
                                            Spacer()
                                            Image(systemName: selected.contains(friend.id)
                                                  ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundStyle(selected.contains(friend.id)
                                                                 ? Color.coral : Color.chevron)
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .top) {
                                        if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .card(16)
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.h(12, .bold))
                            .foregroundStyle(Color.coralDark)
                    }

                    Button {
                        busy = true
                        error = nil
                        Task {
                            let result = await model.createChallenge(
                                kind: kind, target: target, days: days,
                                invitees: Array(selected))
                            busy = false
                            if let result { error = result } else { dismiss() }
                        }
                    } label: {
                        Text(busy ? "Kuruluyor…" : "Davetleri Gönder")
                            .font(.h(14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(selected.isEmpty ? Color.chevron : Color.coral)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(selected.isEmpty || busy)
                }
                .padding(20)
            }
            .background(Color.bgApp)
            .navigationTitle("Yeni Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .font(.h(13))
                        .foregroundStyle(Color.coral)
                }
            }
        }
    }
}
