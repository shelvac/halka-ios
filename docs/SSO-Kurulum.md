# SSO Kurulumu (US-018) — Google & Apple ile Giriş

Kod tarafı hazır: giriş ekranındaki **Apple ile devam et** ve **Google ile devam et**
düğmeleri Supabase OAuth akışını başlatıyor, dönüşte `halka://login-callback`
ile uygulamaya geri geliniyor. Düğmeler, sağlayıcı Supabase'de etkinleştirilene
kadar "henüz etkin değil" uyarısı verir.

> **App Store kuralı:** Google gibi üçüncü taraf girişi sunuyorsan **Sign in with
> Apple eklemek zorunludur** (Guideline 4.8). İkisi birlikte açılmalı.

---

## 1. Google ile Giriş

### a) Google Cloud'da OAuth istemcisi (senin adımın, ~10 dk)

1. https://console.cloud.google.com → yeni proje: `halka`
2. **APIs & Services → OAuth consent screen** → External → uygulama adı `halka`,
   destek e-postası, geliştirici e-postası → Save
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type: **Web application** (Supabase üzerinden aktığı için web tipi)
   - Authorized redirect URI:
     ```
     https://urrjkubdngoszkttpeph.supabase.co/auth/v1/callback
     ```
   - Oluştur → **Client ID** ve **Client Secret**'ı kopyala

### b) Supabase'e gir

Dashboard → **Authentication → Sign In / Providers → Google** → Enable →
Client ID + Client Secret yapıştır → **Save**.

Bu kadar; uygulamadaki Google düğmesi anında çalışmaya başlar.

### c) (Sonraki iterasyon) Native Google Sign-In SDK

Yol haritası §4'teki "Supabase URL'i görünmesin" notu için: `GoogleSignIn-iOS`
SDK'sı ile native akışa geçilip `signInWithIdToken` kullanılır. Bunun için
ayrıca **iOS tipi** bir OAuth client ID gerekir. Şimdilik web akışı çalışıyor;
bu iyileştirme ayrı bir story (US-019) olarak backlog'da.

---

## 2. Apple ile Giriş

⚠️ **Apple Developer hesabı gerekir** (yol haritası v2: bireysel hesap, 99 USD/yıl —
D-U-N-S beklemeye gerek yok).

1. https://developer.apple.com/account → **Certificates, IDs & Profiles**
2. **Identifiers → +** → **Services IDs** → tanımlayıcı: `com.simgehelvaci.halka.signin`
   - Sign in with Apple'ı işaretle → Configure:
     - Primary App ID: `com.simgehelvaci.halka`
     - Return URL: `https://urrjkubdngoszkttpeph.supabase.co/auth/v1/callback`
3. **Keys → +** → Sign in with Apple → key oluştur → `.p8` dosyasını indir
   (bir kez indirilir!), **Key ID** ve **Team ID**'yi not al
4. Supabase Dashboard → **Authentication → Providers → Apple** → Enable →
   Services ID, Team ID, Key ID ve `.p8` içeriğini yapıştır → Save

Ayrıca Xcode'da: hedef → **Signing & Capabilities → + Capability →
Sign in with Apple** (hesap bağlandıktan sonra).

---

## Test

1. Uygulamayı **gerçek cihazda** çalıştır (simülatörde de çalışır ama Apple girişi cihazda daha sağlıklı)
2. Giriş ekranı → sağlayıcı düğmesi → tarayıcı sayfası açılır → izin ver
3. Uygulama otomatik geri açılır ve ana ekran gelir
4. Supabase Dashboard → **Authentication → Users** listesinde yeni kullanıcıyı,
   **Table Editor → users** tablosunda profil satırını gör
