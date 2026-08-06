import Foundation
import CryptoKit

/// Native Sign in with Apple için nonce üretimi (US-015).
///
/// Akış: rastgele nonce üret → SHA256'sını Apple'a gönder → Apple'ın döndürdüğü
/// identity token ile birlikte **ham** nonce'ı Supabase'e ver. Supabase token
/// içindeki hash'i ham nonce ile karşılaştırıp yanıt tekrarı (replay) saldırılarını
/// engeller.
enum AppleNonce {

    /// Kriptografik olarak güvenli rastgele nonce.
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            guard status == errSecSuccess else {
                // Son çare: UUID tabanlı (yine tahmin edilemez, sadece daha kısa entropi)
                return UUID().uuidString + UUID().uuidString
            }
            for byte in bytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// Apple'a gönderilecek hash'lenmiş hâli.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// Kimlik akışlarında kullanıcıya yansıtılmayan hataların kaydı.
/// (Sprint 6'da Sentry'ye bağlanacak — şimdilik konsol.)
enum AuthLog {
    static func warn(_ context: String, _ error: Error) {
        #if DEBUG
        print("⚠️ auth/\(context): \(error.localizedDescription)")
        #endif
    }
}
