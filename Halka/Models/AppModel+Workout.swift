import Foundation

// MARK: - Workout program builder + live workout

extension AppModel {

    var filteredLibrary: [Exercise] {
        Demo.exerciseLibrary.filter { ex in
            (libraryRegion == "Tümü" || ex.region == libraryRegion)
                && (libraryQuery.isEmpty
                    || ex.name.lowercased().contains(libraryQuery.lowercased()))
        }
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
