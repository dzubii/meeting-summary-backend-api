import SwiftUI

@main
struct Meeting_Summary_AIApp: App {
    let persistenceController = CoreDataManager.shared
    @StateObject private var audioRecorder = AudioRecorderService()
    @StateObject private var viewModel = MeetingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.context)
                .environmentObject(viewModel)
                .environmentObject(audioRecorder)
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}