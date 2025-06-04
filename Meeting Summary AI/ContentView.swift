//
//  ContentView.swift
//  Meeting Summary AI
//
//  Created by David Zubicek on 2025-06-03.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MeetingViewModel()
    @State private var showingNewMeeting = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.meetings, id: \.id) { meeting in
                    NavigationLink(destination: MeetingDetailView(meeting: meeting)) {
                        MeetingRowView(meeting: meeting)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteMeeting(viewModel.meetings[index])
                    }
                }
            }
            .navigationTitle("Meetings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewMeeting = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewMeeting) {
                RecordingView(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Processing Recording", isPresented: .constant(viewModel.isProcessing)) {
                // No buttons needed, as it's a progress indicator
            } message: {
                Text("Processing your recording...")
            }
        }
    }
}

struct MeetingRowView: View {
    let meeting: Meeting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title ?? "Untitled Meeting")
                .font(.headline)
            
            Text(meeting.date ?? Date(), style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if meeting.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = meeting.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MeetingViewModel
    @ObservedObject var audioRecorder: AudioRecorderService
    
    @State private var meetingTitle = ""
    @State private var showingPermissionAlert = false
    
    init(viewModel: MeetingViewModel) {
        self.viewModel = viewModel
        self.audioRecorder = viewModel.audioRecorder
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !audioRecorder.permissionGranted {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                        
                        Text("Microphone Access Required")
                            .font(.headline)
                        
                        Text("Please enable microphone access to record meetings.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Enable Microphone") {
                            audioRecorder.requestPermission()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if audioRecorder.isRecording {
                    VStack(spacing: 24) {
                        // Recording indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(audioRecorder.isRecording ? 1 : 0.3)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: audioRecorder.isRecording)
                            
                            Text("Recording")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        // Timer
                        Text(viewModel.formatTime(audioRecorder.recordingTime))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        // Stop button
                        Button(action: {
                            viewModel.stopRecording()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    VStack(spacing: 24) {
                        // Start recording button
                        Button(action: {
                            if audioRecorder.permissionGranted {
                                viewModel.startRecording()
                            } else {
                                audioRecorder.requestPermission()
                            }
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
                
                if !audioRecorder.isRecording {
                    TextField("Meeting Title", text: $meetingTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
            }
            .padding()
            .navigationTitle("New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in Settings to record meetings.")
            }
        }
    }
}

#Preview {
    ContentView()
}
