import Foundation
import SwiftUI
import Combine

@MainActor
class MeetingViewModel: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var currentMeeting: Meeting?
    
    private let audioRecorder: AudioRecorderService
    private let openAIService = OpenAIService.shared
    public let coreDataManager = CoreDataManager.shared
    
    init(audioRecorder: AudioRecorderService) {
        self.audioRecorder = audioRecorder
        loadMeetings()
    }
    
    func loadMeetings() {
        meetings = coreDataManager.fetchMeetings()
    }
    
    func startRecording() {
        errorMessage = nil // Clear any previous error messages
        print("MeetingViewModel: startRecording called.")
        print("MeetingViewModel: audioRecorder.permissionGranted = \(audioRecorder.permissionGranted)")
        print("MeetingViewModel: audioRecorder.errorMessage (before startRecording) = \(String(describing: audioRecorder.errorMessage))")

        guard audioRecorder.permissionGranted else {
            errorMessage = "Microphone access is required to record meetings"
            print("MeetingViewModel: Error - Microphone access not granted. errorMessage: \(errorMessage ?? "nil")")
            return
        }
        
        guard let audioURL = audioRecorder.startRecording() else {
            errorMessage = "Failed to start recording"
            print("MeetingViewModel: Error - Failed to start recording. errorMessage: \(errorMessage ?? "nil")")
            return
        }
        
        currentMeeting = coreDataManager.createMeeting(title: "New Meeting")
        currentMeeting?.audioURL = audioURL.absoluteString
        coreDataManager.saveContext()
        print("MeetingViewModel: currentMeeting after creation attempt = \(String(describing: currentMeeting?.title))")
        
        loadMeetings()
    }
    
    // MARK: - FIX #1: Use a weak capture for self in the Task
    func stopRecording() {
        audioRecorder.stopRecording()
        
        if let meeting = currentMeeting {
             meeting.isProcessing = true
             coreDataManager.saveContext()
            // Using [weak self] prevents the "Escaping autoclosure" error
            Task { [weak self] in
                guard let self = self else { return }
                await self.processRecording(for: meeting)
            }
        }
    }
    
    // MARK: - FIX #2: Add a do-catch block to handle errors
    func processRecording(for meeting: Meeting) async {
        guard let audioURLString = meeting.audioURL,
              let audioURL = URL(string: audioURLString) else { return }
        
        // This do-catch block fixes the "Errors thrown from here are not handled" error
        do {
            // Transcribe audio
            let transcript = try await openAIService.transcribeAudio(fileURL: audioURL)
            
            // Summarize transcript
            let (keyPoints, nextSteps) = try await openAIService.summarizeTranscript(transcript)

            // Generate title summary
            let titleSummary = try await openAIService.generateTitleSummary(transcript)
            
            // Update meeting status on the main actor if everything succeeded
            await MainActor.run {
                meeting.transcript = transcript // Assign transcript only on success
                meeting.keyPoints = keyPoints
                meeting.nextSteps = nextSteps
                meeting.title = titleSummary // Update the meeting title
                meeting.isProcessing = false
                meeting.errorMessage = nil
                coreDataManager.saveContext()
            }
            
        } catch {
            // This block runs if transcribeAudio or summarizeTranscript fails
            await MainActor.run {
                meeting.errorMessage = error.localizedDescription
                meeting.isProcessing = false
                coreDataManager.saveContext()
                errorMessage = "Failed to process recording: \(error.localizedDescription)"
                currentMeeting = nil
            }
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        if let audioURLString = meeting.audioURL,
           let audioURL = URL(string: audioURLString) {
            try? FileManager.default.removeItem(at: audioURL)
        }
        coreDataManager.deleteMeeting(meeting)
        loadMeetings()
        if meeting.id == currentMeeting?.id {
            currentMeeting = nil
        }
    }
    
    func updateMeetingTitle(_ meeting: Meeting, newTitle: String) {
        meeting.title = newTitle
        coreDataManager.saveContext()
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
