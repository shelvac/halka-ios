import XCTest
@testable import Halka

/// Sprint 1 test temeli: saf iş mantığı (halka hesapları, tarifler,
/// alerji tespiti, koç akışları). UI testleri sonraki sprintlerde.
final class AppModelTests: XCTestCase {

    // MARK: Kalori günlüğü / Beslenme halkası

    @MainActor
    func testNewUserStartsWithEmptyLog() {
        let model = AppModel()
        // US-024: yeni kullanıcıda yenmiş öğün yok — beslenme halkası sıfırdan.
        XCTAssertEqual(model.consumed(forDay: 2), 0)
        XCTAssertEqual(model.nutritionToday, 0)
    }

    @MainActor
    func testRingsStartEmptyForNewUser() {
        let model = AppModel()
        XCTAssertEqual(model.water, 0)
        XCTAssertEqual(model.exerciseMinutes, 0)
        XCTAssertEqual(model.sleepHours, 0)
        XCTAssertTrue(model.todayFractions.allSatisfy { $0 == 0 })
    }

    @MainActor
    func testPastDaysWithoutRecordsShowZero() {
        let model = AppModel()
        // Demo geçmişi kaldırıldı: kaydı olmayan gün sıfır gösterir, uydurulmaz.
        let past = max(model.selectedCalendarDay - 1, 1)
        if !model.isToday(day: past) {
            XCTAssertEqual(model.fractions(forDay: past), [0, 0, 0, 0])
            XCTAssertFalse(model.hasData(forDay: past))
        }
    }

    @MainActor
    func testTodayWeekdayIndexIsMondayBased() {
        let model = AppModel()
        XCTAssertTrue((0...6).contains(model.todayWeekdayIndex))
        XCTAssertEqual(model.mealDay, model.todayWeekdayIndex)
    }

    @MainActor
    func testTogglingMealUpdatesConsumed() {
        let model = AppModel()
        model.toggleEaten(day: 2, slot: 0) // Çarşamba sabah, 310 kcal
        XCTAssertEqual(model.consumed(forDay: 2), 310)
        model.toggleEaten(day: 2, slot: 2) // Meyve + fındık, 150 kcal
        XCTAssertEqual(model.consumed(forDay: 2), 460)
        model.toggleEaten(day: 2, slot: 2)
        XCTAssertEqual(model.consumed(forDay: 2), 310)
    }

    @MainActor
    func testPhotoExtraCountsTowardsConsumedAndCanBeDeleted() {
        let model = AppModel()
        let estimate = model.currentPhotoEstimate
        let day = model.mealDay          // fotoğraftan öğün bugüne eklenir
        model.savePhotoMeal()
        XCTAssertEqual(model.consumed(forDay: day), estimate.total)
        XCTAssertEqual(model.extras(forDay: day).count, 1)
        model.deleteExtra(model.extras(forDay: day)[0].id)
        XCTAssertEqual(model.consumed(forDay: day), 0)
    }

    @MainActor
    func testCatalogOverrideReplacesPlannedMeal() {
        let model = AppModel()
        model.mealSelection = MealSelection(food: "Yulaf pancake", mealIndex: 0,
                                            fromCatalog: true, catalogName: "Kahvaltı")
        model.adoptCatalogMeal()
        // Öğün düzenlemeleri BUGÜNÜN gününe yazılır (mealDay), sabit güne değil.
        XCTAssertEqual(model.menu(forDay: model.mealDay)[0], "Yulaf pancake")
    }

    // MARK: Su sayacı

    @MainActor
    func testWaterAddAndRemoveRespectBounds() {
        let model = AppModel()
        XCTAssertEqual(model.water, 0)

        model.addWater()
        model.addWater()
        XCTAssertEqual(model.water, 500)

        // Azaltma her an yapılabilir, tek seferle sınırlı değil.
        model.removeWater()
        model.removeWater()
        XCTAssertEqual(model.water, 0)

        // Sıfırın altına inmez.
        model.removeWater()
        XCTAssertEqual(model.water, 0)

        // Üst sınır 4 L.
        for _ in 0..<40 { model.addWater() }
        XCTAssertEqual(model.water, 4000)
    }

    // MARK: Tarifler

    @MainActor
    func testKnownRecipeKcal() {
        let model = AppModel()
        XCTAssertEqual(model.recipe(for: "Yulaf + yoğurt + meyve", slot: 0).kcal, 320)
        XCTAssertEqual(model.recipe(for: "Izgara tavuk + bulgur + salata", slot: 1).kcal, 450)
    }

    @MainActor
    func testUnknownRecipeFallsBackToSlotKcalAndSplitsIngredients() {
        let model = AppModel()
        let recipe = model.recipe(for: "Ev yemeği + salata", slot: 1)
        XCTAssertEqual(recipe.kcal, 450) // slot 1 fallback
        XCTAssertEqual(recipe.ingredients, ["Ev yemeği", "salata"])
    }

    // MARK: Alerji çakışma tespiti (diyetisyen paneli)

    @MainActor
    func testLactoseIntoleranceMatchesDairyMeals() {
        let model = AppModel()
        let ayse = model.clients[0] // Fındık + Laktoz intoleransı
        XCTAssertEqual(model.allergyHits(meal: "Yoğurt + ceviz", client: ayse),
                       ["Laktoz intoleransı"])
        XCTAssertEqual(model.allergyHits(meal: "Meyve + fındık", client: ayse),
                       ["Fındık"])
        XCTAssertTrue(model.allergyHits(meal: "Izgara hindi + sebze", client: ayse).isEmpty)
    }

    @MainActor
    func testSeafoodAllergyMatchesFishKeywords() {
        let model = AppModel()
        let mehmet = model.clients[1] // Deniz ürünleri
        XCTAssertFalse(model.allergyHits(meal: "Fırında somon + sebze", client: mehmet).isEmpty)
        XCTAssertFalse(model.allergyHits(meal: "Ton balıklı salata", client: mehmet).isEmpty)
        XCTAssertTrue(model.allergyHits(meal: "Izgara tavuk + bulgur", client: mehmet).isEmpty)
    }

    @MainActor
    func testWeekWideAllergyWarningsForFirstClient() {
        let model = AppModel()
        model.selectedClient = 0
        XCTAssertFalse(model.allergyWarnings.isEmpty)
        // Düzenlenen öğün çakışmayı giderirse uyarı da kalkar.
        for day in 0..<7 {
            for slot in 0..<4 {
                model.setDietMeal(day: day, slot: slot, text: "Izgara hindi + pirinç")
            }
        }
        XCTAssertTrue(model.allergyWarnings.isEmpty)
    }

    // MARK: AI Koç akışları

    @MainActor
    func testCoachWorkoutFlowProducesSevenDayPlan() {
        let model = AppModel()
        let ask = model.coachReply(to: "Haftalık antrenman planı")
        XCTAssertEqual(ask.role, .ask)
        let plan = model.coachReply(to: "4 gün")
        XCTAssertEqual(plan.role, .week)
        XCTAssertEqual(plan.weekDays.count, 7)
        XCTAssertEqual(plan.weekDays.filter { !$0.rest }.count, 4)
    }

    @MainActor
    func testCoachMealFlowUsesChosenTimes() {
        let model = AppModel()
        _ = model.coachReply(to: "Haftalık besin planı")   // hedef sorusu
        _ = model.coachReply(to: "Kilo vermek")            // saat sorusu
        let menu = model.coachReply(to: "09:00 · 13:30 · 17:00 · 20:30")
        XCTAssertEqual(menu.role, .menu)
        XCTAssertEqual(menu.mealTimes, ["09:00", "13:30", "17:00", "20:30"])
        XCTAssertEqual(menu.menuDays.count, 7)
        XCTAssertEqual(menu.menuDays[0].meals.map(\.time)[0], "09:00")
    }

    @MainActor
    func testParseTimesVariants() {
        let model = AppModel()
        XCTAssertEqual(model.parseTimes("8 13 16 20"),
                       ["08:00", "13:00", "16:00", "20:00"])
        XCTAssertEqual(model.parseTimes("07:30 · 12:30 · 16:00 · 19:30"),
                       ["07:30", "12:30", "16:00", "19:30"])
        // Eksik/karışık girişte güvenli varsayılana döner.
        XCTAssertEqual(model.parseTimes("bilmem"),
                       ["07:30", "12:30", "16:00", "19:30"])
    }

    // MARK: Egzersiz

    @MainActor
    func testFinishRunAddsMinutesAndLogEntry() {
        let model = AppModel()
        model.selectedProgramID = model.programs[0].id
        model.startRun()
        model.toggleRunDone(0)
        model.toggleRunDone(1)
        let before = model.exerciseMinutes
        model.finishRun()
        XCTAssertGreaterThanOrEqual(model.exerciseMinutes, before + 1)
        XCTAssertEqual(model.workoutLog.count, 1)
        XCTAssertTrue(model.workoutLog[0].meta.contains("2/5"))
    }

    // MARK: Profil ve hesaplanan hedefler (US-016)

    private func sampleProfile() -> Profile {
        var p = Profile()
        p.birthDate = Calendar.current.date(byAdding: .year, value: -31, to: Date())
        p.sex = .female
        p.heightCm = 166
        p.weightKg = 72
        p.targetWeightKg = 65
        p.activityLevel = .light
        return p
    }

    func testProfileIsIncompleteWithoutCoreFields() {
        var p = Profile()
        XCTAssertFalse(p.isComplete)
        XCTAssertNil(p.calorieGoal)      // eksik profilde hedef uydurulmaz
        p = sampleProfile()
        XCTAssertTrue(p.isComplete)
        XCTAssertNotNil(p.calorieGoal)
    }

    func testBMIAndLabel() {
        let p = sampleProfile()
        XCTAssertEqual(p.bmi ?? 0, 26.1, accuracy: 0.15)
        XCTAssertEqual(p.bmiLabel, "Fazla kilolu")
    }

    func testCalorieGoalCreatesDeficitButNeverBelowBMR() {
        let p = sampleProfile()
        guard let goal = p.calorieGoal, let tdee = p.tdee, let bmr = p.bmr else {
            return XCTFail("hedef hesaplanamadı")
        }
        XCTAssertLessThan(Double(goal), tdee)            // kilo verme → açık
        XCTAssertGreaterThanOrEqual(Double(goal), bmr - 10)  // ama BMR altına inmez
    }

    func testCalorieGoalRisesWhenGainingWeight() {
        var p = sampleProfile()
        p.targetWeightKg = 78                            // kilo alma hedefi
        guard let goal = p.calorieGoal, let tdee = p.tdee else {
            return XCTFail("hedef hesaplanamadı")
        }
        XCTAssertGreaterThan(Double(goal), tdee)
    }

    func testStepsGoalFollowsActivityLevel() {
        var p = sampleProfile()
        XCTAssertEqual(p.stepsGoal, 8000)          // az hareketli
        p.activityLevel = .sedentary
        XCTAssertEqual(p.stepsGoal, 6000)
        p.activityLevel = .veryActive
        XCTAssertEqual(p.stepsGoal, 14000)
    }

    @MainActor
    func testStepsDriveTheThirdRing() {
        let model = AppModel()
        model.profile = sampleProfile()            // hedef 8000
        XCTAssertEqual(model.todayFractions[2], 0)
        model.hkSteps = 4000
        XCTAssertEqual(model.todayFractions[2], 0.5, accuracy: 0.001)
        XCTAssertEqual(model.currentValue(.steps), 4000)
    }

    // MARK: Gün anahtarı (saat dilimi tuzağı)

    @MainActor
    func testDayKeyMatchesBetweenModelAndService() {
        let model = AppModel()
        // Yazarken ve okurken AYNI anahtar üretilmeli. Ayrıştıklarında veri
        // bir önceki güne yazılıp bugün aranıyor ve kaybolmuş görünüyordu.
        XCTAssertEqual(AppModel.dayKeyFormatter.string(from: model.today),
                       SupabaseService.dayFormatter.string(from: model.today))
    }

    @MainActor
    func testTodayKeyIsTodaysLocalDate() {
        let model = AppModel()
        let expected = SupabaseService.dayFormatter.string(from: Date())
        XCTAssertEqual(model.todayKey, expected)
    }

    // MARK: Seri (streak)

    @MainActor
    func testStreakCountsConsecutiveVisitedDays() {
        let model = AppModel()
        let calendar = AppModel.appCalendar
        func key(_ offset: Int) -> String {
            AppModel.dayKeyFormatter.string(
                from: calendar.date(byAdding: .day, value: offset, to: model.today)!)
        }

        XCTAssertEqual(model.currentStreak, 0)          // hiç ziyaret yok

        model.visitedDays = [key(0), key(-1), key(-2)]
        XCTAssertEqual(model.currentStreak, 3)

        // Araya boşluk girerse seri kopar.
        model.visitedDays = [key(0), key(-1), key(-3)]
        XCTAssertEqual(model.currentStreak, 2)

        // Bugün henüz işaretlenmediyse dünden sayar (kullanıcı açar açmaz
        // serisini sıfırlanmış görmesin).
        model.visitedDays = [key(-1), key(-2)]
        XCTAssertEqual(model.currentStreak, 2)

        // İki gün önce bırakılmışsa seri bitmiştir.
        model.visitedDays = [key(-2), key(-3)]
        XCTAssertEqual(model.currentStreak, 0)
    }

    func testWaterGoalScalesWithWeightAndIsClamped() {
        var p = sampleProfile()
        XCTAssertEqual(p.waterGoalML ?? 0, 2400, accuracy: 50)
        p.weightKg = 30                                  // aşırı düşük → 2 L tabanı
        XCTAssertEqual(p.waterGoalML, 2000)
        p.weightKg = 200                                 // aşırı yüksek → üst sınır
        XCTAssertEqual(p.waterGoalML, 4000)
    }

    @MainActor
    func testRingGoalsFallBackToDefaultsWithoutProfile() {
        let model = AppModel()
        // Profil boşken varsayılan hedefler korunur (uygulama kırılmaz).
        XCTAssertEqual(model.goal(for: .water), RingKind.water.goal)
        XCTAssertEqual(model.goal(for: .nutrition), RingKind.nutrition.goal)

        model.profile = sampleProfile()
        XCTAssertNotEqual(model.goal(for: .water), RingKind.water.goal)
        XCTAssertEqual(model.goal(for: .exercise), 30)   // az hareketli
        XCTAssertEqual(model.goal(for: .steps), 8000)    // az hareketli
    }

    // MARK: Vücut ölçümleri (US-025)

    private func measurement(weight: Double, fat: Double, muscle: Double,
                             at date: Date = Date()) -> BodyMeasurement {
        var m = BodyMeasurement(measuredAt: date)
        m.weightKg = weight
        m.fatPercent = fat
        m.musclePercent = muscle
        return m
    }

    func testEmptyMeasurementIsRejected() {
        let empty = BodyMeasurement(measuredAt: Date())
        XCTAssertTrue(empty.isEmpty)
        var one = empty
        one.weightKg = 70
        XCTAssertFalse(one.isEmpty)
    }

    func testDeltaDirectionReflectsWhetherHigherIsBetter() {
        let previous = measurement(weight: 72.15, fat: 35.7, muscle: 59.8)
        let current = measurement(weight: 71.10, fat: 35.2, muscle: 60.4)

        // Kilo nötr: azalması herkes için "iyi" sayılmaz.
        let weight = current.delta(forField: "weight", since: previous)
        XCTAssertEqual(weight?.amount ?? 0, -1.05, accuracy: 0.001)
        XCTAssertNil(weight?.isImprovement)

        // Yağ oranı düştü → iyileşme.
        XCTAssertEqual(current.delta(forField: "fatPercent", since: previous)?.isImprovement, true)
        // Kas oranı arttı → iyileşme.
        XCTAssertEqual(current.delta(forField: "musclePercent", since: previous)?.isImprovement, true)
    }

    func testDeltaIsNilWithoutPreviousMeasurement() {
        let current = measurement(weight: 70, fat: 30, muscle: 60)
        XCTAssertNil(current.delta(forField: "weight", since: nil))
    }

    @MainActor
    func testBestWeightUsesLast30DaysOnly() {
        let model = AppModel()
        let old = Date().addingTimeInterval(-60 * 24 * 3600)
        model.bodyMeasurements = [
            measurement(weight: 71.1, fat: 35, muscle: 60),
            measurement(weight: 70.0, fat: 35, muscle: 60,
                        at: Date().addingTimeInterval(-5 * 24 * 3600)),
            measurement(weight: 65.0, fat: 35, muscle: 60, at: old)   // 30 günden eski
        ]
        XCTAssertEqual(model.bestWeightLast30Days, 70.0)
        XCTAssertEqual(model.latestMeasurement?.weightKg, 71.1)
        XCTAssertEqual(model.previousMeasurement?.weightKg, 70.0)
    }

    // MARK: Tartı fotoğrafı ayrıştırma

    func testScaleOCRNormalizesTurkishCharacters() {
        // "İ" küçültülünce birleşik nokta bırakıyordu; eşleşme kaçıyordu.
        XCTAssertEqual(ScaleOCR.normalized("İskelet Kası Ağırlığı"), "iskelet kasi agirligi")
        XCTAssertEqual(ScaleOCR.normalized("Yağsız Vücut Ağırlığı"), "yagsiz vucut agirligi")
        XCTAssertEqual(ScaleOCR.normalized("Obezite Derecesi"), "obezite derecesi")
    }

    func testScaleOCRPicksValueIgnoringUnitsInParentheses() {
        XCTAssertEqual(ScaleOCR.number(in: "Ağırlık(Kg) 70.55", isPercent: false), 70.55)
        XCTAssertEqual(ScaleOCR.number(in: "Metabolizma(Kcal/gün) 1404.0", isPercent: nil), 1404)
        XCTAssertEqual(ScaleOCR.number(in: "Su(%) 47,4", isPercent: true), 47.4)
        // Karşılaştırma satırında güncel değer sağda durur.
        XCTAssertEqual(ScaleOCR.number(in: "72.15 Ağırlık(Kg) -1.05 71.10", isPercent: false), 71.10)
        // Yüzde alanında 100'ün üstü okunursa güvenilmez.
        XCTAssertNil(ScaleOCR.number(in: "Yağ(%) 350", isPercent: true))
        XCTAssertNil(ScaleOCR.number(in: "Protein(%)", isPercent: true))
    }

    // MARK: Auth hata mesajları
    //
    // Sunucudan gelen İngilizce hatalar kullanıcıya Türkçe ve eyleme dönük
    // gösterilmeli. Gerçek ağ çağrısı yapmadan yalnızca eşlemeyi doğrular.

    private func serverError(_ message: String) -> NSError {
        NSError(domain: "AuthTest", code: 400,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    @MainActor
    func testSamePasswordErrorIsTranslated() {
        // Supabase bunu hem düz metin hem `same_password` koduyla döndürebiliyor.
        for raw in ["New password should be different from the old password.",
                    "same_password"] {
            let message = AppModel.authMessage(serverError(raw))
            XCTAssertTrue(message.contains("eskisinden farklı"),
                          "beklenmeyen çeviri: \(message)")
        }
    }

    @MainActor
    func testRateLimitErrorIsTranslated() {
        let message = AppModel.authMessage(serverError("email rate limit exceeded"))
        XCTAssertTrue(message.contains("Çok fazla deneme"))
    }

    @MainActor
    func testExpiredLinkErrorIsTranslated() {
        let message = AppModel.authMessage(serverError("Email link is invalid or has expired"))
        XCTAssertTrue(message.contains("süresi dolmuş"))
    }

    @MainActor
    func testMissingSessionErrorIsTranslated() {
        let message = AppModel.authMessage(serverError("Auth session missing!"))
        XCTAssertTrue(message.contains("sıfırlama bağlantısını tekrar aç"))
    }

    @MainActor
    func testUnknownErrorFallsBackWithDetail() {
        // Bilinmeyen hata yutulmamalı: teşhis için özgün metin korunur.
        let message = AppModel.authMessage(serverError("teapot is on fire"))
        XCTAssertTrue(message.contains("teapot is on fire"))
    }

    // MARK: Kan tahlili durumları

    func testBloodTestStatusThresholds() {
        let normal = BloodTest(name: "TSH", value: 2.07, unit: "uIU/mL", refLow: 0.35, refHigh: 4.94)
        XCTAssertEqual(normal.status, "Normal")
        let high = BloodTest(name: "MPV", value: 13.3, unit: "fL", refLow: 7.2, refHigh: 11.7)
        XCTAssertEqual(high.status, "Yüksek")
        XCTAssertEqual(high.refPosition, 0.98, accuracy: 0.001) // clamp üst sınırı
    }

    // MARK: Antrenman detayı (US-023)

    private func workout(name: String, minutes: Int, kcal: Int,
                         km: Double?) -> HealthKitService.WorkoutSummary {
        HealthKitService.WorkoutSummary(
            id: UUID(), name: name, minutes: minutes, kcal: kcal,
            distanceKm: km, start: Date(timeIntervalSince1970: 0),
            symbol: "figure.walk")
    }

    func testDistanceWorkoutLeadsWithKilometres() {
        // Apple gibi: mesafeli antrenmanda büyük değer km, kalori alt satırda.
        let walk = workout(name: "Yürüyüş", minutes: 22, kcal: 96, km: 1.36)
        XCTAssertEqual(walk.headline, "1,36 km")
        XCTAssertTrue(walk.detailLine.contains("22 dk"))
        XCTAssertTrue(walk.detailLine.contains("96 kcal"))
    }

    func testNonDistanceWorkoutLeadsWithCalories() {
        let yoga = workout(name: "Yoga", minutes: 45, kcal: 311, km: nil)
        XCTAssertEqual(yoga.headline, "311 kcal")
        // Kalori zaten büyük değerde; alt satırda tekrarlanmaz.
        XCTAssertEqual(yoga.detailLine, "45 dk")
    }

    func testLongWorkoutShowsHoursAndPace() {
        let run = workout(name: "Koşu", minutes: 95, kcal: 700, km: 12.0)
        XCTAssertEqual(run.durationText, "1 sa 35 dk")
        XCTAssertEqual(run.paceText, "7'55\"/km")
    }

    func testPaceIsHiddenWhenDistanceIsNegligible() {
        // 40 m'lik bir kayıtta "dk/km" anlamsız bir sayı üretirdi.
        let stroll = workout(name: "Yürüyüş", minutes: 3, kcal: 8, km: 0.04)
        XCTAssertNil(stroll.paceText)
    }
}
