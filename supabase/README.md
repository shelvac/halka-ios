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

## 5. iOS tarafı (sonraki adım — ben yapacağım)

- Xcode'da SPM paketi: `https://github.com/supabase/supabase-swift`
- `Halka/Services/DataStore.swift` içindeki `DataStore` protokolünün
  `SupabaseDataStore` implementasyonu yazılacak; URL + anon key
  `Config.xcconfig`'ten okunacak (anahtar repoya girmez).
- AI çağrıları (ADR-003) Claude API'ye **doğrudan istemciden gitmez**:
  `halka-backend` reposundaki Supabase Edge Function proxy'si üzerinden.

Sen 1–3. adımları yapıp bana "Supabase hazır, URL şu" dediğinde
Swift entegrasyonuna başlarım (anon anahtarı sohbete yazmana gerek yok;
`Config.xcconfig` dosyasına lokalde kendin yapıştıracaksın).
