import SwiftUI

/// US-016 — KVKK & Gizlilik.
///
/// Bu ekran bir vitrin değil, verilmiş bir söz: KVKK aydınlatma metni
/// "rızanı dilediğin an Profil > KVKK & Gizlilik bölümünden geri çekebilirsin"
/// diyor. Kanun da (m.6) rızanın vermek kadar kolay geri alınabilmesini
/// gerektiriyor — bu yüzden geri çekme burada gerçek bir işlem.
struct PrivacyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var document: LegalSheet.Document? = nil
    @State private var confirmWithdraw = false

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        consentCard
                        documentsCard
                        rightsCard
                        withdrawCard
                        if let error = model.profileError { errorBanner(error) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(item: $document) { LegalSheet(document: $0) }
        .alert("Açık rızanı geri çekmek istiyor musun?", isPresented: $confirmWithdraw) {
            Button("Vazgeç", role: .cancel) {}
            Button("Rızamı geri çek", role: .destructive) {
                Task { await model.withdrawHealthConsent() }
            }
        } message: {
            Text("Sağlık verilerin bu rızaya dayanarak işleniyor. Geri çekersen "
                 + "sağlık takibi durur ve oturumun kapanır. Verilerin silinmez — "
                 + "silmek istersen Profil ekranındaki “Hesabımı Sil” adımını kullan.")
        }
    }

    private var header: some View {
        HStack {
            Button("Geri") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.coral)
            Spacer()
            Text("KVKK & Gizlilik")
                .font(.h(16))
                .foregroundStyle(Color.ink)
            Spacer()
            Text("Geri").font(.h(13)).opacity(0)   // başlık ortada kalsın
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: Rıza durumu

    private var consentCard: some View {
        card("Rıza durumun") {
            consentRow("Aydınlatma metni onayı", date: model.profile.kvkkAcceptedAt)
            divider
            consentRow("Sağlık verisi açık rızası", date: model.profile.healthConsentAt)

            Text("Sağlık verileri KVKK m.6 kapsamında özel nitelikli veridir ve "
                 + "yalnızca açık rızanla işlenir.")
                .font(.h(11, .semibold))
                .foregroundStyle(Color.faint)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }

    private func consentRow(_ title: String, date: Date?) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.h(12.5, .bold))
                .foregroundStyle(Color.inkBody)
            Spacer()
            if let date {
                StatusChip(text: Self.dayText(date), bg: .greenBg, fg: .greenDark)
            } else {
                StatusChip(text: "Yok", bg: .bgChip, fg: .sub)
            }
        }
        .padding(.vertical, 13)
    }

    // MARK: Belgeler

    private var documentsCard: some View {
        card("Belgeler") {
            documentRow("KVKK Aydınlatma Metni", .kvkk)
            divider
            documentRow("Gizlilik Politikası", .privacy)
            divider
            documentRow("Kullanım Koşulları", .terms)
        }
    }

    private func documentRow(_ title: String, _ doc: LegalSheet.Document) -> some View {
        Button { document = doc } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.h(12.5, .bold))
                    .foregroundStyle(Color.inkBody)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.chevron)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Haklar

    private var rightsCard: some View {
        card("KVKK m.11 haklarınız") {
            Text("Verilerinin işlenip işlenmediğini öğrenme, bilgi ve düzeltme "
                 + "talep etme, silinmesini isteme, aktarıldığı üçüncü kişileri "
                 + "bilme ve işlemeye itiraz etme haklarına sahipsin.")
                .font(.h(12, .semibold))
                .foregroundStyle(Color.inkBody)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)

            divider
                .padding(.top, 12)

            // Taleplerin ulaşacağı gerçek bir adres — metinde söz verilen
            // "destek kanalı" bu.
            Link(destination: URL(string: "mailto:\(LegalText.supportEmail)"
                                  + "?subject=KVKK%20talebi")!) {
                HStack(spacing: 10) {
                    Text("Talep gönder")
                        .font(.h(12.5, .bold))
                        .foregroundStyle(Color.coral)
                    Spacer()
                    Text(LegalText.supportEmail)
                        .font(.h(11.5, .semibold))
                        .foregroundStyle(Color.sub)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.chevron)
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Rıza geri çekme

    private var withdrawCard: some View {
        card("Açık rıza") {
            if model.profile.hasHealthConsent {
                Text("Rızanı dilediğin an geri çekebilirsin. Geri çekme, o ana "
                     + "kadarki işlemelerin hukuka uygunluğunu etkilemez.")
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.inkBody)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                Button { confirmWithdraw = true } label: {
                    HStack(spacing: 8) {
                        if model.profileBusy { ProgressView().scaleEffect(0.7) }
                        Text(model.profileBusy ? "İşleniyor…" : "Açık rızamı geri çek")
                            .font(.h(12.5))
                            .foregroundStyle(Color.coralDark)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.coralBg)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.profileBusy)
                .padding(.vertical, 12)
            } else {
                Text("Sağlık verisi açık rızan bulunmuyor. Sağlık takibi "
                     + "özelliklerini kullanmak için rıza vermen gerekir.")
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.coralNote)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.coralBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.vertical, 12)
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.h(12, .semibold))
            .foregroundStyle(Color.warnDeep)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warnFieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Yapı taşları

    private func card<Content: View>(_ title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.h(11, .bold))
                .foregroundStyle(Color.sub)
                .kerning(0.3)
                .padding(.top, 14)
            content()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(height: 1)
    }

    private static func dayText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: date)
    }
}
