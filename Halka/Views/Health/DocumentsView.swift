import SwiftUI
import QuickLook

/// Belgelerim (US-025): tahlil/tartı PDF'leri — kullanıcıya özel, RLS
/// korumalı Storage klasöründe. Yükle, listele, önizle, sil.
struct DocumentsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    /// QuickLook önizlemesi için geçici dosya.
    @State private var previewURL: URL? = nil
    @State private var downloading: String? = nil
    @State private var confirmDelete: SupabaseService.DocumentFile? = nil

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        uploadCard
                        listCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .task { await model.loadDocuments() }
        .quickLookPreview($previewURL)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                model.uploadDocument(from: url)
            }
        }
        .confirmationDialog("Belge silinsin mi?",
                            isPresented: .init(get: { confirmDelete != nil },
                                               set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                if let file = confirmDelete { model.deleteDocument(file) }
                confirmDelete = nil
            }
            Button("Vazgeç", role: .cancel) { confirmDelete = nil }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 1) {
                Text("Belgelerim")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Text("Tahlil ve tartı PDF'lerin — yalnızca sen görürsün")
                    .font(.h(10.5, .bold))
                    .foregroundStyle(Color.sub)
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button("Kapat") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.coral)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var uploadCard: some View {
        VStack(spacing: 0) {
            Button { showImporter = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("PDF Yükle")
                        .font(.h(14))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.coral)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            if model.bloodPdfState == .processing {
                HStack(spacing: 10) {
                    SpinnerArc(size: 18)
                    Text("\(model.bloodPdfName) yükleniyor…")
                        .font(.h(12, .bold))
                        .foregroundStyle(Color.sub)
                    Spacer()
                }
                .padding(.top, 12)
            }
            if let error = model.bloodPdfError {
                Text(error)
                    .font(.h(11.5, .semibold))
                    .foregroundStyle(Color.coralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var listCard: some View {
        if model.documentsBusy && model.documents.isEmpty {
            HStack(spacing: 10) {
                SpinnerArc(size: 18)
                Text("Belgeler yükleniyor…")
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
            }
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .card(18)
        } else if model.documents.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color.chevron)
                Text("Henüz belge yok")
                    .font(.h(12.5, .bold))
                    .foregroundStyle(Color.sub)
                Text("Kan tahlili veya tartı raporu PDF'ini yükleyebilirsin.")
                    .font(.h(11, .semibold))
                    .foregroundStyle(Color.faint)
            }
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .card(18)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.documents.enumerated()), id: \.element.id) { i, file in
                    Button { open(file) } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.coral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.displayName)
                                    .font(.h(12.5, .bold))
                                    .foregroundStyle(Color.inkBody)
                                    .lineLimit(1)
                                if let date = file.createdAt {
                                    Text(Self.dateText(date))
                                        .font(.h(10.5, .bold))
                                        .foregroundStyle(Color.faint)
                                }
                            }
                            Spacer()
                            if downloading == file.path {
                                SpinnerArc(size: 16)
                            } else {
                                Image(systemName: "eye")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.sub)
                            }
                            Button { confirmDelete = file } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.faint)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .card(18)
        }
    }

    /// Belgeyi geçici dosyaya indirip QuickLook ile açar.
    private func open(_ file: SupabaseService.DocumentFile) {
        guard downloading == nil else { return }
        downloading = file.path
        Task {
            defer { downloading = nil }
            guard let data = await SupabaseService.shared.downloadDocument(path: file.path)
            else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(file.displayName)
            try? data.write(to: url)
            previewURL = url
        }
    }

    private static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM yyyy · HH:mm"
        return f.string(from: date)
    }
}
