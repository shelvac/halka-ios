# Supabase Kurulumu (ADR-002)

## 1. Proje aç (5 dk, senin yapman gereken kısım)

1. https://supabase.com → **Start your project** → GitHub ile giriş.
2. **New project**: isim `halka-dev`, bölge **EU Central (Frankfurt)** (KVKK — AB bölgesi şart), güçlü bir DB şifresi (kaydet).
3. Proje açılınca **Project Settings → API**'den iki değeri not al:
   - `Project URL` (https://xxxx.supabase.co)
   - `anon public` anahtarı
4. Prod için aynısını `halka-prod` adıyla tekrarla (lansmana yakın).

## 2. Şemayı uygula

**Kolay yol (Dashboard):** SQL Editor → New query →
`migrations/0001_init.sql` içeriğini yapıştır → Run.

**CLI yolu:**
```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref <proje-ref>   # URL'deki xxxx kısmı
supabase db push
```

## 3. Storage bucket'ları

Dashboard → Storage → New bucket:

| Bucket | Görünürlük | İçerik |
| --- | --- | --- |
| `meal-photos` | Private | Öğün fotoğrafları (Vision AI girdisi) |
| `blood-pdfs` | Private | Kan tahlili PDF'leri |
| `avatars` | Public | Profil fotoğrafları |

## 4. Auth ayarları

- Dashboard → Authentication → Providers → **Apple**'ı aç
  (Apple Developer hesabı geldikten sonra Services ID + key eklenecek — Sprint 1).
- Email provider varsayılan açık; şimdilik yeterli.

## 5. iOS bağlantısı (✅ kod hazır — tek eksik anon key)

- supabase-swift SPM paketi projeye ekli; Xcode ilk açılışta paketi indirir.
- **Anon key'i yapıştır:** Dashboard → Project Settings → API → **anon public**
  değerini kopyala → `Halka/Services/SupabaseService.swift` içindeki
  `SupabaseConfig.anonKey = ""` satırına yapıştır → commit/push edebilirsin.
  - `anon` anahtarı istemciye açık bir anahtardır (uygulama paketine gömülür);
    güvenlik RLS politikalarındadır. **`service_role` anahtarını ise asla**
    hiçbir yere yapıştırma — o tam yetkilidir.
- Anahtar boşken uygulama **demo modunda** çalışır (giriş düğmeleri eski davranış).
- **Geliştirme kolaylığı (önerilir):** Dashboard → Authentication → Sign In / Up →
  Email → **"Confirm email" kapat** → kayıt sonrası doğrulama e-postası beklemeden
  otomatik giriş yapılır. (Lansmandan önce tekrar açılır.)
- AI çağrıları (ADR-003) Claude API'ye **doğrudan istemciden gitmez**:
  `halka-backend` reposundaki Supabase Edge Function proxy'si üzerinden (sonraki sprint).
