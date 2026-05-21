import SwiftUI

@main
struct NFCAlarmPrototypeApp: App {
    @StateObject private var viewModel: AlarmAppViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AlarmBackgroundTaskCoordinator.shared.register()
        _viewModel = StateObject(wrappedValue: AlarmAppViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Keep the process alive with a silent audio loop so the alarm
                // timer can fire even when the screen is locked.
                viewModel.appDidEnterBackground()
            case .active:
                viewModel.appDidBecomeActive()
            default:
                break
            }
        }
    }
}
