import Foundation
import UIKit
import Vision

/// US-025 — Akıllı tartı ekranının fotoğrafından ölçümleri okur.
///
/// Neden fotoğraf: tartı uygulamaları 15+ değer üretiyor; bunları tek tek elle
/// girmek kimsenin yapacağı bir iş değil. Ekran görüntüsünü okumak, veriyi
/// kullanıcının zaten sahip olduğu yerden almanın en kısa yolu.
///
/// **Okunan değerler doğrudan kaydedilmez.** OCR yanılabilir ve yanlış bir
/// sağlık verisini sessizce kaydetmek kabul edilemez; sonuç önce kullanıcıya
/// gösterilip onaylatılır (`ScaleReviewView`).
enum ScaleOCR {

    /// Etiket eşleştirme kuralları — anahtar kelimeler ASCII'ye indirgenmiş
    /// hâlde yazılır (bkz. `normalized`).
    ///
    /// Sıra ÖNEMLİ ve dikkat ister: "Vücut Yağ Ağırlığı" içinde "yağ",
    /// "İskelet Kası Ağırlığı" içinde "kas" geçiyor. Uzun/özel etiketler
    /// önce denenmezse genel kural onları kapar.
    private static let rules: [(field: String, keywords: [String], expectsPercent: Bool?)] = [
        ("fatMass", ["vucut yag agirligi"], false),
        ("skeletalMusclePercent", ["iskelet kasi kutlesi"], true),
        ("skeletalMuscleKg", ["iskelet kasi agirligi"], false),
        ("muscleMass", ["kas agirligi"], false),
        ("waterMass", ["vucut sivi agirligi", "vucut sivi"], false),
        ("leanMass", ["yagsiz vucut agirligi", "yagsiz vucut"], false),
        ("metabolicAge", ["metabolik yas"], nil),
        ("bmr", ["metabolizma"], nil),
        ("obesity", ["obezite"], true),
        ("boneMass", ["kemik kutlesi", "kemik"], false),
        ("protein", ["protein"], true),
        ("visceralFat", ["v-yag", "viseral", "visseral"], nil),
        ("bmi", ["bmi", "vki"], nil),
        ("musclePercent", ["kas"], true),
        ("fatPercent", ["yag"], true),
        ("waterPercent", ["su"], true),
        ("weight", ["agirlik", "kilo"], false)
    ]

    /// Türkçe metni ASCII'ye indirger.
    ///
    /// Gerekli, çünkü `lowercased()` Türkçe büyük "İ"yi "i" + birleşik nokta
    /// olarak küçültüyor ve "İskelet" hiçbir anahtar kelimeyle eşleşmiyordu —
    /// iskelet kası değerleri yanlış alana yazılıyordu. Ayrıca OCR "ğ"yi "g",
    /// "ş"yi "s" okuyabiliyor; indirgeme bunu da tolere ediyor.
    static func normalized(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "İ", "I", "ı", "i": result.append("i")
            case "Ş", "ş": result.append("s")
            case "Ğ", "ğ": result.append("g")
            case "Ü", "ü": result.append("u")
            case "Ö", "ö": result.append("o")
            case "Ç", "ç": result.append("c")
            case "Â", "â": result.append("a")
            default: result.append(contentsOf: character.lowercased())
            }
        }
        return result
    }

    /// Fotoğraftaki değerleri okur. Hiçbir şey okunamazsa boş ölçüm döner.
    static func read(_ image: UIImage) async -> BodyMeasurement {
        var measurement = BodyMeasurement(measuredAt: Date(), source: .photo)
        guard let cgImage = image.cgImage else { return measurement }

        let lines = await recognizeLines(in: cgImage)
        guard !lines.isEmpty else { return measurement }

        var used = Set<String>()
        for line in lines {
            let lower = normalized(line)
            guard let rule = rules.first(where: { rule in
                !used.contains(rule.field) && rule.keywords.contains { lower.contains($0) }
            }) else { continue }
            guard let value = number(in: line, isPercent: rule.expectsPercent) else { continue }
            measurement.setValue(value, forField: rule.field)
            used.insert(rule.field)
        }

        // Tarih: "06/08/2026 09:09" gibi bir ifade varsa ölçüm zamanı olarak al.
        if let date = date(in: lines) { measurement.measuredAt = date }
        return measurement
    }

    // MARK: Metin tanıma

    /// Satırları soldan sağa birleştirerek döndürür — "Ağırlık(Kg)  70.55"
    /// gibi bir satırda etiket ve değer aynı dizede olsun.
    private static func recognizeLines(in cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let items = observations.compactMap { observation -> (y: CGFloat, x: CGFloat, text: String)? in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    return (observation.boundingBox.midY, observation.boundingBox.minX, text)
                }
                // Aynı yükseklikteki parçalar tek satır sayılır (tolerans: %1,2).
                var lines: [String] = []
                var current: [(x: CGFloat, text: String)] = []
                var lastY: CGFloat?
                for item in items.sorted(by: { $0.y > $1.y }) {
                    if let lastY, abs(lastY - item.y) > 0.012 {
                        lines.append(current.sorted { $0.x < $1.x }.map(\.text)
                            .joined(separator: " "))
                        current = []
                    }
                    current.append((item.x, item.text))
                    lastY = item.y
                }
                if !current.isEmpty {
                    lines.append(current.sorted { $0.x < $1.x }.map(\.text).joined(separator: " "))
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false   // sayılar bozulmasın
            request.recognitionLanguages = ["tr-TR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: Sayı ve tarih ayrıştırma

    /// Satırdaki ölçüm değerini bulur.
    ///
    /// Zorluk: satırda birden çok sayı olabiliyor ("Ağırlık(Kg) 70.55" içindeki
    /// birim, ya da karşılaştırma ekranındaki eski/yeni değerler). Kural:
    /// parantez içindekiler atlanır, kalan sayılardan **sonuncusu** alınır —
    /// tartı ekranlarında güncel değer sağda durur.
    static func number(in line: String, isPercent: Bool?) -> Double? {
        let cleaned = line.replacingOccurrences(
            of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        let pattern = "[-+]?\\d{1,4}(?:[.,]\\d{1,2})?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        let numbers: [Double] = regex.matches(in: cleaned, range: range).compactMap { match in
            guard let r = Range(match.range, in: cleaned) else { return nil }
            return Double(cleaned[r].replacingOccurrences(of: ",", with: "."))
        }
        guard var value = numbers.last else { return nil }

        // Yüzde alanında 100'ün üstü ya da eksi değer okunmuşsa güvenme.
        if isPercent == true, value < 0 || value > 100 { return nil }
        // Negatif ölçü olmaz (fark satırları "-1.05" içerebiliyor).
        if value < 0 { value = abs(value) }
        return value
    }

    private static func date(in lines: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        for format in ["dd/MM/yyyy HH:mm", "dd.MM.yyyy HH:mm", "dd/MM/yyyy", "dd.MM.yyyy"] {
            formatter.dateFormat = format
            let pattern = format.contains("HH")
                ? "\\d{2}[./]\\d{2}[./]\\d{4}\\s+\\d{2}:\\d{2}"
                : "\\d{2}[./]\\d{2}[./]\\d{4}"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      let r = Range(match.range, in: line) else { continue }
                let text = String(line[r]).replacingOccurrences(of: ".", with: "/")
                formatter.dateFormat = format.replacingOccurrences(of: ".", with: "/")
                if let date = formatter.date(from: text), date <= Date() { return date }
            }
        }
        return nil
    }
}
