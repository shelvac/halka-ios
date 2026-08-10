import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                segmentControl
                    .padding(.bottom, 16)

                switch model.homeSegment {
                case .today: TodayView()
                case .calendar: CalendarPane()
                case .social: SocialPane()
                case .dietitian: DietitianMarketPane()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.todayHeaderTitle)
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.sub)
                Text("Merhaba, \(model.userName)")
                    .font(.h(26))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.5)
            }
            Spacer()
            Button {
                model.tab = .health
                model.healthPane = .profile
            } label: {
                ProfileAvatar(image: model.avatarImage,
                              fullName: model.userFullName, size: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    private var segmentControl: some View {
        HStack(spacing: 4) {
            ForEach(HomeSegment.allCases, id: \.self) { seg in
                let active = model.homeSegment == seg
                Button { model.homeSegment = seg } label: {
                    Text(seg.title)
                        .font(.h(12.5))
                        .foregroundStyle(active ? Color.ink : Color.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Color.white : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .shadow(color: active ? Color.ink.opacity(0.09) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .minimumScaleFactor(0.8)
            }
        }
        .padding(4)
        .background(Color.bgSand)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Today

struct TodayView: View {
    @Environment(AppModel.self) private var model
    /// Egzersiz detayı — halkaya, hedef kartına ya da listeye dokununca açılır.
    @State private var showWorkouts = false
    /// Health bağlı değilken halka kartından elle giriş (US-025).
    @State private var showManualEntry = false

    var body: some View {
        VStack(spacing: 0) {
            ringsCard
            // Hızlı işlemler halkanın hemen altında: en sık yapılan şey su
            // eklemek, aşağıda aramaya değmez.
            quickActions
                .padding(.top, 12)
            // US-027 — beslenme ve egzersizin buluştuğu yer; halkalarda
            // olmayan tek bilgi bu.
            //
            // Buradaki "hedef kartları" ızgarası kaldırıldı: halkanın
            // yanındaki liste zaten "1.240 / 2.000 ml" diyordu, ızgara aynı
            // dört sayıyı ikinci kez yazıp ekranın yarısını kaplıyordu.
            EnergyBalanceCard()
                .padding(.top, 12)
            activityStats
                .padding(.top, 12)
            weekStrip
                .padding(.top, 14)
            streakCard
                .padding(.top, 14)
        }
        .sheet(isPresented: $showWorkouts) {
            WorkoutDaySheet(dayTitle: "Bugün",
                            workouts: model.todayWorkouts,
                            exerciseMinutes: model.exerciseMinutes,
                            exerciseGoal: Int(model.goal(for: .exercise)),
                            historyHasWorkouts: !model.hkWorkouts.isEmpty,
                            sourceIsHealth: model.hkConnected)
        }
    }

    private var ringsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                RingStack(fractions: model.todayFractions, size: 176)
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(RingKind.allCases, id: \.self) { kind in
                        // Egzersiz satırı detaya götürüyor; adım satırı Health
                        // yokken elle girişe. Diğerlerinin alt kırılımı yok.
                        if kind == .exercise {
                            Button { showWorkouts = true } label: {
                                HStack(spacing: 4) {
                                    legendRow(kind)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(Color.chevron)
                                }
                            }
                            .buttonStyle(.plain)
                        } else if kind == .steps && !model.hkConnected {
                            Button { showManualEntry = true } label: {
                                HStack(spacing: 4) {
                                    legendRow(kind)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(Color.chevron)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            legendRow(kind)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Health bağlı değilken veriler elle girilir; bu yol saklı
            // kalmasın (US-025). Bağlıyken kaynak Health'tir ve elle giriş
            // sunulmaz — çakışma sessizce çözülmez, hiç oluşmaz.
            if !model.hkConnected {
                Button { showManualEntry = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.coral)
                        Text("Bugünün verilerini elle gir")
                            .font(.h(12, .bold))
                            .foregroundStyle(Color.inkBody)
                        Spacer()
                        Text("Elle giriş")
                            .font(.h(9.5, .bold))
                            .foregroundStyle(Color.sub)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.bgChip))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.chevron)
                    }
                    .padding(.top, 13)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 13)
            }
        }
        .padding(18)
        .card(22)
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView()
        }
    }

    /// Adım ve aktif enerji — halka DEĞİL, istatistik.
    ///
    /// Adımı egzersiz halkasına katmıyoruz: Apple tempolu yürüyüşü zaten
    /// egzersiz dakikası olarak sayıyor, ikisini toplamak aynı hareketi iki kez
    /// saymak olurdu. Burada hedefsiz, dürüst bir gösterim var.
    @ViewBuilder
    private var activityStats: some View {
        if model.hkConnected {
            HStack(spacing: 0) {
                // Uygulamayı üst üste kaç gün açtığın — alışkanlığın ölçüsü.
                // Uyku buradaydı; hedefi olmayan bir ölçüyü öne çıkarmak yerine
                // seri gösteriliyor. Uyku Health'ten okunmaya devam ediyor ve
                // takvim detayında görünüyor.
                statCell(icon: "flame.fill",
                         value: "\(model.currentStreak)",
                         label: "günlük seri",
                         color: .coral)
                Rectangle().fill(Color.hairline).frame(width: 1, height: 34)
                statCell(icon: "bolt.fill",
                         value: Self.grouped(model.hkActiveEnergy),
                         label: "kcal aktif",
                         color: .warnOrange)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .card(18)

            // Apple Watch'ta yapılan antrenmanlar — egzersiz halkasının
            // "neden dolu" sorusunun cevabı. Dokununca tam detay açılır.
            if !model.todayWorkouts.isEmpty {
                WorkoutSummaryCard(title: "Bugünkü antrenmanlar",
                                   workouts: model.todayWorkouts) {
                    showWorkouts = true
                }
                .padding(.top, 10)
            }
        } else {
            // Bağlı değilken sahte sayı göstermek yerine bağlanmaya çağır.
            Button {
                model.tab = .health
                model.healthPane = .profile
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.coral)
                    Text("Adım, uyku ve enerji için Apple Health'i bağla")
                        .font(.h(12, .bold))
                        .foregroundStyle(Color.inkBody)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.chevron)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .card(18)
            }
            .buttonStyle(.plain)
        }
    }

    private func statCell(icon: String, value: String, label: String,
                          color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.h(18))
                    .foregroundStyle(Color.ink)
            }
            Text(label)
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.sub)
        }
        .frame(maxWidth: .infinity)
    }

    /// 8432 → "8.432" (Türkçe binlik ayırıcı).
    private static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func legendRow(_ kind: RingKind) -> some View {
        let color: Color = switch kind {
        case .exercise: .coral
        case .water: .waterBlue
        case .steps: .stepPurple
        case .nutrition: .green
        }
        let cur = model.currentValue(kind)
        let goalValue = model.goal(for: kind)
        let curText = Self.grouped(Int(cur))
        let goalText = Self.grouped(Int(goalValue))
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(kind.name)
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.sub)
            }
            (Text("\(curText) / \(goalText)")
                .font(.h(16))
                .foregroundColor(color)
             + Text(" \(kind.unit)")
                .font(.h(10, .bold))
                .foregroundColor(.faint))
                .kerning(-0.3)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            // Su sayacı: eksi/artı birlikte. Eskiden yalnızca eklemenin
            // ardından 6 saniye görünen tek seferlik "Geri al" vardı; sonradan
            // düzeltmenin yolu yoktu.
            HStack(spacing: 0) {
                Button { model.removeWater() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(model.water > 0 ? Color.blueDark : Color.chevron)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(model.water == 0)

                Text("\(model.water) ml")
                    .font(.h(12))
                    .foregroundStyle(Color.blueDark)
                    .frame(minWidth: 56)

                Button { model.addWater() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.blueDark)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .background(Capsule().fill(Color.blueBg))

            Button {
                model.tab = .meal
                model.mealView = .photo
            } label: {
                pillLabel("Öğün ekle")
            }
            .buttonStyle(.plain)

            Button {
                model.tab = .workout
                model.workoutView = .home
            } label: {
                pillLabel("Egzersiz")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: model.water)
    }

    private func pillLabel(_ text: String) -> some View {
        Text(text)
            .font(.h(12, .bold))
            .foregroundStyle(Color.inkMid)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.white))
            .shadow(color: Color.ink.opacity(0.05), radius: 3, y: 1)
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bu hafta")
                .font(.h(13))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 4)
            HStack {
                // US-024: hafta gerçek takvimden — eskiden 3-9 Ağustos'a sabitti.
                ForEach(Array(model.currentWeek.enumerated()), id: \.offset) { i, date in
                    let isToday = AppModel.appCalendar.isDate(date, inSameDayAs: model.today)
                    VStack(spacing: 5) {
                        MiniRings(fractions: model.fractions(for: date))
                        Text(Demo.dayNamesShort[i])
                            .font(.h(10))
                            .foregroundStyle(isToday ? Color.ink : Color.faint)
                    }
                    if i < 6 { Spacer() }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .card(20)
    }

    /// Marka mesajı. Seri sayısı istatistik satırında gösteriliyor; burada
    /// tekrarlamak yerine yalnızca teşvik metni duruyor.
    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(Color.coral, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 27, height: 27)
                Circle().fill(Color.coral).frame(width: 11, height: 11)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.currentStreak > 1
                     ? "\(model.currentStreak) gündür buradasın"
                     : "Hoş geldin")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Text("Her gün %1 daha iyi — halkaları kapatmaya devam.")
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.coralNote)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.coralBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Elle veri girişi (US-025)

/// Apple Health bağlı olmayan kullanıcı için günün değerleri.
///
/// Health bağlıyken bu ekran sunulmaz: Health tek doğru kaynaktır ve
/// tazelemede elle girilenin üstüne yazardı — kullanıcıya iki kaynağın
/// çatıştığı bir durum hiç yaşatılmıyor.
struct ManualEntryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseText = ""
    @State private var stepsText = ""
    @State private var sleepText = ""

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Bugünün verileri")
                        .font(.h(15))
                        .foregroundStyle(Color.ink)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button("Kapat") { dismiss() }
                        .font(.h(13))
                        .foregroundStyle(Color.coral)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if model.hkConnected {
                            // Health bağlıyken elle giriş kapalı — kaynağın kim
                            // olduğu belirsizleşmesin, Health değeri ezilmesin.
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color.green).frame(width: 9, height: 9)
                                    Text("Apple Health bağlı")
                                        .font(.h(13))
                                        .foregroundStyle(Color.ink)
                                }
                                Text("Egzersiz, adım ve uyku Health'ten otomatik okunuyor: bugün \(model.exerciseMinutes) dk egzersiz · \(model.hkSteps) adım. Elle giriş bu yüzden kapalı — iki kaynak çakışmasın. Health'i kapatırsan (Ayarlar › Gizlilik › Sağlık › halka) bu ekrandan girebilirsin.")
                                    .font(.h(11.5, .semibold))
                                    .foregroundStyle(Color.sub)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card(18)
                        } else {
                        VStack(alignment: .leading, spacing: 0) {
                            field("Egzersiz", unit: "dk", text: $exerciseText,
                                  placeholder: "\(model.exerciseMinutes)")
                            divider
                            field("Adım", unit: "adım", text: $stepsText,
                                  placeholder: "\(model.hkSteps)")
                            divider
                            field("Uyku", unit: "saat", text: $sleepText,
                                  placeholder: String(format: "%.1f", model.sleepHours))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .card(18)

                        Text("Su ana ekrandan, yemekler kalori günlüğünden, kilo Sağlık sekmesinden girilir. Bu değerler \"elle girildi\" olarak kaydedilir; Apple Health'i bağlarsan kaynak Health olur.")
                            .font(.h(11, .semibold))
                            .foregroundStyle(Color.sub)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            model.saveManualEntry(
                                exerciseMin: Int(exerciseText.trimmingCharacters(in: .whitespaces)),
                                steps: Int(stepsText.trimmingCharacters(in: .whitespaces)),
                                sleep: Double(sleepText.replacingOccurrences(of: ",", with: ".")
                                    .trimmingCharacters(in: .whitespaces)))
                            dismiss()
                        } label: {
                            Text("Kaydet").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .coralButton()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(height: 1)
    }

    private func field(_ label: String, unit: String,
                       text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.h(13, .bold))
                .foregroundStyle(Color.inkBody)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.h(15))
                .foregroundStyle(Color.ink)
                .frame(width: 90)
            Text(unit)
                .font(.h(11, .bold))
                .foregroundStyle(Color.sub)
                .frame(width: 38, alignment: .leading)
        }
        .padding(.vertical, 13)
    }
}
