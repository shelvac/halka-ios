import Foundation

// MARK: - Workout program builder + live workout

extension AppModel {

    /// Kütüphanenin kaynağı: gerçek katalog yüklendiyse o, yoksa demo.
    var librarySource: [Exercise] {
        libraryExercises.isEmpty ? Demo.exerciseLibrary : libraryExercises
    }

    /// Bölge çipleri kaynaktan türetilir — gerçek katalogda Biceps/Triceps
    /// gibi bölgeler var, sabit demo listesi onları gösteremiyordu.
    var libraryRegions: [String] {
        ["Tümü"] + Set(librarySource.map(\.region)).sorted {
            $0.compare($1, locale: Locale(identifier: "tr_TR")) == .orderedAscending
        }
    }

    var filteredLibrary: [Exercise] {
        let query = libraryQuery.lowercased(with: Locale(identifier: "tr_TR"))
        return librarySource.filter { ex in
            (libraryRegion == "Tümü" || ex.region == libraryRegion)
                && (query.isEmpty
                    || ex.name.lowercased(with: Locale(identifier: "tr_TR")).contains(query))
        }
    }

    /// Girişte bir kez: gerçek egzersiz kataloğu + kullanıcının programları.
    func loadWorkoutData() async {
        if libraryExercises.isEmpty {
            let fetched = await SupabaseService.shared.fetchPlanExercises()
            libraryExercises = fetched.map {
                Exercise(name: $0.displayName, region: $0.region,
                         reps: $0.mechanic == "isolation" ? "3 × 12" : "3 × 10",
                         images: $0.images, equipment: $0.equipment, level: $0.level)
            }
            .sorted { $0.name.compare($1.name, locale: Locale(identifier: "tr_TR"))
                        == .orderedAscending }
        }
        programs = await SupabaseService.shared.fetchWorkoutPrograms()
    }

    /// Ada göre kütüphane kaydı — AI planındaki veya eski (görselsiz)
    /// programdaki bir hareketin görsel/detayına ulaşmak için.
    func exerciseInfo(named name: String) -> Exercise? {
        libraryExercises.first { $0.name == name }
    }

    func isInDraft(_ exercise: Exercise) -> Bool {
        programDraft.items.contains { $0.name == exercise.name }
    }

    func addToDraft(_ exercise: Exercise) {
        guard !isInDraft(exercise) else { return }
        programDraft.items.append(exercise)
    }

    func removeFromDraft(at index: Int) {
        programDraft.items.remove(at: index)
    }

    func saveProgram() {
        guard !programDraft.items.isEmpty else { return }
        let name = programDraft.name.trimmingCharacters(in: .whitespaces)
        let program = WorkoutProgram(
            name: name.isEmpty ? "\(programDraft.region) · \(programDraft.level)" : name,
            region: programDraft.region,
            level: programDraft.level,
            items: programDraft.items)
        programs.append(program)
        programDraft = ProgramDraft()
        selectedProgramID = program.id
        workoutView = .program
        persistProgram(program)
    }

    func deleteProgram(_ program: WorkoutProgram) {
        programs.removeAll { $0.id == program.id }
        if selectedProgramID == program.id { selectedProgramID = nil }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.deleteWorkoutProgram(id: program.id) }
    }

    private func persistProgram(_ program: WorkoutProgram) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.saveWorkoutProgram(program) }
    }

    func workoutBack() {
        if workoutView == .library && libraryPickMode {
            workoutView = .create
        } else {
            workoutView = .home
        }
        runStart = nil
        runDone = []
    }

    func startRun() {
        runStart = Date()
        runDone = []
        workoutView = .run
    }

    var runElapsedText: String {
        guard let start = runStart else { return "00:00" }
        let sec = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    func toggleRunDone(_ index: Int) {
        if runDone.contains(index) { runDone.remove(index) } else { runDone.insert(index) }
    }

    func finishRun() {
        guard let program = selectedProgram else { return }
        let seconds = runStart.map { Int(Date().timeIntervalSince($0)) } ?? 0
        let minutes = max(1, Int((Double(seconds) / 60).rounded()))
        workoutLog.insert(
            WorkoutLogEntry(title: "\(program.name) · bugün \(Self.nowHHmm())",
                            meta: "\(minutes) dk · \(runDone.count)/\(program.items.count) egzersiz"),
            at: 0)
        extraExerciseMin += minutes
        runStart = nil
        runDone = []
        workoutView = .home
    }
}
