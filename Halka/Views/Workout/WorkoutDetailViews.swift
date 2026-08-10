import SwiftUI

// MARK: - Antrenman detayı (US-023)
//
// "Hangi egzersizleri yaptım?" sorusunun cevabı üç yerde aynı görünmeli:
// ana ekranda bugünün listesi, takvimde seçili günün listesi ve ikisinden de
// açılan tam detay. Daha önce her yerde tek satırlık sıkışık bir özet vardı
// ve hepsi aynı koşu ikonuyla çizildiği için Yoga ile HIIT ayırt edilemiyordu.

/// Tek antrenman — Apple'ın Fitness listesindeki kart.
struct WorkoutRow: View {
    let workout: HealthKitService.WorkoutSummary
    /// Kompakt hâl kart içi listelerde, geniş hâl detay ekranında.
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.coralBg)
                    .frame(width: compact ? 34 : 44, height: compact ? 34 : 44)
                Image(systemName: workout.symbol)
                    .font(.system(size: compact ? 14 : 18, weight: .semibold))
                    .foregroundStyle(Color.coral)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(workout.name)
                    .font(.h(compact ? 11 : 12, .bold))
                    .foregroundStyle(Color.sub)
                    .lineLimit(1)
                Text(workout.headline)
                    .font(.h(compact ? 15 : 20))
                    .foregroundStyle(Color.coral)
                    .kerning(-0.4)
                if !compact {
                    Text(workout.detailLine)
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.faint)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(workout.timeText)
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.faint)
                if compact {
                    Text(workout.durationText)
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.sub)
                }
            }
        }
    }
}

/// Bir günün antrenman özeti — dokununca tam detayı açar.
///
/// Ana ekranda ve takvim detayında aynı kart kullanılıyor; ikisinin farklı
/// görünmesinin bir sebebi yok.
struct WorkoutSummaryCard: View {
    let title: String
    let workouts: [HealthKitService.WorkoutSummary]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.h(12.5))
                        .foregroundStyle(Color.ink)
                    Text("\(workouts.count)")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.coral)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.coralBg))
                    Spacer()
                    Text("Detay")
                        .font(.h(11, .bold))
                        .foregroundStyle(Color.sub)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.chevron)
                }
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    // Kart uzayıp ekranı yutmasın: en fazla üç tanesi burada,
                    // gerisi "Detay"da. Kaç tanesinin gizlendiği yazılıyor —
                    // sessizce kesmek listeyi eksik değil, tamam gösterirdi.
                    ForEach(Array(workouts.prefix(3).enumerated()), id: \.element.id) { i, workout in
                        WorkoutRow(workout: workout, compact: true)
                            .padding(.vertical, 8)
                            .overlay(alignment: .top) {
                                if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                            }
                    }
                    if workouts.count > 3 {
                        HStack {
                            Text("+\(workouts.count - 3) antrenman daha")
                                .font(.h(11, .bold))
                                .foregroundStyle(Color.sub)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .card(18)
        }
        .buttonStyle(.plain)
    }
}

/// Bir günün bütün antrenmanları + toplamları.
struct WorkoutDaySheet: View {
    @Environment(\.dismiss) private var dismiss

    let dayTitle: String
    let workouts: [HealthKitService.WorkoutSummary]
    /// Egzersiz halkasının o günkü değeri ve hedefi (dakika).
    let exerciseMinutes: Int
    let exerciseGoal: Int
    /// 90 günlük listede hiç antrenman var mı? Varsa izin sorunu yoktur —
    /// "bugün antrenman kaydı yok ama yürüyüş dakikası var" normal bir gün.
    var historyHasWorkouts = false
    /// Dakikaların kaynağı Apple Health mi (yoksa elle giriş mi)?
    var sourceIsHealth = true

    private var totalMinutes: Int { workouts.reduce(0) { $0 + $1.minutes } }
    private var totalKcal: Int { workouts.reduce(0) { $0 + $1.kcal } }
    private var totalKm: Double { workouts.reduce(0) { $0 + ($1.distanceKm ?? 0) } }

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ringCard
                        if workouts.isEmpty {
                            emptyCard
                        } else {
                            totalsCard
                            listCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 1) {
                Text("Egzersiz")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Text(dayTitle)
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.sub)
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button("Kapat") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.coral)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    /// Halkanın kendisi — antrenmanlar bu sayının "neden" kısmı.
    private var ringCard: some View {
        let pct = exerciseGoal > 0
            ? min(Double(exerciseMinutes) / Double(exerciseGoal), 1) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(exerciseMinutes)")
                    .font(.h(30))
                    .foregroundStyle(Color.coral)
                    .kerning(-0.8)
                Text("/ \(exerciseGoal) dk")
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.sub)
                Spacer()
                if pct >= 1 {
                    Text("Hedef tamam")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.greenDark)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.greenBg))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.hairline2)
                    Capsule().fill(Color.coral).frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 6)
            // Halka Apple'ın `appleExerciseTime`ından geliyor; antrenman
            // sürelerinin toplamıyla birebir tutmayabilir (tempolu yürüyüş
            // antrenman kaydı olmadan da egzersiz dakikası sayılır).
            // Health bağlı değilse kaynak elle giriştir — hangisinin
            // kullanıldığı açıkça söylenir (US-025).
            Text(historyHasWorkouts || sourceIsHealth
                 ? "Kaynak: Apple Health'in egzersiz dakikası"
                 : "Kaynak: elle girilen egzersiz dakikası")
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var totalsCard: some View {
        HStack(spacing: 0) {
            totalCell("\(workouts.count)", "antrenman", .coral)
            divider
            totalCell(totalMinutes >= 60 ? "\(totalMinutes / 60) sa \(totalMinutes % 60) dk"
                                          : "\(totalMinutes) dk",
                      "süre", .ink)
            if totalKm > 0 {
                divider
                totalCell(HealthKitService.WorkoutSummary.km(totalKm), "mesafe", .stepPurple)
            }
            if totalKcal > 0 {
                divider
                totalCell("\(totalKcal)", "kcal", .warnOrange)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .card(18)
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(width: 1, height: 30)
    }

    private func totalCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.h(15))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.h(10, .bold))
                .foregroundStyle(Color.sub)
        }
        .frame(maxWidth: .infinity)
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(workouts.enumerated()), id: \.element.id) { i, workout in
                WorkoutRow(workout: workout)
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .card(18)
    }

    /// Egzersiz dakikası varken antrenman listesinin TAMAMEN boş olması
    /// (yalnızca o gün değil, 90 günün hiçbirinde) izin verilmediğini
    /// düşündürür. Geçmişte antrenman görünüyorsa izin var demektir —
    /// o günkü boşluk sadece "antrenman kaydı olmayan bir gün"dür.
    private var missingPermission: Bool { exerciseMinutes > 0 && !historyHasWorkouts }

    private var emptyCard: some View {
        VStack(spacing: 6) {
            Image(systemName: missingPermission ? "lock.open.trianglebadge.exclamationmark"
                                                : "figure.mixed.cardio")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color.chevron)
            Text(missingPermission
                 ? "Antrenman listesi okunamıyor"
                 : "Bu gün kayıtlı antrenman yok")
                .font(.h(12.5, .bold))
                .foregroundStyle(Color.sub)
            Text(missingPermission
                 ? "Egzersiz dakikan geliyor ama antrenman kayıtları gelmiyor. Sağlık uygulaması › Profil › Uygulamalar › Halka'dan \"Antrenmanlar\" iznini aç."
                 : "Apple Watch ya da iPhone'da başlattığın antrenmanlar burada listelenir.")
                .font(.h(11, .semibold))
                .foregroundStyle(Color.faint)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .card(18)
    }
}
