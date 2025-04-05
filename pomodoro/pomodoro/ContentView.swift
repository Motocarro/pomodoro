import SwiftUI
import AudioToolbox

// Define the main view of the app
struct ContentView: View {
    // State variables to keep track of the timer
    @State private var time = 1500 // 25 minutes in seconds
    @State private var breakTime = 300 // 5 minutes in seconds
    @State private var currentTime = 1500 // start with 25 minutes
    @State private var isPomodoro = true // flag to indicate whether we're in Pomodoro or break phase
    @State private var timer: Timer? // the timer object
    @State private var started = false // flag to indicate whether the timer has started
    @State private var pauseText = "" // text to display when paused

    // Define the body of the view
    var body: some View {
        // Use a ZStack to layer the background color and the timer text
        ZStack {
            // If we're in Pomodoro phase, use a black background
            if isPomodoro {
                Color.black
                    .edgesIgnoringSafeArea(.all) // make the background fill the entire screen
            }
            // If we're in break phase, use a green background
            else {
                Color.green
                    .edgesIgnoringSafeArea(.all) // make the background fill the entire screen
            }
            // Display the timer text
            VStack {
                Spacer()
                Text(formatTime(currentTime))
                    .font(.system(size: 64, weight: .bold)) // make the text bold and large
                    .foregroundColor(isPomodoro ? .red : .black) // use red text for Pomodoro phase and black text for break phase
                Spacer()
                if !isPomodoro {
                    Text(pauseText)
                        .font(.system(size: 24, weight: .bold)) // make the text bold
                        .foregroundColor(.black) // use black text
                }
                Spacer()
                    .frame(height: 100)
            }
        }
        // Use a tap gesture to start the timer
        .onTapGesture {
            // If the timer hasn't started yet, start it
            if !started {
                started = true
                // Adds an haptic feedback when the timer starts
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                // Create a timer that fires every second
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    // Update the timer every second
                    self.updateTimer()
                }
            }
        }
    }

    // Function to format the timer text
    func formatTime(_ time: Int) -> String {
        // Calculate the minutes and seconds
        let minutes = time / 60
        let seconds = time % 60
        // Return the formatted timer text
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Function to update the timer
    func updateTimer() {
        // Decrement the current time by 1 second
        currentTime -= 1
        // If the timer has reached 0, switch phases
        if currentTime == 0 {
            // If we're in Pomodoro phase, switch to break phase
            if isPomodoro {
                isPomodoro = false
                currentTime = breakTime
                // Vibrate to indicate the phase switch
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                // Update the pause text
                updatePauseText()
            }
            // If we're in break phase, switch to Pomodoro phase
            else {
                isPomodoro = true
                currentTime = time
                // Vibrate to indicate the phase switch
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                // Reset the pause text
                pauseText = ""
            }
        }
    }

    // Function to update the pause text
    func updatePauseText() {
        let messages = [
            "take a break!",
            "breathe air",
            "drink water",
            "keep going, you're doing great!",
            "touch grass",
            "go out"
        ]
        pauseText = messages.randomElement() ?? ""
        // 1 in 1000 chance to display the arch message
        if Int.random(in: 1...1000) == 1 {
            pauseText = "i use arch btw"
        }
    }
}

// Preview provider for the view
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
