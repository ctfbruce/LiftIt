import SwiftUI
import CoreData

/// Displays and manages progression goals for a specific workout program.
///
/// Unlike the original global `GoalsView`, this view lives under a
/// particular `WorkoutProgram` and lets the user track target weights on
/// a per‑exercise basis. It enumerates each exercise appearing in the
/// program, offers a text field for entering the desired goal weight
/// and shows an estimate of how many sessions and weeks it might take
/// to reach that goal based on the current weight goal stored in the
/// program. The current deload counter (consecutive misses) is shown
/// alongside each exercise with a warning when a deload is imminent.
///
/// User‑entered target weights are persisted in `UserDefaults` keyed by
/// the program and exercise identifiers. This allows goals to survive
/// app launches without requiring changes to the Core Data model. When
/// the view appears it loads any saved values and prepopulates the
/// text fields accordingly. A “Save Goals” button writes the latest
/// entries back to `UserDefaults`.
struct ProgramGoalsView: View {
    @ObservedObject var program: WorkoutProgram

    /// Holds the text input for each exercise’s target weight. Keys are
    /// composed of the exercise’s UUID string. Values are raw text to
    /// allow users to input partial numbers without immediate parsing.
    @State private var targetWeightInputs: [UUID: String] = [:]

    /// A computed list of distinct `ProgramExercise` objects grouped by
    /// their associated `Exercise`. Because exercises may appear on
    /// multiple days or slots, we deduplicate by the exercise ID and
    /// pick the first occurrence to represent its current state.
    private var uniqueProgramExercises: [ProgramExercise] {
        guard let all = program.programExercises else { return [] }
        var seen: Set<UUID> = []
        var uniques: [ProgramExercise] = []
        for pe in all.sorted(by: { $0.exercise?.name ?? "" < $1.exercise?.name ?? "" }) {
            if let exId = pe.exercise?.id, !seen.contains(exId) {
                seen.insert(exId)
                uniques.append(pe)
            }
        }
        return uniques
    }

    var body: some View {
        Form {
            Section(header: Text("Set your goals")) {
                if uniqueProgramExercises.isEmpty {
                    Text("No exercises in this program yet.")
                        .foregroundColor(.secondary)
                }
                // Use the program exercise's UUID as the identifier for each row.
                ForEach(uniqueProgramExercises, id: \.id) { pe in
                    let exerciseId = pe.exercise?.id ?? UUID()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pe.exercise?.name ?? "Exercise")
                                .font(.headline)
                            Spacer()
                            // Show the current deload counter. When it reaches 2
                            // (meaning a deload will occur on the next miss), display
                            // a warning in red.
                            if pe.consecutiveMisses >= 2 {
                                Text("Deload imminent")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            } else {
                                Text("Misses: \(pe.consecutiveMisses)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            TextField("Target kg", text: Binding(
                                get: { targetWeightInputs[exerciseId] ?? "" },
                                set: { targetWeightInputs[exerciseId] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            // Prediction view: compute sessions/weeks when a
                            // valid target is entered and greater than the
                            // current weight goal. Otherwise, show nothing.
                            if let targetDouble = Double(targetWeightInputs[exerciseId] ?? ""), targetDouble > 0 {
                                if let prediction = predictedSessions(for: pe, targetWeight: targetDouble) {
                                    VStack(alignment: .leading) {
                                        Text("~\(prediction.sessions) sessions")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("~\(prediction.weeks) weeks")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if !uniqueProgramExercises.isEmpty {
                Section {
                    Button(action: saveGoals) {
                        HStack {
                            Spacer()
                            Text("Save Goals")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .onAppear {
            loadSavedGoals()
        }
    }

    /// Computes the predicted number of sessions and weeks required to
    /// reach a target weight for a given program exercise. This uses the
    /// current `weightGoal` on the program exercise as the starting
    /// point. The algorithm mirrors the logic from `GoalsView` where
    /// weight increases by 2.5 kg per session and one session per week
    /// is assumed.
    private func predictedSessions(for pe: ProgramExercise, targetWeight: Double) -> (sessions: Int, weeks: Int)? {
        let currentGoal = pe.weightGoal
        guard targetWeight > currentGoal else { return nil }
        let difference = targetWeight - currentGoal
        let increments = difference / 2.5
        let sessions = Int(ceil(increments))
        let weeks = sessions // one session per week assumption
        return (sessions, weeks)
    }

    /// Constructs a UserDefaults key for persisting a target weight based on
    /// the program and exercise identifiers. This avoids collisions
    /// between different programs that happen to use the same exercise.
    private func key(for exerciseId: UUID) -> String {
        return "goalWeight_\(program.id.uuidString)_\(exerciseId.uuidString)"
    }

    /// Loads any saved target weights from UserDefaults and populates
    /// `targetWeightInputs`. Called when the view appears.
    private func loadSavedGoals() {
        for pe in uniqueProgramExercises {
            if let exId = pe.exercise?.id {
                let saved = UserDefaults.standard.object(forKey: key(for: exId)) as? Double
                if let value = saved {
                    targetWeightInputs[exId] = value == 0 ? "" : String(format: "%.2f", value)
                }
            }
        }
    }

    /// Persists the current target weights into UserDefaults. Blank or
    /// non‑numerical entries are treated as removal of the goal (the key
    /// is removed). After saving, the keyboard is dismissed.
    private func saveGoals() {
        for (exId, text) in targetWeightInputs {
            if let value = Double(text), value > 0 {
                UserDefaults.standard.set(value, forKey: key(for: exId))
            } else {
                UserDefaults.standard.removeObject(forKey: key(for: exId))
            }
        }
        // End editing to dismiss the keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview
struct ProgramGoalsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create an in‑memory persistence controller for previewing
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        // Build a mock program with a couple of exercises
        let program = WorkoutProgram(context: context)
        program.id = UUID()
        program.name = "Mock Program"
        program.currentDayIndex = 1
        // Create an exercise and program exercise
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = "Bench Press"
        let pe = ProgramExercise(context: context)
        pe.id = UUID()
        pe.dayIndex = 1
        pe.order = 0
        pe.sets = 3
        pe.repMin = 8
        pe.repMax = 12
        pe.repGoal = 10
        pe.weightGoal = 50
        pe.consecutiveMisses = 1
        pe.exercise = exercise
        pe.program = program
        program.programExercises = [pe]
        return NavigationView {
            ProgramGoalsView(program: program)
        }
        .environment(\.managedObjectContext, context)
    }
}