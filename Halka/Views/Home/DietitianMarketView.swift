import SwiftUI

/// "Diyetisyen" segment: marketplace → profile & reviews → checkout → my dietitian.
struct DietitianMarketPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.myDietitian != nil {
            MyDietitianView()
        } else {
            switch model.marketView {
            case .list: MarketListView()
            case .profile: DietitianProfileView()
            case .checkout: CheckoutView()
            }
        }
    }
}

// MARK: - Suggested experts

struct MarketListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Henüz aktif diyetisyenin yok")
                    .font(.h(14))
                    .foregroundStyle(Color.ink)
                Text("Hedefine ve sağlık profiline göre önerilen uzmanlar — paket alınca tüm verilerini seninle takip eder.")
                    .font(.h(11.5, .semibold))
                    .foregroundStyle(Color.coralNote)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.coralBg)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.bottom, 14)

            ForEach(Array(Demo.dietitians.enumerated()), id: \.element.id) { i, dietitian in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        InitialsAvatar(text: dietitian.initial, index: i, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dietitian.name)
                                .font(.h(14))
                                .foregroundStyle(Color.ink)
                            Text(dietitian.specialty)
                                .font(.h(11, .bold))
                                .foregroundStyle(Color.sub)
                            Text(dietitian.rating)
                                .font(.h(11))
                                .foregroundStyle(Color.goldDark)
                                .padding(.top, 1)
                        }
                        Spacer()
                    }
                    HStack {
                        (Text(dietitian.price).font(.h(16)).foregroundColor(.ink)
                         + Text(" / 8 seanslık paket").font(.h(10.5, .bold)).foregroundColor(.faint))
                        Spacer()
                        Button { model.openDietitianProfile(i) } label: {
                            Text("Paket Al")
                                .font(.h(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Color.coral))
                                .shadow(color: Color.coral.opacity(0.3), radius: 5, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                    .padding(.top, 12)
                }
                .padding(16)
                .card(20)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Profile + reviews

struct DietitianProfileView: View {
    @Environment(AppModel.self) private var model

    private var dietitian: Dietitian { Demo.dietitians[model.selectedDietitian] }

    var body: some View {
        VStack(spacing: 0) {
            Button { model.marketBack() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Uzmanlara dön").font(.h(12.5))
                }
                .foregroundStyle(Color.sub)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)

            // Profile card
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 13) {
                    InitialsAvatar(text: dietitian.initial, index: model.selectedDietitian, size: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dietitian.name).font(.h(16)).foregroundStyle(Color.ink)
                        Text(dietitian.specialty).font(.h(11.5, .bold)).foregroundStyle(Color.sub)
                        Text(dietitian.rating).font(.h(11.5)).foregroundStyle(Color.goldDark).padding(.top, 1)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    ForEach(dietitian.stats, id: \.1) { stat in
                        VStack(spacing: 1) {
                            Text(stat.0).font(.h(15)).foregroundStyle(Color.ink)
                            Text(stat.1).font(.h(9.5)).foregroundStyle(Color.sub)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
                .padding(.top, 14)
                Text(dietitian.bio)
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.inkMid)
                    .lineSpacing(4)
                    .padding(.top, 13)
            }
            .padding(20)
            .card(22)

            (Text("Değerlendirmeler ").font(.h(14)).foregroundColor(.ink)
             + Text("· \(dietitian.reviews.count)").font(.h(14)).foregroundColor(.faint))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .padding(.horizontal, 2)

            ForEach(dietitian.reviews) { review in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(review.name).font(.h(12)).foregroundStyle(Color.ink)
                        Text(String(repeating: "★", count: review.stars))
                            .font(.h(10.5))
                            .foregroundStyle(Color.goldDark)
                        Spacer()
                        Text(review.date).font(.h(10, .bold)).foregroundStyle(Color.faint)
                    }
                    Text(review.text)
                        .font(.h(11.5, .semibold))
                        .foregroundStyle(Color.inkMid)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(18)
                .padding(.bottom, 9)
            }

            // Price bar
            HStack(spacing: 12) {
                (Text(dietitian.price).font(.h(17)).foregroundColor(.ink)
                 + Text(" / 8 seanslık paket").font(.h(10.5, .bold)).foregroundColor(.faint))
                Spacer()
                Button {
                    model.marketView = .checkout
                    model.payState = .idle
                } label: {
                    Text("Paket Al")
                        .font(.h(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.coral))
                        .shadow(color: Color.coral.opacity(0.3), radius: 7, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .card(20)
            .padding(.top, 12)
        }
    }
}

// MARK: - Checkout

struct CheckoutView: View {
    @Environment(AppModel.self) private var model

    private var dietitian: Dietitian { Demo.dietitians[model.selectedDietitian] }

    var body: some View {
        VStack(spacing: 0) {
            Button { model.marketBack() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Profile dön").font(.h(12.5))
                }
                .foregroundStyle(Color.sub)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)

            switch model.payState {
            case .idle: idleContent
            case .processing: processingCard
            case .done: doneCard
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: 12) {
            // Order summary
            VStack(alignment: .leading, spacing: 0) {
                Text("Sipariş özeti")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 12)
                HStack(spacing: 11) {
                    InitialsAvatar(text: dietitian.initial, index: model.selectedDietitian, size: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dietitian.name).font(.h(13)).foregroundStyle(Color.ink)
                        Text("8 seanslık takip paketi · 2 ay")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text(dietitian.price).font(.h(14)).foregroundStyle(Color.ink)
                }
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Demo.packageIncludes, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Color.green)
                            Text(item)
                                .font(.h(11.5, .semibold))
                                .foregroundStyle(Color.inkMid)
                        }
                    }
                }
                .padding(.top, 13)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
                .padding(.top, 13)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(22)

            // Payment method
            VStack(alignment: .leading, spacing: 0) {
                Text("Ödeme yöntemi")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 12)
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.ink)
                        .frame(width: 38, height: 26)
                        .overlay(Text("VISA").font(.h(8)).foregroundStyle(.white).kerning(0.5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("•••• 4262").font(.h(12)).foregroundStyle(Color.ink)
                        Text("Simge K. · 08/27").font(.h(10, .bold)).foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text("Değiştir").font(.h(11)).foregroundStyle(Color.coral)
                }
                .padding(14)
                .background(Color.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    Text("Toplam").font(.h(12)).foregroundStyle(Color.sub)
                    Spacer()
                    Text(dietitian.price).font(.h(16)).foregroundStyle(Color.ink)
                }
                .padding(.top, 13)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
                .padding(.top, 13)
            }
            .padding(18)
            .card(22)

            Button { model.payNow() } label: {
                Text("Ödemeyi Tamamla · \(dietitian.price)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()

            Text("256-bit SSL ile güvenli ödeme · İlk seanstan önce iptal edilebilir")
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
        }
    }

    private var processingCard: some View {
        VStack(spacing: 12) {
            SpinnerArc(size: 34)
            Text("Ödeme işleniyor…")
                .font(.h(13))
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 24)
        .card(22)
    }

    private var doneCard: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.greenBg)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.green)
                )
                .padding(.bottom, 14)
            Text("Ödeme tamamlandı")
                .font(.h(17))
                .foregroundStyle(Color.ink)
            Text("\(dietitian.name) artık senin diyetisyenin. Verilerin kendisiyle paylaşıldı, ilk programın hazırlanıyor.")
                .font(.h(12, .semibold))
                .foregroundStyle(Color.sub)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 6)
            Button { model.activateDietitian() } label: {
                Text("Diyetisyen Sayfasını Aç").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()
            .padding(.top, 18)
        }
        .padding(.vertical, 34)
        .padding(.horizontal, 24)
        .card(22)
    }
}

// MARK: - Active dietitian page

struct MyDietitianView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        guard let my = model.myDietitian else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 12) {
                // Dietitian header
                HStack(spacing: 12) {
                    InitialsAvatar(text: my.initial, index: my.avatarIndex, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(my.name).font(.h(15)).foregroundStyle(Color.ink)
                        Text(my.specialty).font(.h(11, .bold)).foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text("Mesaj")
                        .font(.h(12))
                        .foregroundStyle(Color.coralDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.coralBg))
                }
                .padding(18)
                .card(22)

                // Dark package card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paket").font(.h(10, .bold)).foregroundStyle(.white.opacity(0.5))
                        Text(my.price).font(.h(14)).foregroundStyle(.white)
                        Text("8 seans").font(.h(9.5, .bold)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Text("Kalan seans").font(.h(10, .bold)).foregroundStyle(.white.opacity(0.5))
                        Text("\(my.sessionsLeft)").font(.h(22)).foregroundStyle(Color.gold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Sonraki randevu").font(.h(10, .bold)).foregroundStyle(.white.opacity(0.5))
                        Text("12 Ağustos").font(.h(13)).foregroundStyle(.white)
                        Text("14:00 · Online").font(.h(10, .bold)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color.ink)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Notes
                VStack(alignment: .leading, spacing: 0) {
                    Text("Diyetisyen notları")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                        .padding(.vertical, 8)
                    ForEach(Array(Demo.dietitianNotes.enumerated()), id: \.offset) { i, note in
                        HStack(alignment: .top, spacing: 10) {
                            Text(note.0)
                                .font(.h(10))
                                .foregroundStyle(Color.faint)
                                .frame(width: 44, alignment: .leading)
                                .padding(.top, 2)
                            Text(note.1)
                                .font(.h(12.5, .semibold))
                                .foregroundStyle(Color.inkSoft)
                                .lineSpacing(3)
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(20)

                // Today's plan
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Beslenme listen · Bugün")
                            .font(.h(13))
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Button {
                            model.tab = .meal
                            model.mealView = .menu
                        } label: {
                            Text("Tümünü gör").font(.h(11)).foregroundStyle(Color.coralDark)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    ForEach(Array(Demo.mealLabels.enumerated()), id: \.offset) { j, label in
                        HStack(spacing: 8) {
                            Text(model.mealTimes[j])
                                .font(.h(11))
                                .foregroundStyle(Color.coral)
                                .frame(width: 40, alignment: .leading)
                            Text(label)
                                .font(.h(10))
                                .foregroundStyle(Color.faint)
                                .frame(width: 36, alignment: .leading)
                            Text(Demo.menus[2][j])
                                .font(.h(12.5, .bold))
                                .foregroundStyle(Color.inkSoft)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if j > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .card(20)

                Button { model.dropDietitian() } label: {
                    Text("Diyetisyeni değiştir")
                        .font(.h(11.5))
                        .foregroundStyle(Color.sub)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        )
    }
}
