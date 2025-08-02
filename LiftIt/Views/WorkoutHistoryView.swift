import SwiftUI
import CoreData

/// Displays a history of all completed workout sessions. Each entry shows the
/// date, the program name, a brief summary (number of exercises and total
/// volume) and, optionally, the details for each exercise performed. This
/// screen allows you to look back at prior workouts and observe progress
/// across time.
struct WorkoutHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    // Fetch all sessions sorted by date descending
    @FetchRequest(
        entity: WorkoutSession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutSession.date, ascending: false)],
        animation: .default
    ) private var sessions: FetchedResults<WorkoutSession>
    
    // Tracks which sessions are expanded. Uses the session's UUID as the key.
    @State private var expandedSessionIDs: Set<UUID> = []

    var body: some View {
        NavigationView {
            List {
                // Provide an identifier for each session using its UUID. Without this,
                // SwiftUI requires the element type to conform to `Identifiable`.
                ForEach(sessions, id: \.id) { session in
                    // Use the session ID as a stable identifier for expansion state
                    DisclosureGroup(
                        isExpanded: Binding(
                            // Session IDs are non‑optional, so we can use them directly for lookups.
                            get: { expandedSessionIDs.contains(session.id) },
                            set: { newValue in
                                // No need for optional binding – `id` exists on all sessions.
                                if newValue {
                                    expandedSessionIDs.insert(session.id)
                                } else {
                                    expandedSessionIDs.remove(session.id)
                                }
                            }
                        ),
                        content: {
                            // Details: list each exercise performed during the session
                            ForEach(sessionExercises(session), id: \.id) { se in
                                // Determine if the performed set met the goal. A goal is
                                // considered met when both the weight and reps are at
                                // least the target values stored on the session exercise.
                                let goalMet = se.weightPerformed >= se.weightGoal && se.repsPerformed >= se.repGoal
                                VStack(alignment: .leading) {
                                    Text(se.exercise?.name ?? "Exercise")
                                        .font(.subheadline)
                                    Text("Weight: \(String(format: "%.1f", se.weightPerformed)) kg, Reps: \(se.repsPerformed)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                .listRowBackground(goalMet ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            }
                        },
                        label: {
                            VStack(alignment: .leading) {
                                Text(formattedDate(session.date))
                                    .font(.headline)
                                Text(session.program?.name ?? "Program")
                                    .font(.subheadline)
                                let summary = sessionSummary(session)
                                Text("Exercises: \(summary.count), Volume: \(String(format: "%.1f", summary.volume))")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                }
            }
            // Use an inset grouped style for the history list to give it a more
            // modern, card‑like appearance. This avoids the plain settings
            // look and instead groups sessions into visually distinct sections.
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("History")
        }
    }
    
    /// Formats a date to a human‑readable string. Uses the user’s locale.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Flattens the session’s exercises set into a sorted array. Exercises are sorted
    /// alphabetically by name for consistency.
    private func sessionExercises(_ session: WorkoutSession) -> [SessionExercise] {
        let arr = Array(session.sessionExercises ?? [])
        return arr.sorted { ($0.exercise?.name ?? "") < ($1.exercise?.name ?? "") }
    }
    
    /// Computes a simple summary consisting of the number of exercises and the total volume.
    /// Total volume = weight × reps for each exercise. If no exercises exist, returns zeros.
    private func sessionSummary(_ session: WorkoutSession) -> (count: Int, volume: Double) {
        let exercises = Array(session.sessionExercises ?? [])
        var volume: Double = 0
        for se in exercises {
            volume += se.weightPerformed * Double(se.repsPerformed)
        }
        return (exercises.count, volume)
    }
}

struct WorkoutHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutHistoryView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}