import SwiftUI
import CoreData

/// Form for adding or editing an exercise inside a workout template.
/// Allows the user to select an existing exercise, specify number of
/// sets and rep range. When editing, the existing values are shown.
struct TemplateExerciseFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    let template: WorkoutTemplate
    var templateExercise: TemplateExercise?

    @State private var selectedExercise: Exercise?
    @State private var sets: Int = 3
    @State private var repMin: Int = 8
    @State private var repMax: Int = 12

    @FetchRequest(
        entity: Exercise.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
    ) private var allExercises: FetchedResults<Exercise>

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise")) {
                    Picker("Exercise", selection: Binding(
                        get: { selectedExercise ?? allExercises.first },
                        set: { selectedExercise = $0 }
                    )) {
                        // Provide an identifier for each exercise since Core Data
                        // entities do not automatically conform to `Identifiable`.
                        ForEach(allExercises, id: \.id) { exercise in
                            Text(exercise.name).tag(Optional(exercise))
                        }
                    }
                }
                Section(header: Text("Details")) {
                    Stepper(value: $sets, in: 1...10) {
                        Text("Sets: \(sets)")
                    }
                    Stepper(value: $repMin, in: 1...50) {
                        Text("Min reps: \(repMin)")
                    }
                    Stepper(value: $repMax, in: repMin...50) {
                        Text("Max reps: \(repMax)")
                    }
                }
            }
            .navigationTitle(templateExercise == nil ? "Add Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(selectedExercise == nil)
                }
            }
        }
        .onAppear {
            if let te = templateExercise {
                selectedExercise = te.exercise
                sets = Int(te.sets)
                repMin = Int(te.repMin)
                repMax = Int(te.repMax)
            }
        }
    }

    private func save() {
        guard let exercise = selectedExercise else { return }
        let te: TemplateExercise
        if let existing = templateExercise {
            te = existing
        } else {
            te = TemplateExercise(context: viewContext)
            te.id = UUID()
            te.template = template
            // Determine next order index as current count
            let currentCount = Int16((template.templateExercises ?? []).count)
            te.order = currentCount
        }
        te.exercise = exercise
        te.sets = Int16(sets)
        te.repMin = Int16(repMin)
        te.repMax = Int16(repMax)
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to save template exercise: \(error)")
        }
    }
}