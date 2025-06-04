import SwiftUI

struct MeetingDetailView: View {
    @ObservedObject var meeting: Meeting
    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title section
                HStack {
                    if isEditingTitle {
                        TextField("Meeting Title", text: $editedTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                meeting.title = editedTitle
                                isEditingTitle = false
                            }
                    } else {
                        Text(meeting.title ?? "Untitled Meeting")
                            .font(.title)
                            .bold()
                    }
                    
                    Button(action: {
                        editedTitle = meeting.title ?? ""
                        isEditingTitle = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Date
                Text(meeting.date ?? Date(), style: .date)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if meeting.isProcessing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Processing meeting...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if let error = meeting.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Key Points section
                    if let keyPoints = meeting.keyPoints {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Points")
                                .font(.headline)
                            
                            Text(keyPoints)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Next Steps section
                    if let nextSteps = meeting.nextSteps {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next Steps")
                                .font(.headline)
                            
                            Text(nextSteps)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Transcript section
                    if let transcript = meeting.transcript {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcript")
                                .font(.headline)
                            
                            Text(transcript)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let meeting = Meeting(context: context)
    meeting.id = UUID()
    meeting.title = "Sample Meeting"
    meeting.date = Date()
    meeting.transcript = "This is a sample transcript."
    meeting.keyPoints = "• Point 1\n• Point 2"
    meeting.nextSteps = "1. Action item 1\n2. Action item 2"
    return MeetingDetailView(meeting: meeting)
} 