import Foundation
import CoreData

// MARK: - Core Data Managed Object Classes

// Each class below represents one of the entities defined in the app's
// data model. Because the model is created programmatically (see
// `PersistenceController.managedObjectModel()`), these classes do not
// require code generation from an .xcdatamodeld file.

@objc(Exercise)
public class Exercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var muscles: String?
    /// Secondary muscle groups targeted by this exercise. These are optional
    /// and can store multiple groups such as "Bicep" and "Tricep". The
    /// primary muscle group is stored in the `muscles` property. When
    /// filtering exercises by muscle group, both primary and secondary
    /// assignments are considered.
    @NSManaged public var secondaryMuscles: [String]?
    /// Optional notes for the exercise. These notes can contain tips or
    /// reminders such as "brace your core". They are displayed beneath
    /// the exercise name throughout the app.
    @NSManaged public var notes: String?
    @NSManaged public var templateExercises: Set<TemplateExercise>?
    @NSManaged public var programExercises: Set<ProgramExercise>?
    @NSManaged public var sessionExercises: Set<SessionExercise>?
}

@objc(WorkoutTemplate)
public class WorkoutTemplate: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var templateExercises: Set<TemplateExercise>?
}

@objc(TemplateExercise)
public class TemplateExercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var sets: Int16
    @NSManaged public var repMin: Int16
    @NSManaged public var repMax: Int16
    @NSManaged public var order: Int16
    @NSManaged public var exercise: Exercise?
    @NSManaged public var template: WorkoutTemplate?
}

@objc(WorkoutProgram)
public class WorkoutProgram: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var currentDayIndex: Int16
    /// Indicates which template slot (workout group) is scheduled next for the current day.
    /// When a program has multiple workouts on the same day, this index cycles through
    /// the groups. For example, if a program has two workouts per day, the order of
    /// sessions will be day 1 A, day 1 B, day 2 A, day 2 B.
    @NSManaged public var currentTemplateSlot: Int16
    @NSManaged public var programExercises: Set<ProgramExercise>?
    @NSManaged public var workoutSessions: Set<WorkoutSession>?
}

@objc(ProgramExercise)
public class ProgramExercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var dayIndex: Int16
    @NSManaged public var order: Int16
    @NSManaged public var sets: Int16
    @NSManaged public var repMin: Int16
    @NSManaged public var repMax: Int16
    @NSManaged public var repGoal: Int16
    @NSManaged public var weightGoal: Double
    @NSManaged public var consecutiveMisses: Int16
    /// The name of the template this program exercise originated from. This
    /// allows grouping exercises back into their parent workout (e.g. "Push" or
    /// "Pull") when viewing program details. It is optional for backward
    /// compatibility with existing data.
    @NSManaged public var templateName: String?
    @NSManaged public var program: WorkoutProgram?
    @NSManaged public var exercise: Exercise?
}

@objc(WorkoutSession)
public class WorkoutSession: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var program: WorkoutProgram?
    @NSManaged public var sessionExercises: Set<SessionExercise>?
}

@objc(SessionExercise)
public class SessionExercise: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var sets: Int16
    @NSManaged public var repGoal: Int16
    @NSManaged public var repsPerformed: Int16
    @NSManaged public var weightGoal: Double
    @NSManaged public var weightPerformed: Double
    @NSManaged public var session: WorkoutSession?
    @NSManaged public var exercise: Exercise?
}
// MARK: - Identifiable for SwiftUI convenience
extension TemplateExercise: Identifiable {}
extension WorkoutTemplate: Identifiable {}
extension Exercise: Identifiable {}
extension WorkoutProgram: Identifiable {}
extension ProgramExercise: Identifiable {}
extension WorkoutSession: Identifiable {}
extension SessionExercise: Identifiable {}
