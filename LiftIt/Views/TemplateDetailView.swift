import SwiftUI
import CoreData

/// Shows the exercises contained within a workout template. Users can
/// reorder, add, edit and delete template exercises. The list
/// ordering is persisted to the `order` attribute.
struct TemplateDetailView: View {
    @ObservedObject var template: WorkoutTemplate
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingAddSheet = false
    @State private var selectedTemplateExercise: TemplateExercise?
    
    // Fetch only the exercises belonging to this template, sorted by order.
    private var fetchRequest: FetchRequest<TemplateExercise>
    private var templateExercises: FetchedResults<TemplateExercise> { fetchRequest.wrappedValue }
    
    init(template: WorkoutTemplate) {
        self.template = template
        let predicate = NSPredicate(format: "template == %@", template)
        self.fetchRequest = FetchRequest(
            entity: TemplateExercise.entity(),
            sortDescriptors: [NSSortDescriptor(key: "order", ascending: true)],
            predicate: predicate,
            animation: .default)
    }
    
    var body: some View {
        List {
            // Use the template exercise's UUID for identification since
            // Core Data entities do not adopt `Identifiable` automatically.
            ForEach(templateExercises, id: \.id) { te in
                Button(action: { selectedTemplateExercise = te }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(te.exercise?.name ?? "Unknown")
                                .font(.headline)
                            Text("\(te.sets) sets, reps \(te.repMin)–\(te.repMax)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let notes = te.exercise?.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onDelete(perform: deleteTemplateExercises)
            .onMove(perform: moveTemplateExercises)
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    EditButton()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            TemplateExerciseFormView(template: template, templateExercise: nil)
        }
        .sheet(item: $selectedTemplateExercise) { te in
            TemplateExerciseFormView(template: template, templateExercise: te)
        }
    }
    
    /// Remove exercises at offsets and renumber the remaining ones.
    private func deleteTemplateExercises(at offsets: IndexSet) {
        for index in offsets {
            let te = templateExercises[index]
            viewContext.delete(te)
        }
        saveAndRenumber()
    }
    
    /// Reorders exercises when the user moves them in the list. After
    /// moving, the `order` attribute on each item is updated.
    private func moveTemplateExercises(from source: IndexSet, to destination: Int) {
        var items = Array(templateExercises)
        items.move(fromOffsets: source, toOffset: destination)
        for (index, te) in items.enumerated() {
            te.order = Int16(index)
        }
        save()
    }
    
    private func saveAndRenumber() {
        for (index, te) in templateExercises.enumerated() {
            te.order = Int16(index)
        }
        save()
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save template exercises: \(error)")
        }
    }
}