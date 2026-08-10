import SwiftUI

// MARK: - Meal planning, calorie log, photo estimation

extension AppModel {

    /// AI koçun kurduğu plandaki gün — yoksa nil, demo menüye düşülür.
    ///
    /// "AI koçun oluşturduğu plan yemek sekmesine yansımıyor": sekme sabit
    /// demo menüyü gösteriyordu, üretilen plan yalnızca sonuç ekranında
    /// yaşıyordu. Plan varsa artık tek kaynak o.
    func planMeals(forDay day: Int) -> [PlannedMeal]? {
        guard let plan = mealPlan,
              let planDay = plan.days.first(where: { $0.day == day }),
              !planDay.meals.isEmpty else { return nil }
        return planDay.meals
    }

    /// Menu for a given day with any catalog overrides applied.
    func menu(forDay day: Int) -> [String] {
        if let meals = planMeals(forDay: day) {
            return meals.enumerated().map { i, meal in
                overrides["\(day)-\(i)"] ?? meal.items.map(\.name).joined(separator: " · ")
            }
        }
        return Demo.menus[day].enumerated().map { i, food in
            overrides["\(day)-\(i)"] ?? food
        }
    }

    /// Öğünün kalorisi — plan varsa plandan, katalogla değiştirildiyse veya
    /// demo menüdeyse tariften.
    func mealKcal(day: Int, slot: Int) -> Int {
        if let override = overrides["\(day)-\(slot)"] {
            return recipe(for: override, slot: min(slot, Demo.fallbackKcal.count - 1)).kcal
        }
        if let meals = planMeals(forDay: day), slot < meals.count {
            return meals[slot].kcal
        }
        let foods = Demo.menus[day]
        guard slot < foods.count else { return 0 }
        return recipe(for: foods[slot], slot: slot).kcal
    }

    /// Plan 3-5 öğünlü olabilir; sabit 4'lük demo dizilerine slot'la girmek
    /// taşardı. Saat ve etiket her zaman buradan okunur.
    func mealTime(day: Int, slot: Int) -> String {
        if let meals = planMeals(forDay: day), slot < meals.count {
            return meals[slot].time
        }
        return slot < mealTimes.count ? mealTimes[slot] : "—"
    }

    func mealLabel(day: Int, slot: Int) -> String {
        if let meals = planMeals(forDay: day), slot < meals.count {
            return meals[slot].label
        }
        return slot < Demo.mealLabels.count ? Demo.mealLabels[slot] : "Öğün"
    }

    /// Günlük kalori hedefi — profil hedefi (plan da aynı hedefle kurulur).
    var kcalGoal: Int { Int(goal(for: .nutrition)) }

    func isEaten(day: Int, slot: Int) -> Bool {
        eaten.contains("\(day)-\(slot)")
    }

    func isRemoved(day: Int, slot: Int) -> Bool {
        removedMeals.contains("\(day)-\(slot)")
    }

    /// Menüde görünen öğünler — kaldırılanlar hariç.
    ///
    /// Dizi indeksi yerine (slot, yemek) çifti dönüyor: kaldırılanı diziden
    /// çıkarmak sonraki öğünlerin slot numarasını kaydırır ve "işaretlendi",
    /// "değiştirildi" gibi kayıtlar yanlış öğüne bağlanırdı.
    func visibleMenu(forDay day: Int) -> [(slot: Int, food: String)] {
        menu(forDay: day).enumerated()
            .filter { !isRemoved(day: day, slot: $0.offset) }
            .map { (slot: $0.offset, food: $0.element) }
    }

    /// Öğünü menüden kaldırır. İşaretliyse işaret de kalkar — kaldırılan bir
    /// öğün yenmiş sayılamaz.
    func removeMeal(day: Int, slot: Int) {
        removedMeals.insert("\(day)-\(slot)")
        eaten.remove("\(day)-\(slot)")
        scheduleMealSave()
        if day == todayWeekdayIndex { scheduleRingSave() }
    }

    func restoreMeals(day: Int) {
        removedMeals = removedMeals.filter { !$0.hasPrefix("\(day)-") }
        scheduleMealSave()
        if day == todayWeekdayIndex { scheduleRingSave() }
    }

    func removedCount(forDay day: Int) -> Int {
        removedMeals.filter { $0.hasPrefix("\(day)-") }.count
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
        let plan = visibleMenu(forDay: day).reduce(0) { sum, item in
            sum + (isEaten(day: day, slot: item.slot)
                   ? mealKcal(day: day, slot: item.slot) : 0)
        }
        return plan + extras(forDay: day).reduce(0) { $0 + $1.kcal }
    }

    /// Beslenme halkasının kaynağı: BUGÜNÜN kaydı.
    /// Eskiden Çarşamba'ya (demo günü) sabitti.
    var nutritionToday: Int { consumed(forDay: todayWeekdayIndex) }

    /// Sum of the full planned menu for a day (regardless of eaten state).
    func planTotal(forDay day: Int) -> Int {
        let plan = visibleMenu(forDay: day).reduce(0) { sum, item in
            sum + mealKcal(day: day, slot: item.slot)
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

    /// Katalogdan doğrudan günlüğe ekler — fotoğraf akışından geçmeden.
    ///
    /// Yemek veritabanı yalnızca fotoğraf onay ekranından erişilebiliyordu;
    /// fotoğraf çekmeden bir şey eklemek isteyen kullanıcının yolu yoktu.
    @discardableResult
    func logFood(_ option: FoodOption, grams: Int) -> ExtraMeal {
        let kcal = Int((Double(option.kcal100) * Double(grams) / 100).rounded())
        let entry = ExtraMeal(day: mealDay,
                              title: "\(option.name) · \(grams) g",
                              kcal: kcal,
                              time: Self.nowHHmm())
        extras.append(entry)
        // Sık kullanılanlar öğrenilsin: kahveyi hep ekleyen, şeridin
        // başında kahveyi görsün.
        quickCounts[option.name, default: 0] += 1
        scheduleMealSave()
        if mealDay == todayWeekdayIndex { scheduleRingSave() }
        return entry
    }

    // MARK: Hızlı ekle — fotoğrafsız tek dokunuş (kahve, çay, ayran…)

    /// Şeridin varsayılanları (katalog `search_key` değerleri). Kullanıcının
    /// kendi sık ekledikleri sayaçla bunların önüne geçer.
    static let quickFoodKeys = [
        "kahve", "cay", "turk kahvesi (sade)", "ayran", "yogurt",
        "elma", "muz", "badem", "bitter cikolata"
    ]

    /// Çiplerin yemek bilgisini bir kez getirir (varsayılanlar + kullanıcının
    /// sayaçlı yemekleri).
    func loadQuickFoods() async {
        guard quickFoods.isEmpty else { return }
        var keys = Set(Self.quickFoodKeys)
        keys.formUnion(quickCounts.keys.map { SupabaseService.searchKey($0) })
        quickFoods = await SupabaseService.shared.fetchFoods(searchKeys: Array(keys))
    }

    /// Şerit sırası: en sık eklenenler önce, kalanlar varsayılan sırada.
    static func quickAddOrder(options: [FoodOption],
                              counts: [String: Int]) -> [FoodOption] {
        let defaultRank = Dictionary(uniqueKeysWithValues:
            quickFoodKeys.enumerated().map { ($0.element, $0.offset) })
        return options.sorted { a, b in
            let ca = counts[a.name] ?? 0, cb = counts[b.name] ?? 0
            if ca != cb { return ca > cb }
            let ra = defaultRank[SupabaseService.searchKey(a.name)] ?? .max
            let rb = defaultRank[SupabaseService.searchKey(b.name)] ?? .max
            if ra != rb { return ra < rb }
            return a.name < b.name
        }
    }

    var quickAddOptions: [FoodOption] {
        Self.quickAddOrder(options: quickFoods, counts: quickCounts)
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
