import AuthenticationServices
import CryptoKit
import Foundation

/// US-019 — Native Google girişi (SDK'sız).
///
/// Eski akışta yetkilendirme Supabase'in web istemcisi üzerinden dönüyordu;
/// Google da izin ekranında istemcinin sahibi olarak
/// `urrjkubdngoszkttpeph.supabase.co` gösteriyordu. Bu akış Google'a doğrudan
/// BİZİM iOS OAuth istemcimizle gider — ekranda uygulamanın kendi kimliği
/// görünür ve Supabase alan adı hiç geçmez.
///
/// Google'ın resmî SDK'sı yerine standart OAuth (PKCE) kullanılıyor: SDK da
/// aynı tarayıcı sayfasını açıyor; tek farkı ~4 ek bağımlılık getirmesi.
///
/// Akış (Apple'daki nonce düzeniyle aynı mantık):
///   1. PKCE verifier + challenge ve nonce üret
///   2. ASWebAuthenticationSession ile Google yetkilendirme sayfası
///   3. Dönen kodu Google'ın token ucunda id_token'a çevir (iOS istemcileri
///      secret kullanmaz; PKCE yeterli)
///   4. id_token + HAM nonce Supabase'e verilir; Supabase token içindeki
///      hash'lenmiş nonce ile karşılaştırıp tekrar saldırısını engeller
///
/// Not: iOS istemci ID'si gizli değildir (uygulama paketinden zaten okunur);
/// Supabase tarafında `external_google_client_id` listesine eklenmiş olmalıdır,
/// yoksa id_token "audience" kontrolünden geçemez.
@MainActor
final class GoogleOAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleOAuth()

    private static let clientID =
        "79557204804-r4ttpt0n056k5leklb3fpi4v26rpgecm.apps.googleusercontent.com"
    /// Google iOS istemcilerinde geri dönüş şeması ters çevrilmiş client ID'dir.
    private static let callbackScheme =
        "com.googleusercontent.apps.79557204804-r4ttpt0n056k5leklb3fpi4v26rpgecm"
    private static let redirectURI = callbackScheme + ":/oauth2redirect"

    struct Tokens {
        let idToken: String
        let accessToken: String?
        /// Supabase'e verilecek HAM nonce.
        let nonce: String
    }

    enum Failure: LocalizedError {
        case cancelled
        case exchange(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "cancelled"
            case .exchange(let detail): return "Google token exchange: \(detail)"
            }
        }
    }

    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> Tokens {
        let verifier = Self.pkceVerifier()
        let nonce = AppleNonce.random()
        let state = AppleNonce.random(length: 16)

        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: Self.s256(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            // Apple akışıyla aynı düzen: Google'a hash gider, Supabase'e ham hâli.
            URLQueryItem(name: "nonce", value: AppleNonce.sha256(nonce)),
            URLQueryItem(name: "state", value: state),
        ]

        let callback = try await open(auth.url!)

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw Failure.exchange("kod alınamadı: \(callback)")
        }

        return try await exchange(code: code, verifier: verifier, nonce: nonce)
    }

    // MARK: Tarayıcı oturumu

    private func open(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: Self.callbackScheme
            ) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error, (error as NSError).code ==
                            ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    continuation.resume(throwing: Failure.cancelled)
                } else {
                    continuation.resume(throwing: error ?? Failure.exchange("boş yanıt"))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                continuation.resume(throwing: Failure.exchange("oturum başlatılamadı"))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    // MARK: Kod → token

    private func exchange(code: String, verifier: String, nonce: String) async throws -> Tokens {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String else {
            let detail = String(data: data.prefix(300), encoding: .utf8) ?? "?"
            throw Failure.exchange(detail)
        }
        return Tokens(idToken: idToken,
                      accessToken: json["access_token"] as? String,
                      nonce: nonce)
    }

    // MARK: PKCE

    private static func pkceVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return AppleNonce.random(length: 64)
        }
        return Data(bytes).base64URLEncoded
    }

    private static func s256(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }
}

private extension Data {
    /// RFC 7636'nın istediği base64url biçimi (dolgu yok, +/ yerine -_).
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
