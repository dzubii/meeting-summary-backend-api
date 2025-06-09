import SwiftUI

@main
struct Meeting_Summary_AIApp: App {
    let persistenceController = CoreDataManager.shared
     
    // These properties will be initialized in the init() method below.
    @StateObject private var audioRecorder: AudioRecorderService
    @StateObject private var viewModel: MeetingViewModel

    init() {
        // 1. Create the dependency as a local constant first.
        let recorder = AudioRecorderService()
        
        // 2. Initialize both StateObjects using the local constant.
        // This avoids the "escaping autoclosure" error.
        _audioRecorder = StateObject(wrappedValue: recorder)
        _viewModel = StateObject(wrappedValue: MeetingViewModel(audioRecorder: recorder))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.context)
                .environmentObject(viewModel)
                .environmentObject(audioRecorder)
        }
    }
}
