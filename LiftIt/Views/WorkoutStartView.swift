import SwiftUI
import CoreData

/// Starting point for workouts. Presents a list of existing programs
/// and allows the user to select one to start a session on the
/// program's current day. Navigates to `WorkoutSessionView` upon
/// selection.
struct WorkoutStartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: WorkoutProgram.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutProgram.name, ascending: true)],
        animation: .default
    ) private var programs: FetchedResults<WorkoutProgram>
    
    var body: some View {
        NavigationView {
            List {
                // Use the program's UUID as the identifier for each row. Without specifying
                // an `id` parameter, SwiftUI requires the element type to conform to
                // `Identifiable`. Our Core Data entities do not adopt `Identifiable`
                // explicitly, so we supply the ID key path to satisfy the requirement.
                ForEach(programs, id: \.id) { program in
                    NavigationLink(destination: WorkoutSessionView(program: program)) {
                        VStack(alignment: .leading) {
                            Text(program.name)
                                .font(.headline)
                            Text("Next day: \(program.currentDayIndex)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Start Workout")
        }
    }
}