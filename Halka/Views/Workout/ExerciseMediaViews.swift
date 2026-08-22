import SwiftUI

// MARK: - Hareket görselleri (F1)
//
// Kaynak: free-exercise-db (yuhonas) — kamu malı; her hareketin başlangıç/
// bitiş pozu olmak üzere iki karesi var. Kareler dönüşümlü gösterilince
// hareket "canlanıyor" — video çekmeden Hevy hissi. Görseller şimdilik
// kaynağın kendi deposundan çekiliyor; lansman öncesi kendi depomuza
// kopyalamak E11 listesinde.

enum ExerciseMedia {
    static let base = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    /// "Slug/0.jpg" → tam URL. Boşluk gibi karakterler yüzde-kodlanır.
    nonisolated static func url(_ path: String) -> URL? {
        guard !path.isEmpty,
              let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return URL(string: base + encoded)
    }
}

/// Liste satırı küçük görseli — ilk kare; görsel yoksa eski yer tutucu.
struct ExerciseThumb: View {
    var exercise: Exercise

    var body: some View {
        if let path = exercise.images?.first, let url = ExerciseMedia.url(path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ImagePlaceholder(label: exercise.name)
                }
            }
        } else {
            ImagePlaceholder(label: exercise.name)
        }
    }
}

/// Başlangıç/bitiş karelerini dönüşümlü oynatan "animasyon".
/// İki kare de aynı anda yüklü tutulur; geçişte titreme olmaz.
struct ExerciseAnimation: View {
    var paths: [String]
    @State private var showSecond = false

    var body: some View {
        ZStack {
            frame(0).opacity(showSecond ? 0 : 1)
            if paths.count > 1 {
                frame(1).opacity(showSecond ? 1 : 0)
            }
        }
        .task {
            guard paths.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeInOut(duration: 0.25)) { showSecond.toggle() }
            }
        }
    }

    @ViewBuilder
    private func frame(_ index: Int) -> some View {
        if paths.indices.contains(index), let url = ExerciseMedia.url(paths[index]) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.chevron)
                default:
                    ProgressView()
                }
            }
        }
    }
}

/// Hareket detay sayfası: animasyon + bölge/ekipman/seviye + set önerisi.
struct ExerciseDetailSheet: View {
    var exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if exercise.images?.isEmpty == false {
                        ExerciseAnimation(paths: exercise.images ?? [])
                            .frame(maxWidth: .infinity)
                            .frame(height: 230)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    Text(exercise.name)
                        .font(.h(22))
                        .foregroundStyle(Color.ink)
                        .kerning(-0.5)

                    HStack(spacing: 6) {
                        chip(exercise.region, fg: Color.coralDark, bg: Color.coralBg)
                        if let equipment = exercise.equipment {
                            chip(equipment, fg: Color.blueDark, bg: Color.blueBg)
                        }
                        if let level = exercise.level {
                            chip(level, fg: Color.greenDark, bg: Color.greenBg)
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "repeat")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.coral)
                        Text("Önerilen: \(exercise.reps)")
                            .font(.h(12.5, .bold))
                            .foregroundStyle(Color.inkBody)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .card(16)

                    Text("İki kare, hareketin başlangıç ve bitiş pozunu gösterir. Ağırlık seçerken son tekrarları zorlanarak ama formu bozmadan tamamlayabileceğin yükü hedefle.")
                        .font(.h(11, .semibold))
                        .foregroundStyle(Color.sub)
                        .lineSpacing(4)

                    Text("Görsel: free-exercise-db (kamu malı)")
                        .font(.h(9.5, .bold))
                        .foregroundStyle(Color.faint)
                }
                .padding(20)
            }
            .background(Color.bgApp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .font(.h(13))
                        .foregroundStyle(Color.coral)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func chip(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.h(11))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }
}
