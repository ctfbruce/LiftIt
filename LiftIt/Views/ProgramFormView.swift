import SwiftUI
import CoreData

/// Form for creating or editing a workout program. Users provide a
/// program name, select how many days the program has, choose up to
/// two templates per day and enter starting weight goals for each
/// exercise in the selected templates. On save, the form constructs
/// the corresponding `ProgramExercise` objects and persists them.
struct ProgramFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    var program: WorkoutProgram?

    @State private var name: String = ""
    @State private var daysCount: Int = 1
    // For each day, store up to two selected templates. Each subarray has exactly 2 entries (some may be nil).
    @State private var selectedTemplates: [[WorkoutTemplate?]] = []
    // Map of keys "dayIndex_uuid" to weight string input
    @State private var weightInputs: [String: String] = [:]

    @FetchRequest(
        entity: WorkoutTemplate.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutTemplate.name, ascending: true)]
    ) private var templates: FetchedResults<WorkoutTemplate>

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Program")) {
                    TextField("Name", text: $name)
                }
                Section(header: Text("Days")) {
                    Stepper(value: $daysCount, in: 1...7, onEditingChanged: { _ in
                        adjustSelectedTemplatesArray()
                    }) {
                        Text("Number of days: \(daysCount)")
                    }
                }
                ForEach(0..<daysCount, id: \.self) { dayIndex in
                    DaySectionView(
                        dayIndex: dayIndex,
                        selectedTemplates: $selectedTemplates,
                        templates: templates,
                        weightInputs: $weightInputs,
                        keyFor: keyFor,
                        clearWeightInputs: clearWeightInputs
                    )
                }
            }
            .navigationTitle(program == nil ? "New Program" : "Edit Program")
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
            .onAppear {
                if let program = program {
                    // Editing existing program: basic prefill
                    name = program.name
                    // NOTE: editing of selectedTemplates / weights is not implemented fully
                }
                adjustSelectedTemplatesArray()
            }
        }
    }

    /// Ensures that the selectedTemplates array matches the number of days
    /// whenever the user adjusts the daysCount. Initializes new days
    /// with two nil entries.
    private func adjustSelectedTemplatesArray() {
        if selectedTemplates.count < daysCount {
            for _ in selectedTemplates.count..<daysCount {
                selectedTemplates.append([nil, nil])
            }
        } else if selectedTemplates.count > daysCount {
            selectedTemplates.removeLast(selectedTemplates.count - daysCount)
        }
    }

    /// Clears any stored weight inputs for a given day and template slot.
    private func clearWeightInputs(forDay dayIndex: Int, slot: Int) {
        // Remove keys matching this day and template exercise ids
        weightInputs = weightInputs.filter { !($0.key.hasPrefix("\(dayIndex)_")) }
    }

    /// Generates a unique key string for storing weight input for a specific
    /// template exercise on a given day. The key concatenates the day
    /// index and the UUID string to avoid collisions.
    private func keyFor(day: Int, teID: UUID) -> String {
        return "\(day)_\(teID.uuidString)"
    }

    private func save() {
        // Create new program only; editing existing program is not fully supported here
        let prog: WorkoutProgram
        if let program = program {
            prog = program
            // Remove existing exercises for simplicity
            if let existingExercises = prog.programExercises {
                for ex in existingExercises {
                    viewContext.delete(ex)
                }
            }
        } else {
            prog = WorkoutProgram(context: viewContext)
            prog.id = UUID()
        }
        prog.name = name.trimmingCharacters(in: .whitespaces)
        prog.currentDayIndex = 1

        // Build program exercises
        var dayIndex: Int16 = 1
        for day in selectedTemplates.prefix(daysCount) {
            var order: Int16 = 0
            for template in day.compactMap({ $0 }) {
                let teList = (template.templateExercises ?? []).sorted { $0.order < $1.order }
                for te in teList {
                    let pe = ProgramExercise(context: viewContext)
                    pe.id = UUID()
                    pe.dayIndex = dayIndex
                    pe.order = order
                    pe.sets = te.sets
                    pe.repMin = te.repMin
                    pe.repMax = te.repMax
                    pe.repGoal = te.repMax
                    // Determine weight goal
                    let key = keyFor(day: Int(dayIndex - 1), teID: te.id)
                    let weightString = weightInputs[key] ?? ""
                    let weight = Double(weightString) ?? 0.0
                    pe.weightGoal = weight
                    pe.consecutiveMisses = 0
                    pe.exercise = te.exercise
                    pe.program = prog
                    // Preserve template name for grouping in ProgramDetailView
                    pe.templateName = template.name
                    order += 1
                }
            }
            dayIndex += 1
        }

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to save program: \(error)")
        }
    }
}

/// Subview representing a single day's section with template pickers and
/// starting weight inputs.
private struct DaySectionView: View {
    let dayIndex: Int
    @Binding var selectedTemplates: [[WorkoutTemplate?]]
    var templates: FetchedResults<WorkoutTemplate>
    @Binding var weightInputs: [String: String]
    var keyFor: (Int, UUID) -> String
    var clearWeightInputs: (Int, Int) -> Void

    var body: some View {
        Section(header: Text("Day \(dayIndex + 1)")) {
            // Template selection slots
            ForEach(0..<2, id: \.self) { slot in
                Picker("Template \(slot+1)", selection: templateBinding(slot: slot)) {
                    Text("None").tag(Optional<WorkoutTemplate>.none)
                    ForEach(templates, id: \.id) { template in
                        Text(template.name).tag(Optional(template))
                    }
                }
            }

            // Weight inputs for each selected template
            ForEach(0..<2, id: \.self) { slot in
                if let template = templateFor(slot: slot) {
                    let exers = (template.templateExercises ?? []).sorted { $0.order < $1.order }
                    ForEach(exers, id: \.id) { te in
                        HStack {
                            Text("\(te.exercise?.name ?? "Exercise") weight")
                            Spacer()
                            TextField("kg", text: weightBinding(teID: te.id))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }
            }
        }
    }

    private func templateFor(slot: Int) -> WorkoutTemplate? {
        guard selectedTemplates.indices.contains(dayIndex),
              selectedTemplates[dayIndex].indices.contains(slot) else {
            return nil
        }
        return selectedTemplates[dayIndex][slot]
    }

    private func templateBinding(slot: Int) -> Binding<WorkoutTemplate?> {
        Binding(
            get: {
                templateFor(slot: slot)
            },
            set: { newValue in
                if !selectedTemplates.indices.contains(dayIndex) {
                    // Safety: expand outer array if needed (should be maintained by parent)
                    while selectedTemplates.count <= dayIndex {
                        selectedTemplates.append([nil, nil])
                    }
                }
                if selectedTemplates[dayIndex].count < 2 {
                    selectedTemplates[dayIndex] = [nil, nil]
                }
                selectedTemplates[dayIndex][slot] = newValue
                clearWeightInputs(dayIndex, slot)
            }
        )
    }

    private func weightBinding(teID: UUID) -> Binding<String> {
        let key = keyFor(dayIndex, teID)
        return Binding(
            get: { weightInputs[key] ?? "" },
            set: { weightInputs[key] = $0 }
        )
    }
}

// MARK: - Safe index subscript on array
extension Array {
    /// Safely returns the element at `index` if it’s in bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
