import XCTest
@testable import Halka

/// Sprint 1 test temeli: saf iş mantığı (halka hesapları, tarifler,
/// alerji tespiti, koç akışları). UI testleri sonraki sprintlerde.
final class AppModelTests: XCTestCase {

    // MARK: Kalori günlüğü / Beslenme halkası

    @MainActor
    func testConsumedMatchesInitiallyEatenMeals() {
        let model = AppModel()
        // Demo state: Çarşamba (day 2) sabah (310) + öğle (400) yenmiş.
        XCTAssertEqual(model.consumed(forDay: 2), 710)
        XCTAssertEqual(model.nutritionToday, 710)
    }

    @MainActor
    func testTogglingMealUpdatesConsumed() {
        let model = AppModel()
        model.toggleEaten(day: 2, slot: 2) // Meyve + fındık, 150 kcal
        XCTAssertEqual(model.consumed(forDay: 2), 860)
        model.toggleEaten(day: 2, slot: 2)
        XCTAssertEqual(model.consumed(forDay: 2), 710)
    }

    @MainActor
    func testPhotoExtraCountsTowardsConsumedAndCanBeDeleted() {
        let model = AppModel()
        let estimate = model.currentPhotoEstimate
        model.savePhotoMeal()
        XCTAssertEqual(model.consumed(forDay: 2), 710 + estimate.total)
        XCTAssertEqual(model.extras(forDay: 2).count, 1)
        model.deleteExtra(model.extras(forDay: 2)[0].id)
        XCTAssertEqual(model.consumed(forDay: 2), 710)
    }

    @MainActor
    func testCatalogOverrideReplacesPlannedMeal() {
        let model = AppModel()
        model.mealSelection = MealSelection(food: "Yulaf pancake", mealIndex: 0,
                                            fromCatalog: true, catalogName: "Kahvaltı")
        model.adoptCatalogMeal()
        XCTAssertEqual(model.menu(forDay: 2)[0], "Yulaf pancake")
    }

    // MARK: Su + geri alma

    @MainActor
    func testWaterAddAndUndoRespectBounds() {
        let model = AppModel()
        let start = model.water
        model.addWater()
        XCTAssertEqual(model.water, start + 250)
        XCTAssertTrue(model.waterUndoVisible)
        model.undoWater()
        XCTAssertEqual(model.water, start)
        XCTAssertFalse(model.waterUndoVisible)
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

    // MARK: Kan tahlili durumları

    func testBloodTestStatusThresholds() {
        let normal = BloodTest(name: "TSH", value: 2.07, unit: "uIU/mL", refLow: 0.35, refHigh: 4.94)
        XCTAssertEqual(normal.status, "Normal")
        let high = BloodTest(name: "MPV", value: 13.3, unit: "fL", refLow: 7.2, refHigh: 11.7)
        XCTAssertEqual(high.status, "Yüksek")
        XCTAssertEqual(high.refPosition, 0.98, accuracy: 0.001) // clamp üst sınırı
    }
}
