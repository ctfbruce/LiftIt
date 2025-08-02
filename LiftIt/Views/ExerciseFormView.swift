import SwiftUI
import CoreData

/// Form view for creating or editing an exercise. Presents fields for
/// name and muscle group selection. When "Other" is chosen from the
/// picker, an additional text field allows entry of a custom muscle
/// name. On save, data is written to Core Data.
struct ExerciseFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    /// The exercise being edited. If nil, a new exercise will be created.
    var exercise: Exercise?

    @State private var name: String = ""
    // Primary muscle group selection. Default to the first entry in muscleGroups.
    @State private var selectedMuscle: String = "Chest"
    // Secondary muscle groups selection. Users can choose any number of additional
    // muscle groups beyond the primary. Stored as a set to avoid duplicates.
    @State private var secondarySelections: Set<String> = []

    /// User entered notes for this exercise. Notes are optional and
    /// provide a place to capture cues or reminders (e.g. "Brace core").
    @State private var notes: String = ""

    /// Predefined list of muscle groups used throughout the app. Users select
    /// one of these as the primary muscle and may optionally select any
    /// number as secondary muscles. This list drives the filtering cards on
    /// the Exercises page.
    private let muscleGroups: [String] = [
        "Bicep", "Tricep", "Chest", "Shoulder", "Hamstring", "Glute", "Core", "Quad", "Calves", "Lats", "Back"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise")) {
                    TextField("Name", text: $name)
                }
                Section(header: Text("Primary Muscle")) {
                    Picker("Primary", selection: $selectedMuscle) {
                        ForEach(muscleGroups, id: \ .self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                Section(header: Text("Secondary Muscles")) {
                    // List all muscle groups except the currently selected primary. Use
                    // toggles to allow multiple selections. Tapping a toggle adds or
                    // removes the group from the secondarySelections set.
                    ForEach(muscleGroups.filter { $0 != selectedMuscle }, id: \ .self) { group in
                        Toggle(group, isOn: Binding(
                            get: { secondarySelections.contains(group) },
                            set: { isOn in
                                if isOn {
                                    secondarySelections.insert(group)
                                } else {
                                    secondarySelections.remove(group)
                                }
                            }
                        ))
                    }
                }
                Section(header: Text("Notes")) {
                    // Multiline text editor for notes. Using TextEditor
                    // instead of TextField allows users to enter more
                    // descriptive cues without the text scrolling off
                    // screen. The frame limits height to a few lines.
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                }
            }
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let exercise = exercise {
                name = exercise.name
                // Set the primary muscle to the stored muscles value if present,
                // otherwise use the first muscle group as default.
                if let primary = exercise.muscles, !primary.isEmpty {
                    selectedMuscle = primary
                } else {
                    selectedMuscle = muscleGroups.first ?? "Chest"
                }
                // Load secondary muscles from the model. If the primary appears in
                // secondary, remove it to avoid duplication.
                if let secs = exercise.secondaryMuscles {
                    secondarySelections = Set(secs).subtracting([selectedMuscle])
                }
                // Load existing notes when editing
                notes = exercise.notes ?? ""
            } else {
                // Set default primary to the first group when creating a new exercise
                selectedMuscle = muscleGroups.first ?? "Chest"
            }
        }
    }

    private func save() {
        let target: Exercise
        if let exercise = exercise {
            target = exercise
        } else {
            target = Exercise(context: viewContext)
            target.id = UUID()
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        // Save primary and secondary muscle selections. Primary is stored in the
        // `muscles` attribute and secondary groups are stored in the
        // `secondaryMuscles` transformable array. Remove any occurrence of the
        // primary from secondary to avoid duplication.
        target.muscles = selectedMuscle
        let secs = Array(secondarySelections.subtracting([selectedMuscle]))
        target.secondaryMuscles = secs.isEmpty ? nil : secs
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to save exercise: \(error)")
        }
    }
}