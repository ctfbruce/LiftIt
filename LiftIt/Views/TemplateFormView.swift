import SwiftUI
import CoreData

/// Form for creating or editing a workout template. Only the name is
/// edited here; exercises are managed in the detail view. On save,
/// the template is persisted and the sheet dismissed.
struct TemplateFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    var template: WorkoutTemplate?

    @State private var name: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Template")) {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
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
        }
        .onAppear {
            if let template = template {
                name = template.name
            }
        }
    }

    private func save() {
        let target: WorkoutTemplate
        if let template = template {
            target = template
        } else {
            target = WorkoutTemplate(context: viewContext)
            target.id = UUID()
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to save template: \(error)")
        }
    }
}