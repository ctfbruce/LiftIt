import Foundation
import CoreData

/// A convenience class responsible for setting up the Core Data stack,
/// creating the managed object model programmatically and injecting
/// sample data on first launch. The class follows the singleton
/// pattern; the shared instance can be accessed via `PersistenceController.shared`.
struct PersistenceController {
    /// The shared singleton used throughout the app.
    static let shared = PersistenceController()
    
    /// The underlying persistent container. Its viewContext should be
    /// supplied to SwiftUI views via the environment.
    let container: NSPersistentContainer
    
    /// Creates a new persistence controller. If `inMemory` is set to true,
    /// a transient store located in `/dev/null` is used instead of an
    /// on-disk SQLite file. This is primarily useful for unit tests.
    init(inMemory: Bool = false) {
        let model = PersistenceController.managedObjectModel()
        container = NSPersistentContainer(name: "LiftIt", managedObjectModel: model)
        
        if inMemory {
            // Persist to a volatile location when running in-memory.
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Automatically merge changes coming from parent contexts. Use
        // `NSMergeByPropertyObjectTrumpMergePolicy` so that in-memory
        // changes take precedence over persisted ones on conflict.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Prepopulate sample data once on first launch. We check
        // existence of any programs to decide whether to seed the store.
        let context = container.viewContext
        let request: NSFetchRequest<WorkoutProgram> = WorkoutProgram.fetchRequest()
        request.fetchLimit = 1
        do {
            let count = try context.count(for: request)
            if count == 0 {
                try PersistenceController.prepopulate(in: context)
            }
        } catch {
            print("Failed to check program count: \(error)")
        }
    }
    
    /// Builds the NSManagedObjectModel programmatically. This method
    /// defines all entities, attributes and relationships to avoid
    /// relying on an .xcdatamodeld file. Should you need to evolve
    /// the schema in the future, adjust this function accordingly.
    static func managedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Helper closure to create an attribute.
        func attribute(name: String, type: NSAttributeType, isOptional: Bool = false) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = isOptional
            return attr
        }
        
        // MARK: Exercise entity
        let exerciseEntity = NSEntityDescription()
        exerciseEntity.name = "Exercise"
        exerciseEntity.managedObjectClassName = String(describing: Exercise.self)
        
        let exerciseID = attribute(name: "id", type: .UUIDAttributeType)
        let exerciseName = attribute(name: "name", type: .stringAttributeType)
        let exerciseMuscles = attribute(name: "muscles", type: .stringAttributeType, isOptional: true)
        // Optional notes attribute. If provided, it stores free‐form text
        // describing form cues or other reminders. Without this field in
        // the model, notes would have to live outside of Core Data.
        let exerciseNotes = attribute(name: "notes", type: .stringAttributeType, isOptional: true)
        // Secondary muscle groups stored as an array of strings. Use a transformable
        // attribute so Core Data handles the archival of the array automatically.
        let exerciseSecondary = attribute(name: "secondaryMuscles", type: .transformableAttributeType, isOptional: true)
        // Specify that the value is an NSArray containing NSStrings. Without this,
        // Core Data defaults to `NSObject` which can lead to runtime type errors.
        exerciseSecondary.attributeValueClassName = NSStringFromClass(NSArray.self)
        exerciseSecondary.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue

        exerciseEntity.properties = [exerciseID, exerciseName, exerciseMuscles, exerciseNotes, exerciseSecondary]
        
        // MARK: WorkoutTemplate entity
        let templateEntity = NSEntityDescription()
        templateEntity.name = "WorkoutTemplate"
        templateEntity.managedObjectClassName = String(describing: WorkoutTemplate.self)
        
        let templateID = attribute(name: "id", type: .UUIDAttributeType)
        let templateName = attribute(name: "name", type: .stringAttributeType)
        
        templateEntity.properties = [templateID, templateName]
        
        // MARK: TemplateExercise entity
        let templateExerciseEntity = NSEntityDescription()
        templateExerciseEntity.name = "TemplateExercise"
        templateExerciseEntity.managedObjectClassName = String(describing: TemplateExercise.self)
        
        let teID = attribute(name: "id", type: .UUIDAttributeType)
        let teSets = attribute(name: "sets", type: .integer16AttributeType)
        let teRepMin = attribute(name: "repMin", type: .integer16AttributeType)
        let teRepMax = attribute(name: "repMax", type: .integer16AttributeType)
        let teOrder = attribute(name: "order", type: .integer16AttributeType)
        
        templateExerciseEntity.properties = [teID, teSets, teRepMin, teRepMax, teOrder]
        
        // MARK: WorkoutProgram entity
        let programEntity = NSEntityDescription()
        programEntity.name = "WorkoutProgram"
        programEntity.managedObjectClassName = String(describing: WorkoutProgram.self)
        
        let programID = attribute(name: "id", type: .UUIDAttributeType)
        let programName = attribute(name: "name", type: .stringAttributeType)
        let programDayIndex = attribute(name: "currentDayIndex", type: .integer16AttributeType)
        // Attribute to track which template group is scheduled next for the current day.
        let programTemplateSlot = attribute(name: "currentTemplateSlot", type: .integer16AttributeType)
        // Provide a default value of 0 so that existing stores can be migrated
        // automatically without requiring a migration mapping. Without a
        // default, existing `WorkoutProgram` records would have a nil value
        // for this non‑optional attribute, causing the store to fail to load.
        programTemplateSlot.defaultValue = 0

        programEntity.properties = [programID, programName, programDayIndex, programTemplateSlot]
        
        // MARK: ProgramExercise entity
        let programExerciseEntity = NSEntityDescription()
        programExerciseEntity.name = "ProgramExercise"
        programExerciseEntity.managedObjectClassName = String(describing: ProgramExercise.self)
        
        let peID = attribute(name: "id", type: .UUIDAttributeType)
        let peDayIndex = attribute(name: "dayIndex", type: .integer16AttributeType)
        let peOrder = attribute(name: "order", type: .integer16AttributeType)
        let peSets = attribute(name: "sets", type: .integer16AttributeType)
        let peRepMin = attribute(name: "repMin", type: .integer16AttributeType)
        let peRepMax = attribute(name: "repMax", type: .integer16AttributeType)
        let peRepGoal = attribute(name: "repGoal", type: .integer16AttributeType)
        let peWeightGoal = attribute(name: "weightGoal", type: .doubleAttributeType)
        let peConsecutiveMisses = attribute(name: "consecutiveMisses", type: .integer16AttributeType)
        // Optional template name to preserve grouping information when viewing programs.
        let peTemplateName = attribute(name: "templateName", type: .stringAttributeType, isOptional: true)

        programExerciseEntity.properties = [peID, peDayIndex, peOrder, peSets, peRepMin, peRepMax, peRepGoal, peWeightGoal, peConsecutiveMisses, peTemplateName]
        
        // MARK: WorkoutSession entity
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "WorkoutSession"
        sessionEntity.managedObjectClassName = String(describing: WorkoutSession.self)
        
        let sessionID = attribute(name: "id", type: .UUIDAttributeType)
        let sessionDate = attribute(name: "date", type: .dateAttributeType)
        
        sessionEntity.properties = [sessionID, sessionDate]
        
        // MARK: SessionExercise entity
        let sessionExerciseEntity = NSEntityDescription()
        sessionExerciseEntity.name = "SessionExercise"
        sessionExerciseEntity.managedObjectClassName = String(describing: SessionExercise.self)
        
        let seID = attribute(name: "id", type: .UUIDAttributeType)
        let seSets = attribute(name: "sets", type: .integer16AttributeType)
        let seRepGoal = attribute(name: "repGoal", type: .integer16AttributeType)
        let seRepsPerformed = attribute(name: "repsPerformed", type: .integer16AttributeType)
        let seWeightGoal = attribute(name: "weightGoal", type: .doubleAttributeType)
        let seWeightPerformed = attribute(name: "weightPerformed", type: .doubleAttributeType)
        
        sessionExerciseEntity.properties = [seID, seSets, seRepGoal, seRepsPerformed, seWeightGoal, seWeightPerformed]
        
        // MARK: Relationships
        
        // Exercise relationships
        let exerciseToTemplateExercises = NSRelationshipDescription()
        exerciseToTemplateExercises.name = "templateExercises"
        exerciseToTemplateExercises.destinationEntity = templateExerciseEntity
        exerciseToTemplateExercises.minCount = 0
        exerciseToTemplateExercises.maxCount = 0 // unlimited
        exerciseToTemplateExercises.deleteRule = .cascadeDeleteRule
        exerciseToTemplateExercises.isOptional = true
        
        let exerciseToProgramExercises = NSRelationshipDescription()
        exerciseToProgramExercises.name = "programExercises"
        exerciseToProgramExercises.destinationEntity = programExerciseEntity
        exerciseToProgramExercises.minCount = 0
        exerciseToProgramExercises.maxCount = 0
        exerciseToProgramExercises.deleteRule = .cascadeDeleteRule
        exerciseToProgramExercises.isOptional = true
        
        let exerciseToSessionExercises = NSRelationshipDescription()
        exerciseToSessionExercises.name = "sessionExercises"
        exerciseToSessionExercises.destinationEntity = sessionExerciseEntity
        exerciseToSessionExercises.minCount = 0
        exerciseToSessionExercises.maxCount = 0
        exerciseToSessionExercises.deleteRule = .cascadeDeleteRule
        exerciseToSessionExercises.isOptional = true
        
        // Template relationships
        let templateToTemplateExercises = NSRelationshipDescription()
        templateToTemplateExercises.name = "templateExercises"
        templateToTemplateExercises.destinationEntity = templateExerciseEntity
        templateToTemplateExercises.minCount = 0
        templateToTemplateExercises.maxCount = 0
        templateToTemplateExercises.deleteRule = .cascadeDeleteRule
        templateToTemplateExercises.isOptional = true
        
        // TemplateExercise relationships
        let teToExercise = NSRelationshipDescription()
        teToExercise.name = "exercise"
        teToExercise.destinationEntity = exerciseEntity
        teToExercise.minCount = 0
        teToExercise.maxCount = 1
        teToExercise.deleteRule = .nullifyDeleteRule
        teToExercise.isOptional = true
        
        let teToTemplate = NSRelationshipDescription()
        teToTemplate.name = "template"
        teToTemplate.destinationEntity = templateEntity
        teToTemplate.minCount = 0
        teToTemplate.maxCount = 1
        teToTemplate.deleteRule = .nullifyDeleteRule
        teToTemplate.isOptional = true
        
        // Program relationships
        let programToProgramExercises = NSRelationshipDescription()
        programToProgramExercises.name = "programExercises"
        programToProgramExercises.destinationEntity = programExerciseEntity
        programToProgramExercises.minCount = 0
        programToProgramExercises.maxCount = 0
        programToProgramExercises.deleteRule = .cascadeDeleteRule
        programToProgramExercises.isOptional = true
        
        let programToSessions = NSRelationshipDescription()
        programToSessions.name = "workoutSessions"
        programToSessions.destinationEntity = sessionEntity
        programToSessions.minCount = 0
        programToSessions.maxCount = 0
        programToSessions.deleteRule = .cascadeDeleteRule
        programToSessions.isOptional = true
        
        // ProgramExercise relationships
        let peToProgram = NSRelationshipDescription()
        peToProgram.name = "program"
        peToProgram.destinationEntity = programEntity
        peToProgram.minCount = 0
        peToProgram.maxCount = 1
        peToProgram.deleteRule = .nullifyDeleteRule
        peToProgram.isOptional = true
        
        let peToExercise = NSRelationshipDescription()
        peToExercise.name = "exercise"
        peToExercise.destinationEntity = exerciseEntity
        peToExercise.minCount = 0
        peToExercise.maxCount = 1
        peToExercise.deleteRule = .nullifyDeleteRule
        peToExercise.isOptional = true
        
        // Session relationships
        let sessionToProgram = NSRelationshipDescription()
        sessionToProgram.name = "program"
        sessionToProgram.destinationEntity = programEntity
        sessionToProgram.minCount = 0
        sessionToProgram.maxCount = 1
        sessionToProgram.deleteRule = .nullifyDeleteRule
        sessionToProgram.isOptional = true
        
        let sessionToSessionExercises = NSRelationshipDescription()
        sessionToSessionExercises.name = "sessionExercises"
        sessionToSessionExercises.destinationEntity = sessionExerciseEntity
        sessionToSessionExercises.minCount = 0
        sessionToSessionExercises.maxCount = 0
        sessionToSessionExercises.deleteRule = .cascadeDeleteRule
        sessionToSessionExercises.isOptional = true
        
        // SessionExercise relationships
        let seToSession = NSRelationshipDescription()
        seToSession.name = "session"
        seToSession.destinationEntity = sessionEntity
        seToSession.minCount = 0
        seToSession.maxCount = 1
        seToSession.deleteRule = .nullifyDeleteRule
        seToSession.isOptional = true
        
        let seToExercise = NSRelationshipDescription()
        seToExercise.name = "exercise"
        seToExercise.destinationEntity = exerciseEntity
        seToExercise.minCount = 0
        seToExercise.maxCount = 1
        seToExercise.deleteRule = .nullifyDeleteRule
        seToExercise.isOptional = true
        
        // Set inverse relationships
        // Exercise <-> TemplateExercise
        exerciseToTemplateExercises.inverseRelationship = teToExercise
        teToExercise.inverseRelationship = exerciseToTemplateExercises
        
        // Exercise <-> ProgramExercise
        exerciseToProgramExercises.inverseRelationship = peToExercise
        peToExercise.inverseRelationship = exerciseToProgramExercises
        
        // Exercise <-> SessionExercise
        exerciseToSessionExercises.inverseRelationship = seToExercise
        seToExercise.inverseRelationship = exerciseToSessionExercises
        
        // Template <-> TemplateExercise
        templateToTemplateExercises.inverseRelationship = teToTemplate
        teToTemplate.inverseRelationship = templateToTemplateExercises
        
        // Program <-> ProgramExercise
        programToProgramExercises.inverseRelationship = peToProgram
        peToProgram.inverseRelationship = programToProgramExercises
        
        // Program <-> Session
        programToSessions.inverseRelationship = sessionToProgram
        sessionToProgram.inverseRelationship = programToSessions
        
        // Session <-> SessionExercise
        sessionToSessionExercises.inverseRelationship = seToSession
        seToSession.inverseRelationship = sessionToSessionExercises
        
        // Add relationship properties to each entity's property array
        exerciseEntity.properties.append(contentsOf: [exerciseToTemplateExercises, exerciseToProgramExercises, exerciseToSessionExercises])
        templateEntity.properties.append(templateToTemplateExercises)
        templateExerciseEntity.properties.append(contentsOf: [teToExercise, teToTemplate])
        programEntity.properties.append(contentsOf: [programToProgramExercises, programToSessions])
        programExerciseEntity.properties.append(contentsOf: [peToProgram, peToExercise])
        sessionEntity.properties.append(contentsOf: [sessionToProgram, sessionToSessionExercises])
        sessionExerciseEntity.properties.append(contentsOf: [seToSession, seToExercise])
        
        model.entities = [exerciseEntity, templateEntity, templateExerciseEntity, programEntity, programExerciseEntity, sessionEntity, sessionExerciseEntity]
        return model
    }
    
    /// Populates the persistent store with sample data. This method will
    /// only be called if the store is empty when the persistence
    /// controller is initialized. Should there already be user data
    /// present, this function does nothing. To regenerate the seed data,
    /// remove the app from the simulator/device so the SQLite file is
    /// deleted and then run again.
    static func prepopulate(in context: NSManagedObjectContext) throws {
        // Helper to create an exercise with primary and secondary muscle groups
        func createExercise(name: String, primary: String, secondary: [String] = []) -> Exercise {
            let ex = Exercise(context: context)
            ex.id = UUID()
            ex.name = name
            ex.muscles = primary
            ex.secondaryMuscles = secondary.isEmpty ? nil : secondary
            return ex
        }
        // Create all exercises defined by the user
        let exAbWheel = createExercise(name: "Ab Wheel", primary: "Core")
        let exBackExtension = createExercise(name: "Back Extension", primary: "Back")
        let exBackSquat = createExercise(name: "Back Squat", primary: "Quad", secondary: ["Glute", "Calves", "Hamstring"])
        let exBenchPress = createExercise(name: "Bench Press", primary: "Chest", secondary: ["Shoulder", "Tricep"])
        let exCableCrunch = createExercise(name: "Cable Crunch", primary: "Core")
        let exCalfRaise = createExercise(name: "Calf Raise", primary: "Calves")
        let exChestFly = createExercise(name: "Chest Fly", primary: "Chest")
        let exConDeadlift = createExercise(name: "Conventional Deadlift", primary: "Hamstring", secondary: ["Back"])
        let exDips = createExercise(name: "Dips", primary: "Tricep", secondary: ["Shoulder", "Chest"])
        let exDragonFlag = createExercise(name: "Dragon Flag", primary: "Core")
        let exFrontSquat = createExercise(name: "Front Squat", primary: "Quad", secondary: ["Hamstring", "Glute"])
        let exHipThrust = createExercise(name: "Hip Thrust", primary: "Glute")
        let exInclinePress = createExercise(name: "Incline Press", primary: "Chest", secondary: ["Tricep", "Shoulder"])
        let exJMPress = createExercise(name: "JM Press", primary: "Tricep")
        let exLatPushdown = createExercise(name: "Lat Pushdown", primary: "Lats")
        let exLateralRaise = createExercise(name: "Lateral Raise", primary: "Shoulder")
        let exLegCurl = createExercise(name: "Leg Curl", primary: "Hamstring")
        let exLegExtension = createExercise(name: "Leg Extension", primary: "Quad")
        let exLegPress = createExercise(name: "Leg Press", primary: "Quad", secondary: ["Glute", "Hamstring"])
        let exOHP = createExercise(name: "OHP", primary: "Shoulder", secondary: ["Tricep"])
        let exPauseSquat = createExercise(name: "Pause Squat", primary: "Quad", secondary: ["Glute", "Hamstring"])
        let exPreacherCurl = createExercise(name: "Preacher Curl", primary: "Bicep")
        let exPullUp = createExercise(name: "Pull Up", primary: "Lats", secondary: ["Bicep", "Back"])
        let exPushdown = createExercise(name: "Pushdown", primary: "Tricep")
        let exRDL = createExercise(name: "RDL", primary: "Hamstring", secondary: ["Back"])
        let exRearDeltFly = createExercise(name: "Rear delt fly", primary: "Shoulder")
        let exRow = createExercise(name: "Row", primary: "Back", secondary: ["Lats", "Bicep"])
        let exSideBend = createExercise(name: "Side Bend", primary: "Core")

        // Helper to create a template and its exercises
        func createTemplate(name: String, exercises: [(Exercise, Int16, Int16, Int16)]) -> WorkoutTemplate {
            let template = WorkoutTemplate(context: context)
            template.id = UUID()
            template.name = name
            for (index, tuple) in exercises.enumerated() {
                let (exercise, sets, repMin, repMax) = tuple
                let te = TemplateExercise(context: context)
                te.id = UUID()
                te.sets = sets
                te.repMin = repMin
                te.repMax = repMax
                te.order = Int16(index)
                te.exercise = exercise
                te.template = template
            }
            return template
        }

        // Define workout templates
        // A. Upper: Overhead Press + back
        let templateA = createTemplate(name: "Upper", exercises: [
            (exOHP, 4, 6, 8),
            (exPullUp, 4, 7, 10),
            (exRow, 4, 8, 12),
            (exLateralRaise, 4, 11, 15),
            (exPreacherCurl, 3, 8, 12),
            (exRearDeltFly, 3, 11, 15)
        ])
        // B. Bench + chest/shoulder/tricep
        let templateB = createTemplate(name: "Bench", exercises: [
            (exBenchPress, 5, 6, 8),
            (exInclinePress, 4, 8, 12),
            (exChestFly, 3, 12, 15),
            (exOHP, 3, 8, 12),
            (exDips, 4, 8, 12),
            (exPushdown, 3, 11, 15)
        ])
        // C. Core
        let templateC = createTemplate(name: "Core", exercises: [
            (exDragonFlag, 4, 8, 12),
            (exSideBend, 3, 8, 12),
            (exCableCrunch, 3, 8, 12),
            (exAbWheel, 3, 8, 12)
        ])
        // D. Deadlift & Ham/Glutes
        let templateD = createTemplate(name: "Deadlift & Ham/Glutes", exercises: [
            (exConDeadlift, 4, 5, 8),
            (exRDL, 4, 8, 12),
            (exHipThrust, 4, 12, 15),
            (exLegCurl, 4, 8, 12),
            (exBackExtension, 3, 11, 15)
        ])
        // E. Quad & Glute + accessory overload
        let templateE = createTemplate(name: "Quad & Glute + accessory", exercises: [
            (exFrontSquat, 4, 8, 12),
            (exPauseSquat, 4, 8, 12),
            (exPreacherCurl, 4, 8, 12),
            (exPushdown, 4, 7, 10)
        ])
        // F. Squat & Quads
        let templateF = createTemplate(name: "Squat & Quads", exercises: [
            (exBackSquat, 5, 5, 8),
            (exLegPress, 4, 7, 10),
            (exLegExtension, 3, 12, 15),
            (exCalfRaise, 5, 8, 12)
        ])
        // G. Full body finisher
        let templateG = createTemplate(name: "Full Body Finisher", exercises: [
            (exBenchPress, 3, 8, 12),
            (exLatPushdown, 3, 8, 12),
            (exRow, 3, 8, 12),
            (exPreacherCurl, 3, 8, 12),
            (exHipThrust, 3, 8, 12),
            (exCalfRaise, 3, 8, 12)
        ])

        // Helper to create a program and duplicate template exercises into program exercises
        func createProgram(name: String, templateOrder: [WorkoutTemplate]) -> WorkoutProgram {
            let program = WorkoutProgram(context: context)
            program.id = UUID()
            program.name = name
            program.currentDayIndex = 1
            program.currentTemplateSlot = 0
            var dayIndex: Int16 = 1
            for template in templateOrder {
                var order: Int16 = 0
                let exers = (template.templateExercises ?? []).sorted { $0.order < $1.order }
                for te in exers {
                    let pe = ProgramExercise(context: context)
                    pe.id = UUID()
                    pe.dayIndex = dayIndex
                    pe.order = order
                    pe.sets = te.sets
                    pe.repMin = te.repMin
                    pe.repMax = te.repMax
                    pe.repGoal = te.repMax
                    pe.weightGoal = 0.0
                    pe.consecutiveMisses = 0
                    pe.exercise = te.exercise
                    pe.program = program
                    pe.templateName = template.name
                    order += 1
                }
                dayIndex += 1
            }
            return program
        }
        // Create the single program "Getting swole 💪"
        _ = createProgram(name: "Getting swole 💪", templateOrder: [
            templateF, // Day 1: Squat & Quads
            templateB, // Day 2: Bench + chest/shoulder/tricep
            templateD, // Day 3: Deadlift & Ham/Glutes
            templateE, // Day 4: Quad & Glute + accessory
            templateA, // Day 5: Upper: Overhead Press + back
            templateG, // Day 6: Full Body Finisher
            templateC  // Day 7: Core
        ])

        try context.save()
    }
}

extension NSManagedObject {
    /// Returns the typed fetch request for the current entity. This utility
    /// allows easier writing of fetches like `Exercise.fetchRequest()`.
    class func fetchRequest<T: NSManagedObject>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: String(describing: self))
    }
}