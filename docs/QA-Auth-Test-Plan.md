# Kimlik Akışları — Düzeltme Stratejisi ve Test Planı

**Kapsam:** Kayıt, Giriş, Şifremi Unuttum, SSO (Apple/Google)
**İlgili story'ler:** US-010 … US-018
**Son güncelleme:** 6 Ağustos 2026

---

# Bölüm 1 · Düzeltme Stratejisi ve Mantık Adımları

## 1.1 Temel ilke: mesaj politikası bilinçli seçilir

Kimlik akışlarında iki karşıt hedef vardır:

| Hedef | Ne ister |
| --- | --- |
| **Kullanılabilirlik (UX)** | "Bu hesap yok", "bu mail zaten kayıtlı" gibi net mesajlar |
| **Güvenlik** | Saldırganın hangi e-postaların sistemde olduğunu öğrenmesini engellemek (*user enumeration*) |

Bu ikisi her ekranda aynı anda sağlanamaz. halka'nın kararı — **akış bazında ayrıştırma**:

| Akış | Politika | Gerekçe |
| --- | --- | --- |
| **Şifremi Unuttum** | 🔒 **Jenerik** — "Bu adres kayıtlıysa bağlantı gönderildi" | Bu ekran giriş yapmamış herkese açık ve otomatize taranması en kolay yer. Sızıntı riski en yüksek burada. |
| **Giriş** | 🎯 **Net** — "Kayıtlı hesap bulunamadı" | Kullanıcı zaten bir şifre denemesi yapıyor; sınırlı bilgi karşılığında büyük UX kazancı. Hız sınırı ve CAPTCHA ile dengelenir. |
| **Kayıt** | 🎯 **Net** — "Bu e-posta zaten kullanımda" | Kaçınılmaz: aynı adresle ikinci hesap açılamayacağı bilgisi zaten akışın sonucudur. |

> **Not:** Kayıt ekranında "zaten kullanımda" demek de teknik olarak bir enumeration'dır; kaçınmak isteyen ürünler burada da "doğrulama e-postası gönderildi" der. halka, kullanıcıyı çıkmazda bırakmamak için net mesajı tercih etti.

## 1.2 Backend (Supabase Auth) tarafı

**a) Supabase'in varsayılan davranışı ve neden yetmediği**

| Durum | Supabase'in yanıtı | Sorun |
| --- | --- | --- |
| Yanlış şifre | `400 invalid login credentials` | Aynı mesaj |
| Hesap yok | `400 invalid login credentials` | Ayırt edilemiyor |
| Kayıtlı e-postayla `signUp` | `200` + `user.identities == []` | Hata fırlatmaz, sessizce "başarılı" görünür |
| Kayıtsız e-postayla `recover` | `200` | Mail gitmez ama başarı döner (bu davranış **doğru** ve korunur) |

**b) Eklenen sunucu fonksiyonu** — `supabase/migrations/0002_account_status.sql`

```sql
create or replace function public.account_status(p_email text)
returns json language sql security definer stable
```

Döndürdüğü alanlar: `exists`, `has_password`, `providers` (`google,apple`…).

`SECURITY DEFINER` kullanılır çünkü `auth.users` tablosuna anon rolü erişemez.
Fonksiyon **kişisel veri döndürmez** — yalnızca varlık ve giriş yöntemi.

**c) Rate limiting ve bot koruması (production öncesi zorunlu)**

| Ayar | Şimdiki | Lansman hedefi |
| --- | --- | --- |
| `rate_limit_email_sent` | 100 / saat | 100 (yeterli) |
| Token/giriş isteği limiti | Supabase varsayılanı (IP başına) | Aynı kalır |
| CAPTCHA (`security_captcha_enabled`) | ❌ kapalı | ✅ **açılacak** (hCaptcha veya Turnstile) — enumeration'ı otomatize etmeyi anlamsız kılar |
| Şifre sıfırlama token ömrü | 1 saat (varsayılan) | Aynı |

CAPTCHA açılmadan "Giriş"teki net mesaj, tek başına bir e-posta listesi taranmasına
izin verir. **Lansman öncesi kapatılması gereken açık budur** (bkz. §1.5).

## 1.3 Frontend (SwiftUI) tarafı

**Katmanlar:**

```
View (LoginView / RegisterView / ForgotPasswordView)
   ↓ kullanıcı eylemi
AppModel+Auth        → akış mantığı, istemci tarafı doğrulama, mesaj seçimi
   ↓
SupabaseService      → ağ çağrıları (signIn / signUp / recover / accountStatus)
   ↓
Supabase Auth + account_status RPC
```

**a) İstemci tarafı ön doğrulama** (ağ isteği yapmadan önce)

| Kontrol | Mesaj |
| --- | --- |
| Boş e-posta / şifre | "E-posta ve şifreni gir." |
| Şifre < 8 karakter | "Şifre en az 8 karakter olmalı." |
| Ad boş (kayıt) | "Adını gir." |
| KVKK işaretsiz | Buton **pasif** (mesaj yerine engelleme) |

**b) Sunucu hatalarının çevirisi** — `AppModel.authMessage(_:)`
Tek bir yerde toplanır; her yeni hata örüntüsü buraya eklenir:

```
invalid login credentials → signInMessage() ile ayrıştırılır
already registered       → "Bu e-posta zaten kullanımda, lütfen giriş yapın."
email not confirmed      → "E-postan henüz doğrulanmamış…"
rate limit / too many    → "Çok fazla deneme yapıldı — birkaç dakika sonra tekrar dene."
expired / invalid token  → "Bağlantının süresi dolmuş — yeni bir bağlantı iste."
URLError / network       → "Bağlantı kurulamadı…"
```

**c) Giriş hatasının ayrıştırılması** — `signInMessage(_:email:)`

```
"invalid login credentials" mi?
├── hayır → genel çeviri
└── evet  → account_status(email)
        ├── exists = false        → "Bu e-posta adresiyle kayıtlı bir hesap bulunamadı."
        ├── has_password = false  → "Bu hesap Google/Apple ile açılmış — o düğmeyle giriş yap."
        └── diğer                 → "E-posta veya şifre hatalı."
```

`account_status` çağrısı başarısız olursa (ağ/fonksiyon yok) akış **bozulmaz**,
genel mesaja düşer — *fail-safe* tasarım.

**d) Şifre sıfırlamada sessiz hata**

```swift
do { try await resetPassword(email:) }
catch { AuthLog.warn("resetPassword", error) }   // kullanıcıya YANSIMAZ
forgotSent = true                                 // her durumda jenerik onay
```

Hata kullanıcıya gösterilmez ama **loglanır** — böylece gerçek bir arıza
(SMTP çökmesi, kota) fark edilir. Sprint 6'da `AuthLog` Sentry'ye bağlanacak.

**e) Buton durumları**
Her ağ çağrısında `authBusy = true` → butonda `ProgressView`, `disabled(true)`.
Çift dokunuş ve mükerrer istek engellenir.

## 1.4 SSO'ya özel mantık

| Konu | Karar |
| --- | --- |
| **Apple** | Native `SignInWithAppleButton` + `signInWithIdToken` (tarayıcı yok). Nonce: rastgele üretilir, SHA256'sı Apple'a, ham hâli Supabase'e gider (replay koruması). |
| **Google** | Şu an web OAuth (ASWebAuthenticationSession). Native SDK'ya geçiş → US-019. |
| **Vazgeçme** | `ASAuthorizationError.canceled` (kod 1) → **hiçbir mesaj gösterilmez**. |
| **Sağlayıcı kapalıysa** | Tarayıcı **açılmadan önce** `/auth/v1/settings` ile kontrol → net uyarı. |
| **Ad bilgisi** | Apple adı yalnızca **ilk** girişte döner; o an yakalanıp `users.full_name`'e yazılır. |
| **Hesap birleştirme** | Supabase, aynı **doğrulanmış** e-postaya sahip kimlikleri varsayılan olarak tek kullanıcıda birleştirir (`Link identities` açık). Şifreli hesap + aynı mailin Google'ı → tek kullanıcı, iki identity. |

## 1.5 Lansman öncesi kapatılacak açıklar

- [ ] **CAPTCHA'yı aç** (Supabase → Auth → Bot & Abuse Protection) — Giriş ekranındaki net mesajın enumeration riskini dengeler
- [ ] Şifre politikası: Supabase → Auth → Password'ta minimum uzunluk **8** ve "leaked password protection" aç
- [ ] `account_status` fonksiyonuna istek limiti (Edge Function proxy veya `pg_cron` ile kötüye kullanım izleme)
- [ ] `AuthLog` → Sentry
- [ ] Doğrulanmış alan adı (Resend) — `onboarding@resend.dev` yalnızca hesap sahibine gönderiyor

---

# Bölüm 2 · Test Senaryoları

**Ortam:** Gerçek iPhone (deep link ve Apple girişi simülatörde eksik çalışır)
**Ön koşul:** Supabase'de e-posta doğrulaması **açık**, `rate_limit_email_sent = 100`
**Kısaltmalar:** ✅ geçmeli · ⚠️ bilinen sınırlama · 🔒 güvenlik testi

## 2.1 Kayıt Ol (Register)

| # | Adım | Beklenen sonuç |
| --- | --- | --- |
| R-01 | Geçerli ad, yeni e-posta, 8+ karakter şifre, KVKK işaretli → **Kayıt Ol** | ✅ "E-postanı doğrula" ekranı açılır; adres ekranda görünür; **uygulamaya girilmez** |
| R-02 | R-01 sonrası Supabase → Table Editor → `users` | ✅ Satır oluşmuş; `kvkk_accepted_at` ve `health_consent_at` **dolu** |
| R-03 | Geçersiz format (`abc`, `a@`, `a@b`) | ✅ "Geçerli bir e-posta adresi gir." |
| R-04 | Şifre 7 karakter | ✅ "Şifre en az 8 karakter olmalı." — ağ isteği **atılmaz** |
| R-05 | Sistemde var olan e-posta | ✅ "Bu e-posta zaten kullanımda, lütfen giriş yapın." |
| R-06 | KVKK kutusu işaretsiz | ✅ **Kayıt Ol butonu pasif** (soluk), dokunma etkisiz |
| R-07 | Ad alanı boş | ✅ "Adını gir." |
| R-08 | KVKK metnine dokun | ✅ Aydınlatma metni sayfası açılır, "Kapat" ile döner |
| R-09 | Uçak modunda kayıt | ✅ "Bağlantı kurulamadı — internetini kontrol edip tekrar dene." |
| R-10 | Kayıt sırasında butona hızlıca 3 kez dokun | ✅ Tek istek gider; buton yükleniyor durumunda ve pasif |
| R-11 🔒 | E-posta alanına `test@x.com' OR 1=1--` | ✅ Format hatası; SQL/enjeksiyon etkisi yok (PostgREST parametreli sorgu) |
| R-12 🔒 | Ad alanına `<script>alert(1)</script>` | ✅ Metin düz metin olarak saklanır ve gösterilir; çalıştırılmaz |
| R-13 | Doğrulama ekranında "E-postayı tekrar gönder" | ✅ "Doğrulama e-postası tekrar gönderildi." + yeni mail gelir |
| R-14 | R-13'ü art arda 5 kez | ⚠️ Supabase min. gönderim aralığı (5 sn) devrede → hata mesajı anlaşılır olmalı |
| R-15 | Maildeki bağlantıya **telefondan** dokun | ✅ Uygulama açılır, ana ekrana girilir, selamlamada gerçek ad görünür |
| R-16 | Aynı bağlantıya **ikinci kez** dokun | ✅ "Bağlantının süresi dolmuş — yeni bir bağlantı iste." (tek kullanımlık) |
| R-17 ⚠️ | Maildeki bağlantıyı **masaüstünde** aç | ⚠️ `halka://` şeması tanınmaz — bu beklenen davranış; e-posta metni "telefonundan aç" diyor |

## 2.2 Giriş Yap (Login)

| # | Adım | Beklenen sonuç |
| --- | --- | --- |
| L-01 | Doğru e-posta + şifre (doğrulanmış hesap) | ✅ Ana ekran açılır; selamlamada gerçek ad |
| L-02 | Doğru e-posta, **yanlış şifre** | ✅ "E-posta veya şifre hatalı." — alanlar temizlenmez |
| L-03 | **Kayıtlı olmayan** e-posta | ✅ "Bu e-posta adresiyle kayıtlı bir hesap bulunamadı." |
| L-04 | Yalnızca **Google/Apple** ile açılmış hesabın maili + rastgele şifre | ✅ "Bu hesap Google/Apple ile açılmış — o düğmeyle giriş yap." |
| L-05 | **Doğrulanmamış** hesapla giriş | ✅ İçeri **alınmaz**; "E-postanı doğrula" ekranına yönlendirilir; oturum kapatılır |
| L-06 | Art arda **5 yanlış şifre** | ✅ Hesap kilitlenmez (Supabase varsayılanı), ancak IP limitine takılınca "Çok fazla deneme yapıldı…" görünür |
| L-07 🔒 | L-06'yı 20+ denemeye çıkar | ⚠️ Supabase IP başına limit uygular; **CAPTCHA açılmadan** koruma zayıftır → §1.5 |
| L-08 | Boş e-posta veya boş şifre | ✅ "E-posta ve şifreni gir." — ağ isteği atılmaz |
| L-09 | Uçak modu | ✅ "Bağlantı kurulamadı…" ve buton yeniden denenebilir |
| L-10 | Giriş sırasında butona çift dokun | ✅ Tek istek; yükleniyor göstergesi |
| L-11 | Giriş → uygulamayı **tamamen kapat** → yeniden aç | ✅ Şifre sorulmaz, doğrudan ana ekran (Keychain oturumu) |
| L-12 | Profil → **Çıkış Yap** → geri dön | ✅ Giriş ekranı; geri hareketiyle içeri dönülemez |
| L-13 🔒 | Çıkış sonrası cihazda oturum kalıntısı | ✅ Yeni açılışta oturum yok; token'lar Keychain'den silinmiş |
| L-14 | Rol segmenti **Diyetisyen** seçip giriş | ✅ Premium paywall ekranı açılır |

## 2.3 Şifremi Unuttum (Forgot Password)

| # | Adım | Beklenen sonuç |
| --- | --- | --- |
| F-01 | Kayıtlı e-posta → **Sıfırlama Bağlantısı Gönder** | ✅ "Bu adres sistemimizde kayıtlıysa şifre sıfırlama bağlantısı gönderildi…" + mail gelir |
| F-02 🔒 | **Kayıtlı olmayan** e-posta | ✅ **Aynı** jenerik mesaj; mail gitmez; uygulama çökmez |
| F-03 🔒 | F-01 ve F-02 yanıt sürelerini karşılaştır | ✅ Belirgin fark olmamalı (zamanlama üzerinden enumeration) |
| F-04 | Boş e-posta | ✅ "E-posta adresini gir." |
| F-05 | Maildeki bağlantıya **telefondan** dokun | ✅ Uygulama açılır → **Yeni şifre belirle** ekranı |
| F-06 | Yeni şifre 7 karakter | ✅ "Şifre en az 8 karakter olmalı." |
| F-07 | İki şifre alanı farklı | ✅ "Şifreler eşleşmiyor." |
| F-08 | Geçerli yeni şifre → **Şifreyi Güncelle** | ✅ Ana ekrana girilir; yeni şifreyle giriş yapılabilir |
| F-09 | Eski şifreyle giriş dene | ✅ "E-posta veya şifre hatalı." |
| F-10 | Bağlantıya **24 saat sonra** dokun | ✅ "Bağlantının süresi dolmuş — yeni bir bağlantı iste." → Şifremi Unuttum ekranına döner |
| F-11 | Aynı bağlantıyı **ikinci kez** kullan | ✅ Süresi dolmuş muamelesi; şifre değişmez |
| F-12 🔒 | Bağlantıdaki `code` parametresini elle boz | ✅ "Bağlantı geçersiz veya süresi dolmuş" — oturum açılmaz |
| F-13 🔒 | Bağlantıyı **başka bir cihazda** aç | ✅ Çalışmaz (PKCE aynı cihaz şartı) — bu **kasıtlı** güvenlik davranışı |
| F-14 | Art arda 3 sıfırlama isteği | ✅ Her seferinde jenerik onay; en son bağlantı geçerli |
| F-15 | SMTP kotası dolduğunda | ✅ Kullanıcı yine jenerik onay görür; hata **loglanır** (`AuthLog`) |

## 2.4 SSO (Apple / Google)

| # | Adım | Beklenen sonuç |
| --- | --- | --- |
| S-01 | **Apple ile devam et** (ilk kez) | ✅ Sistem diyaloğu (Face ID) — **tarayıcı açılmaz**; onay sonrası ana ekran |
| S-02 | S-01 sonrası Supabase → Authentication → Users | ✅ Yeni kullanıcı; `provider = apple` |
| S-03 | S-01'de Apple'ın verdiği ad | ✅ `users.full_name`'e yazılır; selamlamada görünür |
| S-04 | **İkinci** Apple girişi | ✅ Ad Apple'dan gelmez ama **profilden okunur**, selamlama bozulmaz |
| S-05 | Apple diyaloğunu **iptal et** | ✅ Sessizce giriş ekranında kalınır — **hata mesajı gösterilmez** |
| S-06 | Apple'da "E-postamı gizle" seç | ✅ `privaterelay.appleid.com` adresiyle hesap açılır ve çalışır |
| S-07 | **Google ile devam et** | ✅ Tarayıcı açılır → hesap seçimi → uygulamaya döner → ana ekran |
| S-08 | Google penceresini **yarıda kapat** | ✅ Giriş ekranında kalınır, hata mesajı yok |
| S-09 | Google'da hesap seçmeden **geri** | ✅ Aynı — sessiz iptal |
| S-10 | **Account Linking:** `x@gmail.com` ile şifreli kayıt → doğrula → çıkış → aynı mailin **Google**'ı ile giriş | ✅ **Tek kullanıcı**; Supabase → Users'ta 1 satır, 2 identity (`email` + `google`); veriler korunur |
| S-11 | S-10 sonrası eski şifreyle giriş | ✅ Çalışır — iki yöntem de aynı hesaba açılır |
| S-12 | Aynı senaryoyu **Apple** ile tekrarla | ✅ Aynı davranış (e-posta gizlenmediyse) |
| S-13 ⚠️ | Apple'da e-posta gizlenmişse birleştirme | ⚠️ Relay adresi farklı olduğu için **ayrı hesap** oluşur — beklenen; kullanıcıya profilde açıklanmalı |
| S-14 | Sağlayıcı Supabase'de kapalıyken düğmeye dokun | ✅ Tarayıcı **açılmadan** "… henüz etkin değil" uyarısı |
| S-15 | Uçak modunda SSO | ✅ Anlaşılır bağlantı hatası; uygulama çökmez |
| S-16 | SSO ile giriş → uygulamayı kapat/aç | ✅ Oturum korunur (Keychain) |
| S-17 🔒 | Apple nonce doğrulaması | ✅ Manipüle edilmiş token reddedilir — "Apple girişi tamamlanamadı" |

## 2.5 Regresyon (her sürümde koşulacak)

| # | Kontrol |
| --- | --- |
| G-01 | Splash → geçerli oturum varsa ≤1,5 sn'de ana ekran |
| G-02 | Splash → oturum yoksa giriş ekranı |
| G-03 | Doğrulanmamış oturumla açılış → doğrulama ekranı (içeri alınmaz) |
| G-04 | Tüm hata mesajları Türkçe ve ekrana sığıyor (uzun metinlerde kırpılma yok) |
| G-05 | `Cmd + U` → unit testler yeşil |
| G-06 | Dinamik yazı boyutu (Ayarlar → Erişilebilirlik → daha büyük metin) ile ekranlar bozulmuyor |

---

## Otomasyon önerisi (Sprint 6)

| Katman | Araç | Kapsam |
| --- | --- | --- |
| Birim | XCTest (`HalkaTests`) | Mesaj eşleme (`authMessage`), doğrulama kuralları, `signInMessage` dallanmaları |
| Entegrasyon | XCTest + test Supabase projesi | signUp/signIn/recover uçtan uca, `account_status` yanıtları |
| UI | XCUITest | R-01, L-01…L-05, F-01/F-02, S-05/S-08 (kritik yol) |
| CI | GitHub Actions | Her PR'da birim + entegrasyon; UI testleri gecelik |

Bu tablodaki senaryolar, kabul kriterleri olarak ilgili GitHub issue'larına
(US-011, US-012, US-013, US-015, US-018) eklenebilir.
