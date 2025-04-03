import SwiftUI

@main
struct PomodoroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            // Hide the Status Bar
                .statusBar(hidden: true)
            // Hide the Home Bar
                .edgesIgnoringSafeArea(.bottom)
                .onAppear {
                    // Disable the idle timer to prevent the screen from dimming
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
