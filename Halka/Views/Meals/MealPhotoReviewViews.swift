import SwiftUI

// MARK: - Fotoğraf tahmininin onay ekranı (US-029)
//
// Porsiyon tahmini fotoğraftan yapılıyor ve doğası gereği hatalı: bir tabak
// pilavın 120 mi 200 gram mı olduğunu fotoğraftan kesin bilmek mümkün değil.
// Bu yüzden hiçbir tahmin onaysız kaydedilmiyor ve düzeltme dört seviyeli:
// porsiyon (en sık) → yemeği değiştir → eksik olanı ekle → tamamen reddet.

/// Tahmin edilen yiyeceklerin listesi.
struct MealEstimateCard: View {
    @Environment(AppModel.self) private var model
    let analysis: MealAnalysis

    /// Hangi satır için yemek araması açık?
    @State private var replacing: AnalyzedFood? = nil
    @State private var addingFood = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(analysis.items) { item in
                itemRow(item)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
            }
            actions
            totalRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
        .sheet(item: $replacing) { item in
            FoodSearchSheet(title: "Yemeği değiştir") { option in
                model.replaceItem(item.id, with: option)
            }
        }
        .sheet(isPresented: $addingFood) {
            FoodSearchSheet(title: "Yemek ekle") { option in
                model.addItem(option)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Tahmin")
                .font(.h(13))
                .foregroundStyle(Color.ink)
            // Güven düşükse bunu söylemek, sessizce kaydetmekten iyi.
            if analysis.lowestConfidence < 0.6 {
                Text("emin değil")
                    .font(.h(10, .bold))
                    .foregroundStyle(Color.warnOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.warnOrangeBg))
            }
            Spacer()
            if analysis.quota > 0 {
                Text("bugün \(analysis.usedToday)/\(analysis.quota)")
                    .font(.h(10, .bold))
                    .foregroundStyle(Color.faint)
            }
        }
        .padding(.bottom, 4)
    }

    private func itemRow(_ item: AnalyzedFood) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.h(13.5, .bold))
                        .foregroundStyle(Color.inkBody)
                    HStack(spacing: 5) {
                        Text(item.portionText)
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.sub)
                        // Katalogda yoksa kalori AI'ın tahmini — kullanıcı
                        // sayının nereden geldiğini bilmeli.
                        if !item.matched {
                            Text("katalogda yok")
                                .font(.h(9.5, .bold))
                                .foregroundStyle(Color.warnOrange)
                        }
                    }
                }
                Spacer(minLength: 6)
                Text("\(item.kcal) kcal")
                    .font(.h(15))
                    .foregroundStyle(Color.green)
            }

            HStack(spacing: 6) {
                ForEach(AnalyzedFood.steps, id: \.self) { step in
                    let grams = Int((Double(item.portionG) * step).rounded())
                    let active = abs(item.portionMultiple - step) < 0.13
                    Button { model.setGrams(grams, forItem: item.id) } label: {
                        Text(AnalyzedFood.stepLabel(step))
                            .font(.h(12, .bold))
                            .foregroundStyle(active ? .white : Color.inkMid)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(active ? Color.coral : Color.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Button { replacing = item } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.inkMid)
                        .frame(width: 34, height: 30)
                        .background(Color.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                Button { model.removeItem(item.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.coral)
                        .frame(width: 34, height: 30)
                        .background(Color.coralBg)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actions: some View {
        Button { addingFood = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .heavy))
                Text("Eksik bir şey var, ekle")
                    .font(.h(12, .bold))
                Spacer()
            }
            .foregroundStyle(Color.inkMid)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }

    private var totalRow: some View {
        let range = analysis.kcalRange
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Toplam")
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.inkMid)
                Spacer()
                Text("≈ \(analysis.totalKcal) kcal")
                    .font(.h(18))
                    .foregroundStyle(Color.ink)
            }
            // Tek sayı, porsiyon tahminindeki belirsizliği gizlerdi.
            Text("Muhtemel aralık \(range.low)–\(range.high) kcal · porsiyonu düzeltirsen daha isabetli olur")
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }
}

// MARK: - Yemek araması

/// Katalogdan yemek seçme.
///
/// Çark (picker) yerine arama: yemek kümesi sınırsız, 225 kayıt arasında
/// çark döndürmek işkence olurdu. Porsiyon ise sınırlı bir küme olduğu için
/// orada çark/adım düğmeleri doğru kontrol.
struct FoodSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (FoodOption) -> Void

    @State private var query = ""
    @State private var results: [FoodOption] = []
    @State private var searching = false

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                searchField
                if searching && results.isEmpty {
                    Spacer()
                    SpinnerArc(size: 24)
                    Spacer()
                } else if results.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .task(id: query) {
            // Her harfte istek atmamak için kısa bir bekleme.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            searching = true
            results = await SupabaseService.shared.searchFoods(query)
            searching = false
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.h(15))
                .foregroundStyle(Color.ink)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button("Vazgeç") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.sub)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.faint)
            TextField("Yemek ara…", text: $query)
                .font(.h(13, .semibold))
                .foregroundStyle(Color.ink)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.chevron)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text(query.isEmpty ? "Yemek adı yaz" : "Bulunamadı")
                .font(.h(13))
                .foregroundStyle(Color.sub)
            Text(query.isEmpty
                 ? "\"mer\" yazınca mercimek çorbası gelir."
                 : "Farklı bir yazım dene — katalog büyüyor.")
                .font(.h(11, .semibold))
                .foregroundStyle(Color.faint)
            Spacer()
        }
        .padding(.horizontal, 30)
        .multilineTextAlignment(.center)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(results) { option in
                    Button {
                        onPick(option)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.name)
                                    .font(.h(13, .bold))
                                    .foregroundStyle(Color.inkBody)
                                Text("1 \(option.portionName) · \(option.portionG) g")
                                    .font(.h(10.5, .bold))
                                    .foregroundStyle(Color.faint)
                            }
                            Spacer()
                            Text("\(option.portionKcal) kcal")
                                .font(.h(13))
                                .foregroundStyle(Color.green)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.hairline)
                            .frame(height: 1).padding(.horizontal, 16)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}
