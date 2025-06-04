//
//  Meeting_Summary_AIApp.swift
//  Meeting Summary AI
//
//  Created by David Zubicek on 2025-06-03.
//

import SwiftUI

@main
struct Meeting_Summary_AIApp: App {
    let persistenceController = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
    }
}
