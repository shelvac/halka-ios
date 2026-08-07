# E-posta Şablonları — Test Rehberi

Bu belge iki bölüm: **Bölüm 1** senin elle yapacağın adım adım testler,
**Bölüm 2** neyin otomatikleştirilebildiği (ve neyin neden otomatikleşemediği).

Güncel altyapı: **Gmail SMTP** (`halkahealthapp@gmail.com` üzerinden),
saatlik limit 100, şablonlar `supabase/emails/*.html` dosyalarından yüklenir.

---

## Bölüm 1 — Elle test adımları

### Hazırlık

1. Xcode'da **Source Control → Pull** (son commit'ler gelsin), uygulamayı
   telefonuna yeniden yükle.
2. Test için **iki adres** hazırla:
   - `simgehelvaci@gmail.com` (ana hesabın)
   - Kullanılmamış ikinci bir adres (ör. `halkahealthapp@gmail.com` ya da
     Gmail'in `simgehelvaci+test1@gmail.com` numaralandırması — Gmail bunu
     aynı kutuya düşürür ama Supabase ayrı hesap sayar)
3. Her mail için **üç şeye** bak: konu satırı, gönderen adı, içerik/tasarım.
   Gelen kutusunda yoksa **Spam** ve **Tanıtımlar** sekmelerine bak.

### T1 · Kayıt doğrulama maili

| Adım | Beklenen |
|---|---|
| 1. Uygulamada yeni bir adresle **Kayıt Ol** | "E-posta doğrula" ekranına gider |
| 2. Gelen kutusunu aç | Gönderen: **halka** · Konu: **halka — e-posta adresini doğrula** |
| 3. Mail tasarımı | Halka logosu (3 halka), krem arka plan, mercan renkli "E-postamı doğrula" düğmesi |
| 4. Düğmeye **telefondan** dokun | Uygulama açılır, oturum kurulur, ana ekrana girer |
| 5. "Tekrar gönder" düğmesi | İkinci mail gelir (aynı tasarım) |

### T2 · Şifre sıfırlama maili

| Adım | Beklenen |
|---|---|
| 1. Giriş ekranı → **Şifremi unuttum** → kayıtlı adresini gir | "Bu adres sistemimizde kayıtlıysa… gönderildi" (kasıtlı olarak genel mesaj) |
| 2. Gelen kutusu | Konu: **halka — şifreni sıfırla** · sarı bilgi kutusu "Bağlantıyı telefonundan aç" |
| 3. Düğmeye dokun | Uygulama açılır, **yeni şifre** ekranı gelir |
| 4. **Eski şifreni** gir | ⚠️ "Yeni şifre eskisinden farklı olmalı — başka bir şifre seç." |
| 5. Farklı bir şifre gir | Şifre güncellenir, uygulamaya girer |
| 6. **Kayıtsız** bir adresle tekrar dene | Aynı genel mesaj görünür, **mail gelmez** (hesap sızdırmama) |

### T3 · Şifre değişikliği bildirimi *(yeni)*

| Adım | Beklenen |
|---|---|
| 1. T2'yi tamamla (şifreyi gerçekten değiştir) | — |
| 2. Gelen kutusu | Konu: **halka — şifren değiştirildi** |
| 3. İçerik | Yeşil "HESAP GÜVENLİĞİ" etiketi + kırmızı uyarı kutusu ("Bunu sen yapmadıysan…") |

### T4 · Giriş yöntemi eklendi bildirimi *(yeni)*

| Adım | Beklenen |
|---|---|
| 1. E-posta+şifreyle açtığın bir hesaba gir | — |
| 2. Aynı e-postaya sahip **Google** (veya Apple) hesabıyla giriş yap | Hesaplar birleşir |
| 3. Gelen kutusu | Konu: **halka — hesabına yeni giriş yöntemi eklendi** |

> Not: Bu bildirim yalnızca yeni bir giriş yöntemi **ilk kez** bağlandığında
> gider; aynı yöntemle tekrar girişte gitmez.

### T5 · E-posta değişikliği *(iki mail birden)*

Uygulamada e-posta değiştirme ekranı henüz yok (US-016 kapsamında gelecek).
Şimdilik Supabase Dashboard → Authentication → Users üzerinden bir kullanıcının
adresini değiştirerek test edilebilir. Beklenen:
- Yeni adrese: **halka — yeni e-posta adresini onayla** (onay bağlantılı)
- Eski adrese: **halka — e-posta adresin değişti** (güvenlik bildirimi)

### T6 · Hesap silme + veda maili *(yeni)*

| Adım | Beklenen |
|---|---|
| 1. Test hesabıyla gir → **Profil** → alt kısım | "Çıkış Yap"ın altında **Hesabımı Sil** |
| 2. Dokun | Onay penceresi: "Hesabını silmek istediğine emin misin?" |
| 3. **Vazgeç** | Hiçbir şey olmaz (hesap durur) |
| 4. Tekrar → **Hesabımı sil** | Giriş ekranına döner |
| 5. Aynı bilgilerle giriş dene | "Bu e-posta adresiyle kayıtlı bir hesap bulunamadı." |
| 6. Gelen kutusu | Konu: **halka — hesabın silindi** · mor "HESAP SİLİNDİ" etiketi, "Görüşmek üzere 👋" |
| 7. Aynı adresle yeniden kayıt ol | Kayıt başarılı (adres serbest kalmış olmalı) |

⚠️ **Bu testi ana hesabınla yapma** — geri dönüşü yok. İkinci adresle yap.

### Sonuçları paylaşırken

Her test için şu formatta yazman yeterli, gerisini ben hallederim:

```
T1: ✅
T2: ❌ adım 4'te uyarı çıkmadı, şifre değişti
T3: ✅ ama mail spam'e düştü
```

Ekran görüntüsü eklersen tasarım sorunlarını da düzeltebilirim.

---

## Bölüm 2 — Otomatik test: ne mümkün, ne değil

### Neyi unit test **edemeyiz**

Unit testler uygulamanın içinde, ağ olmadan çalışır. Bir mailin gerçekten
gönderilip gönderilmediği; Gmail'in onu gelen kutusuna mı spam'e mi koyduğu;
tasarımın Gmail'de nasıl göründüğü — bunların hiçbiri unit testin göreceği
şeyler değil. Bu yüzden "mail geldi mi" sorusunun cevabı her zaman kısmen
manuel kalır.

### Neyi otomatikleştirdim / edebiliriz

| Katman | Ne kontrol eder | Durum |
|---|---|---|
| **Şablon doğrulama** (`email-template-check.yml`) | Her şablonda doğru Supabase değişkeni (`{{ .ConfirmationURL }}`) var mı, HTML bozuk mu, marka öğeleri (logo, renk, alt bilgi) yerinde mi | ✅ kuruldu |
| **Tetikleme testi** (`email-fire-all.yml`) | Her mail türünü sırayla tetikler, Supabase auth loglarında SMTP hatası var mı bakar | ✅ kuruldu |
| **Unit test** (`AppModelTests`) | Hata mesajı eşlemeleri: hangi sunucu hatası hangi Türkçe metne dönüşüyor | ✅ mevcut |
| **Gerçek teslimat** | Mailin gelen kutusuna düşmesi, tasarımın görünümü | ❌ elle (Bölüm 1) |

### Neden "tetikleme testi" işe yarıyor

Mailin gönderilme yolu üç aşamalı: **uygulama → Supabase → Gmail SMTP → alıcı.**
İlk iki aşamayı otomatik doğrulayabiliyoruz (HTTP yanıtı + auth logları); üçüncü
aşamada hata olursa auth loglarında SMTP hatası olarak görünüyor. Yani otomatik
test "mail çıktı mı" sorusunu güvenle cevaplıyor; "gelen kutusuna mı düştü"
sorusu insana kalıyor.

### İleride eklenebilecek tam otomasyon

Kendi alan adımız olduğunda Resend'e döneceğiz; Resend'in API'si her mailin
teslim durumunu (`delivered`, `bounced`, `complained`) sorgulanabilir kılıyor.
O zaman testi uçtan uca otomatikleştirebiliriz: mail gönder → 30 sn bekle →
API'den durumu sor → `delivered` değilse testi düşür.
