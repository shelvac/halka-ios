import SwiftUI
import PhotosUI

// MARK: - Meal detail (image, ingredients/market list, steps)

struct MealDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        guard let sel = model.mealSelection else { return AnyView(EmptyView()) }
        let recipe = model.recipe(for: sel.food, slot: sel.mealIndex)
        let label = sel.fromCatalog ? (sel.catalogName ?? "")
                  : model.mealLabel(day: model.mealDay, slot: sel.mealIndex)
        let meta = (sel.fromCatalog ? ""
                    : "\(model.mealTime(day: model.mealDay, slot: sel.mealIndex)) · ")
                 + "~\(recipe.kcal) kcal"

        return AnyView(VStack(alignment: .leading, spacing: 0) {
            BackRow(label: sel.fromCatalog ? "Kataloğa dön" : "Menüye dön") {
                model.backFromMealSubview()
            }

            ImagePlaceholder(label: "\(sel.food) fotoğrafı")
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.ink.opacity(0.08), radius: 7, y: 2)

            HStack(spacing: 8) {
                Text(label)
                    .font(.h(11))
                    .foregroundStyle(Color.coralDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.coralBg))
                Text(meta).font(.h(11)).foregroundStyle(Color.sub)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)

            Text(sel.food)
                .font(.h(20))
                .foregroundStyle(Color.ink)
                .kerning(-0.4)
                .lineSpacing(3)

            if sel.fromCatalog {
                Button { model.adoptCatalogMeal() } label: {
                    Text("Bugünün menüsüne yaz").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .coralButton()
                .padding(.top, 12)
            }

            // Ingredients
            VStack(alignment: .leading, spacing: 10) {
                Text("Malzemeler · Market listesi")
                    .font(.h(14))
                    .foregroundStyle(Color.ink)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        HStack(spacing: 9) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text(ingredient)
                                .font(.h(12.5, .semibold))
                                .foregroundStyle(Color.inkBody)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)
            .padding(.top, 14)

            // Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("Hazırlanışı")
                    .font(.h(14))
                    .foregroundStyle(Color.ink)
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color(hex: 0xF7F1E6))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text("\(i + 1)").font(.h(11)).foregroundStyle(Color.brown)
                            )
                        Text(step)
                            .font(.h(12.5, .semibold))
                            .foregroundStyle(Color.inkBody)
                            .lineSpacing(4)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)
            .padding(.top, 12)
        })
    }
}

// MARK: - Catalog

struct MealCatalogView: View {
    @Environment(AppModel.self) private var model
    @State private var searchingDatabase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackRow(label: "Menüye dön") { model.mealView = .menu }

            Text("Yemek Kataloğu")
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
            Text("Diyet hedefine uygun alternatifler — tıkla, tarifi ve market listesini gör")
                .font(.h(12, .semibold))
                .foregroundStyle(Color.sub)
                .padding(.top, 2)
                .padding(.bottom, 14)

            // Aşağıdaki gruplar elle seçilmiş birkaç alternatif; asıl geniş
            // liste yemek veritabanında. Oraya yalnızca fotoğraf onay
            // ekranından girilebiliyordu, fotoğraf çekmeden ulaşılamıyordu.
            Button { searchingDatabase = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.coral)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Yemek veritabanında ara")
                            .font(.h(13))
                            .foregroundStyle(Color.ink)
                        Text("245 yemek · porsiyonunu seç, doğrudan günlüğe ekle")
                            .font(.h(10.5, .semibold))
                            .foregroundStyle(Color.sub)
                    }
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
            .padding(.bottom, 18)

            ForEach(Demo.catalog, id: \.0) { group in
                VStack(alignment: .leading, spacing: 9) {
                    Text(group.0)
                        .font(.h(14))
                        .foregroundStyle(Color.ink)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(group.2, id: \.self) { food in
                            Button {
                                model.openMealDetail(food: food, slot: group.1,
                                                     from: .catalog, catalogName: group.0)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    ImagePlaceholder(label: food)
                                        .frame(height: 92)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(food)
                                            .font(.h(12))
                                            .foregroundStyle(Color.inkSoft)
                                            .multilineTextAlignment(.leading)
                                            .lineSpacing(2)
                                        Text("~\(model.recipe(for: food, slot: group.1).kcal) kcal")
                                            .font(.h(10.5))
                                            .foregroundStyle(Color.sub)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.top, 10)
                                    .padding(.bottom, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $searchingDatabase) {
            FoodSearchSheet(title: "Yemek veritabanı", asksPortion: true,
                            onPick: { _ in },
                            onPickWithGrams: { option, grams in
                                model.logFood(option, grams: grams)
                                model.mealView = .menu
                            })
        }
    }
}

// MARK: - "Başka bir şey yedim" — photo + Vision AI estimate

struct PhotoLogView: View {
    @Environment(AppModel.self) private var model
    @State private var pickerItem: PhotosPickerItem? = nil
    /// AI çalışmadığında elle yemek ekleme.
    @State private var manualAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackRow(label: "Menüye dön") { model.mealView = .menu }

            Text("Başka bir şey yedim")
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
            Text("Öğününü fotoğrafla — yapay zekâ yiyecekleri ve porsiyonu tahmin eder, sen onaylarsın")
                .font(.h(12, .semibold))
                .foregroundStyle(Color.sub)
                .padding(.top, 2)
                .padding(.bottom, 14)

            if let data = model.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.08), radius: 7, y: 2)

                if model.photoState == .analyzing {
                    HStack(spacing: 12) {
                        SpinnerArc(size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Fotoğraf inceleniyor…")
                                .font(.h(13))
                                .foregroundStyle(Color.ink)
                            Text("Yiyecekler ve porsiyon tanımlanıyor")
                                .font(.h(11, .semibold))
                                .foregroundStyle(Color.sub)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .card(18)
                    .padding(.top, 12)
                }

                if model.photoState == .done {
                    if let error = model.mealAnalysisError {
                        photoErrorCard(error)
                            .padding(.top, 12)
                    }
                    if let analysis = model.mealAnalysis, !analysis.items.isEmpty {
                        MealEstimateCard(analysis: analysis)
                            .padding(.top, 12)

                        Button { model.savePhotoMeal() } label: {
                            Text("Günlüğe kaydet").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .coralButton()
                        .padding(.top, 12)
                    }

                    Button {
                        pickerItem = nil
                        model.retryPhoto()
                    } label: {
                        Text("Farklı fotoğraf yükle")
                            .font(.h(12))
                            .foregroundStyle(Color.sub)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Color.faint)
                        Text("Fotoğraf çek veya yükle")
                            .font(.h(13))
                            .foregroundStyle(Color.inkMid)
                        Text("JPG · PNG · HEIC")
                            .font(.h(11, .semibold))
                            .foregroundStyle(Color.faint)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color(hex: 0xFCFAF6))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.dashBorder, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                    )
                }
            }
        }
        .onChange(of: pickerItem) {
            guard let item = pickerItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.photoPicked(data)
                }
            }
        }
    }

    /// Tahmin alınamadıysa sebebini söyle — sessizce boş ekran gösterme.
    private func photoErrorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.warnOrange)
                Text("Tahmin alınamadı")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
            }
            Text(text)
                .font(.h(11.5, .semibold))
                .foregroundStyle(Color.sub)
                .fixedSize(horizontal: false, vertical: true)
            // Yine de elle ekleyebilsin: AI'ın çalışmaması öğün kaydını
            // tamamen engellememeli.
            Button { manualAdd = true } label: {
                Text("Elle ekle")
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.coral)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
        .sheet(isPresented: $manualAdd) {
            FoodSearchSheet(title: "Yemek ekle") { model.addItem($0) }
        }
    }

}

// MARK: - Market list (day's ingredients, checkable)

struct MarketListPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let day = model.mealDay
        // Menüden kaldırılan öğünün malzemesini alışveriş listesine
        // yazmanın anlamı yok.
        let menu = model.visibleMenu(forDay: day)
        return VStack(alignment: .leading, spacing: 0) {
            BackRow(label: "Menüye dön") { model.mealView = .menu }

            Text("Market Listesi")
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
            Text("\(model.mealDayTitle) menüsünün malzemeleri")
                .font(.h(12, .semibold))
                .foregroundStyle(Color.sub)
                .padding(.top, 2)
                .padding(.bottom, 14)

            ForEach(menu, id: \.slot) { slot, food in
                let recipe = model.recipe(for: food, slot: slot)
                VStack(alignment: .leading, spacing: 9) {
                    Text("\(model.mealLabel(day: day, slot: slot)) · \(food)")
                        .font(.h(12))
                        .foregroundStyle(Color.brown)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { itemIndex, ingredient in
                            let checked = model.isMarketChecked(day: day, slot: slot, item: itemIndex)
                            Button {
                                model.toggleMarket(day: day, slot: slot, item: itemIndex)
                            } label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(checked ? Color.green : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(checked ? Color.green : Color.dashBorder, lineWidth: 2)
                                        )
                                        .overlay {
                                            if checked {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .heavy))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(width: 20, height: 20)
                                    Text(ingredient)
                                        .font(.h(12.5, .semibold))
                                        .foregroundStyle(checked ? Color.faint : Color.inkBody)
                                        .strikethrough(checked)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(18)
                .padding(.bottom, 10)
            }
        }
    }
}
