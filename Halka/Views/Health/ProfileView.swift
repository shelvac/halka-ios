import SwiftUI
import PhotosUI

/// Profile: identity card, Apple Health card with screenshot fallback, settings, logout.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var shotItem: PhotosPickerItem? = nil
    @State private var confirmDelete = false
    @State private var editingProfile = false
    @State private var showPrivacy = false

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
            case .documents: return "Yakında"
            case .privacy: return ""
            }
        }

        var isEnabled: Bool { self == .privacy }
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

            // Screenshot fallback → AI Koç parses activity data
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Health verileri ekle")
                        .font(.h(12.5))
                        .foregroundStyle(Color.ink)
                    Text(model.healthShotState == .done
                         ? "Son aktarım: bugün · ekran görüntüsünden"
                         : "Apple Health bağlanamadı — ekran görüntüsü yükle, AI Koç okusun")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                PhotosPicker(selection: $shotItem, matching: .images) {
                    Text(model.healthShotState == .done ? "Yeni Yükle" : "Görüntü Yükle")
                        .font(.h(11.5))
                        .foregroundStyle(Color.coralDark)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.coralBg))
                }
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
            .padding(.top, 12)

            if model.healthShotState == .processing {
                HStack(spacing: 10) {
                    SpinnerArc(size: 18)
                    Text("AI Koç ekran görüntüsünü okuyor — adım, egzersiz ve enerji verileri ayrıştırılıyor…")
                        .font(.h(12))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(2)
                    Spacer(minLength: 0)
                }
                .padding(13)
                .background(Color.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.top, 10)
            }
            if model.healthShotState == .done {
                HStack(spacing: 10) {
                    CheckBadge(size: 18)
                    Text("AI Koç ekledi: 32 dk yürüyüş · 4.812 adım · 214 kcal aktif enerji — egzersiz halkasına işlendi")
                        .font(.h(12))
                        .foregroundStyle(Color.greenDark)
                        .lineSpacing(2)
                    Spacer(minLength: 0)
                }
                .padding(13)
                .background(Color.greenBg)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .card(20)
        .onChange(of: shotItem) {
            guard shotItem != nil else { return }
            shotItem = nil
            model.processHealthScreenshot()
        }
    }
}
