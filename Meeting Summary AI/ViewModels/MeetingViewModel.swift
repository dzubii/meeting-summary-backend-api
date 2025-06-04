import Foundation
import SwiftUI

@MainActor
class MeetingViewModel: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    let audioRecorder = AudioRecorderService()
    private let openAIService = OpenAIService.shared
    private let coreDataManager = CoreDataManager.shared
    private var currentMeeting: Meeting?
    
    init() {
        loadMeetings()
    }
    
    func loadMeetings() {
        meetings = coreDataManager.fetchMeetings()
    }
    
    func startRecording() {
        guard audioRecorder.permissionGranted else {
            errorMessage = "Microphone access is required to record meetings"
            return
        }
        
        guard let audioURL = audioRecorder.startRecording() else {
            errorMessage = "Failed to start recording"
            return
        }
        
        currentMeeting = coreDataManager.createMeeting(title: "New Meeting")
        currentMeeting?.audioURL = audioURL
        currentMeeting?.isProcessing = true
        coreDataManager.saveContext()
        
        isRecording = true
        loadMeetings()
    }
    
    func stopRecording() {
        audioRecorder.stopRecording()
        isRecording = false
        
        // Process the recording if we have a current meeting
        if let meeting = currentMeeting {
            Task {
                await processRecording(for: meeting)
            }
        }
        currentMeeting = nil
    }
    
    func processRecording(for meeting: Meeting) async {
        guard let audioURL = meeting.audioURL else { return }
        
        do {
            // Transcribe audio
            let transcript = try await openAIService.transcribeAudio(fileURL: audioURL)
            meeting.transcript = transcript
            
            // Summarize transcript
            let (keyPoints, nextSteps) = try await openAIService.summarizeTranscript(transcript)
            meeting.keyPoints = keyPoints
            meeting.nextSteps = nextSteps
            
            // Update meeting status
            meeting.isProcessing = false
            coreDataManager.saveContext()
            
            // Refresh meetings list
            loadMeetings()
        } catch {
            meeting.errorMessage = error.localizedDescription
            meeting.isProcessing = false
            coreDataManager.saveContext()
            errorMessage = "Failed to process recording: \(error.localizedDescription)"
        }
    }
    
    func deleteMeeting(_ meeting: Meeting) {
        if let audioURL = meeting.audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        coreDataManager.deleteMeeting(meeting)
        loadMeetings()
    }
    
    func updateMeetingTitle(_ meeting: Meeting, newTitle: String) {
        meeting.title = newTitle
        coreDataManager.saveContext()
        loadMeetings()
    }
    
    // Helper function to format time
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 