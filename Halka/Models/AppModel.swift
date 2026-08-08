import SwiftUI
import Observation

/// Single source of truth for the whole app (demo/in-memory, mirrors the prototype's state).
@MainActor
@Observable
final class AppModel {

    // MARK: Auth / routing
    var screen: Screen = .splash
    var loginRole: Role = .user       // segment on the login screen
    var role: Role = .user            // active session role
    var tab: Tab = .home
    var homeSegment: HomeSegment = .today

    // MARK: Auth state (Sprint 1)
    var authBusy = false
    var authError: String? = nil
    var authInfo: String? = nil
    var forgotSent = false
    var pendingEmail = ""        // doğrulama bekleyen hesap
    var userName = "Simge"            // selamlamada görünen ad (buluttan güncellenir)
    var userFullName = "Simge Helvacı"

    // MARK: Profil (US-016)
    /// Buluttan yüklenen profil. Boşken hedefler varsayılan değerlere düşer.
    var profile = Profile()
    var profileBusy = false
    var profileError: String? = nil
    /// Profil fotoğrafı — buluttan indirilip bellekte tutulur (US-016).
    var avatarImage: UIImage? = nil

    /// Kişiye özel halka hedefi; profil eksikse `RingKind`'ın varsayılanı.
    func goal(for kind: RingKind) -> Double {
        switch kind {
        case .exercise: return Double(profile.exerciseGoalMin)
        case .water: return Double(profile.waterGoalML ?? Int(kind.goal))
        case .steps: return Double(profile.stepsGoal)
        case .nutrition: return Double(profile.calorieGoal ?? Int(kind.goal))
        }
    }

    // MARK: Rings (US-024 — gerçek veri; demo değerleri kaldırıldı)
    //
    // Yeni kullanıcı halkaları SIFIRDAN görür. Değerler Apple Health'ten ya da
    // kullanıcının kendi girdisinden gelir, `rings_daily` tablosunda saklanır.
    var water = 0                     // ml
    var exerciseBase = 0              // Health'ten okunan egzersiz dakikası
    var extraExerciseMin = 0          // uygulama içi antrenmanlardan eklenen
    var sleepHours = 0.0              // Health'ten okunan uyku

    /// Takvim: gerçek tarihe bağlı (eskiden Ağustos 2026'ya sabitti).
    var visibleMonth: Date = AppModel.appCalendar.date(
        from: AppModel.appCalendar.dateComponents([.year, .month], from: Date())) ?? Date()
    var selectedCalendarDay: Int = AppModel.appCalendar.component(.day, from: Date())
    /// Görüntülenen ayın kayıtları ("yyyy-MM-dd" → satır).
    var ringHistory: [String: SupabaseService.RingsRow] = [:]
    var ringSaveToken = 0

    var exerciseMinutes: Int { exerciseBase + extraExerciseMin }

    /// Bugünün halka oranları [egzersiz, su, adım, beslenme].
    var todayFractions: [Double] {
        [Double(exerciseMinutes) / goal(for: .exercise),
         Double(water) / goal(for: .water),
         Double(hkSteps) / goal(for: .steps),
         Double(nutritionToday) / goal(for: .nutrition)]
    }

    func currentValue(_ kind: RingKind) -> Double {
        switch kind {
        case .exercise: return Double(exerciseMinutes)
        case .water: return Double(water)
        case .steps: return Double(hkSteps)
        case .nutrition: return Double(nutritionToday)
        }
    }

    /// Su sayacı — 250 ml adımlarla. Üst sınır 4 L: günlük su hedefinin
    /// tavanıyla aynı, üstü tıbbi değerlendirme ister.
    func addWater() {
        water = min(water + 250, 4000)
        scheduleRingSave()
    }

    /// Yanlış eklemeyi düzeltmek için. Eskiden yalnızca eklemenin ardından
    /// 6 saniye görünen tek seferlik bir "geri al" vardı; sonradan düzeltme
    /// mümkün değildi.
    func removeWater() {
        water = max(water - 250, 0)
        scheduleRingSave()
    }

    /// Uykuyu elle ayarlar (US-025 — Health'te uyku kaydı olmayan kullanıcılar).
    /// Health'ten veri geldiğinde `refreshFromHealthKit` bunun üzerine yazar:
    /// ölçülen veri, tahmin edilenden önce gelir.
    func setSleepHours(_ hours: Double) {
        sleepHours = min(max(hours, 0), 14)
        scheduleRingSave()
    }

    // MARK: Meals
    var mealDay: Int = (AppModel.appCalendar.component(.weekday, from: Date()) + 5) % 7
    var mealView: MealView = .menu
    var mealBack: MealView = .menu
    var mealSelection: MealSelection? = nil
    var mealTimes = ["09:00", "13:30", "16:30", "19:30"]
    var eaten: Set<String> = []       // US-024: yenmiş öğünler kullanıcı verisi
    var overrides: [String: String] = [:]
    var marketChecked: Set<String> = []
    var extras: [ExtraMeal] = []
    var photoData: Data? = nil
    var photoState: PhotoState = .idle

    // MARK: Coach
    var messages: [CoachMessage] = Demo.initialMessages()
    var coachTyping = false
    var coachDraft = ""
    var pending: CoachPending = .none
    var pendingMealGoal = "kilo"

    // MARK: Workout
    var workoutView: WorkoutView = .home
    var libraryRegion = "Tümü"
    var libraryQuery = ""
    var libraryPickMode = false
    var programDraft = ProgramDraft()
    var programs: [WorkoutProgram] = Demo.initialPrograms()
    var selectedProgramID: UUID? = nil
    var runStart: Date? = nil
    var runDone: Set<Int> = []
    var workoutLog: [WorkoutLogEntry] = []

    var selectedProgram: WorkoutProgram? {
        programs.first { $0.id == selectedProgramID }
    }

    // MARK: HealthKit (Sprint 4)
    var hkConnected = false
    var hkSteps = 0
    var hkActiveEnergy = 0
    /// Apple Watch/iPhone'da kaydedilen antrenmanlar — son 90 gün (US-023).
    /// Bugünküler ana ekranda, geçmiş günler takvim ve Egzersiz sekmesinde.
    var hkWorkouts: [HealthKitService.WorkoutSummary] = []
    /// Geçmiş aktarımı bu oturumda yapıldı mı? (her tazelemede tekrarlanmasın)
    var healthBackfillDone = false

    /// İzin diyaloğunu tetikler (Profil'deki "Bağlan" düğmesi).
    func connectHealthKit() {
        guard HealthKitService.shared.isAvailable else { return }
        Task { [weak self] in
            try? await HealthKitService.shared.requestAuthorization()
            await self?.refreshFromHealthKit()
        }
    }

    /// Sessiz senkronizasyon: izin verilmişse Health verisi halkalara işlenir.
    ///
    /// Health bu ölçüler için tek doğru kaynak sayılır — kullanıcı Health'te
    /// düzeltme yaptıysa uygulama onu ezmemeli. Su ise iki yerden gelebildiği
    /// için (uygulama içi "+250 ml" ya da Health) büyük olan alınır: Health'e
    /// yazmadığımız sürece uygulamadaki eklemeler orada görünmüyor.
    func refreshFromHealthKit() async {
        guard HealthKitService.shared.isAvailable else { return }
        let snapshot = await HealthKitService.shared.fetchToday()
        guard snapshot.hasAnyData else { return }
        hkConnected = true
        hkSteps = snapshot.steps
        hkActiveEnergy = snapshot.activeEnergy
        if snapshot.exerciseMinutes > 0 { exerciseBase = snapshot.exerciseMinutes }
        if snapshot.sleepHours > 0 { sleepHours = snapshot.sleepHours }
        if snapshot.waterML > 0 { water = max(water, snapshot.waterML) }
        hkWorkouts = await HealthKitService.shared.fetchWorkouts(days: 90)
        await persistRings()
        // Geçmişi bir kez aktar: takvim ilk açılışta dolu gelsin.
        if !healthBackfillDone { await backfillFromHealthKit() }
    }

    // MARK: Health
    var healthPane: HealthPane = .body
    /// US-025 — Vücut ölçümleri (yeniden eskiye). Yeni kullanıcıda BOŞ:
    /// demo kilo geçmişi kaldırıldı, veriyi kullanıcı ekliyor.
    var bodyMeasurements: [BodyMeasurement] = []
    var scaleBusy = false
    var bodyError: String? = nil
    /// Onay bekleyen tartı fotoğrafı (kaydedilince yüklenir).
    var pendingScalePhoto: UIImage? = nil
    var supplements: [Supplement] = Demo.initialSupplements
    var bloodPdfState: ProcessState = .idle
    var bloodPdfName = ""
    var healthShotState: ProcessState = .idle

    // MARK: Social
    var friends: [Friend] = Demo.initialFriends()
    var friendNameDraft = ""

    // MARK: Dietitian marketplace
    var marketView: MarketView = .list
    var selectedDietitian = 0
    var payState: PayState = .idle
    var myDietitian: MyDietitian? = nil

    // MARK: Dietitian panel
    var clients: [Client] = Demo.initialClients()
    var clientNameDraft = ""
    var panelView: PanelView = .list
    var selectedClient = 0
    var clientTab: ClientTab = .general
    var allergyDraft = ""
    var dietDay = 0
    var dietPlan: [[String]]? = nil   // 7×4, defaults to Demo.menus until edited
    var dietKcalTarget = "1400"
    var dietSent = false

    // MARK: Auth actions

    func login() {
        if loginRole == .dietitian {
            screen = .premium
        } else {
            role = .user
            screen = .app
        }
    }

    func startPremium() {
        role = .dietitian
        panelView = .list
        screen = .app
    }

    func continueFree() {
        role = .user
        screen = .app
    }

    /// US-021 — Hesabı sil. Sunucudaki veri cascade ile temizlenir; sonrasında
    /// oturum kapanır ve giriş ekranına dönülür (çıkışla aynı yerel sıfırlama).
    func deleteAccount() async {
        authError = nil
        authBusy = true
        defer { authBusy = false }
        do {
            try await SupabaseService.shared.deleteAccount()
            logout()
            authInfo = "Hesabın ve tüm verilerin silindi."
        } catch {
            authError = "Hesap silinemedi: \(error.localizedDescription)"
        }
    }

    func logout() {
        Task { await SupabaseService.shared.signOut() }
        screen = .login
        role = .user
        tab = .home
        homeSegment = .today
        healthPane = .body
        authError = nil
        authInfo = nil
        userName = "Simge"
        userFullName = "Simge Helvacı"
        pendingEmail = ""
    }

    // MARK: Shared helpers

    func recipe(for food: String, slot: Int) -> Recipe {
        if let r = Demo.recipes[food] { return r }
        let parts = food
            .components(separatedBy: CharacterSet(charactersIn: "+·:,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let kcal = slot >= 0 && slot < Demo.fallbackKcal.count ? Demo.fallbackKcal[slot] : 350
        return Recipe(kcal: kcal, ingredients: parts,
                      steps: ["Malzemeleri hazırla ve porsiyonla", "Tercihe göre pişir ve servis et"])
    }

    static func nowHHmm() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}
