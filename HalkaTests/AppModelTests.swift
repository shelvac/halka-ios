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
        // US-029: kalori artık demo dizisinden değil, onaylanan tahminden
        // geliyor. Kaydedilen her yiyecek ayrı bir günlük satırı.
        let model = AppModel()
        let day = model.mealDay          // fotoğraftan öğün bugüne eklenir
        model.mealAnalysis = MealAnalysis(
            items: [AnalyzedFood(name: "Izgara köfte", matched: true, grams: 150,
                                 kcal100: 215, portionG: 150,
                                 portionName: "porsiyon", confidence: 0.9)],
            note: nil, logID: nil, usedToday: 1, quota: 3)
        model.savePhotoMeal()
        XCTAssertEqual(model.consumed(forDay: day), 323)
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

    // MARK: Menüden öğün kaldırma

    @MainActor
    func testRemovedMealLeavesTheMenuAndTheTotals() {
        let model = AppModel()
        let day = model.mealDay
        let before = model.planTotal(forDay: day)
        let visibleBefore = model.visibleMenu(forDay: day).count
        model.toggleEaten(day: day, slot: 1)
        let eatenTotal = model.consumed(forDay: day)
        XCTAssertGreaterThan(eatenTotal, 0)

        model.removeMeal(day: day, slot: 1)
        XCTAssertEqual(model.visibleMenu(forDay: day).count, visibleBefore - 1)
        XCTAssertLessThan(model.planTotal(forDay: day), before)
        // Kaldırılan öğün yenmiş sayılamaz.
        XCTAssertFalse(model.isEaten(day: day, slot: 1))
        XCTAssertEqual(model.consumed(forDay: day), 0)
    }

    @MainActor
    func testRemovingDoesNotShiftSlotNumbers() {
        // Diziden çıkarmak sonraki öğünlerin slot numarasını kaydırır ve
        // "işaretlendi"/"değiştirildi" kayıtları yanlış öğüne bağlanırdı.
        let model = AppModel()
        let day = model.mealDay
        let lastFood = model.menu(forDay: day)[3]
        model.removeMeal(day: day, slot: 0)
        let visible = model.visibleMenu(forDay: day)
        XCTAssertEqual(visible.map(\.slot), [1, 2, 3])
        XCTAssertEqual(visible.last?.food, lastFood)
    }

    @MainActor
    func testRestoreBringsRemovedMealsBack() {
        let model = AppModel()
        let day = model.mealDay
        model.removeMeal(day: day, slot: 0)
        model.removeMeal(day: day, slot: 2)
        XCTAssertEqual(model.removedCount(forDay: day), 2)
        model.restoreMeals(day: day)
        XCTAssertEqual(model.removedCount(forDay: day), 0)
        XCTAssertEqual(model.visibleMenu(forDay: day).count, 4)
    }

    @MainActor
    func testLogFoodAddsCatalogItemStraightToTheLog() {
        // Yemek veritabanına yalnızca fotoğraf onay ekranından girilebiliyordu.
        let model = AppModel()
        let day = model.mealDay
        model.logFood(FoodOption(id: "x", name: "Mercimek çorbası", kcal100: 65,
                                 portionG: 250, portionName: "kase"), grams: 250)
        XCTAssertEqual(model.extras(forDay: day).count, 1)
        XCTAssertEqual(model.extras(forDay: day)[0].kcal, 163)
        XCTAssertTrue(model.extras(forDay: day)[0].title.contains("Mercimek çorbası"))
    }

    // MARK: Fotoğraftan öğün tahmini (US-029)

    private func analyzed(_ name: String, grams: Int, kcal100: Int,
                          portionG: Int, matched: Bool = true,
                          confidence: Double = 0.9) -> AnalyzedFood {
        AnalyzedFood(name: name, matched: matched, grams: grams, kcal100: kcal100,
                     portionG: portionG, portionName: "porsiyon", confidence: confidence)
    }

    func testKcalFollowsGrams() {
        // Porsiyon değişince kalori yeniden hesaplanmalı; sunucudan gelen
        // sabit sayıyı taşımak düzeltmeyi anlamsız kılardı.
        var item = analyzed("Bulgur pilavı", grams: 150, kcal100: 138, portionG: 150)
        XCTAssertEqual(item.kcal, 207)
        item.grams = 75
        XCTAssertEqual(item.kcal, 104)
    }

    func testPortionTextUsesFractions() {
        XCTAssertEqual(analyzed("Pilav", grams: 75, kcal100: 138, portionG: 150).portionText,
                       "½ porsiyon · 75 g")
        XCTAssertEqual(analyzed("Pilav", grams: 225, kcal100: 138, portionG: 150).portionText,
                       "1½ porsiyon · 225 g")
    }

    func testTotalIsShownAsRangeNotSingleNumber() {
        // Porsiyon fotoğraftan tahmin ediliyor; tek sayı belirsizliği gizlerdi.
        let analysis = MealAnalysis(
            items: [analyzed("Köfte", grams: 150, kcal100: 215, portionG: 150),
                    analyzed("Pilav", grams: 150, kcal100: 138, portionG: 150)],
            note: nil, logID: nil, usedToday: 1, quota: 3)
        XCTAssertEqual(analysis.totalKcal, 530)
        let range = analysis.kcalRange
        XCTAssertLessThan(range.low, analysis.totalKcal)
        XCTAssertGreaterThan(range.high, analysis.totalKcal)
    }

    @MainActor
    func testReplacingFoodRefitsPortionToTheNewDish() {
        // Çorbanın 150 g'ı ile pilavın 150 g'ı aynı şey değil; gramajı
        // aynen taşımak yanıltıcı olurdu.
        let model = AppModel()
        model.mealAnalysis = MealAnalysis(
            items: [analyzed("Pilav", grams: 300, kcal100: 138, portionG: 150)],
            note: nil, logID: nil, usedToday: 1, quota: 3)
        let id = model.mealAnalysis!.items[0].id
        model.replaceItem(id, with: FoodOption(id: "x", name: "Mercimek çorbası",
                                               kcal100: 65, portionG: 250,
                                               portionName: "kase"))
        let item = model.mealAnalysis!.items[0]
        XCTAssertEqual(item.name, "Mercimek çorbası")
        // Tabaktaki madde miktarı (300 g) korunuyor ama yeni yemeğin porsiyon
        // adımına oturtuluyor: 250 g'lık kaseye en yakın kat 1 kase.
        // Eski porsiyon KATINI (2) taşımak 500 g verirdi — tabakta o kadar
        // yemek yokken miktarı ikiye katlamak olurdu.
        XCTAssertEqual(item.grams, 250)
        XCTAssertTrue(model.mealAnalysisEdited)
    }

    @MainActor
    func testEachAnalyzedFoodBecomesItsOwnLogEntry() {
        // Tek satırda toplasaydık kullanıcı yalnızca birini silemezdi.
        let model = AppModel()
        model.mealDay = model.todayWeekdayIndex
        model.mealAnalysis = MealAnalysis(
            items: [analyzed("Köfte", grams: 150, kcal100: 215, portionG: 150),
                    analyzed("Cacık", grams: 150, kcal100: 45, portionG: 150)],
            note: nil, logID: nil, usedToday: 1, quota: 3)
        let before = model.extras.count
        model.savePhotoMeal()
        XCTAssertEqual(model.extras.count, before + 2)
        XCTAssertNil(model.mealAnalysis)          // onay ekranı kapanır
        XCTAssertEqual(model.photoState, .idle)
    }

    func testSearchKeyFlattensTurkishCharacters() {
        // Türkçe'de lowercased() "İ" harfini "i" + birleşik nokta yapıyor ve
        // hiçbir kayda eşleşmiyor — tartı OCR'ında da aynı tuzağa düşmüştük.
        XCTAssertEqual(SupabaseService.searchKey("İzgara Köfte"), "izgara kofte")
        XCTAssertEqual(SupabaseService.searchKey("Şehriyeli Pilav"), "sehriyeli pilav")
        XCTAssertEqual(SupabaseService.searchKey("  Çiğ Köfte "), "cig kofte")
    }

    // MARK: Enerji dengesi ve kilo tahmini (US-027)

    private func testProfile() -> Profile {
        var p = Profile()
        p.sex = .female
        p.heightCm = 168
        p.weightKg = 68
        p.birthDate = Calendar(identifier: .gregorian)
            .date(byAdding: .year, value: -32, to: Date())
        p.activityLevel = .moderate
        return p
    }

    func testBalanceSubtractsBasalActiveAndThermicEffect() {
        let balance = EnergyBalance(intakeKcal: 1800, basalKcal: 1400, activeKcal: 500)
        XCTAssertEqual(balance.thermicKcal, 180)          // alımın %10'u
        XCTAssertEqual(balance.expenditureKcal, 2080)
        XCTAssertEqual(balance.balanceKcal, -280)         // negatif = açık
    }

    func testDayWithoutMealLogIsNotUsable() {
        // Harcama tarafı dolu, alım boş: hesaba girse günde 2000 kcal'lik
        // sahte bir açık üretirdi.
        let balance = EnergyBalance(intakeKcal: 0, basalKcal: 1400, activeKcal: 600)
        XCTAssertFalse(balance.isUsable)
    }

    @MainActor
    func testMeasuredPathDoesNotDoubleCountExercise() {
        // `Profile.tdee` = BMR × hareket çarpanı ve çarpan egzersizi zaten
        // içeriyor. Ölçülen yolda çarpan hiç devreye girmemeli.
        let model = AppModel()
        model.profile = testProfile()
        model.hkConnected = true
        model.hkActiveEnergy = 800
        guard let energy = model.displayedEnergy, let bmr = model.profile.bmr else {
            return XCTFail("denge hesaplanamadı")
        }
        XCTAssertEqual(energy.activeKcal, 800)
        XCTAssertEqual(energy.basalKcal, Int(bmr.rounded()))
        // Çarpanlı TDEE eklenseydi harcama bunun çok üstüne çıkardı.
        XCTAssertLessThan(Double(energy.expenditureKcal),
                          model.profile.tdee! + 800)
    }

    @MainActor
    func testEstimatedPathUsesActivityMultiplierWhenHealthIsOff() {
        let model = AppModel()
        model.profile = testProfile()
        model.hkConnected = false
        model.hkActiveEnergy = 800          // yok sayılmalı
        guard let energy = model.displayedEnergy else { return XCTFail("denge yok") }
        XCTAssertEqual(energy.activeKcal, model.estimatedActiveKcal)
        XCTAssertNotEqual(energy.activeKcal, 800)
    }

    func testProjectionIsFarBelowTheLinear7700Rule() {
        // Wishnofsky (1958) doğrusal kuralı harcamanın sabit kaldığını
        // varsayar ve kaybı fazla tahmin eder; dinamik model daha düşük.
        let deficit = -500.0
        let dynamic = abs(WeightProjection.changeKg(dailyBalance: deficit, days: 365))
        let linear = 500.0 * 365 / 7700
        XCTAssertLessThan(dynamic, linear)
        XCTAssertGreaterThan(dynamic, linear * 0.4)   // yarısı mertebesinde
    }

    func testProjectionApproachesHallsEventualChange() {
        // Hall kuralı: 10 kcal/gün → ~0,45 kg nihai değişim.
        let eventual = abs(WeightProjection.changeKg(dailyBalance: -10, days: 100_000))
        XCTAssertEqual(eventual, 0.45, accuracy: 0.01)
        // Yarısı ~1 yılda.
        let oneYear = abs(WeightProjection.changeKg(dailyBalance: -10, days: 365))
        XCTAssertEqual(oneYear, 0.225, accuracy: 0.01)
    }

    func testProjectionRangeWidensWithUncertainty() {
        let range = WeightProjection.rangeKg(dailyBalance: -400, days: 90)
        XCTAssertLessThan(range.low, range.high)
        let mid = abs(WeightProjection.changeKg(dailyBalance: -400, days: 90))
        XCTAssertLessThan(range.low, mid)
        XCTAssertGreaterThan(range.high, mid)
    }

    @MainActor
    func testProjectionIsHiddenForUnderweightUsers() {
        let model = AppModel()
        var profile = testProfile()
        profile.weightKg = 45          // BMI ≈ 15,9
        model.profile = profile
        model.hkConnected = true
        model.hkActiveEnergy = 600
        model.eaten = ["0-0"]
        // Üç günlük kayıt olmadan zaten gösterilmiyor; önce onu kur.
        XCTAssertNotEqual(model.projectionGate, .ready)
    }

    @MainActor
    func testProjectionNeedsProfileFirst() {
        let model = AppModel()
        XCTAssertEqual(model.projectionGate, .needsProfile)
    }

    func testSignedFormattingAlwaysShowsDirection() {
        XCTAssertEqual(EnergyFormat.signed(-470), "−470")
        XCTAssertEqual(EnergyFormat.signed(180), "+180")
        XCTAssertEqual(EnergyFormat.kg(2.74), "2,7")
    }

    // MARK: Okumadan yazma koruması (veri kaybı)

    @MainActor
    func testRingsAreNotSavedBeforeTheyAreLoaded() async {
        // Açılışta Health tazelemesi ile kayıt yükleme yarışıyordu; tazeleme
        // önce biterse bellekteki sıfırlar sunucudaki suyu eziyordu.
        let model = AppModel()
        XCTAssertFalse(model.ringsLoaded)
        model.water = 0
        await model.persistRings()      // yazmamalı — henüz okumadık
        XCTAssertFalse(model.ringsLoaded)
    }

    @MainActor
    func testLogoutClearsLoadedFlagsAndData() {
        let model = AppModel()
        model.ringsLoaded = true
        model.mealStateLoaded = true
        model.water = 1500
        model.eaten = ["0-1"]
        model.logout()
        // Sonraki kullanıcı kendi verisini okumadan yazmaya başlamamalı.
        XCTAssertFalse(model.ringsLoaded)
        XCTAssertFalse(model.mealStateLoaded)
        XCTAssertEqual(model.water, 0)
        XCTAssertTrue(model.eaten.isEmpty)
    }

    @MainActor
    func testWeekStartIsMonday() {
        // Öğün kaydı haftalık; hafta başı yanlışsa geçen haftanın işaretleri
        // bu haftaya sızardı.
        let model = AppModel()
        let weekday = AppModel.appCalendar.component(.weekday, from: model.weekStart)
        XCTAssertEqual(weekday, 2)      // 2 = Pazartesi
        XCTAssertLessThanOrEqual(model.weekStart, model.today)
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

    @MainActor
    func testPastWorkoutsAreGroupedByDayNewestFirst() {
        // Egzersiz sekmesinde 90 günün antrenmanları düz bir liste hâlinde
        // akıyor, hepsi aynı güne aitmiş gibi görünüyordu.
        let model = AppModel()
        let calendar = AppModel.appCalendar
        func at(_ daysAgo: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: model.today)!
            return calendar.date(byAdding: .hour, value: hour, to: day)!
        }
        model.hkWorkouts = [
            .init(id: UUID(), name: "Yoga", minutes: 30, kcal: 100,
                  distanceKm: nil, start: at(0, hour: 9), symbol: "figure.yoga"),
            .init(id: UUID(), name: "Koşu", minutes: 20, kcal: 200,
                  distanceKm: 3, start: at(1, hour: 8), symbol: "figure.run"),
            .init(id: UUID(), name: "Yürüyüş", minutes: 15, kcal: 60,
                  distanceKm: 1, start: at(1, hour: 18), symbol: "figure.walk"),
            .init(id: UUID(), name: "HIIT", minutes: 25, kcal: 180,
                  distanceKm: nil, start: at(3, hour: 12), symbol: "figure.run")
        ]
        XCTAssertEqual(model.todayWorkouts.count, 1)

        let past = model.pastWorkoutDays
        XCTAssertEqual(past.count, 2)                 // bugün gruplara girmez
        XCTAssertEqual(past[0].items.count, 2)        // dün iki antrenman
        XCTAssertGreaterThan(past[0].date, past[1].date)
        // Gün içinde de yeniden eskiye.
        XCTAssertEqual(past[0].items[0].name, "Yürüyüş")
        XCTAssertEqual(AppModel.workoutDayTitle(past[0].date), "Dün")
    }

    func testPaceIsHiddenWhenDistanceIsNegligible() {
        // 40 m'lik bir kayıtta "dk/km" anlamsız bir sayı üretirdi.
        let stroll = workout(name: "Yürüyüş", minutes: 3, kcal: 8, km: 0.04)
        XCTAssertNil(stroll.paceText)
    }
}

// MARK: - Kural tabanlı plan üretimi (US-032 · US-033)

final class PlanGeneratorTests: XCTestCase {

    private func food(_ id: String, _ name: String, _ category: String,
                      kcal: Int, protein: Double = 5, portion: Int = 150,
                      tags: [String] = [], role: String = "ana") -> PlanFood {
        PlanFood(id: id, name: name, category: category, kcal100: kcal,
                 protein100: protein, carb100: 20, fat100: 5,
                 portionG: portion, portionName: "porsiyon", tags: tags, role: role)
    }

    private var catalog: [PlanFood] {
        [food("1", "Izgara köfte", "et", kcal: 215, tags: ["et", "kirmizi_et"], role: "ana"),
         food("2", "Tavuk sote", "et", kcal: 145, tags: ["et"], role: "ana"),
         food("11", "Nohut yemeği", "baklagil", kcal: 125, portion: 250,
              tags: ["vegan", "vejetaryen", "baklagil"], role: "ana"),
         food("3", "Bulgur pilavı", "pilav", kcal: 138, tags: ["vegan", "vejetaryen"],
              role: "garnitur"),
         food("12", "Pirinç pilavı", "pilav", kcal: 145, tags: ["vegan", "vejetaryen"],
              role: "garnitur"),
         food("4", "Beyaz peynir", "sut", kcal: 265, portion: 30, tags: ["sut", "vejetaryen"],
              role: "kahvalti_protein"),
         food("13", "Lor peyniri", "sut", kcal: 120, portion: 50, tags: ["sut", "vejetaryen"],
              role: "kahvalti_protein"),
         food("5", "Tam buğday ekmeği", "ekmek", kcal: 245, portion: 50,
              tags: ["gluten", "vegan", "vejetaryen"], role: "ekmek"),
         food("14", "Zeytin", "kahvalti", kcal: 145, portion: 20,
              tags: ["vegan", "vejetaryen", "zeytin"], role: "kahvalti_yan"),
         food("6", "Elma", "meyve", kcal: 52, portion: 180, tags: ["vegan", "vejetaryen"],
              role: "meyve"),
         food("7", "Mercimek çorbası", "corba", kcal: 65, portion: 250,
              tags: ["vegan", "vejetaryen"], role: "corba"),
         food("8", "Çoban salata", "salata", kcal: 35, portion: 200,
              tags: ["vegan", "vejetaryen"], role: "yan"),
         food("15", "Ispanak yemeği", "sebze", kcal: 68, portion: 200,
              tags: ["vegan", "vejetaryen"], role: "yan"),
         food("9", "Ceviz", "kuruyemis", kcal: 654, portion: 30,
              tags: ["findik", "vegan", "vejetaryen"], role: "kuruyemis"),
         food("10", "Bira", "icecek", kcal: 43, portion: 330, tags: ["alkol", "vegan"],
              role: "icecek"),
         food("16", "Sucuk", "kahvalti", kcal: 420, portion: 40,
              tags: ["et", "kirmizi_et", "islenmis_et"], role: "keyfi"),
         food("17", "Baklava", "tatli", kcal: 430, portion: 60,
              tags: ["yuksek_seker", "gluten", "vejetaryen"], role: "keyfi")]
    }

    private var prefs: PlanPreferences {
        var p = PlanPreferences()
        p.mealsPerDay = 4
        p.mealTimes = ["08:30", "13:00", "16:30", "20:00"]
        return p
    }

    func testVeganStyleRemovesAnimalFoods() {
        var p = prefs
        p.dietStyle = .vegan
        let pool = MealPlanGenerator.pool(from: catalog, prefs: p, protocolItem: nil)
        XCTAssertFalse(pool.contains { $0.name == "Izgara köfte" })
        XCTAssertFalse(pool.contains { $0.name == "Beyaz peynir" })
        XCTAssertTrue(pool.contains { $0.name == "Bulgur pilavı" })
    }

    func testAllergyRemovesMatchingTag() {
        var p = prefs
        p.allergies = ["Gluten"]
        let pool = MealPlanGenerator.pool(from: catalog, prefs: p, protocolItem: nil)
        XCTAssertFalse(pool.contains { $0.name == "Tam buğday ekmeği" })
    }

    func testFreeTextDislikeIsMatchedByName() {
        // Kullanıcı listede olmayan bir şey yazdıysa etiket yok, ada bakmak
        // tek yol ("Ceviz" → kuruyemiş etiketi genel kalırdı).
        var p = prefs
        p.dislikes = ["Ceviz"]
        let pool = MealPlanGenerator.pool(from: catalog, prefs: p, protocolItem: nil)
        XCTAssertFalse(pool.contains { $0.name == "Ceviz" })
        XCTAssertTrue(pool.contains { $0.name == "Elma" })
    }

    func testTreatsAndProcessedMeatNeverEnterThePlan() {
        // "Diyet planı" diye sucuk ve baklava sunmak ciddiyetsizlik.
        let pool = MealPlanGenerator.pool(from: catalog, prefs: prefs, protocolItem: nil)
        XCTAssertFalse(pool.contains { $0.name == "Bira" })
        XCTAssertFalse(pool.contains { $0.name == "Sucuk" })
        XCTAssertFalse(pool.contains { $0.name == "Baklava" })
    }

    func testMainMealHasExactlyOneMainDish() {
        // Asıl hata buydu: "İskender + Kavurma + Somon ızgara" aynı öğünde.
        let mains = Set(catalog.filter { $0.role == "ana" }.map(\.id))
        let plan = MealPlanGenerator.generate(
            foods: catalog, prefs: prefs, protocolItem: nil, kcalTarget: 1800,
            weightKg: 68, weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        for day in plan.days {
            for meal in day.meals where meal.label == "Öğle" || meal.label == "Akşam" {
                let count = meal.items.filter { mains.contains($0.id) }.count
                XCTAssertEqual(count, 1, "\(meal.label): \(meal.items.map(\.name))")
            }
        }
    }

    func testBreakfastIsAProperBreakfast() {
        // Protein + ekmek + yan. "Sucuk, ekmek, yoğurt" diye kahvaltı olmaz.
        let plan = MealPlanGenerator.generate(
            foods: catalog, prefs: prefs, protocolItem: nil, kcalTarget: 1800,
            weightKg: 68, weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        let breakfastRoles = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.role) })
        for day in plan.days {
            guard let meal = day.meals.first(where: { $0.label == "Kahvaltı" }) else { continue }
            let roles = meal.items.compactMap { breakfastRoles[$0.id] }
            XCTAssertTrue(roles.contains("kahvalti_protein"))
            XCTAssertTrue(roles.contains("ekmek"))
            XCTAssertFalse(roles.contains("ana"))
        }
    }

    func testDailyTotalStaysCloseToTarget() {
        let target = 1800
        let plan = MealPlanGenerator.generate(
            foods: catalog, prefs: prefs, protocolItem: nil, kcalTarget: target,
            weightKg: 68, weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        for day in plan.days {
            let off = abs(Double(day.kcal - target)) / Double(target) * 100
            XCTAssertLessThan(off, 15, "gün \(day.day): \(day.kcal) kcal")
        }
    }

    func testPlanCoversSevenDaysWithAllMeals() {
        let plan = MealPlanGenerator.generate(
            foods: catalog, prefs: prefs, protocolItem: nil, kcalTarget: 1800,
            weightKg: 68, weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        XCTAssertEqual(plan.days.count, 7)
        XCTAssertTrue(plan.days.allSatisfy { $0.meals.count == 4 })
        XCTAssertTrue(plan.days.allSatisfy { day in day.meals.allSatisfy { !$0.items.isEmpty } })
    }

    func testSameWeekProducesSamePlan() {
        // Her açılışta menü değişirse kullanıcı dünkü planını bulamaz.
        let week = Date(timeIntervalSince1970: 1_754_611_200)
        let a = MealPlanGenerator.generate(foods: catalog, prefs: prefs, protocolItem: nil,
                                           kcalTarget: 1800, weightKg: 68, weekStart: week)
        let b = MealPlanGenerator.generate(foods: catalog, prefs: prefs, protocolItem: nil,
                                           kcalTarget: 1800, weightKg: 68, weekStart: week)
        XCTAssertEqual(a, b)
    }

    func testDifferentWeeksProduceDifferentPlans() {
        let week1 = Date(timeIntervalSince1970: 1_754_611_200)
        let week2 = week1.addingTimeInterval(7 * 86_400)
        let a = MealPlanGenerator.generate(foods: catalog, prefs: prefs, protocolItem: nil,
                                           kcalTarget: 1800, weightKg: 68, weekStart: week1)
        let b = MealPlanGenerator.generate(foods: catalog, prefs: prefs, protocolItem: nil,
                                           kcalTarget: 1800, weightKg: 68, weekStart: week2)
        XCTAssertNotEqual(a.days, b.days)
    }

    func testPortionsAreRoundedToMeasurableAmounts() {
        // "137 gram pilav" ölçülemez; 25 g'ın katları kullanılıyor.
        let plan = MealPlanGenerator.generate(
            foods: catalog, prefs: prefs, protocolItem: nil, kcalTarget: 1800,
            weightKg: 68, weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        let items = plan.days.flatMap { $0.meals }.flatMap { $0.items }
        XCTAssertFalse(items.isEmpty)
        // Büyük porsiyonlar 25 g, küçükler (peynir, zeytin) 10 g adımla.
        XCTAssertTrue(items.allSatisfy {
            $0.grams % ($0.portionG >= 100 ? 25 : 10) == 0
        })
    }

    // MARK: Antrenman

    private func exercise(_ id: String, _ region: String, needs: String = "none",
                          level: String = "Başlangıç",
                          mechanic: String = "compound") -> PlanExercise {
        PlanExercise(id: id, name: id, nameTR: nil, region: region,
                     equipment: "Ekipmansız", needs: needs, level: level,
                     category: "Kuvvet", mechanic: mechanic)
    }

    private var gym: [PlanExercise] {
        var list: [PlanExercise] = []
        for region in ["Göğüs", "Omuz", "Triceps", "Sırt", "Biceps", "Trapez",
                       "Ön Bacak", "Arka Bacak", "Kalça", "Baldır", "Karın", "Bel"] {
            for i in 0..<3 {
                list.append(exercise("\(region)-\(i)", region,
                                     needs: i == 0 ? "none" : "gym"))
            }
        }
        return list
    }

    func testEquipmentFilterRespectsWhatUserHas() {
        var p = PlanPreferences()
        p.equipment = .none
        let pool = WorkoutPlanGenerator.pool(from: gym, prefs: p, beginner: true)
        XCTAssertTrue(pool.allSatisfy { $0.needs == "none" })
    }

    func testInjuryRemovesTheWholeRegion() {
        // Sakat bölgeyi çalıştırmak iyileşmeyi geciktirir.
        var p = PlanPreferences()
        p.equipment = .gym
        p.injuries = ["Diz"]
        let pool = WorkoutPlanGenerator.pool(from: gym, prefs: p, beginner: false)
        XCTAssertFalse(pool.contains { $0.region == "Ön Bacak" })
        XCTAssertFalse(pool.contains { $0.region == "Arka Bacak" })
        XCTAssertTrue(pool.contains { $0.region == "Göğüs" })
    }

    func testSessionCountMatchesRequestedDays() {
        var p = PlanPreferences()
        p.equipment = .gym
        p.workoutDays = 4
        let plan = WorkoutPlanGenerator.generate(
            exercises: gym, prefs: p, activity: .moderate,
            weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        XCTAssertEqual(plan.sessions.count, 4)
        XCTAssertEqual(plan.restDays.count, 3)
        // Günler haftaya yayılmalı, arka arkaya yığılmamalı.
        XCTAssertEqual(Set(plan.sessions.map(\.day)).count, 4)
    }

    func testWeeklyCardioMeetsWhoMinimum() {
        // DSÖ 2020: haftada en az 150 dk orta şiddet aerobik.
        var p = PlanPreferences()
        p.equipment = .gym
        p.workoutDays = 3
        let plan = WorkoutPlanGenerator.generate(
            exercises: gym, prefs: p, activity: .moderate,
            weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        XCTAssertGreaterThanOrEqual(plan.weeklyCardioMinutes, 150)
    }

    func testBeginnerGetsFullBodyAndFewerSets() {
        // Yeni başlayanda itme/çekme ayrımı gereksiz karmaşıklık; sıklık
        // daha değerli (ACSM başlangıç için 2-3 gün, 2-4 set).
        let split = WorkoutPlanGenerator.split(days: 3, beginner: true)
        XCTAssertTrue(split.allSatisfy { $0.title == "Tüm vücut" })
        var p = PlanPreferences()
        p.equipment = .gym
        p.workoutDays = 3
        let plan = WorkoutPlanGenerator.generate(
            exercises: gym, prefs: p, activity: .sedentary,
            weekStart: Date(timeIntervalSince1970: 1_754_611_200))
        let sets = plan.sessions.flatMap { $0.exercises }.map(\.sets)
        XCTAssertTrue(sets.allSatisfy { $0 == 2 })
    }
}

// MARK: - Oturumlar arası veri sızması

final class SessionResetTests: XCTestCase {

    @MainActor
    func testSigningInAsAnotherUserClearsEverything() {
        // Kullanıcı çıkış yapmadan başka bir hesapla girdiğinde önceki
        // kişinin profil fotoğrafı, plan tercihleri ve ölçümleri ekranda
        // kalıyordu — kafa karışıklığı değil, veri sızması.
        let model = AppModel()
        model.profile.fullName = "Simge Helvacı"
        model.profile.weightKg = 68
        model.avatarImage = UIImage()
        model.userName = "Simge"
        model.planPreferences = PlanPreferences()
        model.mealPlan = WeekMealPlan(days: [], kcalTarget: 1800, proteinTarget: 90,
                                      carbTarget: 200, fatTarget: 60, poolSize: 100)
        model.workoutPlan = WeekWorkoutPlan(sessions: [], weeklyCardioMinutes: 150,
                                            weeklySets: [:], note: "")
        model.water = 1500
        model.eaten = ["0-1"]
        model.bodyMeasurements = [BodyMeasurement(measuredAt: Date())]

        model.resetUserState()

        XCTAssertNil(model.avatarImage)
        XCTAssertNil(model.profile.weightKg)
        XCTAssertEqual(model.profile.fullName, "")
        XCTAssertNil(model.planPreferences)
        XCTAssertNil(model.mealPlan)
        XCTAssertNil(model.workoutPlan)
        XCTAssertEqual(model.water, 0)
        XCTAssertTrue(model.eaten.isEmpty)
        XCTAssertTrue(model.bodyMeasurements.isEmpty)
        XCTAssertFalse(model.ringsLoaded)
        XCTAssertFalse(model.mealStateLoaded)
    }

    @MainActor
    func testLogoutAlsoResets() {
        let model = AppModel()
        model.water = 1250
        model.avatarImage = UIImage()
        model.logout()
        XCTAssertEqual(model.water, 0)
        XCTAssertNil(model.avatarImage)
        XCTAssertEqual(model.screen, .login)
    }
}

// MARK: - AI plan doğrulayıcı ve dönüştürücü (US-034)

final class PlanAITests: XCTestCase {

    private func item(_ name: String, category: FoodCategory,
                      protein: ProteinType = .yok, grams: Int = 150,
                      kcal: Int = 200) -> FoodItem {
        FoodItem(name: name, category: category, proteinType: protein,
                 amount: 1, unit: .porsiyon, grams: grams, kcal: kcal,
                 proteinG: 10, carbG: 10, fatG: 5)
    }

    private func day(meals: [Meal], kcal: Int) -> DailyMealPlan {
        DailyMealPlan(day: .pazartesi, meals: meals,
                      dayTotals: MacroTotals(kcal: kcal, proteinG: 90,
                                             carbG: 150, fatG: 50),
                      targetDeviationPct: 0,
                      ruleCheck: RuleCheck(oneMainPerMeal: true, noProteinMixing: true,
                                           breakfastIntegrity: true, kcalWithinTolerance: true,
                                           allergensAbsent: true, protocolCompliant: true))
    }

    func testValidatorRejectsTwoMainsInOneMeal() {
        // Asıl şikâyet: "İskender + Kavurma + Somon ızgara" aynı öğünde.
        let lunch = Meal(mealType: .ogle, time: "13:00",
                         items: [item("İskender kebap", category: .anaYemek, protein: .kirmiziEt),
                                 item("Somon ızgara", category: .anaYemek, protein: .denizUrunu)],
                         mealTotals: MacroTotals(kcal: 700, proteinG: 60, carbG: 30, fatG: 35))
        let plan = day(meals: [lunch], kcal: 1800)
        let errors = PlanValidator(targetKcal: 1800, allergenKeywords: [])
            .validate(plan)
        // Hem R1 (iki ana) hem R2 (kırmızı et + deniz ürünü) yakalanmalı.
        XCTAssertTrue(errors.contains { if case .multipleMains = $0 { return true }; return false })
        XCTAssertTrue(errors.contains { if case .proteinMixing = $0 { return true }; return false })
    }

    func testValidatorRejectsStewAtBreakfast() {
        let breakfast = Meal(mealType: .kahvalti, time: "09:00",
                             items: [item("Kavurma", category: .anaYemek, protein: .kirmiziEt)],
                             mealTotals: MacroTotals(kcal: 400, proteinG: 30, carbG: 5, fatG: 30))
        let errors = PlanValidator(targetKcal: 1800, allergenKeywords: [])
            .validate(day(meals: [breakfast], kcal: 1800))
        XCTAssertTrue(errors.contains { if case .breakfastViolation = $0 { return true }; return false })
    }

    func testValidatorCatchesAllergenByName() {
        let snack = Meal(mealType: .araOgun, time: "16:30",
                         items: [item("Ceviz", category: .atistirmalik, grams: 30, kcal: 196)],
                         mealTotals: MacroTotals(kcal: 196, proteinG: 5, carbG: 4, fatG: 20))
        let errors = PlanValidator(targetKcal: 196, allergenKeywords: ["ceviz"])
            .validate(day(meals: [snack], kcal: 196))
        XCTAssertTrue(errors.contains { if case .allergenPresent = $0 { return true }; return false })
    }

    func testValidatorEnforcesCalorieTolerance() {
        let lunch = Meal(mealType: .ogle, time: "13:00",
                         items: [item("Izgara tavuk", category: .anaYemek, protein: .beyazEt,
                                      kcal: 1000)],
                         mealTotals: MacroTotals(kcal: 1000, proteinG: 60, carbG: 0, fatG: 20))
        // Hedef 1800, gün 1000 → %44 sapma. AI "kcal_within_tolerance: true"
        // dese bile burada yakalanır — beyana güvenmiyoruz.
        let errors = PlanValidator(targetKcal: 1800, allergenKeywords: [])
            .validate(day(meals: [lunch], kcal: 1000))
        XCTAssertTrue(errors.contains { if case .kcalOutOfTolerance = $0 { return true }; return false })
    }

    @MainActor
    func testConversionKeepsUserMealTimesAndPortionLabels() {
        let lunch = Meal(mealType: .ogle, time: "12:00",
                         items: [FoodItem(name: "Bulgur pilavı", category: .yanYemek,
                                          proteinType: .yok, amount: 4, unit: .yemekKasigi,
                                          grams: 90, kcal: 108, proteinG: 3.6,
                                          carbG: 21.6, fatG: 1.4)],
                         mealTotals: MacroTotals(kcal: 108, proteinG: 3.6, carbG: 21.6, fatG: 1.4))
        let converted = AppModel.plannedDay(
            from: day(meals: [lunch], kcal: 108), dayIndex: 2,
            times: ["08:30", "13:00", "16:30", "20:00"])
        XCTAssertEqual(converted.day, 2)
        // Model 12:00 dedi ama kullanıcı 08:30 seçmişti (ilk slot) — kullanıcı kazanır.
        XCTAssertEqual(converted.meals[0].time, "08:30")
        XCTAssertEqual(converted.meals[0].items[0].portionText, "4 yemek kaşığı")
        XCTAssertEqual(converted.meals[0].items[0].kcal, 108)
    }

    @MainActor
    func testHealthFlagsNeverLeaveTheDeviceAsLabels() {
        // KVKK sözü: sağlık bayrağı gönderilmez. Modele giden yalnızca
        // türetilmiş yiyecek kısıtları — "tansiyon" değil, "sucuk".
        let exclusions = AppModel.aiExclusions(healthFlags: ["tansiyon", "gut"])
        XCTAssertTrue(exclusions.contains("sucuk"))
        XCTAssertTrue(exclusions.contains("sakatat"))
        XCTAssertFalse(exclusions.contains { $0.contains("tansiyon") || $0.contains("gut") })
    }

    @MainActor
    func testVeganStyleOverridesProtocolName() {
        var prefs = PlanPreferences()
        prefs.protocolKey = "akdeniz"
        prefs.dietStyle = .vegan
        XCTAssertEqual(AppModel.aiProtocolName(prefs), "Vegan")
        prefs.dietStyle = .omnivore
        XCTAssertEqual(AppModel.aiProtocolName(prefs), "Akdeniz")
    }
}

// MARK: - Doğrulayıcı sertleştirme (etiket körlüğü + yasaklılar)

final class ValidatorHardeningTests: XCTestCase {

    private func item(_ name: String, category: FoodCategory,
                      protein: ProteinType = .yok, grams: Int = 150,
                      kcal: Int = 200) -> FoodItem {
        FoodItem(name: name, category: category, proteinType: protein,
                 amount: 1, unit: .porsiyon, grams: grams, kcal: kcal,
                 proteinG: 10, carbG: 10, fatG: 5)
    }

    private func plan(_ meals: [Meal]) -> DailyMealPlan {
        DailyMealPlan(day: .pazartesi, meals: meals,
                      dayTotals: MacroTotals(kcal: 1420, proteinG: 113,
                                             carbG: 130, fatG: 50),
                      targetDeviationPct: 0,
                      ruleCheck: RuleCheck(oneMainPerMeal: true, noProteinMixing: true,
                                           breakfastIntegrity: true, kcalWithinTolerance: true,
                                           allergensAbsent: true, protocolCompliant: true))
    }

    @MainActor
    func testPastramiAsComplementIsStillRejected() {
        // Simge'nin şikâyeti: yüksek proteinli menüde pastırma çıkıyor.
        // Model onu "tamamlayıcı" etiketlerse eski doğrulayıcı GÖRMÜYORDU:
        // R1 kategori sayıyordu, R2 yalnızca ana yemek kalemlerine bakıyordu.
        let lunch = Meal(mealType: .ogle, time: "13:00",
            items: [item("Izgara Tavuk Göğsü", category: .anaYemek, protein: .beyazEt),
                    item("Pastırma", category: .tamamlayici, protein: .kirmiziEt,
                         grams: 25, kcal: 60)],
            mealTotals: MacroTotals(kcal: 460, proteinG: 55, carbG: 2, fatG: 18))
        let errors = PlanValidator(
            targetKcal: 1420, allergenKeywords: [],
            bannedKeywords: AppModel.bannedFoods(goal: .lose)
        ).validate(plan([lunch]))
        XCTAssertTrue(errors.contains { if case .bannedFood = $0 { return true }; return false })
        XCTAssertTrue(errors.contains { if case .proteinMixing = $0 { return true }; return false })
    }

    func testMislabeledSecondMainIsCaught() {
        // 150 g'lık ikinci bir et kalemi "yan yemek" etiketiyle R1'i deliyordu.
        // 90 g üzeri hayvansal protein pratikte ana yemektir.
        let dinner = Meal(mealType: .aksam, time: "19:00",
            items: [item("Izgara Köfte", category: .anaYemek, protein: .kirmiziEt),
                    item("Tas Kebabı", category: .yanYemek, protein: .kirmiziEt,
                         grams: 150, kcal: 250)],
            mealTotals: MacroTotals(kcal: 570, proteinG: 45, carbG: 10, fatG: 35))
        let errors = PlanValidator(targetKcal: 1420, allergenKeywords: [])
            .validate(plan([dinner]))
        XCTAssertTrue(errors.contains { if case .multipleMains = $0 { return true }; return false })
    }

    @MainActor
    func testYogurtComplementsRemainAllowed() {
        // Sertleştirme meşru düzeni bozmamalı: tavuk + ayran + cacık serbest
        // (yumurta_sut muaf), 200 g sebze garnitürü ana yemek sayılmaz.
        let lunch = Meal(mealType: .ogle, time: "13:00",
            items: [item("Izgara Tavuk Göğsü", category: .anaYemek, protein: .beyazEt),
                    item("Cacık", category: .tamamlayici, protein: .yumurtaSut,
                         grams: 200, kcal: 90),
                    item("Zeytinyağlı Sebze", category: .tamamlayici, grams: 200, kcal: 105)],
            mealTotals: MacroTotals(kcal: 445, proteinG: 50, carbG: 15, fatG: 15))
        let errors = PlanValidator(
            targetKcal: 1420, allergenKeywords: [],
            bannedKeywords: AppModel.bannedFoods(goal: .lose)
        ).validate(plan([lunch]))
        XCTAssertTrue(errors.isEmpty, "\(errors.map(\.description))")
    }

    @MainActor
    func testBannedFoodsGoToModelAsExclusionsToo() {
        XCTAssertTrue(AppModel.bannedFoods(goal: .lose).contains("pastırma"))
        XCTAssertTrue(AppModel.bannedFoods(goal: .lose).contains("kavurma"))
        // Kas kazanımında işlenmiş et yine yasak, iskender/kavurma değil.
        XCTAssertTrue(AppModel.bannedFoods(goal: .gain).contains("sucuk"))
        XCTAssertFalse(AppModel.bannedFoods(goal: .gain).contains("kavurma"))
    }
}

// MARK: - Sohbet içi plan akışı (US-035)

final class CoachPlanFlowTests: XCTestCase {

    @MainActor
    func testFullFlowCollectsAllPreferences() {
        let model = AppModel()
        var reply = model.coachReply(to: AppModel.chipFullPlan)
        XCTAssertEqual(reply.role, .ask)                       // hedef sorusu
        reply = model.coachReply(to: "Kilo vermek")
        XCTAssertTrue(reply.text.contains("sağlık"))
        reply = model.coachReply(to: "Var, yazacağım")
        _ = reply
        reply = model.coachReply(to: "tansiyon ve gut var")
        XCTAssertTrue(reply.options.contains("DASH (tansiyon)"))
        // Gut → yüksek proteinli sohbette önerilmez.
        XCTAssertFalse(reply.options.contains("Yüksek proteinli"))
        reply = model.coachReply(to: "Akdeniz")
        reply = model.coachReply(to: "fıstık, mantar")
        reply = model.coachReply(to: "4 öğün")
        XCTAssertTrue(reply.text.contains("antrenman") || reply.text.contains("kaç gün"))
        reply = model.coachReply(to: "3 gün")
        reply = model.coachReply(to: "Evde")

        // Akış bitti, tercihler işlendi, "hazırlıyorum" mesajı döndü.
        XCTAssertNil(model.coachFlow)
        let prefs = model.planPreferences
        XCTAssertEqual(prefs?.goal, .lose)
        XCTAssertEqual(prefs?.healthFlags, ["tansiyon", "gut"])
        XCTAssertEqual(prefs?.protocolKey, "akdeniz")
        XCTAssertEqual(prefs?.allergies, ["Fındık/ceviz"])
        XCTAssertEqual(prefs?.dislikes, ["Mantar"])
        XCTAssertEqual(prefs?.mealsPerDay, 4)
        XCTAssertEqual(prefs?.workoutDays, 3)
        XCTAssertEqual(prefs?.equipment, .home)
        XCTAssertTrue(reply.text.contains("hazırlıyorum"))
    }

    @MainActor
    func testWorkoutOnlyFlowSkipsFoodQuestions() {
        let model = AppModel()
        var reply = model.coachReply(to: AppModel.chipWorkoutPlan)
        XCTAssertTrue(reply.text.contains("kaç gün"))          // doğrudan spor
        reply = model.coachReply(to: "4 gün")
        reply = model.coachReply(to: "Salonda")
        XCTAssertNil(model.coachFlow)
        XCTAssertEqual(model.planPreferences?.workoutDays, 4)
        XCTAssertEqual(model.planPreferences?.equipment, .gym)
    }

    @MainActor
    func testSavedPreferencesOfferShortcut() {
        let model = AppModel()
        var prefs = PlanPreferences()
        prefs.goal = .maintain
        model.planPreferences = prefs
        let reply = model.coachReply(to: AppModel.chipFullPlan)
        XCTAssertTrue(reply.options.contains("Kayıtlı tercihlerimle kur"))
        let done = model.coachReply(to: "Kayıtlı tercihlerimle kur")
        XCTAssertNil(model.coachFlow)
        XCTAssertTrue(done.text.contains("hazırlıyorum"))
    }

    @MainActor
    func testRegenerateBumpsVariation() {
        let model = AppModel()
        model.planPreferences = PlanPreferences()
        _ = model.coachReply(to: AppModel.chipRegenMeals)
        _ = model.coachReply(to: AppModel.chipRegenMeals)
        XCTAssertEqual(model.planVariationMeals, 2)
        _ = model.coachReply(to: AppModel.chipRegenWorkout)
        XCTAssertEqual(model.planVariationWorkout, 1)
        XCTAssertEqual(model.planVariationMeals, 2)   // birbirine karışmaz
    }

    /// "1 dakika sürmeden planın hazır dedi ve içi boş" — üretim boş
    /// döndüyse "hazır" denmez, özür + tekrar dene seçeneği gelir.
    @MainActor
    func testEmptyPlanIsReportedAsFailureNotReady() {
        let model = AppModel()
        model.mealPlan = nil
        let message = model.planReadyMessage(part: .meals)
        XCTAssertEqual(message.role, .ask)
        XCTAssertTrue(message.text.contains("kuramadım"))
        XCTAssertEqual(message.options, [AppModel.chipRegenMeals])
    }

    @MainActor
    func testReadyMessageScopesToRequestedPart() {
        let model = AppModel()
        model.mealPlan = WeekMealPlan(days: [PlannedDay(day: 0, meals: [])],
                                      kcalTarget: 1500, proteinTarget: 90,
                                      carbTarget: 150, fatTarget: 50, poolSize: 100)
        let message = model.planReadyMessage(part: .meals)
        XCTAssertEqual(message.role, .planReady)
        XCTAssertEqual(message.title, "Besin planın hazır")
        // Sadece besin istendi: antrenman değiştirme çipi görünmez.
        XCTAssertFalse(message.options.contains(AppModel.chipRegenWorkout))
        XCTAssertTrue(message.options.contains(AppModel.chipRegenMeals))
    }

    /// "sadece beslenme dememe rağmen antrenman sekmesi de açtı" —
    /// sonuç ekranı yalnızca istenen bölümleri göstermeli; daha önce
    /// kurulmuş bölüm varsa o da korunur.
    @MainActor
    func testRecordPlanPartsScopesResultScreen() {
        let model = AppModel()
        model.recordPlanParts([.meals])
        XCTAssertEqual(model.planParts, [.meals])

        // Önce antrenman varken sadece besin yenilenirse antrenman kalır.
        model.workoutPlan = WeekWorkoutPlan(sessions: [], weeklyCardioMinutes: 0,
                                            weeklySets: [:], note: "")
        model.recordPlanParts([.meals])
        XCTAssertEqual(model.planParts, [.meals, .workouts])

        // Tersi: besin planı varken sadece antrenman yenilenirse besin kalır.
        model.workoutPlan = nil
        model.mealPlan = WeekMealPlan(days: [PlannedDay(day: 0, meals: [])],
                                      kcalTarget: 1500, proteinTarget: 90,
                                      carbTarget: 150, fatTarget: 50, poolSize: 100)
        model.recordPlanParts([.workouts])
        XCTAssertEqual(model.planParts, [.meals, .workouts])
    }

    @MainActor
    func testHealthParsingMapsTurkishPhrases() {
        XCTAssertEqual(AppModel.parseHealthFlags("tansiyonum ve şeker hastalığım var"),
                       ["tansiyon", "diyabet_ilac"])
        XCTAssertEqual(AppModel.parseHealthFlags("hamileyim"), ["gebelik"])
        XCTAssertTrue(AppModel.parseHealthFlags("yok").isEmpty)
    }

    @MainActor
    func testFoodAversionParsingSplitsAllergyAndDislike() {
        let parsed = AppModel.parseFoodAversions("fıstık, mantar, laktoz")
        XCTAssertEqual(parsed.allergies, ["Fındık/ceviz", "Laktoz"])
        XCTAssertEqual(parsed.dislikes, ["Mantar"])
    }

    @MainActor
    func testVariationShiftsRotation() {
        var prefs = PlanPreferences()
        prefs.protocolKey = "dengeli"
        let base = AppModel.rotationDirective(dayIndex: 0, prefs: prefs, variation: 0)
        let varied = AppModel.rotationDirective(dayIndex: 0, prefs: prefs, variation: 1)
        XCTAssertNotEqual(base, varied)   // "başka plan" gerçekten başka
    }
}
