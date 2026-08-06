import SwiftUI

/// Premium dietitian mode: client roster + 5-tab client detail.
struct DietitianPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    switch model.panelView {
                    case .list: ClientListView()
                    case .client: ClientDetailView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Client roster

struct ClientListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let stats = model.clientStats
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Danışanlarım")
                            .font(.h(24))
                            .foregroundStyle(Color.ink)
                            .kerning(-0.5)
                        Text("PREMIUM")
                            .font(.h(9.5))
                            .foregroundStyle(Color.ink)
                            .kerning(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.gold))
                    }
                    Text("Dyt. Simge Helvacı")
                        .font(.h(12, .bold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                Button { model.logout() } label: {
                    Text("Çıkış")
                        .font(.h(12))
                        .foregroundStyle(Color.coralDark)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            // Summary card
            HStack {
                summaryColumn("Danışan", stats.count, .ink)
                Spacer()
                summaryColumn("Ort. uyum", stats.avg, .greenDark)
                Spacer()
                summaryColumn("Bu hafta kilo", stats.loss, .greenDark)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .card(20)

            // Add client
            HStack(spacing: 8) {
                TextField("Danışan adı…", text: $model.clientNameDraft)
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                Button { model.addClient() } label: {
                    Text("+ Ekle")
                        .font(.h(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(Color.coral)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.coral.opacity(0.3), radius: 6, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)

            // Client cards
            ForEach(Array(model.clients.enumerated()), id: \.element.id) { i, client in
                Button { model.openClient(i) } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blueBg)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text(client.initials)
                                    .font(.h(15))
                                    .foregroundStyle(Color.blueDark)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.name).font(.h(14)).foregroundStyle(Color.ink)
                            Text(client.lastMeal)
                                .font(.h(10.5, .bold))
                                .foregroundStyle(Color.sub)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(client.weightText) kg")
                                .font(.h(14))
                                .foregroundStyle(Color.ink)
                            deltaChip(client)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }
        }
    }

    private func summaryColumn(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.h(10, .bold)).foregroundStyle(Color.faint)
            Text(value).font(.h(17)).foregroundStyle(color)
        }
    }
}

func deltaChip(_ client: Client) -> some View {
    Text(client.deltaText)
        .font(.h(10))
        .foregroundStyle(client.delta < 0 ? Color.greenDark : Color.goldDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(client.delta < 0 ? Color.greenBg : Color.goldBg))
}

// MARK: - Client detail (5 tabs)

struct ClientDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        guard let client = model.currentClient else { return AnyView(EmptyView()) }
        return AnyView(VStack(spacing: 0) {
            BackRow(label: "Danışanlarım") { model.panelView = .list }

            headerCard(client)

            // Tab bar
            HStack(spacing: 5) {
                ForEach(ClientTab.allCases, id: \.self) { tab in
                    let active = model.clientTab == tab
                    Button { model.clientTab = tab } label: {
                        Text(tab.rawValue)
                            .font(.h(11))
                            .foregroundStyle(active ? .white : Color.sub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(active ? Color.ink : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .shadow(color: active ? .clear : Color.ink.opacity(0.05), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)

            switch model.clientTab {
            case .general: GeneralTab(client: client)
            case .body: BodyTab(client: client)
            case .blood: BloodTab()
            case .supplements: SupplementsTab()
            case .diet: DietTab(client: client)
            }
        })
    }

    private func headerCard(_ client: Client) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blueBg)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(client.initials).font(.h(18)).foregroundStyle(Color.blueDark)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name).font(.h(18)).foregroundStyle(Color.ink)
                    Text("Son tartım: bugün")
                        .font(.h(11, .bold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(client.weightText) kg").font(.h(20)).foregroundStyle(Color.ink)
                    deltaChip(client)
                }
            }

            // 4-week weight trend
            let trend = model.clientTrend(client)
            let minW = trend.map(\.1).min() ?? 0
            let maxW = trend.map(\.1).max() ?? 1
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(trend.enumerated()), id: \.offset) { i, bar in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(i == 3 ? Color.coral : Color.avatarPeach)
                            .frame(maxWidth: 34)
                            .frame(height: 26 + CGFloat((bar.1 - minW) / max(maxW - minW, 0.001)) * 34)
                        Text(bar.0).font(.h(9)).foregroundStyle(Color.faint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76, alignment: .bottom)
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
            .padding(.top, 18)
        }
        .padding(20)
        .card(22)
    }
}

// MARK: General tab

private struct GeneralTab: View {
    @Environment(AppModel.self) private var model
    var client: Client

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Quick stats
            HStack(spacing: 8) {
                quickStat("Halka uyumu", "%\(client.compliance)", .greenDark)
                quickStat("Bugün kalori", "1240 / 1400", .ink)
                quickStat("Su", "1.4 / 2 L", .blueDark)
            }
            .padding(.top, 12)

            // Allergies + health note
            VStack(alignment: .leading, spacing: 0) {
                Text("Alerjiler & İntoleranslar")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 10)
                FlowLayout(spacing: 6) {
                    ForEach(Array(client.allergies.enumerated()), id: \.offset) { i, allergy in
                        HStack(spacing: 4) {
                            Text(allergy)
                            Button { model.removeAllergy(at: i) } label: {
                                Text("×").opacity(0.6)
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.h(11))
                        .foregroundStyle(Color.coralDark)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.coralBg))
                    }
                }
                .padding(.bottom, 10)
                HStack(spacing: 7) {
                    TextField("Alerji / intolerans ekle…", text: $model.allergyDraft)
                        .font(.h(12, .semibold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(Color.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Button { model.addAllergy() } label: {
                        Text("Ekle")
                            .font(.h(12))
                            .foregroundStyle(Color.coralDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.coralBg)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text("Sağlık notu")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                TextField("Not ekle…", text: Binding(
                    get: { model.currentClient?.note ?? "" },
                    set: { newValue in
                        if model.clients.indices.contains(model.selectedClient) {
                            model.clients[model.selectedClient].note = newValue
                        }
                    }), axis: .vertical)
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(3...5)
                    .padding(13)
                    .background(Color.bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)
            .padding(.top, 12)

            // Today's meals
            VStack(alignment: .leading, spacing: 0) {
                Text("Bugün yedikleri")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                ForEach(Array(Demo.clientMeals.enumerated()), id: \.offset) { i, meal in
                    HStack(spacing: 10) {
                        Text(meal.0)
                            .font(.h(11))
                            .monospacedDigit()
                            .foregroundStyle(Color.faint)
                            .frame(width: 40, alignment: .leading)
                        Text(meal.1)
                            .font(.h(12.5, .bold))
                            .foregroundStyle(Color.inkSoft)
                        Spacer()
                        Text(meal.2).font(.h(11)).foregroundStyle(Color.sub)
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
            .padding(.top, 12)

            Button {} label: {
                Text("Danışana not gönder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()
            .padding(.top, 12)
        }
    }

    private func quickStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.h(9.5, .bold)).foregroundStyle(Color.faint)
            Text(value).font(.h(15)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: Body / Blood / Supplements tabs

private struct BodyTab: View {
    @Environment(AppModel.self) private var model
    var client: Client

    var body: some View {
        VStack(spacing: 0) {
            metricList(model.clientBodyRows(client))
                .padding(.top, 12)
            Text("Son akıllı tartı ölçümü · bugün 09:03")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
                .padding(.top, 10)
        }
    }
}

private struct BloodTab: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            metricList(model.clientBloodRows())
                .padding(.top, 12)
            Text(model.clientBloodNote)
                .font(.h(11.5, .semibold))
                .foregroundStyle(Color.coralNote)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .background(Color.coralBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 10)
        }
    }
}

/// Shared name/value/status list used by Body & Blood tabs.
private func metricList(_ rows: [(String, String, String, String)]) -> some View {
    VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
            let colors = statusColors(row.3)
            HStack(spacing: 10) {
                Text(row.0).font(.h(13, .bold)).foregroundStyle(Color.inkBody)
                Spacer()
                (Text(row.1).font(.h(15)).foregroundColor(.ink)
                 + Text(" \(row.2)").font(.h(10, .bold)).foregroundColor(.faint))
                StatusChip(text: row.3, bg: colors.bg, fg: colors.fg, minWidth: 58)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .top) {
                if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
            }
        }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 6)
    .card(20)
}

private struct SupplementsTab: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Demo.clientSupplements.enumerated()), id: \.offset) { _, supp in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supp.0).font(.h(13.5)).foregroundStyle(Color.ink)
                        Text(supp.1).font(.h(10.5, .bold)).foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text(supp.2)
                        .font(.h(11))
                        .foregroundStyle(Color.inkMid)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.bgField))
                    Text("%\(supp.3)")
                        .font(.h(11))
                        .foregroundStyle(supp.3 >= 75 ? Color.greenDark : Color.goldDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(supp.3 >= 75 ? Color.greenBg : Color.goldBg))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                .padding(.top, 10)
            }
            Text("Uyum: son 30 günde alınan doz oranı")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
                .padding(.top, 10)
        }
    }
}

// MARK: Diet tab — weekly editor with live allergy warnings

private struct DietTab: View {
    @Environment(AppModel.self) private var model
    var client: Client

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Editor card
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Haftalık Diyet Programı")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    HStack(spacing: 5) {
                        Text("Hedef").font(.h(10)).foregroundStyle(Color.faint)
                        TextField("kcal", text: $model.dietKcalTarget)
                            .font(.h(12))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .frame(width: 52)
                            .padding(.vertical, 6)
                            .background(Color.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .onChange(of: model.dietKcalTarget) { model.dietSent = false }
                        Text("kcal").font(.h(10)).foregroundStyle(Color.faint)
                    }
                }
                .padding(.bottom, 12)

                // Day picker
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        let active = model.dietDay == i
                        Button { model.dietDay = i } label: {
                            Text(Demo.dayNamesShort[i])
                                .font(.h(10))
                                .foregroundStyle(active ? .white : Color.sub)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(active ? Color.coral : Color.bgField)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 12)

                // Meal editors
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(0..<4, id: \.self) { slot in
                        let meal = model.activeDietPlan[model.dietDay][slot]
                        let hits = model.allergyHits(meal: meal, client: client)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Demo.mealLabels[slot].uppercased(with: Locale(identifier: "tr"))) · \(model.mealTimes[slot])")
                                .font(.h(10))
                                .foregroundStyle(Color.faint)
                            TextField("Öğün…", text: Binding(
                                get: { model.activeDietPlan[model.dietDay][slot] },
                                set: { model.setDietMeal(day: model.dietDay, slot: slot, text: $0) }))
                                .font(.h(12, .semibold))
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .background(hits.isEmpty ? Color.bgField : Color.warnFieldBg)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(hits.isEmpty ? .clear : Color.warnFieldBorder, lineWidth: 1.5)
                                )
                            if !hits.isEmpty {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.coralDark)
                                    Text("\(hits.joined(separator: ", ")) alerjisi ile çakışıyor")
                                        .font(.h(10.5))
                                        .foregroundStyle(Color.coralDark)
                                }
                                .padding(.leading, 2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)
            .padding(.top, 12)

            // Week-wide conflict summary
            let warnings = model.allergyWarnings
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.coralDark)
                        Text("Alerji uyarısı — \(warnings.count) çakışma")
                            .font(.h(12))
                            .foregroundStyle(Color.coralDark)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(warnings, id: \.self) { warning in
                            Text(warning)
                                .font(.h(11, .semibold))
                                .foregroundStyle(Color.warnDeep)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.coralBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 10)
            }

            if model.dietSent {
                HStack(spacing: 11) {
                    CheckBadge(size: 20)
                    Text(model.dietSentText)
                        .font(.h(12.5))
                        .foregroundStyle(Color.greenDark)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.greenBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 10)
            }

            Button { model.sendDietProgram() } label: {
                Text("Diyet Programını Gönder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()
            .padding(.top, 10)
        }
    }
}
