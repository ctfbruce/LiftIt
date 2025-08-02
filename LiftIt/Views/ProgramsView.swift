import SwiftUI
import CoreData

/// Lists all workout programs and allows the user to create, view and
/// delete them. Creating a program opens a form where the user can
/// configure days and assign templates.
struct ProgramsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: WorkoutProgram.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutProgram.name, ascending: true)],
        animation: .default
    ) private var programs: FetchedResults<WorkoutProgram>
    
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    // Specify the identifier explicitly since our Core Data
                    // entities do not conform to `Identifiable`. Use
                    // the program's UUID as the key path for uniqueness.
                    ForEach(programs, id: \.id) { program in
                        // Navigate to a tabbed program detail that includes goals.
                        NavigationLink(destination: ProgramDetailTabsView(program: program)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(program.name)
                                    .font(.headline)
                                Text("Next day: \(program.currentDayIndex)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(program: program)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ProgramFormView(program: nil)
            }
        }
    }
    
    private func deletePrograms(at offsets: IndexSet) {
        for index in offsets {
            let program = programs[index]
            viewContext.delete(program)
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete program: \(error)")
        }
    }

    /// Deletes a single program, used in the context menu on grid cards.
    private func delete(program: WorkoutProgram) {
        viewContext.delete(program)
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete program: \(error)")
        }
    }
}