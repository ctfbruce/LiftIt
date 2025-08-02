import SwiftUI
import CoreData

/// Displays all exercises in the store as a list of cards. Users can
/// create new exercises or edit/delete existing ones. Selecting a
/// card brings up an edit sheet. Deleting uses the swipe-to-delete
/// gesture built into `List`.
struct ExercisesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Exercise.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)],
        animation: .default
    ) private var exercises: FetchedResults<Exercise>
    
    @State private var showingAddSheet = false
    @State private var selectedExercise: Exercise?
    /// Currently selected muscle group filter. When non‑nil, only exercises
    /// containing this group (as primary or secondary) are displayed. A nil
    /// value indicates no filtering.
    @State private var selectedGroup: String? = nil

    /// All muscle groups available for selection. Matches the list used in
    /// ExerciseFormView so users can consistently assign muscles and filter.
    private let allMuscleGroups: [String] = [
        "Bicep", "Tricep", "Chest", "Shoulder", "Hamstring", "Glute", "Core", "Quad", "Calves", "Lats", "Back"
    ]

    /// Computes the list of exercises to show based on the current filter
    /// selection. When a group is selected, exercises with that group as
    /// primary appear first, followed by exercises where it appears as
    /// secondary. Otherwise, all exercises are shown sorted by name.
    private var filteredExercises: [Exercise] {
        let all = Array(exercises)
        guard let group = selectedGroup else {
            return all
        }
        // Partition into primary and secondary matches
        var primaries: [Exercise] = []
        var secondaries: [Exercise] = []
        for ex in all {
            let primary = ex.muscles ?? ""
            let secs = ex.secondaryMuscles ?? []
            if primary == group {
                primaries.append(ex)
            } else if secs.contains(group) {
                secondaries.append(ex)
            }
        }
        // Sort both lists alphabetically by name
        primaries.sort { ($0.name) < ($1.name) }
        secondaries.sort { ($0.name) < ($1.name) }
        return primaries + secondaries
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Horizontal scroll of muscle group cards. Tapping a card toggles
                // the filter: selecting a group applies the filter; tapping again
                // clears it. The appearance reflects selection state.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allMuscleGroups, id: \ .self) { group in
                            Button(action: {
                                if selectedGroup == group {
                                    selectedGroup = nil
                                } else {
                                    selectedGroup = group
                                }
                            }) {
                                Text(group)
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .foregroundColor(selectedGroup == group ? .white : .primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedGroup == group ? Color.accentColor : Color.secondary.opacity(0.2))
                                    )
                            }
                        }
                    }
                    .padding([.horizontal, .top])
                }
                List {
                    // Provide an explicit identifier since `Exercise` does not conform
                    // to `Identifiable`. Use the exercise's UUID property for uniqueness.
                    ForEach(filteredExercises, id: \.id) { exercise in
                        Button(action: {
                            selectedExercise = exercise
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    // Show primary and secondary muscle groups. Primary in bold,
                                    // secondary comma‑separated.
                                    if let primary = exercise.muscles, !primary.isEmpty {
                                        let secs = exercise.secondaryMuscles ?? []
                                        let secondaryString = secs.joined(separator: ", ")
                                        Text(secondaryString.isEmpty ? primary : "\(primary) • \(secondaryString)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    // Display notes beneath the muscles when provided.
                                    if let notes = exercise.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteExercises)
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ExerciseFormView(exercise: nil)
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseFormView(exercise: exercise)
            }
        }
    }
    
    /// Deletes exercises from the context. Deleting an exercise cascades to
    /// related template/program/session exercises thanks to the delete
    /// rules defined in the data model.
    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            let exercise = exercises[index]
            viewContext.delete(exercise)
        }
        save()
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}