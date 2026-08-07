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

    // MARK: Rings (demo day: 5 Ağustos 2026, Çarşamba)
    var water = 1250                  // ml
    var exerciseBase = 24             // minutes logged before app interactions
    var extraExerciseMin = 0          // added by workouts + Health imports
    var sleepHours = 6.5              // overwritten by HealthKit when data exists
    var waterUndoVisible = false
    private var waterUndoToken = 0
    var selectedCalendarDay = 5

    var exerciseMinutes: Int { exerciseBase + extraExerciseMin }

    /// Ring fractions [exercise, water, sleep, nutrition] for today.
    var todayFractions: [Double] {
        [Double(exerciseMinutes) / RingKind.exercise.goal,
         Double(water) / RingKind.water.goal,
         sleepHours / RingKind.sleep.goal,
         Double(nutritionToday) / RingKind.nutrition.goal]
    }

    func fractions(forDay day: Int) -> [Double] {
        day == 5 ? todayFractions : (Demo.history[day] ?? [0, 0, 0, 0])
    }

    func currentValue(_ kind: RingKind) -> Double {
        switch kind {
        case .exercise: return Double(exerciseMinutes)
        case .water: return Double(water)
        case .sleep: return sleepHours
        case .nutrition: return Double(nutritionToday)
        }
    }

    func addWater() {
        water = min(water + 250, 3000)
        waterUndoVisible = true
        waterUndoToken += 1
        let token = waterUndoToken
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.waterUndoToken == token else { return }
            self.waterUndoVisible = false
        }
    }

    func undoWater() {
        water = max(water - 250, 0)
        waterUndoVisible = false
        waterUndoToken += 1
    }

    // MARK: Meals
    var mealDay = 2                   // Wednesday
    var mealView: MealView = .menu
    var mealBack: MealView = .menu
    var mealSelection: MealSelection? = nil
    var mealTimes = ["09:00", "13:30", "16:30", "19:30"]
    var eaten: Set<String> = ["2-0", "2-1"]
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

    /// İzin diyaloğunu tetikler (Profil'deki "Bağlan" düğmesi).
    func connectHealthKit() {
        guard HealthKitService.shared.isAvailable else { return }
        Task { [weak self] in
            try? await HealthKitService.shared.requestAuthorization()
            await self?.refreshFromHealthKit()
        }
    }

    /// Sessiz senkronizasyon: izin zaten verilmişse veriyi halkalara işler,
    /// verilmemişse hiçbir diyalog göstermeden demo değerlerde kalır.
    func refreshFromHealthKit() async {
        guard HealthKitService.shared.isAvailable else { return }
        let snapshot = await HealthKitService.shared.fetchToday()
        guard snapshot.hasAnyData else { return }
        hkConnected = true
        hkSteps = snapshot.steps
        hkActiveEnergy = snapshot.activeEnergy
        if snapshot.exerciseMinutes > 0 { exerciseBase = snapshot.exerciseMinutes }
        if snapshot.sleepHours > 0 { sleepHours = snapshot.sleepHours }
    }

    // MARK: Health
    var healthPane: HealthPane = .body
    var supplements: [Supplement] = Demo.initialSupplements
    var bodyPdfState: ProcessState = .idle
    var bodyPdfName = ""
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
