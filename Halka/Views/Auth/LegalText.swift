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
}

/// Kayıt ekranından açılan okunabilir yasal metin sayfası.
struct LegalSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Sağlık verilerin özel nitelikli kişisel veridir. Aşağıdaki metin, bu verilerin nasıl işlendiğini açıklar.")
                        .font(.h(13, .semibold))
                        .foregroundStyle(Color.coralNote)
                        .lineSpacing(4)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.coralBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    ForEach(LegalText.kvkkSections, id: \.0) { section in
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
            .navigationTitle(LegalText.kvkkTitle)
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
