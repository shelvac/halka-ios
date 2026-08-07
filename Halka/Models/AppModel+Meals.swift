import Foundation

// MARK: - Meal planning, calorie log, photo estimation

extension AppModel {

    /// Menu for a given day with any catalog overrides applied.
    func menu(forDay day: Int) -> [String] {
        Demo.menus[day].enumerated().map { i, food in
            overrides["\(day)-\(i)"] ?? food
        }
    }

    func isEaten(day: Int, slot: Int) -> Bool {
        eaten.contains("\(day)-\(slot)")
    }

    func toggleEaten(day: Int, slot: Int) {
        let key = "\(day)-\(slot)"
        if eaten.contains(key) { eaten.remove(key) } else { eaten.insert(key) }
        // Beslenme halkasını etkiliyorsa günlük kayda yaz (US-024).
        if day == todayWeekdayIndex { scheduleRingSave() }
    }

    func extras(forDay day: Int) -> [ExtraMeal] {
        extras.filter { $0.day == day }
    }

    /// Calories actually consumed (checked plan meals + photo extras) for a day.
    func consumed(forDay day: Int) -> Int {
        let plan = menu(forDay: day).enumerated().reduce(0) { sum, pair in
            sum + (isEaten(day: day, slot: pair.offset) ? recipe(for: pair.element, slot: pair.offset).kcal : 0)
        }
        return plan + extras(forDay: day).reduce(0) { $0 + $1.kcal }
    }

    /// Beslenme halkasının kaynağı: BUGÜNÜN kaydı.
    /// Eskiden Çarşamba'ya (demo günü) sabitti.
    var nutritionToday: Int { consumed(forDay: todayWeekdayIndex) }

    /// Sum of the full planned menu for a day (regardless of eaten state).
    func planTotal(forDay day: Int) -> Int {
        let plan = menu(forDay: day).enumerated().reduce(0) { sum, pair in
            sum + recipe(for: pair.element, slot: pair.offset).kcal
        }
        return plan + extras(forDay: day).reduce(0) { $0 + $1.kcal }
    }

    var mealDayTitle: String {
        Demo.dayNamesFull[mealDay] + (mealDay == todayWeekdayIndex ? " · Bugün" : "")
    }

    var currentPhotoEstimate: PhotoEstimate {
        Demo.photoEstimates[extras.count % Demo.photoEstimates.count]
    }

    // MARK: Navigation

    func openMealDetail(food: String, slot: Int, from: MealView, catalogName: String? = nil) {
        mealSelection = MealSelection(food: food, mealIndex: slot,
                                      fromCatalog: catalogName != nil, catalogName: catalogName)
        mealBack = from
        mealView = .detail
    }

    func backFromMealSubview() {
        if mealView == .detail {
            mealView = mealBack
            mealSelection = nil
        } else {
            mealView = .menu
        }
    }

    /// Catalog dish replaces the planned meal in that slot for the selected day.
    func adoptCatalogMeal() {
        guard let sel = mealSelection, sel.fromCatalog else { return }
        overrides["\(mealDay)-\(sel.mealIndex)"] = sel.food
        mealView = .menu
        mealSelection = nil
    }

    // MARK: Photo flow

    func photoPicked(_ data: Data) {
        photoData = data
        photoState = .analyzing
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard let self, self.photoState == .analyzing else { return }
            self.photoState = .done
        }
    }

    func savePhotoMeal() {
        let est = currentPhotoEstimate
        extras.append(ExtraMeal(day: mealDay,
                                title: "Fotoğraftan öğün — \(est.items[0].0)",
                                kcal: est.total,
                                time: Self.nowHHmm()))
        photoData = nil
        photoState = .idle
        mealView = .menu
    }

    func retryPhoto() {
        photoData = nil
        photoState = .idle
    }

    func deleteExtra(_ id: UUID) {
        extras.removeAll { $0.id == id }
    }

    // MARK: Market list

    func isMarketChecked(day: Int, slot: Int, item: Int) -> Bool {
        marketChecked.contains("\(day)-\(slot)-\(item)")
    }

    func toggleMarket(day: Int, slot: Int, item: Int) {
        let key = "\(day)-\(slot)-\(item)"
        if marketChecked.contains(key) { marketChecked.remove(key) } else { marketChecked.insert(key) }
    }
}
