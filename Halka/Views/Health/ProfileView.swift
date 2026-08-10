import SwiftUI
import PhotosUI

/// Profile: identity card, Apple Health card with screenshot fallback, settings, logout.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmDelete = false
    @State private var editingProfile = false
    @State private var showPrivacy = false
    @State private var showDocuments = false
    @State private var showManualEntry = false

    /// Ayar satırları. "Birimler" kaldırıldı: metrik/imperial desteği her
    /// kg/cm/ml/kcal gösterimini dolaşan yatay bir iş ve Türkiye'deki kullanıcı
    /// için karşılığı yok — ölü satır olarak durmasındansa hiç olmasın.
    /// Bildirimler ve Hedeflerim henüz ekransız; sahte durum ("Açık",
    /// "Kilo: 65 kg") göstermek yerine "Yakında" deyip pasif bırakıldılar.
    private enum SettingRow: String, CaseIterable, Identifiable {
        case notifications, goals, documents, privacy
        var id: String { rawValue }

        var title: String {
            switch self {
            case .notifications: return "Bildirimler"
            case .goals: return "Hedeflerim"
            case .documents: return "Belgelerim"
            case .privacy: return "KVKK & Gizlilik"
            }
        }

        var detail: String {
            switch self {
            case .notifications: return "Yakında"
            case .goals: return "Yakında"
            case .documents: return ""
            case .privacy: return ""
            }
        }

        var isEnabled: Bool { self == .privacy || self == .documents }
    }

    var body: some View {
        VStack(spacing: 0) {
            BackRow(label: "Geri") { model.healthPane = .body }
                .padding(.top, 4)

            // Identity card — US-016: değerler profilden gelir, sabit değil.
            VStack(spacing: 0) {
                ProfileAvatar(image: model.avatarImage,
                              fullName: model.userFullName, size: 76)
                Text(model.userFullName)
                    .font(.h(20))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.4)
                    .padding(.top, 12)
                Text(model.profileSummary)
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 3)
                HStack(spacing: 20) {
                    statColumn("Kilo", Self.weightText(model.profile.weightKg), .ink)
                    statColumn("Hedef", Self.weightText(model.profile.targetWeightKg), .greenDark)
                    statColumn("BMI", Self.bmiText(model.profile.bmi), .ink)
                    statColumn("Kalori", Self.kcalText(model.profile.calorieGoal), .coral)
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
                .padding(.top, 16)

                Button { editingProfile = true } label: {
                    Text(model.profile.isComplete ? "Profili düzenle" : "Profilini tamamla")
                        .font(.h(12.5))
                        .foregroundStyle(Color.coralDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.coralBg)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .card(22)

            appleHealthCard
                .padding(.top, 12)

            // Settings
            VStack(spacing: 0) {
                ForEach(Array(SettingRow.allCases.enumerated()), id: \.element.id) { i, row in
                    Button {
                        if row == .privacy { showPrivacy = true }
                        if row == .documents { showDocuments = true }
                    } label: {
                        HStack(spacing: 10) {
                            Text(row.title)
                                .font(.h(13, .bold))
                                .foregroundStyle(row.isEnabled ? Color.inkBody : Color.disabledText)
                            Spacer()
                            if !row.detail.isEmpty {
                                Text(row.detail)
                                    .font(.h(11.5, .bold))
                                    .foregroundStyle(Color.faint)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Color.chevron)
                        }
                        .padding(.vertical, 14)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!row.isEnabled)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .card(20)
            .padding(.top, 12)

            Button { model.logout() } label: {
                Text("Çıkış Yap")
                    .font(.h(13))
                    .foregroundStyle(Color.coralDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.coralBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)

            deleteAccountButton
                .padding(.top, 8)
        }
        .sheet(isPresented: $editingProfile) {
            ProfileEditView()
                .environment(model)
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyView()
                .environment(model)
        }
        .sheet(isPresented: $showDocuments) {
            DocumentsView()
                .environment(model)
        }
        // Geri alınamaz bir işlem — onay penceresi zorunlu (US-021).
        .alert("Hesabını silmek istediğine emin misin?", isPresented: $confirmDelete) {
            Button("Vazgeç", role: .cancel) {}
            Button("Hesabımı sil", role: .destructive) {
                Task { await model.deleteAccount() }
            }
        } message: {
            Text("Ölçümlerin, öğünlerin, antrenmanların, tahlillerin ve mesajların "
                 + "kalıcı olarak silinir. Bu işlem geri alınamaz.")
        }
    }

    /// US-021 — Hesabı sil. Yıkıcı bir işlem olduğu için çıkıştan görsel olarak
    /// ayrıştırılmış: dolgusuz, yalnızca yazı.
    private var deleteAccountButton: some View {
        Button { confirmDelete = true } label: {
            HStack(spacing: 6) {
                if model.authBusy {
                    ProgressView().scaleEffect(0.7)
                }
                Text(model.authBusy ? "Siliniyor…" : "Hesabımı Sil")
                    .font(.h(12.5))
                    .foregroundStyle(Color.sub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(model.authBusy)
    }

    /// Profil eksikken sayı uydurmuyoruz — tire gösterip düzenlemeye yönlendiriyoruz.
    private static func weightText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f kg", value)
    }

    private static func bmiText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private static func kcalText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    private func statColumn(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.h(10, .bold)).foregroundStyle(Color.faint)
            Text(value).font(.h(15)).foregroundStyle(color)
        }
    }

    private var appleHealthCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(model.hkConnected ? Color.green : Color.faint)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.hkConnected ? "Apple Health bağlı" : "Apple Health bağlı değil")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Text(model.hkConnected
                         ? "Bugün \(model.hkSteps) adım · \(model.hkActiveEnergy) kcal aktif enerji"
                         : "Adım, egzersiz ve uyku halkalara otomatik işlensin")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                if model.hkConnected {
                    Text("Aktif")
                        .font(.h(11))
                        .foregroundStyle(Color.greenDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.greenBg))
                } else {
                    Button { model.connectHealthKit() } label: {
                        Text("Bağlan")
                            .font(.h(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.coral))
                    }
                    .buttonStyle(.plain)
                }
            }

            // "Bağlan"a basıldı ama iOS izin diyaloğunu bir daha göstermedi
            // (daha önce yanıtlanmış). Sessiz kalmak "çalışmıyor" hissi
            // veriyor — yol tarif edilir.
            if !model.hkConnected && model.healthConnectHint {
                VStack(alignment: .leading, spacing: 8) {
                    Text("İzinler daha önce yanıtlandığı için iOS pencereyi tekrar göstermiyor. Sağlık uygulamasında şu yolu izle: sağ üstten profil fotoğrafın › Gizlilik › Uygulamalar › halka › Tümünü Aç. Uygulamaya döndüğünde veriler otomatik gelir.")
                        .font(.h(11.5, .semibold))
                        .foregroundStyle(Color.inkBody)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        // Health uygulamasını doğrudan aç — Ayarlar'a
                        // yönlendirmek yanlıştı: Health izinleri Sağlık
                        // uygulamasının içinden yönetiliyor.
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Sağlık Uygulamasını Aç")
                            .font(.h(12, .bold))
                            .foregroundStyle(Color.coral)
                    }
                    .buttonStyle(.plain)
                }
                .padding(13)
                .background(Color.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.top, 10)
            }

            // Elle veri girişi (US-025). Eskiden burada "ekran görüntüsü
            // yükle, AI Koç okusun" diye SAHTE bir akış vardı: görüntüye
            // bakmadan +32 dk yazıyordu. Kaldırıldı — gerçek giriş ekranı.
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Manuel veri gir")
                        .font(.h(12.5))
                        .foregroundStyle(Color.ink)
                    Text(model.hkConnected
                         ? "Health bağlıyken adım ve egzersiz Health'ten okunur"
                         : "Egzersiz ve adımı kendin gir")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                Button { showManualEntry = true } label: {
                    Text(model.hkConnected ? "Ayrıntı" : "Veri Gir")
                        .font(.h(11.5))
                        .foregroundStyle(Color.coralDark)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.coralBg))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .card(20)
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView()
                .environment(model)
        }
    }
}
