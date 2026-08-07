import SwiftUI

/// KVKK aydınlatma metni — **taslak** (Sprint 0'da avukat kontrolünden geçecek,
/// yayına çıkmadan önce web'de barındırılan sürümle değiştirilecek).
enum LegalText {
    static let kvkkTitle = "KVKK Aydınlatma Metni"

    static let kvkkSections: [(String, String)] = [
        ("Veri Sorumlusu",
         "halka uygulaması (\"Uygulama\"), 6698 sayılı Kişisel Verilerin Korunması Kanunu (\"KVKK\") kapsamında veri sorumlusu sıfatıyla hareket eder. Bu metin, sağlık verilerinin işlenmesine ilişkin aydınlatma yükümlülüğünü yerine getirmek üzere hazırlanmıştır."),

        ("İşlenen Kişisel Veriler",
         "Kimlik ve iletişim verileri (ad soyad, e-posta), sağlık verileri (kilo, vücut kompozisyonu, kan tahlili sonuçları, uyku ve egzersiz kayıtları, öğün ve kalori kayıtları, takviye kullanımı), cihaz ve kullanım verileri (uygulama içi etkileşimler, çökme kayıtları)."),

        ("İşleme Amaçları",
         "Hesabın oluşturulması ve güvenliğinin sağlanması; halka takibi, beslenme ve egzersiz planlarının üretilmesi; AI koç önerilerinin oluşturulması; talep etmen hâlinde seçtiğin diyetisyenle verilerinin paylaşılması; uygulamanın iyileştirilmesi ve hata giderme."),

        ("Hukuki Sebep — Açık Rıza",
         "Sağlık verileri KVKK m.6 uyarınca özel nitelikli kişisel veridir ve yalnızca AÇIK RIZANLA işlenir. Rızanı vermemen hâlinde sağlık takibi özellikleri çalışmaz; rızanı dilediğin an Profil > KVKK & Gizlilik bölümünden geri çekebilirsin. Geri çekme, o ana kadarki işlemelerin hukuka uygunluğunu etkilemez."),

        ("Aktarım ve Saklama",
         "Veriler, altyapı sağlayıcımız Supabase'in Avrupa Birliği (Frankfurt) bölgesindeki sunucularında saklanır. Yurt dışına aktarım, açık rızan ve standart sözleşme hükümlerine dayanır. Verilerine yalnızca sen ve — paket satın aldıysan — seçtiğin diyetisyen erişebilir; erişim, veritabanı düzeyinde satır bazlı güvenlik politikalarıyla teknik olarak kısıtlanmıştır."),

        ("Saklama Süresi",
         "Veriler hesabın aktif olduğu sürece saklanır. Hesabını sildiğinde sağlık verilerin en geç 30 gün içinde kalıcı olarak silinir; mevzuat gereği saklanması zorunlu kayıtlar yasal süre boyunca muhafaza edilir."),

        ("Haklarınız (KVKK m.11)",
         "Kişisel verilerinin işlenip işlenmediğini öğrenme, bilgi talep etme, işlenme amacını öğrenme, düzeltilmesini veya silinmesini isteme, aktarıldığı üçüncü kişileri bilme, işlemeye itiraz etme ve zararının giderilmesini talep etme haklarına sahipsin. Taleplerini uygulama içindeki destek kanalından iletebilirsin."),

        ("Tıbbi Sorumluluk Reddi",
         "Uygulama tanı veya tedavi hizmeti sunmaz. AI koç çıktıları ve içerikler tıbbi tavsiye değildir. Diyetisyenler, verdikleri hizmetten kendi mesleki sorumlulukları çerçevesinde sorumludur. Sağlık durumunla ilgili kararlar için hekimine danış.")
    ]

    /// Gizlilik Politikası — halka-web'deki yayın sürümüyle aynı metin.
    static let privacySections: [(String, String)] = [
        ("1. Veri sorumlusu",
         "halka uygulaması (“Uygulama”), 6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) kapsamında veri sorumlusu sıfatıyla hareket eder. Sorularınız için: simgehelvaci@gmail.com."),
        ("2. İşlenen kişisel veriler",
         "• Kimlik ve iletişim: ad soyad, e-posta adresi, doğum tarihi.\n• Sağlık verileri (özel nitelikli): kilo ve vücut kompozisyonu ölçümleri, kan tahlili sonuçları, uyku ve egzersiz kayıtları, öğün ve kalori kayıtları, takviye/ilaç kullanım bilgileri.\n• Görsel veriler: yüklediğiniz öğün fotoğrafları ve tahlil belgeleri.\n• Cihaz ve kullanım verileri: uygulama içi etkileşimler, hata ve çökme kayıtları."),
        ("3. Verilerin işlenme amaçları",
         "• Hesabınızın oluşturulması, girişin ve hesap güvenliğinin sağlanması\n• Halka takibi ile beslenme ve egzersiz planlarının üretilmesi\n• Yapay zekâ destekli koç önerilerinin ve kalori tahminlerinin oluşturulması\n• Talebiniz hâlinde seçtiğiniz diyetisyenle verilerinizin paylaşılması\n• Uygulamanın iyileştirilmesi, hataların giderilmesi"),
        ("4. Hukuki sebep — açık rıza",
         "Sağlık verileri KVKK m.6 uyarınca özel nitelikli kişisel veridir ve yalnızca açık rızanızla işlenir. Rıza vermemeniz hâlinde sağlık takibi özellikleri çalışmaz. Rızanızı dilediğiniz an uygulama içinden veya yukarıdaki e-posta adresinden geri çekebilirsiniz; geri çekme, o ana kadarki işlemelerin hukuka uygunluğunu etkilemez."),
        ("5. Apple Health verileri",
         "İzin vermeniz hâlinde adım, egzersiz süresi, aktif enerji ve uyku verileri Apple Health üzerinden okunur. Bu veriler yalnızca halkalarınızı hesaplamak için kullanılır; reklam veya pazarlama amacıyla kullanılmaz, üçüncü taraflara satılmaz. İzni iOS Ayarlar &gt; Gizlilik & Güvenlik &gt; Sağlık bölümünden istediğiniz an kaldırabilirsiniz."),
        ("6. Aktarım ve saklama",
         "Veriler, altyapı sağlayıcımız Supabase'in Avrupa Birliği (Frankfurt) bölgesindeki sunucularında saklanır. Yurt dışına aktarım açık rızanıza ve standart sözleşme hükümlerine dayanır. Verilerinize yalnızca siz ve — paket satın aldıysanız — seçtiğiniz diyetisyen erişebilir; erişim, veritabanı düzeyinde satır bazlı güvenlik politikalarıyla teknik olarak kısıtlanmıştır. Şifreler tarafımızca görülemez; oturum bilgileri cihazınızda Keychain'de saklanır."),
        ("7. Yapay zekâ işlemleri",
         "Öğün fotoğrafı analizi ve koç önerileri için verileriniz, işlem süresince üçüncü taraf bir yapay zekâ sağlayıcısına iletilir. Bu veriler sağlayıcı tarafından model eğitimi için kullanılmaz."),
        ("8. Saklama süresi",
         "Veriler hesabınız aktif olduğu sürece saklanır. Hesabınızı sildiğinizde sağlık verileriniz en geç 30 gün içinde kalıcı olarak silinir; mevzuat gereği saklanması zorunlu kayıtlar yasal süre boyunca muhafaza edilir."),
        ("9. Haklarınız (KVKK m.11)",
         "Kişisel verilerinizin işlenip işlenmediğini öğrenme, bilgi talep etme, işlenme amacını öğrenme, düzeltilmesini veya silinmesini isteme, aktarıldığı üçüncü kişileri bilme, işlemeye itiraz etme ve zararınızın giderilmesini talep etme haklarına sahipsiniz. Taleplerinizi simgehelvaci@gmail.com adresine iletebilirsiniz; en geç 30 gün içinde yanıtlanır."),
        ("10. Çocukların gizliliği",
         "Uygulama 18 yaşından küçükler için tasarlanmamıştır ve bilerek çocuklardan kişisel veri toplamaz."),
        ("11. Değişiklikler",
         "Bu politika güncellenebilir; önemli değişikliklerde uygulama içinde bilgilendirme yapılır ve yukarıdaki güncelleme tarihi değiştirilir.")
    ]

    /// Kullanım Koşulları — halka-web'deki yayın sürümüyle aynı metin.
    static let termsSections: [(String, String)] = [
        ("1. Taraflar ve kapsam",
         "Bu koşullar, halka uygulamasını kullanan kişiler (“Kullanıcı”) ile uygulama sahibi arasındaki ilişkiyi düzenler. Uygulamayı indirerek veya kullanarak bu koşulları kabul etmiş olursunuz."),
        ("2. Hizmetin tanımı",
         "halka; beslenme, egzersiz, uyku, su ve sağlık ölçümlerinin takibine yardımcı olan bir dijital araçtır. Uygulama ayrıca diyetisyenlerle kullanıcıları buluşturan bir pazaryeri sunar."),
        ("3. Tıbbi sorumluluk reddi",
         ""),
        ("4. Hesap ve güvenlik",
         "• Verdiğiniz bilgilerin doğru ve güncel olmasından siz sorumlusunuz.\n• Şifrenizin gizliliğini korumak sizin sorumluluğunuzdadır.\n• Hesabınızı başkasıyla paylaşamaz, devredemezsiniz.\n• 18 yaşından küçükler uygulamayı kullanamaz."),
        ("5. Diyetisyen hizmetleri",
         "• Diyetisyenler bağımsız uzmanlardır; verdikleri hizmetten kendi mesleki sorumlulukları çerçevesinde sorumludur.\n• halka, uzmanla kullanıcıyı buluşturan aracı platformdur; danışmanlık içeriğinin doğruluğunu taahhüt etmez.\n• Paket satın aldığınızda, takibin gerektirdiği ölçüde sağlık verileriniz seçtiğiniz diyetisyenle paylaşılır."),
        ("6. Ücretler, abonelik ve iptal",
         "• Uygulamanın temel özellikleri ücretsizdir. Premium özellikler ve diyetisyen paketleri ücretlidir; fiyatlar satın alma ekranında gösterilir.\n• Abonelikler App Store üzerinden yönetilir ve iptal edilmedikçe otomatik yenilenir. İptal işlemi cihazınızın App Store hesap ayarlarından yapılır.\n• Diyetisyen paketlerinde, ilk seans gerçekleşmeden önce cayma hakkınız saklıdır (Mesafeli Sözleşmeler Yönetmeliği kapsamında 14 gün)."),
        ("7. Kullanıcı yükümlülükleri",
         "• Uygulamayı hukuka aykırı amaçlarla kullanamazsınız.\n• Başkasının verisini izinsiz yükleyemezsiniz.\n• Uygulamanın güvenliğini tehdit eden, tersine mühendislik içeren veya sistemi aşırı yükleyen davranışlarda bulunamazsınız."),
        ("8. Fikri mülkiyet",
         "Uygulamanın tasarımı, markası, yazılımı ve içerikleri halka'ya aittir. Kendi yüklediğiniz veriler ve fotoğraflar sizindir; bunları hizmeti sunmak amacıyla işlememize izin vermiş olursunuz."),
        ("9. Sorumluluğun sınırlandırılması",
         "Uygulama “olduğu gibi” sunulur. Kesintisiz veya hatasız çalışacağı taahhüt edilmez. Dolaylı zararlardan, veri kaybından veya üçüncü taraf hizmet kesintilerinden mevzuatın izin verdiği ölçüde sorumluluk kabul edilmez."),
        ("10. Hesabın sonlandırılması",
         "Hesabınızı dilediğiniz an silebilirsiniz. Bu koşulların ihlali hâlinde hesabınız askıya alınabilir veya kapatılabilir."),
        ("11. Uygulanacak hukuk",
         "Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır; uyuşmazlıklarda İstanbul mahkemeleri ve icra daireleri yetkilidir."),
        ("12. İletişim",
         "simgehelvaci@gmail.com")
    ]

    static let privacyTitle = "Gizlilik Politikası"
    static let termsTitle = "Kullanım Koşulları"
    static let lastUpdated = "Son güncelleme: 6 Ağustos 2026"
    static let supportEmail = "halkahealthapp@gmail.com"
}

/// Yasal metin sayfası — KVKK aydınlatma, gizlilik politikası ve kullanım
/// koşulları aynı düzeni paylaşır (US-016 · KVKK & Gizlilik ekranı).
struct LegalSheet: View {
    enum Document: String, Identifiable {
        case kvkk, privacy, terms
        var id: String { rawValue }

        var title: String {
            switch self {
            case .kvkk: return LegalText.kvkkTitle
            case .privacy: return LegalText.privacyTitle
            case .terms: return LegalText.termsTitle
            }
        }

        var sections: [(String, String)] {
            switch self {
            case .kvkk: return LegalText.kvkkSections
            case .privacy: return LegalText.privacySections
            case .terms: return LegalText.termsSections
            }
        }

        /// Üstteki vurgulu giriş — yalnızca KVKK metninde var.
        var intro: String? {
            switch self {
            case .kvkk:
                return "Sağlık verilerin özel nitelikli kişisel veridir. "
                     + "Aşağıdaki metin, bu verilerin nasıl işlendiğini açıklar."
            case .privacy, .terms:
                return nil
            }
        }
    }

    var document: Document = .kvkk
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let intro = document.intro {
                        Text(intro)
                            .font(.h(13, .semibold))
                            .foregroundStyle(Color.coralNote)
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.coralBg)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text(LegalText.lastUpdated)
                        .font(.h(11, .bold))
                        .foregroundStyle(Color.faint)

                    ForEach(document.sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.0)
                                .font(.h(14))
                                .foregroundStyle(Color.ink)
                            Text(section.1)
                                .font(.h(12.5, .semibold))
                                .foregroundStyle(Color.inkBody)
                                .lineSpacing(5)
                        }
                    }

                    Text("Bu metin taslak sürümdür; yayın öncesi hukuki incelemeden geçirilecektir.")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.faint)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.bgApp)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .font(.h(13))
                        .foregroundStyle(Color.coral)
                }
            }
        }
    }
}
