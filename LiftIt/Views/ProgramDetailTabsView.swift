import SwiftUI
import CoreData

/// A wrapper view that presents the standard program details alongside a
/// program‑specific goals manager in a swipeable interface. This view
/// uses a paging `TabView` so users can navigate between their
/// workouts and goals for a given program by swiping horizontally.
///
/// The leading and trailing navigation bar items (add and edit
/// controls) are displayed only on the workouts page to reduce
/// clutter on the goals page. The title of the navigation bar shows
/// the program’s name consistently across both pages.
struct ProgramDetailTabsView: View {
    @ObservedObject var program: WorkoutProgram
    @Environment(\.managedObjectContext) private var viewContext

    /// Tracks which page is currently visible in the TabView. Page 0 is
    /// the workouts overview (`ProgramDetailView`), and page 1 is the
    /// goals manager (`ProgramGoalsView`).
    @State private var selectedTab: Int = 0
    /// Controls presentation of the add workout sheet when the plus
    /// button is tapped. This is managed here to keep it tied to the
    /// top‑level navigation bar rather than inside the child view.
    @State private var showingAddWorkout = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ProgramDetailView(program: program)
                .tag(0)
                .tabItem {
                    Label("Workouts", systemImage: "list.number")
                }
            ProgramGoalsView(program: program)
                .tag(1)
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .navigationTitle(program.name)
        // Show add and edit buttons only on the workouts page. When the
        // user swipes to the goals page, these controls disappear.
        .toolbar {
            // Leading add button
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedTab == 0 {
                    Button(action: { showingAddWorkout.toggle() }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // Trailing edit button
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 0 {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutView(program: program)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

// MARK: - Preview
struct ProgramDetailTabsView_Previews: PreviewProvider {
    static var previews: some View {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let program = WorkoutProgram(context: context)
        program.id = UUID()
        program.name = "Preview Program"
        return NavigationView {
            ProgramDetailTabsView(program: program)
        }
        .environment(\.managedObjectContext, context)
    }
}