import SwiftUI
import CoreData

/// Allows the user to specify a target weight for a given exercise and
/// estimates how many workout sessions it may take to reach that goal
/// assuming the progression algorithm increases the weight by 2.5 kg
/// whenever goals are met. The calculation is a rough approximation and
/// assumes the goal is always met in each session.
struct GoalsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Exercise.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
    ) private var exercises: FetchedResults<Exercise>
    @FetchRequest(
        entity: WorkoutProgram.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutProgram.name, ascending: true)]
    ) private var programs: FetchedResults<WorkoutProgram>

    @State private var selectedExercise: Exercise? = nil
    @State private var targetWeightString: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise")) {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(exercises) { exercise in
                            Text(exercise.name).tag(Optional(exercise))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                Section(header: Text("Target Weight (kg)")) {
                    TextField("kg", text: $targetWeightString)
                        .keyboardType(.decimalPad)
                }
                if let prediction = predictedSessions() {
                    Section(header: Text("Prediction")) {
                        Text("Estimated sessions to reach target: \(prediction.sessions)")
                        Text("Approximate time: \(prediction.weeks) weeks")
                    }
                }
            }
            .navigationTitle("Goals")
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
            }
        }
    }

    /// Computes the number of sessions and approximate time to reach the target
    /// weight for the selected exercise. It looks up the current weight goal
    /// from the program where the exercise appears (if any) and then
    /// calculates how many 2.5 kg increments are required. Assumes one
    /// session per week for simplicity.
    private func predictedSessions() -> (sessions: Int, weeks: Int)? {
        guard let exercise = selectedExercise, let targetWeight = Double(targetWeightString), targetWeight > 0 else { return nil }
        // Find the current weight goal for this exercise from any program exercise
        // (assumes only one active program for the exercise). If none found,
        // assume starting weight 0.
        var currentGoal: Double = 0
        for program in programs {
            for pe in program.programExercises ?? [] {
                if pe.exercise == exercise {
                    currentGoal = max(currentGoal, pe.weightGoal)
                }
            }
        }
        if currentGoal <= 0 {
            currentGoal = 0
        }
        let difference = max(0, targetWeight - currentGoal)
        let increments = difference / 2.5
        let sessions = Int(ceil(increments))
        // Assume one session per week; convert to weeks
        let weeks = sessions
        return (sessions, weeks)
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}