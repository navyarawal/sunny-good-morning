import SwiftUI

@main
struct NFCAlarmPrototypeApp: App {
    @StateObject private var viewModel = AlarmAppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
