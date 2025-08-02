import SwiftUI
import CoreData

/// A view for adding an additional workout (template) to an existing program.
/// The user chooses which day to insert the workout on, selects a template
/// from the list of available templates, and optionally enters starting
/// weight goals for each exercise in the selected template. Upon saving,
/// the selected template's exercises are duplicated into `ProgramExercise`
/// records on the chosen day. The new exercises are appended after any
/// existing template groups for that day and are assigned the next order
/// numbers. Rep goals default to the template's maximum reps and sets,
/// rep ranges and exercise assignments mirror the template definition.
struct AddWorkoutView: View {
    /// The program we are adding a workout to. Passed in from the
    /// presenting view.
    @ObservedObject var program: WorkoutProgram
    /// Managed object context for saving changes.
    @Environment(\.managedObjectContext) private var viewContext
    /// Presentation mode for dismissing the sheet on completion.
    @Environment(\.presentationMode) private var presentationMode
    
    /// Index of the day (zero‑based) that the new workout should be inserted
    /// on. This maps to the program's `dayIndex` which is one‑based in
    /// persisted data. Days run from 0 up to and including the last existing
    /// day (to append to a new day at the end).
    @State private var selectedDay: Int = 0
    /// The template chosen by the user for the new workout. When nil, the
    /// form cannot be saved.
    @State private var selectedTemplate: WorkoutTemplate? = nil
    /// Stores per‑exercise weight goal inputs keyed by the template exercise
    /// UUID. Users may leave fields blank to default to 0.0 kg.
    @State private var weightInputs: [UUID: String] = [:]
    
    /// Fetches all available templates sorted by name. We allow selection
    /// of any template defined in the app.
    @FetchRequest(
        entity: WorkoutTemplate.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutTemplate.name, ascending: true)]
    ) private var templates: FetchedResults<WorkoutTemplate>
    
    /// The highest day index currently present in the program. Programs
    /// store day indices starting at 1, so we map to zero‑based for the UI.
    private var maxExistingDayIndex: Int {
        let days = (program.programExercises ?? []).map { Int($0.dayIndex) }
        return (days.max() ?? 1) - 1
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Day")) {
                    Picker("Insert on Day", selection: $selectedDay) {
                        // List all existing days plus one extra to append a new day
                        ForEach(0...maxExistingDayIndex + 1, id: \ .self) { index in
                            Text("Day \(index + 1)").tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                Section(header: Text("Template")) {
                    Picker("Template", selection: $selectedTemplate) {
                        Text("Select Template").tag(Optional<WorkoutTemplate>(nil))
                        ForEach(templates) { tpl in
                            Text(tpl.name).tag(Optional(tpl))
                        }
                    }
                }
                // If a template is selected, present weight goal inputs for its exercises
                if let template = selectedTemplate {
                    Section(header: Text("Weight Goals (kg)")) {
                        // Sort template exercises by their order to mirror the template
                        let teList = (template.templateExercises ?? []).sorted { $0.order < $1.order }
                        ForEach(teList, id: \ .id) { te in
                            HStack {
                                Text(te.exercise?.name ?? "Exercise")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField("kg", text: Binding(
                                    get: { weightInputs[te.id] ?? "" },
                                    set: { weightInputs[te.id] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(selectedTemplate == nil)
                }
            }
        }
        .onAppear {
            // Initialize selected day to the first new day if the program has no exercises.
            // Otherwise, default to the last existing day.
            selectedDay = maxExistingDayIndex + 1
        }
    }
    
    /// Persists the new workout to the program. Duplicates the selected template's
    /// exercises into `ProgramExercise` records with appropriate day index and
    /// ordering. Weight goals come from user input (or 0.0 if blank) and
    /// rep goals default to the template's maximum reps. After saving, the
    /// sheet is dismissed.
    private func save() {
        guard let template = selectedTemplate else { return }
        // Determine the day index in the persisted model (1‑based)
        let targetDayIndex = Int16(selectedDay + 1)
        // Fetch all existing exercises on the target day to compute next order value
        let existingForDay = (program.programExercises ?? []).filter { $0.dayIndex == targetDayIndex }.sorted { $0.order < $1.order }
        var nextOrder: Int16 = (existingForDay.last?.order ?? -1) + 1
        // Iterate through the template's exercises in their defined order
        let teList = (template.templateExercises ?? []).sorted { $0.order < $1.order }
        for te in teList {
            let pe = ProgramExercise(context: viewContext)
            pe.id = UUID()
            pe.dayIndex = targetDayIndex
            pe.order = nextOrder
            nextOrder += 1
            pe.sets = te.sets
            pe.repMin = te.repMin
            pe.repMax = te.repMax
            pe.repGoal = te.repMax
            // Parse weight input; default to 0.0 if blank or invalid
            let weightString = weightInputs[te.id] ?? ""
            let weight = Double(weightString) ?? 0.0
            pe.weightGoal = weight
            pe.consecutiveMisses = 0
            pe.templateName = template.name
            pe.exercise = te.exercise
            pe.program = program
        }
        // Reset current template slot so the user starts with the first group on the new day
        program.currentTemplateSlot = 0
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to add workout: \(error)")
        }
    }
}