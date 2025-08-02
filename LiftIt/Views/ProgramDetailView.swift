import SwiftUI
import CoreData

/// Displays the details of a workout program, grouped by sequential day
/// index. Each day shows the exercises in their defined order along
/// with sets, rep range and weight goal. Editing of program
/// definition is not supported here.
struct ProgramDetailView: View {
    @ObservedObject var program: WorkoutProgram

    // Access to the managed object context for saving edits.
    @Environment(\.managedObjectContext) private var viewContext
    
    // Groups the program exercises first by day index and then by the originating
    // template name. Within each template group, exercises remain sorted by their
    // order value. The returned array preserves the relative ordering of
    // templates within a day as created when the program was assembled.
    private var groupedByDayAndTemplate: [(dayIndex: Int16, groups: [(templateName: String, exercises: [ProgramExercise])]) ] {
        // sort by day and order
        let list = (program.programExercises ?? []).sorted {
            if $0.dayIndex != $1.dayIndex { return $0.dayIndex < $1.dayIndex }
            return $0.order < $1.order
        }
        var result: [(Int16, [(String, [ProgramExercise])])] = []
        var currentDay: Int16? = nil
        var groups: [(String, [ProgramExercise])] = []
        var currentTemplateName: String? = nil
        var currentExercises: [ProgramExercise] = []
        for pe in list {
            if currentDay == nil || pe.dayIndex != currentDay {
                // flush previous day
                if let cd = currentDay {
                    if let templateName = currentTemplateName {
                        groups.append((templateName, currentExercises))
                    }
                    result.append((cd, groups))
                }
                // start new day
                currentDay = pe.dayIndex
                groups = []
                currentTemplateName = pe.templateName ?? "Workout"
                currentExercises = [pe]
            } else {
                // same day
                let tName = pe.templateName ?? "Workout"
                if currentTemplateName == nil {
                    currentTemplateName = tName
                    currentExercises = [pe]
                } else if tName == currentTemplateName {
                    currentExercises.append(pe)
                } else {
                    // template name changed -> flush previous group
                    if let ct = currentTemplateName {
                        groups.append((ct, currentExercises))
                    }
                    currentTemplateName = tName
                    currentExercises = [pe]
                }
            }
        }
        // flush final group
        if let cd = currentDay {
            if let ct = currentTemplateName {
                groups.append((ct, currentExercises))
            }
            result.append((cd, groups))
        }
        return result
    }

    /// Tracks which template groups are expanded in the UI. Keys are composed of
    /// the day index and template name to uniquely identify each group across
    /// days.
    @State private var expandedGroupKeys: Set<String> = []

    /// Edit mode environment value, used to toggle between viewing and editing states.
    /// When active, the list allows moving and deleting of template groups within each day.
    @Environment(\.editMode) private var editMode

    /// Deletes an entire template group (i.e. all program exercises belonging to the same template) on a given day.
    /// After deletion, the remaining exercises are renumbered to preserve order.
    private func deleteTemplateGroup(dayIndex: Int16, templateName: String) {
        // Delete all program exercises in this day that belong to the specified template
        let toDelete = (program.programExercises ?? []).filter { $0.dayIndex == dayIndex && ($0.templateName ?? "Workout") == templateName }
        for pe in toDelete {
            viewContext.delete(pe)
        }
        // Renumber the remaining exercises on this day
        var remaining = (program.programExercises ?? []).filter { $0.dayIndex == dayIndex && ($0.templateName ?? "Workout") != templateName }
            .sorted { $0.order < $1.order }
        for (idx, ex) in remaining.enumerated() {
            ex.order = Int16(idx)
        }
        saveChanges()
    }

    /// Reorders template groups within a day. Moves groups from the source offsets to the destination
    /// index and recalculates the `order` values for all program exercises on that day.
    private func moveTemplateGroup(dayIndex: Int16, from source: IndexSet, to destination: Int) {
        // Build current groups for this day from the program's exercises, preserving order
        let exercisesForDay = (program.programExercises ?? []).filter { $0.dayIndex == dayIndex }.sorted { $0.order < $1.order }
        // Group exercises by their template names in order
        var groups: [(templateName: String, exercises: [ProgramExercise])] = []
        var currentName: String? = nil
        var currentExercises: [ProgramExercise] = []
        for pe in exercisesForDay {
            let name = pe.templateName ?? "Workout"
            if currentName == nil {
                currentName = name
                currentExercises = [pe]
            } else if name == currentName {
                currentExercises.append(pe)
            } else {
                if let cn = currentName {
                    groups.append((cn, currentExercises))
                }
                currentName = name
                currentExercises = [pe]
            }
        }
        if let cn = currentName {
            groups.append((cn, currentExercises))
        }
        // Perform the move
        groups.move(fromOffsets: source, toOffset: destination)
        // Flatten and update order numbers
        var order: Int16 = 0
        for group in groups {
            for pe in group.exercises {
                pe.order = order
                order += 1
            }
        }
        saveChanges()
    }

    /// Saves the managed object context, capturing any potential errors.
    private func saveChanges() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save program edits: \(error)")
        }
    }

    /// Controls whether the add workout sheet is presented. When true, a sheet
    /// is shown allowing the user to insert a new workout (template) into
    /// the program. The sheet uses `AddWorkoutView` for its UI.
    ///
    /// When this view is presented inside a `ProgramDetailTabsView`, the
    /// parent wrapper supplies its own add button and manages presentation
    /// of the sheet. In that context this state is unused but must still
    /// exist to satisfy the binding used in the sheet modifier below.
    @State private var showingAddWorkout: Bool = false
    
    var body: some View {
        List {
            // Iterate through each day and its template groups
            ForEach(groupedByDayAndTemplate, id: \ .dayIndex) { dayGroup in
                Section(header: Text("Day \(dayGroup.dayIndex)")) {
                    // Use indices when editing so that onMove/onDelete operate on the correct group index
                    ForEach(Array(dayGroup.groups.enumerated()), id: \ .element.templateName) { index, tpl in
                        // A collapsible group for each originating template. When collapsed, only
                        // the template name is visible. When expanded, the exercises appear beneath.
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: {
                                    expandedGroupKeys.contains("\(dayGroup.dayIndex)_\(tpl.templateName)")
                                },
                                set: { newValue in
                                    let key = "\(dayGroup.dayIndex)_\(tpl.templateName)"
                                    if newValue {
                                        expandedGroupKeys.insert(key)
                                    } else {
                                        expandedGroupKeys.remove(key)
                                    }
                                }
                            ),
                            content: {
                                // Use the program exercise's UUID as the identifier for each row.
                                ForEach(tpl.exercises, id: \.id) { pe in
                                    VStack(alignment: .leading) {
                                        Text(pe.exercise?.name ?? "Exercise")
                                            .font(.headline)
                                        Text("Sets: \(pe.sets), reps \(pe.repMin)–\(pe.repMax), goal \(String(format: "%.1f", pe.weightGoal)) kg")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        if let notes = pe.exercise?.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            },
                            label: {
                                Text(tpl.templateName)
                                    .font(.headline)
                            }
                        )
                    }
                    .onDelete { offsets in
                        // Delete each selected group by name. Use `dayGroup.groups` to find the template names.
                        for offset in offsets {
                            let tplName = dayGroup.groups[offset].templateName
                            deleteTemplateGroup(dayIndex: dayGroup.dayIndex, templateName: tplName)
                        }
                    }
                    .onMove { source, destination in
                        moveTemplateGroup(dayIndex: dayGroup.dayIndex, from: source, to: destination)
                    }
                }
            }
        }
        .navigationTitle(program.name)
        // The add and edit controls are supplied by the parent `ProgramDetailTabsView` when
        // this view is displayed inside a tabbed container. If this view is used on its own
        // (outside of `ProgramDetailTabsView`) the navigation bar will show no controls by
        // default. The sheet modifier remains here to allow the parent wrapper to toggle
        // presentation via the binding, but the `.navigationBarItems` call has been removed
        // to prevent duplicate buttons when wrapped.
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutView(program: program)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}