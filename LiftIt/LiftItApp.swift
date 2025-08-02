//
//  LiftItApp.swift
//  LiftIt
//
//  Created by Theodor Mattli on 01.08.2025.
//

import SwiftUI

@main
struct LiftItApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
