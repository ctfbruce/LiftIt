import SwiftUI
import CoreData
import Charts

/// Displays simple statistics about workout progress. Users select an exercise
/// from a picker and view a line chart of their estimated one‑rep maxes over
/// time. One‑rep max is computed using the formula
/// `(1 + reps/30) * weight` for each session exercise. For sessions where
/// multiple sets of the same exercise exist, the highest one‑rep max for
/// that session is used.
struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Exercise.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
    ) private var exercises: FetchedResults<Exercise>
    @FetchRequest(
        entity: WorkoutSession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutSession.date, ascending: true)]
    ) private var sessions: FetchedResults<WorkoutSession>

    /// Currently selected exercise for which to plot statistics. Defaults to
    /// the first exercise if available.
    @State private var selectedExercise: Exercise? = nil

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if exercises.isEmpty {
                    Text("No exercises available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Display exercises as horizontally scrollable chips instead of a menu picker.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Provide an explicit identifier for exercises since our
                            // Core Data entities do not conform to `Identifiable`. Use
                            // the UUID property for uniqueness.
                            ForEach(exercises, id: \.id) { exercise in
                                Button(action: { selectedExercise = exercise }) {
                                    Text(exercise.name)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedExercise == exercise ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    // When an exercise is selected, show its 1RM progress chart. Use the same
                    // computation logic as before. When no history exists for the selected
                    // exercise, display an informative placeholder.
                    if let ex = selectedExercise {
                        let dataPoints = calculateDataPoints(for: ex)
                        if dataPoints.isEmpty {
                            Text("No history for \(ex.name)")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            Chart(dataPoints, id: \ .0) { (date, value) in
                                LineMark(
                                    x: .value("Date", date),
                                    y: .value("1RM", value)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Color.accentColor)
                                PointMark(
                                    x: .value("Date", date),
                                    y: .value("1RM", value)
                                )
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { val in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month().year())
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .padding()
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Stats")
            .onAppear {
                // Initialize the picker with the first exercise on appear
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
            }
        }
    }

    /// Builds an array of (date, oneRepMax) tuples for the given exercise by
    /// scanning all workout sessions. For each session, it finds the
    /// session exercise matching the target exercise and computes the 1RM. If
    /// multiple entries exist for the same session (unlikely in current
    /// schema), the maximum 1RM across entries is used. The resulting list
    /// is sorted by date ascending.
    private func calculateDataPoints(for exercise: Exercise) -> [(Date, Double)] {
        var points: [(Date, Double)] = []
        for session in sessions {
            let date = session.date
            var maxOneRM: Double = 0
            for se in session.sessionExercises ?? [] {
                if se.exercise == exercise {
                    // Compute one rep max using (1 + reps/30) * weight
                    let reps = Double(se.repsPerformed)
                    let weight = se.weightPerformed
                    let oneRM = (1.0 + (reps / 30.0)) * weight
                    if oneRM > maxOneRM { maxOneRM = oneRM }
                }
            }
            if maxOneRM > 0 {
                points.append((date, maxOneRM))
            }
        }
        return points
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}