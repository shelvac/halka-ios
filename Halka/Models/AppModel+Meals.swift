import SwiftUI

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
        scheduleMealSave()
        // Beslenme halkasını etkiliyorsa günlük kayda yaz (US-024).
        if day == todayWeekdayIndex { scheduleRingSave() }
    }

    /// Öğün kaydını gecikmeli yazar — arka arkaya işaretlemede her dokunuş
    /// için istek atmamak adına (`scheduleRingSave` ile aynı desen).
    func scheduleMealSave() {
        mealSaveToken += 1
        let token = mealSaveToken
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.mealSaveToken == token else { return }
            await self.persistMealState()
        }
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
        scheduleMealSave()
        mealView = .menu
        mealSelection = nil
    }

    // MARK: Photo flow

    /// Fotoğrafı sunucuya gönderip tahmini alır (US-029).
    ///
    /// Eskiden burada AI yoktu: `Demo.photoEstimates` dizisinden sırayla
    /// değer okunuyordu, fotoğrafa hiç bakılmıyordu. "Ne atarsam atayım köfte
    /// diyor" şikâyetinin sebebi buydu.
    func photoPicked(_ data: Data) {
        photoData = data
        photoState = .analyzing
        mealAnalysis = nil
        mealAnalysisError = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                // Fotoğrafı küçültüp göndermek hem hızlı hem ucuz: tam
                // çözünürlük tanımaya bir şey katmıyor, token'ı katlıyor.
                let payload = Self.downscaledJPEG(data) ?? data
                let analysis = try await SupabaseService.shared.analyzeMeal(imageData: payload)
                guard self.photoState == .analyzing else { return }
                if analysis.items.isEmpty {
                    self.mealAnalysisError = "Fotoğrafta yemek tanınamadı. Farklı bir kare dene ya da elle ekle."
                }
                self.mealAnalysis = analysis
                self.photoState = .done
            } catch {
                guard self.photoState == .analyzing else { return }
                self.mealAnalysisError = error.localizedDescription
                self.photoState = .done
            }
        }
    }

    /// Uzun kenarı 1024 piksele indirir ve JPEG'e çevirir.
    static func downscaledJPEG(_ data: Data, maxEdge: CGFloat = 1024,
                               quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxEdge / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: Onay ekranı düzenlemeleri

    func setGrams(_ grams: Int, forItem id: UUID) {
        guard let index = mealAnalysis?.items.firstIndex(where: { $0.id == id }) else { return }
        mealAnalysis?.items[index].grams = max(1, grams)
        mealAnalysisEdited = true
    }

    func replaceItem(_ id: UUID, with option: FoodOption) {
        guard let index = mealAnalysis?.items.firstIndex(where: { $0.id == id }) else { return }
        let grams = mealAnalysis?.items[index].grams ?? option.portionG
        mealAnalysis?.items[index] = AnalyzedFood(
            id: id, name: option.name, foodID: option.id, matched: true,
            // Yemek değiştiğinde gramajı korumak yanıltıcı olurdu: çorbanın
            // 150 g'ı ile pilavın 150 g'ı aynı şey değil. Yeni yemeğin
            // porsiyonuna en yakın katı seçiliyor.
            grams: Self.nearestPortion(grams: grams, portionG: option.portionG),
            kcal100: option.kcal100, portionG: option.portionG,
            portionName: option.portionName, confidence: 1)
        mealAnalysisEdited = true
    }

    func addItem(_ option: FoodOption) {
        let item = AnalyzedFood(name: option.name, foodID: option.id, matched: true,
                                grams: option.portionG, kcal100: option.kcal100,
                                portionG: option.portionG, portionName: option.portionName,
                                confidence: 1)
        if mealAnalysis == nil {
            mealAnalysis = MealAnalysis(items: [item], note: nil, logID: nil,
                                        usedToday: 0, quota: 0)
        } else {
            mealAnalysis?.items.append(item)
        }
        mealAnalysisEdited = true
    }

    func removeItem(_ id: UUID) {
        mealAnalysis?.items.removeAll { $0.id == id }
        mealAnalysisEdited = true
    }

    /// Gramajı yeni yemeğin porsiyon adımlarına oturtur.
    static func nearestPortion(grams: Int, portionG: Int) -> Int {
        let multiple = Double(grams) / Double(max(1, portionG))
        let closest = AnalyzedFood.steps.min {
            abs($0 - multiple) < abs($1 - multiple)
        } ?? 1
        return Int((Double(portionG) * closest).rounded())
    }

    /// Onaylanan öğünleri günlüğe yazar.
    ///
    /// Her yiyecek AYRI kayıt: kullanıcı sonradan yalnızca birini silmek
    /// isteyebilir, tek satırda toplamak bunu imkânsız kılardı.
    func savePhotoMeal() {
        guard let analysis = mealAnalysis, !analysis.items.isEmpty else { return }
        let time = Self.nowHHmm()
        for item in analysis.items {
            extras.append(ExtraMeal(day: mealDay,
                                    title: "\(item.name) · \(item.portionText)",
                                    kcal: item.kcal,
                                    time: time))
        }
        // Doğruluğu ölçebilmek için: AI ne dedi, kullanıcı neye çevirdi.
        if let logID = analysis.logID {
            let items = analysis.items
            let edited = mealAnalysisEdited
            Task {
                await SupabaseService.shared.recordMealCorrection(
                    logID: logID, finalItems: items, corrected: edited)
            }
        }
        scheduleMealSave()
        if mealDay == todayWeekdayIndex { scheduleRingSave() }
        retryPhoto()
        mealView = .menu
    }

    func retryPhoto() {
        photoData = nil
        photoState = .idle
        mealAnalysis = nil
        mealAnalysisError = nil
        mealAnalysisEdited = false
    }

    func deleteExtra(_ id: UUID) {
        extras.removeAll { $0.id == id }
        scheduleMealSave()
        scheduleRingSave()
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
