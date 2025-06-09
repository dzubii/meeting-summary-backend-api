import SwiftUI
import Meeting_Summary_AI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var viewModel: MeetingViewModel
    @EnvironmentObject var audioRecorder: AudioRecorderService
    
    @State private var isPresentingNewMeeting = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.meetings, id: \.objectID) { meeting in
                    NavigationLink {
                        // MeetingDetailView now accepts a Meeting object directly
                        MeetingDetailView(meeting: meeting)
                            .environmentObject(viewModel)
                            .environmentObject(audioRecorder)
                    } label: {
                        MeetingRowView(meeting: meeting)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let meetingToDelete = viewModel.meetings[index]
                        viewModel.deleteMeeting(meetingToDelete)
                    }
                }
            }
            .navigationTitle("Meetings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Request permission every time the button is tapped.
                        // The system will only show the prompt if permission hasn't been granted/denied yet.
                        audioRecorder.requestPermission()
                        // Attempt to start recording immediately. The viewModel's logic
                        // will handle if permission is not yet granted.
                        viewModel.startRecording()
                        isPresentingNewMeeting = true
                    }) {
                        Label("New Meeting", systemImage: "mic.circle")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewMeeting) {
                VStack {
                    if let newMeeting = viewModel.currentMeeting {
                        // Pass the newly created meeting to MeetingDetailView
                        MeetingDetailView(meeting: newMeeting)
                            .environmentObject(viewModel)
                            .environmentObject(audioRecorder)
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .onChange(of: audioRecorder.permissionGranted) { newPermissionStatus in
                    // If permission is now granted and we still don't have a current meeting,
                    // re-attempt to start recording.
                    if newPermissionStatus && viewModel.currentMeeting == nil {
                        viewModel.startRecording()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadMeetings()
        }
    }
}

// MARK: - Meeting Row View (From your original code)
struct MeetingRowView: View {
    @ObservedObject var meeting: Meeting

    var body: some View {
        VStack(alignment: .leading) {
            Text(meeting.title ?? "Untitled Meeting")
                .font(.headline)
            Text(meeting.date ?? Date(), style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Using @StateObject here because this view "owns" the creation of the view models for the preview.
        let viewModel = MeetingViewModel(audioRecorder: AudioRecorderService())
        let audioRecorder = AudioRecorderService()
        
        // You can create sample data within the preview for better isolation
        let context = CoreDataManager.shared.context // Make sure CoreDataManager is accessible here
        let meeting1 = Meeting(context: context)
        meeting1.title = "Sample Meeting 1"
        meeting1.date = Date()

        let meeting2 = Meeting(context: context)
        meeting2.title = "Sample Meeting 2"
        meeting2.date = Date().addingTimeInterval(-3600)

        viewModel.meetings = [meeting1, meeting2]

        return ContentView()
            .environmentObject(viewModel)
            .environmentObject(audioRecorder)
    }
}
