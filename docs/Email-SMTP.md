# E-posta Altyapısı — Resend (US-020)

## Neden gerekli

Supabase'in **varsayılan** e-posta sağlayıcısı ücretsiz planda:

- **Saatte yalnızca birkaç e-posta** gönderir → doğrulama/sıfırlama mailleri "gelmiyor"
  (test sırasında yaşadığımız sorun tam olarak buydu)
- **Şablon değiştirmeye izin vermez** → e-postalar İngilizce ve markasız kalır

Custom SMTP (Resend) ikisini birden çözer: ayda 3.000 e-posta ücretsiz ve şablonlar
tamamen bizim kontrolümüzde.

---

## Kurulum (senin adımın, ~3 dk)

1. **https://resend.com** → **Sign up** (GitHub ile giriş yapabilirsin)
2. Sol menüden **API Keys** → **Create API Key**
   - Name: `halka`
   - Permission: **Sending access**
   - **Create** → çıkan `re_...` anahtarını kopyala
3. Anahtarı bana ilet — GitHub'da **şifreli secret** olarak saklayıp kurulumu
   otomatik çalıştıracağım. (Ya da kendin: repo → Settings → Secrets and variables
   → Actions → New repository secret → isim `RESEND_API_KEY`.)

### Gönderen adres

- **Şimdilik:** `onboarding@resend.dev` — kurulum gerektirmez, ama
  **yalnızca Resend hesabının e-posta adresine** gönderim yapar. Kendi testlerin
  için yeterli.
- **Beta/lansman öncesi:** Resend → **Domains** → alan adını ekle (ör. `halka.app`)
  → DNS kayıtlarını (SPF/DKIM) gir → doğrulandıktan sonra
  `merhaba@halka.app` gibi bir adresten herkese gönderim yapılabilir.

---

## Kurulum sonrası otomatik uygulananlar

`.github/workflows/supabase-smtp.yml` çalıştığında:

- Supabase Auth → SMTP ayarları Resend'e bağlanır (`smtp.resend.com:465`)
- **Türkçe, halka marka kimliğinde HTML şablonlar** yüklenir:
  - Doğrulama: "halka — e-posta adresini doğrula"
  - Sıfırlama: "halka — şifreni sıfırla"
  - Mercan (#E45C49) CTA düğmesi, kum rengi arka plan, "Her gün %1 daha iyi" başlığı

---

## Önemli: bağlantıları **telefonda** aç

Doğrulama ve şifre sıfırlama bağlantıları `halka://` şemasıyla uygulamaya döner ve
güvenlik (PKCE) gereği **bağlantıyı başlatan cihazda** açılmalıdır.

- ✅ iPhone'da Mail/Gmail uygulamasından bağlantıya dokun → halka açılır
- ❌ Masaüstü tarayıcıda açarsan `halka://` şemasını tanımaz → "site açılamıyor"

Test ederken e-postayı telefonundan aç.
