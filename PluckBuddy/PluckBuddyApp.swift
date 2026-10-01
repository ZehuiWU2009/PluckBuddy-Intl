//
//  PluckBuddyApp.swift
//  PluckBuddy
//
//  Created by Zehui Wu on 2026/7/15.
//

import SwiftUI
import CoreData

@main
struct PluckBuddyApp: App {
    let persistenceController = PersistenceController.shared
    
    /// The welcome screen is shown first on launch; tapping the start-practice button or letting it time out enters the main screen
    @State private var showWelcome = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // The main screen stays underneath; as the welcome screen fades out the main screen fades in, avoiding a black or white flash
                HomeView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .opacity(showWelcome ? 0 : 1)
                    .animation(.easeInOut(duration: 0.5), value: showWelcome)
                    .accessibilityHidden(showWelcome)
                if showWelcome {
                    WelcomeView(onEnter: enterMain)
                }
            }
        }
    }
    
    /// The welcome screen exit action (triggered by the timer inside the welcome screen). The guard prevents repeated calls.
    private func enterMain() {
        guard showWelcome else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            showWelcome = false
        }
    }
}
