import SwiftUI

struct MeetingDetailView: View {
    @EnvironmentObject var viewModel: MeetingViewModel
    @EnvironmentObject var audioRecorder: AudioRecorderService
    @ObservedObject var meeting: Meeting
    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    @State private var showDeleteConfirmation = false
    
    @Environment(\.dismiss) var dismiss // Add this to enable programmatic dismissal

    // Enum to represent the different states of the view
    private enum ViewState {
        case processing
        case error(String)
        case results(transcript: String, keyPoints: String?, nextSteps: String?)
        case recording
        case readyToRecord
        case idle
        case permissionRequired
    }
    
    // Computed property to determine the current state
    private var currentState: ViewState {
        // 1. Prioritize displaying results, errors, or processing states for the *current* meeting.
        if let transcript = meeting.transcript, !transcript.isEmpty {
            return .results(transcript: transcript, keyPoints: meeting.keyPoints, nextSteps: meeting.nextSteps)
        } else if let error = meeting.errorMessage, !error.isEmpty {
            return .error(error)
        } else if meeting.isProcessing {
            return .processing
        }

        // 2. Then, check for active recording states, but only if this is the *currently selected* meeting in the ViewModel.
        if let currentVMMeeting = viewModel.currentMeeting, currentVMMeeting.id == meeting.id {
            if !audioRecorder.permissionGranted {
                return .permissionRequired
            } else if audioRecorder.isRecording {
                return .recording
            } else if currentVMMeeting.transcript == nil && currentVMMeeting.errorMessage == nil {
                return .readyToRecord
            }
        }

        // 3. Default to idle if none of the above conditions are met. This covers existing meetings
        //    that are not actively recording/processing and don't have results/errors to display yet.
        return .idle
    }

    var body: some View {
        ScrollView {
            mainContentView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(meeting.title ?? "Untitled Meeting")
        .toolbar {
            // Show Cancel button only when actively recording the current meeting
            // And only if this meeting is the one currently being recorded
            if let currentRecordingMeeting = viewModel.currentMeeting, currentRecordingMeeting.id == meeting.id && audioRecorder.isRecording {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("MeetingDetailView: Cancel button tapped")
                        viewModel.stopRecording()
                        viewModel.currentMeeting = nil
                        dismiss() // Dismiss the sheet/view
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    print("MeetingDetailView: Done button tapped")
                    // Dismiss the view directly.
                    dismiss()
                }
            }
        }
        .onAppear { // Add onAppear to log meeting data
            print("MeetingDetailView: onAppear - Meeting Title: \(meeting.title ?? "N/A")")
            print("MeetingDetailView: onAppear - Transcript: \(meeting.transcript ?? "N/A")")
            print("MeetingDetailView: onAppear - Key Points: \(meeting.keyPoints ?? "N/A")")
            print("MeetingDetailView: onAppear - Next Steps: \(meeting.nextSteps ?? "N/A")")
            print("MeetingDetailView: onAppear - Is Processing: \(meeting.isProcessing)")
            print("MeetingDetailView: onAppear - Error Message: \(meeting.errorMessage ?? "N/A")")
            print("MeetingDetailView: onAppear - Current State: \(String(describing: currentState))")
        }
    }

    // MARK: - Helper Views for States

    private func mainContentView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Conditional UI based on primary states
            Group {
                switch currentState {
                case .recording:
                    recordingView()
                case .processing:
                    processingView()
                case .readyToRecord:
                    readyToRecordView()
                case .permissionRequired:
                    permissionRequiredView()
                case .idle:
                    idleView()
                case .error(let error):
                    errorView(error: error)
                case .results(let transcript, let keyPoints, let nextSteps):
                    resultsView(transcript: transcript, keyPoints: keyPoints, nextSteps: nextSteps)
                }
            }
        }
        .padding(.vertical)
    }


    private func recordingView() -> some View {
        VStack {
            PulsingCircleView(isActive: audioRecorder.isRecording)
                .frame(width: 50, height: 50)
                .padding()

            Text("Recording…")
                .font(.headline)

            Button("Stop Recording") {
                viewModel.stopRecording()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func processingView() -> some View {
        VStack {
            ProgressView("Processing…")
                .progressViewStyle(CircularProgressViewStyle())
            Text("Hang tight, we're processing your recording.")
        }
    }

    private func readyToRecordView() -> some View {
        VStack(spacing: 24) {
           // Moved conditional logic into readyToRecordView based on permission status
            if !audioRecorder.permissionGranted { 
                permissionRequiredView()
            } else { 
                VStack(spacing: 24) {
                     Button(action: {
                         print("MeetingDetailView: Start Recording button tapped")
                         // Set the current meeting in ViewModel before starting recording
                         viewModel.currentMeeting = meeting // Set the current meeting
                         viewModel.startRecording()
                     }) {
                         Image(systemName: "mic.circle.fill")
                             .font(.system(size: 64))
                             .foregroundColor(.blue)
                     }

                     Text("Tap to Start Recording")
                         .font(.headline)
                         .foregroundColor(.secondary)
                 }
             }
         }
         .frame(maxWidth: .infinity)
         .padding()
     }

    private func permissionRequiredView() -> some View {
        VStack {
            Text("Microphone access is needed to record meetings.")
            Button("Enable Microphone") {
                audioRecorder.requestPermission()
            }
            .buttonStyle(.bordered)
        }
    }

    private func idleView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditingTitle {
                HStack {
                    TextField("Meeting Title", text: $editedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Save") {
                        meeting.title = editedTitle
                        isEditingTitle = false
                        viewModel.updateMeetingTitle(meeting, newTitle: editedTitle)
                    }
                    Button("Cancel") {
                        isEditingTitle = false
                        editedTitle = meeting.title ?? ""
                    }
                }
            } else {
                HStack {
                    Text(meeting.title ?? "Untitled Meeting")
                        .font(.title)
                        .bold()
                    Button(action: {
                        editedTitle = meeting.title ?? ""
                        isEditingTitle = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }
            }

            if let date = meeting.date {
                Text("Date: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundColor(.secondary)
            }

            // Display transcript, key points, and next steps if available in idle state (after processing)
             if let transcript = meeting.transcript, !transcript.isEmpty {
                 Text("Transcript:")
                     .font(.headline)
                 Text(transcript)
                     .padding(.top, 2)
             }
            
             if let keyPoints = meeting.keyPoints, !keyPoints.isEmpty {
                 Text("Key Points:")
                     .font(.headline)
                 Text(keyPoints)
                     .padding(.top, 2)
             }
            
             if let nextSteps = meeting.nextSteps, !nextSteps.isEmpty {
                 Text("Next Steps:")
                     .font(.headline)
                 Text(nextSteps)
                     .padding(.top, 2)
             }

            HStack(spacing: 20) {
                Button("Start Recording") {
                    print("MeetingDetailView: Start Recording button tapped")
                    // Set the current meeting in ViewModel before starting recording
                    viewModel.currentMeeting = meeting // Set the current meeting
                    viewModel.startRecording()
                }
                .buttonStyle(.borderedProminent)

                Button("Delete Meeting") {
                     print("MeetingDetailView: Delete Meeting button tapped")
                    showDeleteConfirmation = true
                }
                .foregroundColor(.red)
                .buttonStyle(.bordered)
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Meeting?"),
                    message: Text("This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        viewModel.deleteMeeting(meeting)
                        dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func errorView(error: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.largeTitle)
            Text("Error: \(error)")
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            Button("Dismiss") {
                // Clear error on the meeting itself as well, not just viewModel.errorMessage
                meeting.errorMessage = nil
                if viewModel.currentMeeting?.id == meeting.id {
                    viewModel.errorMessage = nil // Also clear ViewModel's general error if it pertains to this meeting
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func resultsView(transcript: String, keyPoints: String?, nextSteps: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcript:")
                .font(.headline)
            Text(transcript)
                .padding(.bottom, 8)

            Group { // Use Group to conditionally display key points section
                if let keyPoints = keyPoints, !keyPoints.isEmpty {
                    Text("Key Points:")
                        .font(.headline)
                    Text(keyPoints)
                        .padding(.bottom, 8)
                } else {
                    Text("No key points found.")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
            }

            Group { // Use Group to conditionally display next steps section
                if let nextSteps = nextSteps, !nextSteps.isEmpty {
                    Text("Next Steps:")
                        .font(.headline)
                    Text(nextSteps)
                } else {
                    Text("No next steps found.")
                        .foregroundColor(.secondary)
                }
            }
            // Add a toolbar item to edit the title
            HStack(spacing: 20) {
                Button("Start New Recording") {
                    // Set currentMeeting to nil to allow a new recording to be initiated
                    viewModel.currentMeeting = nil
                    viewModel.startRecording()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct PulsingCircleView: View {
    var isActive: Bool
    @State private var pulsate = false

    var body: some View {
        Circle()
            .fill(isActive ? Color.red : Color.gray)
            .frame(width: 50, height: 50)
            .scaleEffect(pulsate ? 1.2 : 1.0)
            .animation(isActive ? Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: pulsate)
            .onAppear {
                if isActive {
                    pulsate = true
                }
            }
            .onChange(of: isActive) { newValue in
                pulsate = newValue
            }
    }
}

// MARK: - Preview
struct MeetingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.context
        let meeting = Meeting(context: context)
        meeting.id = UUID()
        meeting.title = "Sample Meeting"
        meeting.date = Date()
        meeting.transcript = "This is a sample transcript."
        meeting.keyPoints = "• Point 1\n• Point 2"
        meeting.nextSteps = "1. Action item 1\n2. Action item 2"
        
        let viewModel = MeetingViewModel(audioRecorder: AudioRecorderService())
        viewModel.currentMeeting = meeting
        
        let audioRecorder = AudioRecorderService()
        audioRecorder.permissionGranted = true
        
        return MeetingDetailView(meeting: meeting)
            .environmentObject(viewModel)
            .environmentObject(audioRecorder)
    }
}

