import SwiftUI
import UIKit

@main
struct PomodoroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBar(hidden: true)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    // Disable the idle timer to prevent the screen from dimming
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
