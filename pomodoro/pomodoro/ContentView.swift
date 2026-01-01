import SwiftUI
import AudioToolbox
import UserNotifications

struct ContentView: View {
    @State private var time = 1500
    @State private var breakTime = 300
    @State private var currentTime = 1500
    @State private var isPomodoro = true
    @State private var timer: Timer?
    @State private var started = false
    @State private var pauseText = ""
    @State private var targetDate: Date?

    var body: some View {
        ZStack {
            if isPomodoro { Color.black.edgesIgnoringSafeArea(.all) }
            else { Color.green.edgesIgnoringSafeArea(.all) }

            VStack {
                Spacer()
                Text(formatTime(currentTime))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(isPomodoro ? .red : .black)
                Spacer()
                if !isPomodoro {
                    Text(pauseText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer().frame(height: 100)
            }
        }
        .onTapGesture {
            if !started {
                started = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                startSessionIfNeeded()
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    self.updateTimer()
                }
            }
        }
        .onAppear {
            // Request permission
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

            // CLEAR any pending notifications from previous runs (prevents notifications firing after force-quit)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

            // Restore persisted target only if it's still valid (in future)
            if let saved = UserDefaults.standard.object(forKey: "PomodoroTargetDate") as? Date,
               UserDefaults.standard.bool(forKey: "PomodoroStarted") {
                let remaining = saved.timeIntervalSinceNow
                if remaining > 1 {
                    targetDate = saved
                    isPomodoro = UserDefaults.standard.bool(forKey: "PomodoroIsWork")
                    started = true
                    currentTime = Int(max(1, remaining))
                    // Re-schedule a single notification for the remaining time
                    schedulePhaseEndNotification(in: remaining, title: isPomodoro ? "Work finished" : "Break finished", body: isPomodoro ? "Time for a break." : "Time to work.")
                    // start UI timer
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        self.updateTimer()
                    }
                } else {
                    // saved target expired — clear persisted session
                    clearPersistedSession()
                }
            } else {
                // No valid saved session — ensure persisted state is clean
                clearPersistedSession()
            }

            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                persistTarget()
            }
            NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                refreshFromTarget()
            }
            // Also clear persisted session on launch termination edge-cases
            NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                clearPersistedSession()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // Session lifecycle

    func startSessionIfNeeded() {
        guard targetDate == nil else { refreshFromTarget(); return }

        let duration = isPomodoro ? TimeInterval(time) : TimeInterval(breakTime)
        targetDate = Date().addingTimeInterval(duration)
        persistTarget()
        schedulePhaseEndNotification(in: duration, title: isPomodoro ? "Work finished" : "Break finished", body: isPomodoro ? "Time for a break." : "Time to work.")
    }

    func updateTimer() {
        guard let target = targetDate else { return }
        let remainingSeconds = Int(target.timeIntervalSinceNow)
        if remainingSeconds <= 0 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            if isPomodoro {
                isPomodoro = false
                currentTime = breakTime
                updatePauseText()
                targetDate = Date().addingTimeInterval(TimeInterval(breakTime))
                cancelPhaseEndNotification()
                schedulePhaseEndNotification(in: TimeInterval(breakTime), title: "Break finished", body: "Break time is over.")
            } else {
                isPomodoro = true
                currentTime = time
                pauseText = ""
                targetDate = Date().addingTimeInterval(TimeInterval(time))
                cancelPhaseEndNotification()
                schedulePhaseEndNotification(in: TimeInterval(time), title: "Work finished", body: "Work time is over.")
            }
            persistTarget()
        } else {
            currentTime = remainingSeconds
        }
    }

    func refreshFromTarget() {
        guard let target = targetDate else {
            currentTime = isPomodoro ? time : breakTime
            return
        }
        let diff = Int(target.timeIntervalSinceNow)
        if diff <= 0 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            if isPomodoro {
                isPomodoro = false
                updatePauseText()
                targetDate = Date().addingTimeInterval(TimeInterval(breakTime))
                cancelPhaseEndNotification()
                schedulePhaseEndNotification(in: TimeInterval(breakTime), title: "Break finished", body: "Break time is over.")
                currentTime = breakTime
            } else {
                isPomodoro = true
                pauseText = ""
                targetDate = Date().addingTimeInterval(TimeInterval(time))
                cancelPhaseEndNotification()
                schedulePhaseEndNotification(in: TimeInterval(time), title: "Work finished", body: "Work time is over.")
                currentTime = time
            }
            persistTarget()
        } else {
            currentTime = diff
        }
    }

    // Persistence

    func persistTarget() {
        if let t = targetDate {
            UserDefaults.standard.set(t, forKey: "PomodoroTargetDate")
            UserDefaults.standard.set(isPomodoro, forKey: "PomodoroIsWork")
            UserDefaults.standard.set(true, forKey: "PomodoroStarted")
        } else {
            UserDefaults.standard.removeObject(forKey: "PomodoroTargetDate")
            UserDefaults.standard.set(false, forKey: "PomodoroStarted")
        }
    }

    func clearPersistedSession() {
        targetDate = nil
        started = false
        pauseText = ""
        UserDefaults.standard.removeObject(forKey: "PomodoroTargetDate")
        UserDefaults.standard.removeObject(forKey: "PomodoroIsWork")
        UserDefaults.standard.set(false, forKey: "PomodoroStarted")
        cancelPhaseEndNotification()
    }

    // Notifications

    func schedulePhaseEndNotification(in seconds: TimeInterval, id: String = "pomodoro.phaseEnd", title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    func cancelPhaseEndNotification(id: String = "pomodoro.phaseEnd") {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // Utility

    func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

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
        if Int.random(in: 1...1000) == 1 { pauseText = "i use arch btw" }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
