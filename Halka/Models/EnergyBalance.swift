import Foundation

// MARK: - Enerji dengesi ve kilo tahmini (US-027)
//
// Denklem tartışmasız: depo değişimi = alınan − harcanan. Tartışmalı olan,
// iki tarafın da ölçüm hatası ve vücudun açığa verdiği uyum tepkisi. Bu
// dosya ikisini de açıkça modelliyor; tek bir kesin sayı üretmiyor.

/// Bir günün enerji dengesi.
struct EnergyBalance: Equatable {
    /// Kullanıcının işaretlediği öğünlerden gelen kalori.
    var intakeKcal: Int
    /// Bazal metabolizma — Mifflin-St Jeor.
    ///
    /// Apple'ın `basalEnergyBurned` değeri gün içinde birikerek artıyor;
    /// öğleyin günün ancak yarısını içeriyor ve "harcanan"ı yarı yarıya
    /// eksik gösteriyordu. Formül tam günü verdiği için o kullanılıyor.
    var basalKcal: Int
    /// Apple Health'in ölçtüğü aktif enerji (egzersiz + gün içi hareket).
    var activeKcal: Int

    /// Besinin termik etkisi: alınan enerjinin ~%10'u sindirimde harcanır.
    /// Karışık beslenmede kabul gören ortalama.
    var thermicKcal: Int { Int((Double(intakeKcal) * 0.10).rounded()) }

    var expenditureKcal: Int { basalKcal + activeKcal + thermicKcal }

    /// Negatif = açık (kilo verme yönü), pozitif = fazla.
    var balanceKcal: Int { intakeKcal - expenditureKcal }

    /// Öğün kaydı olmayan gün denge hesabına giremez: harcama tarafı dolu,
    /// alım tarafı boş olduğu için sahte bir açık üretirdi.
    var isUsable: Bool { intakeKcal > 0 }
}

/// Sürdürülen enerji dengesinden kilo değişimi tahmini.
///
/// **Neden "7700 kcal = 1 kg" kullanılmıyor:** Wishnofsky (1958) kuralı
/// kaybın tamamının yağ olduğunu ve harcamanın sabit kaldığını varsayar.
/// Kilo düştükçe hem kütle hem de metabolik uyum nedeniyle harcama azalır;
/// doğrusal kural bu yüzden kaybı iki katına kadar fazla tahmin eder.
///
/// Yerine Hall'un dinamik enerji dengesi modelinin pratik doğrusallaştırması
/// kullanılıyor (Hall KD ve ark., *The Lancet* 2011;378:826–37; NIH Body
/// Weight Planner'ın dayandığı model):
///
/// > Günlük **kalıcı** her 10 kcal değişim ≈ 0,45 kg nihai kilo değişimi;
/// > bunun yarısı yaklaşık 1 yılda gerçekleşir.
///
/// Üstel yaklaşım tek zaman sabitiyle kurulduğu için uzun vadede (3+ yıl)
/// Hall'un bildirdiğinden bir miktar **düşük** tahmin veriyor. Kilo verme
/// tahmininde muhafazakâr yönde sapmak tercih edilir.
enum WeightProjection {
    /// Hall'un kuralı: 10 kcal/gün → 0,45 kg ⇒ kcal/gün başına 0,045 kg.
    static let kgPerKcalPerDay = 0.045
    /// Nihai değişimin yarısına ulaşma süresi.
    static let halfLifeDays = 365.0

    /// `dailyBalance` (negatif = açık) sürdürülürse `days` gün sonundaki
    /// tahmini kilo değişimi. Negatif dönerse kayıp.
    static func changeKg(dailyBalance: Double, days: Double) -> Double {
        guard days > 0 else { return 0 }
        let eventual = dailyBalance * kgPerKcalPerDay
        return eventual * (1 - pow(2, -days / halfLifeDays))
    }

    /// Ölçüm belirsizliğini yansıtan aralık.
    ///
    /// Bileşik hata payı kabaca ±%30: giyilebilir cihazın enerji ölçümü
    /// %27–93 hata veriyor (Shcherbina ve ark., *J Pers Med* 2017), kendi
    /// bildirilen besin alımı ise tipik olarak %20–30 eksik bildiriliyor.
    /// Tek bir sayı vermek bu belirsizliği gizlerdi.
    static let uncertainty = 0.30

    /// (iyimser, kötümser) sırasıyla değil — küçükten büyüğe mutlak değişim.
    static func rangeKg(dailyBalance: Double, days: Double) -> (low: Double, high: Double) {
        let a = changeKg(dailyBalance: dailyBalance * (1 - uncertainty), days: days)
        let b = changeKg(dailyBalance: dailyBalance * (1 + uncertainty), days: days)
        return (min(abs(a), abs(b)), max(abs(a), abs(b)))
    }

    /// Haftalık kayıp hızı (kg/hafta) — güvenlik sınırı için.
    static func weeklyRateKg(dailyBalance: Double) -> Double {
        abs(changeKg(dailyBalance: dailyBalance, days: 7))
    }
}

/// Tahminin gösterilip gösterilmeyeceği ve uyarısı.
///
/// Kilo tahmini herkese gösterilemez: zayıf ya da reşit olmayan bir
/// kullanıcıya kilo verme öngörüsü sunmak zararlı olur.
enum ProjectionGate: Equatable {
    case ready
    case needsProfile
    case notEnoughDays(have: Int, need: Int)
    /// BMI 18,5 altı — kilo verme tahmini gösterilmez.
    case underweight
    case minor
    case gaining

    var message: String? {
        switch self {
        case .ready, .gaining: return nil
        case .needsProfile:
            return "Tahmin için boy, kilo, yaş ve cinsiyet bilgisi gerekiyor."
        case .notEnoughDays(let have, let need):
            return "Tahmin için en az \(need) günlük öğün kaydı gerekiyor — şu an \(have) gün var."
        case .underweight:
            return "Vücut kitle indeksin zaten düşük. Kilo verme tahmini göstermiyoruz; bir sağlık uzmanına danışmanı öneririz."
        case .minor:
            return "18 yaş altında kilo tahmini gösterilmiyor."
        }
    }
}
