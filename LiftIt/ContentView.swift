import SwiftUI

/// The root view of the application. Displays a tabbed interface with
/// sections for exercises, templates, programs and workouts. Each
/// tab hosts its own feature view. The environment's managed object
/// context is injected from the app entry point in `LiftItApp`.
struct ContentView: View {
    /// Tracks whether the app is currently in dark mode. Toggling this flag
    /// updates the preferred colour scheme across all child views. The state
    /// persists only for the current run; you could extend this to use
    /// UserDefaults if you want persistence across launches.
    @State private var isDarkMode: Bool = false

    var body: some View {
        // Overlay the dark/light mode toggle in the bottom‑right corner to avoid
        // overlapping navigation bar buttons. Use a ZStack to position it
        // relative to the tab view.
        ZStack(alignment: .bottomTrailing) {
            TabView {
                ExercisesView()
                    .tabItem {
                        Label("Exercises", systemImage: "list.bullet")
                    }
                TemplatesView()
                    .tabItem {
                        Label("Templates", systemImage: "rectangle.stack")
                    }
                ProgramsView()
                    .tabItem {
                        Label("Programs", systemImage: "square.grid.2x2")
                    }
                WorkoutStartView()
                    .tabItem {
                        Label("Workout", systemImage: "figure.strengthtraining.traditional")
                    }
                WorkoutHistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                // Remove the standalone Goals tab.  Goals are now managed
                // within each program via the ProgramDetailTabsView.
                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                    }
            }
            // Toggle button for light/dark mode. Positioned in the bottom right
            // of the screen so it does not obstruct navigation bars or other
            // UI elements. Tapping switches the colour scheme and updates
            // the icon between sun and moon.
            Button(action: { isDarkMode.toggle() }) {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                    .imageScale(.large)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground).opacity(0.8)))
            }
            .foregroundColor(.primary)
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
        // Apply the preferred colour scheme based on our state. When toggled,
        // all child views adopt the chosen appearance regardless of system
        // settings.
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}