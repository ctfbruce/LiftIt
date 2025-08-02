import SwiftUI
import CoreData

final class WorkoutTimer: ObservableObject {
    @Published var elapsedSeconds: Int = 0
    private var startTime: Date?
    private var timer: Timer?

    func start() {
        if startTime == nil {
            startTime = Date()
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        startTime = nil
        elapsedSeconds = 0
        timer?.invalidate()
        timer = nil
    }
}


/// View for performing a workout session for a given program on its
/// current day. Displays the exercises in order with input fields for
/// each set's weight and reps. When the user taps Save, a
/// `WorkoutSession` and `SessionExercise` objects are created and the
/// progression algorithm updates the corresponding `ProgramExercise`
/// records. The program's `currentDayIndex` is advanced.
struct WorkoutSessionView: View {
    @ObservedObject var program: WorkoutProgram
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    /// Holds per-exercise input state keyed by the `ProgramExercise` id. Each
    /// `ExerciseEntry` now tracks which sets have been marked as completed via
    /// the checkmark button. Set completion is independent of the text field
    /// highlights used for goal checking.
    @State private var inputs: [UUID: ExerciseEntry] = [:]

    /// Track the current color scheme so that highlight colours can adapt
    /// automatically to light and dark modes. Dark mode uses a slightly
    /// more opaque overlay for better contrast.
    @Environment(\.colorScheme) private var colorScheme

    /// Remaining seconds on the active rest timer, if any. When nil no timer
    /// is running. The timer counts down to zero once started.
    @State private var restSecondsRemaining: Int? = nil
    /// Internal timer instance used for counting down the rest period.
    @State private var restTimer: Timer? = nil

    @StateObject private var workoutTimer = WorkoutTimer()

    /// Flag controlling display of the post‑workout summary sheet. When
    /// toggled on, a sheet appears showing an overview of the sets, reps
    /// and weights recorded during the session. The user can dismiss
    /// the sheet via a button to return to the previous screen.
    @State private var showSummary: Bool = false
    /// Data model driving the summary sheet. Each entry contains the
    /// exercise name, per‑set weights and reps performed, and total
    /// volume. The summary is built in `saveWorkout()` before the
    /// Core Data changes are committed.
    @State private var summaryEntries: [SummaryEntry] = []

    /// Key used to persist current workout inputs for this program. When the user
    /// switches away from the workout tab, the input state is saved to
    /// `UserDefaults` and restored on reappear. The key embeds the program ID
    /// to avoid collisions across multiple programs.
    private var persistenceKey: String {
        // Build a unique key per program, day and template slot to ensure that
        // in‑progress inputs are restored correctly when switching between
        // multiple workouts on the same day.
        return "currentInputs_\(program.id.uuidString)_\(program.currentDayIndex)_\(program.currentTemplateSlot)"
    }
    
    /// Computed list of exercises for the program's current day and template slot. When a day
    /// contains multiple workouts (template groups), only the exercises for the currently
    /// scheduled template are returned. The groups are ordered by their appearance in the
    /// program definition, and `program.currentTemplateSlot` determines which group to use.
    private var todaysExercises: [ProgramExercise] {
        let day = program.currentDayIndex
        // Fetch all exercises for the current day sorted by their order value
        let dayExercises = (program.programExercises ?? [])
            .filter { $0.dayIndex == day }
            .sorted { $0.order < $1.order }
        // Determine the distinct template names for this day in order of appearance
        var groupNames: [String] = []
        var lastName: String? = nil
        for pe in dayExercises {
            let name = pe.templateName ?? "Workout"
            if lastName == nil || name != lastName {
                groupNames.append(name)
                lastName = name
            }
        }
        // Guard against empty days
        guard !groupNames.isEmpty else { return [] }
        // Determine which group to show based on currentTemplateSlot
        let slot = Int(program.currentTemplateSlot)
        let index = min(slot, groupNames.count - 1)
        let selectedName = groupNames[index]
        return dayExercises.filter { ($0.templateName ?? "Workout") == selectedName }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Display the elapsed workout duration at the top of the session. The
            // time updates every second while the session is active. Use a more
            // prominent headline and prefix the timer with a status message.
            HStack {
                Text("Workout in progress – \(formattedTime(workoutTimer.elapsedSeconds))")
                    .font(.headline)
                    .padding([.top, .horizontal])
                Spacer()
            }
            List {
            // Provide an identifier for each program exercise using its UUID
            ForEach(todaysExercises, id: \.id) { pe in
                Section(header: headerView(for: pe)) {
                    Text("Goal: \(String(format: "%.1f", pe.weightGoal)) kg x \(pe.repGoal) reps (range \(pe.repMin)–\(pe.repMax))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    // Each exercise's entry is keyed by its non‑optional UUID.
                    if let entry = inputs[pe.id] {
                        ForEach(0..<Int(pe.sets), id: \.self) { setIndex in
                            SetRow(pe: pe, entry: entry, setIndex: setIndex, inputs: $inputs, highlightColor: highlightColor)
                        }
                    }
                }
            }
            }
            // Provide a cancel button at the bottom of the session. This allows the
            // user to discard the current workout without saving progress. The
            // button spans the full width and uses a destructive role to
            // emphasise the action.
            Button(role: .destructive) {
                cancelWorkout()
            } label: {
                HStack {
                    Spacer()
                    Text("Cancel Workout")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .padding()
        }
        // Draw a thin green outline around the workout session to visually
        // indicate that a workout is active. The border sits outside of
        // the content and follows the device edges.
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green, lineWidth: 2)
        )
        .navigationTitle("Workout Day \(program.currentDayIndex)")
        .toolbar {
            // Show the remaining rest timer on the leading side when active.
            ToolbarItem(placement: .navigationBarLeading) {
                if let seconds = restSecondsRemaining {
                    Text("Rest: \(formattedTime(seconds))")
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
            // Provide a menu to start a rest timer. Users can select from 1, 2 or 3 minute durations.
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("1 min", action: { startRestTimer(seconds: 60) })
                    Button("2 min", action: { startRestTimer(seconds: 120) })
                    Button("3 min", action: { startRestTimer(seconds: 180) })
                } label: {
                    Label("Rest Timer", systemImage: "timer")
                }
            }
            // Replace the generic Save button with a Finish button to more
            // clearly indicate the end of the workout. This triggers the
            // standard save logic.
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish", action: saveWorkout)
            }
        }
        // Persist input state when the view disappears so that users can
        // switch tabs without losing their progress. Inputs are restored on
        // reappear via setupEntries().

        .onAppear {
            // Initialize input state and start the workout timer
            setupEntries()
            workoutTimer.start()
        }

        .onDisappear {
            // Persist inputs; don’t stop the timer so elapsed time survives transient navigation.
            persistInputs()
        }
        // Present a summary sheet when the workout finishes. The summary lists
        // each exercise with the weights, reps and total volume performed. A
        // button dismisses the sheet and returns to the previous screen.
        .sheet(isPresented: $showSummary) {
            NavigationView {
                List {
                    ForEach(summaryEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.headline)
                            ForEach(0..<entry.setWeights.count, id: \ .self) { idx in
                                let w = entry.setWeights[idx]
                                let r = entry.setReps[idx]
                                Text("Set \(idx+1): \(String(format: "%.1f", w)) kg × \(r) reps")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text("Total Volume: \(String(format: "%.1f", entry.totalVolume))")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Workout Summary")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showSummary = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    /// Initializes input state for each program exercise on this day.
    private func setupEntries() {
        // Attempt to load any persisted inputs from UserDefaults. If none
        // exist for this program, an empty dictionary is returned.
        let saved = loadSavedEntries()
        var dict: [UUID: ExerciseEntry] = [:]
        for pe in todaysExercises {
            // Each program exercise has a non‑optional UUID, use it directly as the key
            let key = pe.id
            let sets = Int(pe.sets)
            if let savedEntry = saved[key] {
                // Clip or extend saved arrays to the current number of sets
                var weights = savedEntry.weightPerformed
                var reps = savedEntry.repsPerformed
                if weights.count < sets { weights.append(contentsOf: Array(repeating: "", count: sets - weights.count)) }
                if reps.count < sets { reps.append(contentsOf: Array(repeating: "", count: sets - reps.count)) }
                if weights.count > sets { weights = Array(weights.prefix(sets)) }
                if reps.count > sets { reps = Array(reps.prefix(sets)) }
                dict[key] = ExerciseEntry(programExercise: pe, weightPerformed: weights, repsPerformed: reps, completedSets: [])
            } else {
                // Prefill each set with the current weight and rep goals. Users can
                // overwrite these values during the session. The weight is
                // formatted with one decimal place for consistency. If you
                // prefer blank fields on first launch, replace the following
                // lines with empty strings as before.
                let weightString = String(format: "%.1f", pe.weightGoal)
                let repString = String(Int(pe.repGoal))
                let weightArray = Array(repeating: weightString, count: sets)
                let repsArray = Array(repeating: repString, count: sets)
                dict[key] = ExerciseEntry(programExercise: pe, weightPerformed: weightArray, repsPerformed: repsArray, completedSets: [])
            }
        }
        inputs = dict
    }
    
    /// Handles the save action: records a session and updates the program
    /// exercises using the progression algorithm. Also advances the
    /// program's current day index.
    private func saveWorkout() {
        // Assemble a new workout session. Also collect summary information
        // per exercise before making any changes to the program exercises. The
        // summary will be displayed to the user after the workout is saved.
        var newSummary: [SummaryEntry] = []
        let session = WorkoutSession(context: viewContext)
        session.id = UUID()
        session.date = Date()
        session.program = program

        // Highest defined day index to wrap after completion
        let maxDay = (program.programExercises ?? []).map { $0.dayIndex }.max() ?? program.currentDayIndex

        for pe in todaysExercises {
            let peId = pe.id
            guard let entry = inputs[peId] else { continue }
            let sets = Int(pe.sets)
            var volumeActual: Double = 0
            let weightGoal = pe.weightGoal
            let repGoal = Int(pe.repGoal)
            var setWeights: [Double] = []
            var setReps: [Int] = []
            for i in 0..<sets {
                let weight = Double(entry.weightPerformed[i] ?? "") ?? weightGoal
                let reps = Int(entry.repsPerformed[i] ?? "") ?? repGoal
                volumeActual += weight * Double(reps)
                setWeights.append(weight)
                setReps.append(reps)
            }
            let volumeGoal = Double(sets) * pe.weightGoal * Double(pe.repGoal)
            // Last set values (fallback to goal values)
            let lastWeight = setWeights.last ?? weightGoal
            let lastReps = setReps.last ?? repGoal

            // Record summary entry for this exercise
            let name = pe.exercise?.name ?? "Exercise"
            let summaryEntry = SummaryEntry(name: name, setWeights: setWeights, setReps: setReps, totalVolume: volumeActual)
            newSummary.append(summaryEntry)

            // Create session exercise record storing only the final set for history
            let se = SessionExercise(context: viewContext)
            se.id = UUID()
            se.session = session
            se.exercise = pe.exercise
            se.sets = Int16(sets)
            se.repGoal = pe.repGoal
            se.repsPerformed = Int16(lastReps)
            se.weightGoal = pe.weightGoal
            se.weightPerformed = lastWeight

            // Progression logic as before
            if volumeActual < volumeGoal {
                pe.consecutiveMisses += 1
                if pe.consecutiveMisses >= 3 {
                    pe.weightGoal *= 0.85 // 15% reduction
                    pe.consecutiveMisses = 0
                }
            } else {
                pe.consecutiveMisses = 0
                if lastReps >= repGoal {
                    if pe.repGoal < pe.repMax {
                        pe.repGoal += 1
                    } else {
                        pe.weightGoal += 2.5
                        pe.repGoal = pe.repMin
                    }
                }
            }
        }

        // Advance the template slot and day index as needed. If there are multiple
        // template groups on the current day, cycle through them before moving
        // to the next day.
        let day = program.currentDayIndex
        let dayExercises = (program.programExercises ?? []).filter { $0.dayIndex == day }.sorted { $0.order < $1.order }
        var groupNames: [String] = []
        var lastName: String? = nil
        for pe in dayExercises {
            let name = pe.templateName ?? "Workout"
            if lastName == nil || name != lastName {
                groupNames.append(name)
                lastName = name
            }
        }
        let totalGroups = groupNames.count
        if program.currentTemplateSlot < Int16(max(totalGroups - 1, 0)) {
            program.currentTemplateSlot += 1
        } else {
            program.currentTemplateSlot = 0
            if program.currentDayIndex >= maxDay {
                program.currentDayIndex = 1
            } else {
                program.currentDayIndex += 1
            }
        }

        do {
            try viewContext.save()
            // Remove any persisted inputs now that the session has been recorded
            UserDefaults.standard.removeObject(forKey: persistenceKey)
            // Populate the summary state and present the summary sheet. The
            // dismissal of this view occurs when the summary sheet is closed.
            workoutTimer.stop()
            summaryEntries = newSummary
            showSummary = true
        } catch {
            print("Error saving workout: \(error)")
        }
    }

    /// Loads persisted entries from UserDefaults, keyed by program and exercise ID. The returned dictionary
    /// maps ProgramExercise UUIDs to ExerciseEntry instances. If no saved data exists, an empty dictionary is returned.
    private func loadSavedEntries() -> [UUID: ExerciseEntry] {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return [:] }
        // The saved format is [String: SavedData], keyed by exercise UUID string. It decodes to a
        // structure containing arrays of weight and rep strings. We rewrap into ExerciseEntry objects below.
        guard let decoded = try? JSONDecoder().decode([String: SavedData].self, from: data) else { return [:] }
        var result: [UUID: ExerciseEntry] = [:]
        for (keyString, saved) in decoded {
            if let uuid = UUID(uuidString: keyString), let pe = todaysExercises.first(where: { $0.id == uuid }) {
                result[uuid] = ExerciseEntry(programExercise: pe, weightPerformed: saved.weights, repsPerformed: saved.reps)
            }
        }
        return result
    }

    /// Persists the current inputs to UserDefaults. Called when the view disappears so that
    /// the user can leave the workout tab and return later without losing progress.
    private func persistInputs() {
        var encoded: [String: SavedData] = [:]
        for (uuid, entry) in inputs {
            encoded[uuid.uuidString] = SavedData(weights: entry.weightPerformed, reps: entry.repsPerformed)
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    /// Builds the header view for an exercise section. It displays the exercise name and its
    /// notes, if any, together in a vertical stack. Without this helper the header builder
    /// becomes unwieldy inline. The header is recomputed on every call to satisfy SwiftUI’s
    /// requirement that views are value types.
    private func headerView(for pe: ProgramExercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pe.exercise?.name ?? "Exercise")
                .font(.headline)
            if let notes = pe.exercise?.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
    }

    /// Internal structure used to persist arrays of weights and reps for a single exercise.
    /// Conformance to Codable allows storage in UserDefaults via JSON encoding.
    private struct SavedData: Codable {
        var weights: [String]
        var reps: [String]
    }

    /// Represents a completed exercise in the post‑workout summary. Stores
    /// the exercise name, a list of per‑set weights and reps that were
    /// performed, and the total training volume (weight × reps summed
    /// across sets). The summary sheet displays these values for the
    /// user after finishing a session.
    private struct SummaryEntry: Identifiable {
        var id = UUID()
        var name: String
        var setWeights: [Double]
        var setReps: [Int]
        var totalVolume: Double
    }

    // MARK: - Highlight Colour
    /// Determines the colour used for highlighting weight and rep text fields when
    /// goals are met. Dark mode uses a slightly higher opacity for legibility.
    private var highlightColor: Color {
        let baseOpacity: Double = colorScheme == .dark ? 0.5 : 0.3
        return Color.green.opacity(baseOpacity)
    }

    // MARK: - Rest Timer Utilities
    /// Starts a rest timer with the given duration in seconds. Any existing timer
    /// is cancelled. While active, the remaining time is displayed in the toolbar.
    private func startRestTimer(seconds: Int) {
        restTimer?.invalidate()
        restSecondsRemaining = seconds
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let current = restSecondsRemaining {
                if current <= 1 {
                    // Timer completed
                    restSecondsRemaining = nil
                    timer.invalidate()
                } else {
                    restSecondsRemaining = current - 1
                }
            } else {
                timer.invalidate()
            }
        }
    }

    /// Formats a number of seconds into `m:ss` string. E.g. 90 -> "1:30".
    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Cancels the current workout session without saving any progress. This removes
    /// any persisted input state for the active session, invalidates running timers
    /// and dismisses the view. Users can use this action to abort a workout and
    /// return to the previous screen without modifying their program data.
    private func cancelWorkout() {
        // Remove any saved inputs for this session so that returning later starts fresh
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        // Invalidate timers if running
        workoutTimer.stop()
        restTimer?.invalidate()
        restTimer = nil
        // Dismiss this view
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - SetRow

/// A view representing a single set row within the workout session. It handles
/// weight and reps input fields, conditional highlighting when goals are met,
/// and a completion toggle. Extracting this into its own view reduces
/// complexity in `WorkoutSessionView.body` and improves compile times.
private struct SetRow: View {
    let pe: ProgramExercise
    let entry: ExerciseEntry
    let setIndex: Int
    @Binding var inputs: [UUID: ExerciseEntry]
    let highlightColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(setIndex + 1)")
                .frame(maxWidth: .infinity, alignment: .leading)
            // Weight text field with conditional highlighting when the entered
            // weight meets or exceeds the weight goal. Only the text field's
            // background turns green rather than the entire row.
            let weightString = entry.weightPerformed[setIndex] ?? ""
            let weightValue = Double(weightString) ?? 0
            let weightGoalReached = weightValue >= pe.weightGoal && weightValue > 0
            TextField("Weight", text: Binding(
                get: { entry.weightPerformed[setIndex] ?? "" },
                set: { newValue in
                    inputs[pe.id]?.weightPerformed[setIndex] = newValue
                }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .padding(4)
            .background(weightGoalReached ? highlightColor : Color.clear)
            .cornerRadius(4)
            // Reps text field with conditional highlighting when the reps
            // meet or exceed the target rep goal.
            let repsString = entry.repsPerformed[setIndex] ?? ""
            let repsValue = Int(repsString) ?? 0
            let repGoalReached = repsValue >= Int(pe.repGoal) && repsValue > 0
            TextField("Reps", text: Binding(
                get: { entry.repsPerformed[setIndex] ?? "" },
                set: { newValue in
                    inputs[pe.id]?.repsPerformed[setIndex] = newValue
                }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 50)
            .padding(4)
            .background(repGoalReached ? highlightColor : Color.clear)
            .cornerRadius(4)
            // Completion checkmark button. Tapping toggles the set’s completed
            // status. A set can only be marked complete when both weight
            // and reps fields are filled; otherwise tapping does nothing.
            Button(action: {
                let w = entry.weightPerformed[setIndex] ?? ""
                let r = entry.repsPerformed[setIndex] ?? ""
                if !w.trimmingCharacters(in: .whitespaces).isEmpty && !r.trimmingCharacters(in: .whitespaces).isEmpty {
                    if inputs[pe.id]?.completedSets.contains(setIndex) == true {
                        inputs[pe.id]?.completedSets.remove(setIndex)
                    } else {
                        inputs[pe.id]?.completedSets.insert(setIndex)
                    }
                }
            }) {
                let isDone = inputs[pe.id]?.completedSets.contains(setIndex) ?? false
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isDone ? .green : .secondary)
            }
        }
    }
}

/// Helper struct representing a per-exercise entry for user input.
private struct ExerciseEntry {
    var programExercise: ProgramExercise
    /// Text field entries for weight values per set. The count matches the number of
    /// sets in the `programExercise`.
    var weightPerformed: [String]
    /// Text field entries for repetition counts per set. The count matches the
    /// number of sets in the `programExercise`.
    var repsPerformed: [String]
    /// Indices of sets that the user has explicitly marked as completed. Tapping
    /// the checkmark button toggles a set’s completion state. Completion is
    /// independent of whether the weight/rep goals are met; users can mark a
    /// set as done even if they undershoot or overshoot.
    var completedSets: Set<Int> = []
}

// MARK: - Safe index subscript on Array
// Note: A safe array subscript is defined globally in Array+Safe.swift so it
// should not be redeclared here. Removing this extension avoids duplicate
// symbol errors.
