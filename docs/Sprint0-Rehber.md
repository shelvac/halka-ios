# Sprint 0 — Kuruluş Rehberi (2 hafta, kod yok)

Yol haritasının Sprint 0 bölümünün uygulanabilir kontrol listesi. Sıra önemli:
en uzun süren işler (D-U-N-S, şirket) ilk gün başlar, gerisi paralel yürür.

## Gün 1 — hemen başlat (bekleme süreli işler)

- [ ] **D-U-N-S numarası başvurusu** (ücretsiz, 1–2 hafta sürer — bu yüzden ilk iş):
  https://developer.apple.com/enroll/duns-lookup/ adresinden önce sorgula;
  kayıt yoksa aynı sayfadan başvur. Şirket adı + adres + iletişim yeterli.
  *Not: Şirket kuruluşu tamamlanmadan başvurursan şahıs adına açılır; şirket
  kurulunca güncellenebilir. D-U-N-S gecikirse TestFlight şahıs hesabıyla
  başlayabilir, sonra organizasyona devredilir (yol haritası, kritik risk 3).*
- [ ] **Mali müşavir seç ve şahıs şirketi kuruluşunu başlat** (~1 hafta):
  - NACE kodu: yazılım geliştirme (62.01)
  - 29 yaş altıysan **genç girişimci vergi istisnasını** sor (kazanç istisnası + Bağ-Kur desteği)
  - İleride yatırım/ortaklık gündeme gelince Limited'e dönüş planlanır

## Hafta 1

- [ ] **Banka:** şirket adına TL + USD hesabı. Bu IBAN'lar:
  - App Store Connect ödeme bilgilerine girilecek (Apple ödemeleri ~aylık, satıştan 33–45 gün sonra)
  - iyzico pazaryeri hakedişleri için kullanılacak
- [ ] **Apple Developer Program — Organizasyon** (99 USD/yıl): D-U-N-S gelince
  https://developer.apple.com/programs/enroll/ — organizasyon hesabı seç
  (şahıs hesabında satıcı adı kişisel isim görünür; marka için organizasyon).
- [ ] **Small Business Program** kaydı: https://developer.apple.com/app-store/small-business-program/
  → IAP komisyonu %30 yerine **%15**. Developer hesabı onaylanır onaylanmaz başvur.
- [ ] **Supabase projesi:** https://supabase.com → New project →
  bölge **EU Central (Frankfurt)** (ADR-002: KVKK yurt dışı aktarımı için AB bölgesi).
  Dev + prod olarak iki proje aç. Şema hazır: `supabase/migrations/0001_init.sql`
  (uygulama adımları `supabase/README.md`'de).

## Hafta 2

- [ ] **Araç ekosistemi:**
  - GitHub: `halka-ios` ✅ (var). `halka-backend` reposunu Edge Function'lar için aç.
  - Branch stratejisi: `main` (prod) / `develop` / `feature/PROJ-XXX` — CI kuruldu ✅
  - Jira Scrum projesi (2 haftalık sprint) + Confluence "Halka Hub" (ADR'ler buraya)
- [ ] **Legal taslaklar** (avukat/mali müşavir kontrolü şart — sağlık verisi *özel nitelikli*):
  - KVKK Aydınlatma Metni + **Açık Rıza** (sağlık verisi için ayrı onay kutusu)
  - Kullanım Koşulları, Diyetisyen Hizmet Sözleşmesi, Mesafeli Satış Sözleşmesi
  - **VERBİS** kayıt yükümlülüğü teyidi
  - AI koç çıktılarına "tıbbi tavsiye değildir" ibaresi (uygulamada var, metne de girecek)
- [ ] **iyzico başvurusu** (Sprint 9'da lazım ama onay süreci uzun olabilir):
  Pazaryeri / alt üye işyeri modeli için satış destek ile görüş.

## Çıktı (Definition of Done)

- D-U-N-S başvurusu yapıldı, şirket + banka hesabı açıldı
- Apple Developer + Small Business Program aktif
- Supabase dev/prod projeleri açık, şema uygulandı
- Jira'da Epic listesi (E1–E11), imzalı MVP Brief
- Legal taslaklar avukat kontrolünde

## Maliyet özeti (Sprint 0)

| Kalem | Tutar |
| --- | --- |
| Apple Developer Program | 99 USD/yıl |
| D-U-N-S | Ücretsiz |
| Supabase | Ücretsiz tier ile başla (prod'da ~25 USD/ay Pro önerilir) |
| Şirket kuruluşu + mali müşavir | ~aylık müşavir ücreti (piyasa) |
| GitHub / Jira / Confluence | Küçük ekip tier'ları ücretsiz/düşük |
