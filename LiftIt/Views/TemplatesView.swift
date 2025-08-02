import SwiftUI
import CoreData

/// Displays the list of workout templates. Users can create, view and
/// delete templates. Tapping a template opens its detail view where
/// exercises can be added and reordered.
struct TemplatesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: WorkoutTemplate.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutTemplate.name, ascending: true)],
        animation: .default
    ) private var templates: FetchedResults<WorkoutTemplate>

    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(templates) { template in
                        NavigationLink(destination: TemplateDetailView(template: template)) {
                            VStack {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        // Allow deletion via context menu since grids don't support swipe‑to‑delete
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(template: template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                TemplateFormView(template: nil)
            }
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            let template = templates[index]
            viewContext.delete(template)
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete template: \(error)")
        }
    }

    /// Deletes a single template. Used by the context menu on grid cards.
    private func delete(template: WorkoutTemplate) {
        viewContext.delete(template)
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete template: \(error)")
        }
    }
}