import XCTest
@testable import Meeting_Summary_AI

final class RecordingTests: XCTestCase {
    var viewModel: MeetingViewModel!
    var audioRecorder: AudioRecorderService!
    
    override func setUp() {
        super.setUp()
        viewModel = MeetingViewModel()
        audioRecorder = viewModel.audioRecorder
    }
    
    override func tearDown() {
        viewModel = nil
        audioRecorder = nil
        super.tearDown()
    }
    
    func testRecordingStateChanges() {
        // Test initial state
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.recordingTime, 0)
        
        // Start recording
        viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)
        
        // Stop recording
        viewModel.stopRecording()
        XCTAssertFalse(viewModel.isRecording)
    }
    
    func testRecordingTimeUpdates() {
        // Start recording
        viewModel.startRecording()
        
        // Wait for a short duration
        let expectation = XCTestExpectation(description: "Recording time updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Verify time has been updated
        XCTAssertGreaterThan(viewModel.recordingTime, 0)
        
        // Stop recording
        viewModel.stopRecording()
    }
    
    func testRecordingPermissionHandling() {
        // Test permission state
        XCTAssertNotNil(audioRecorder.permissionGranted)
        
        // Test error handling when permission is denied
        if !audioRecorder.permissionGranted {
            viewModel.startRecording()
            XCTAssertNotNil(viewModel.errorMessage)
        }
    }
    
    func testRecordingProcessing() {
        // Start recording
        viewModel.startRecording()
        
        // Wait for a short duration
        let expectation = XCTestExpectation(description: "Recording processes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Stop recording and verify processing starts
        viewModel.stopRecording()
        XCTAssertFalse(viewModel.isRecording)
        
        // Verify a meeting was created
        XCTAssertFalse(viewModel.meetings.isEmpty)
    }
    
    func testRecordingErrorHandling() {
        // Test error handling when starting recording without permission
        if !audioRecorder.permissionGranted {
            viewModel.startRecording()
            XCTAssertNotNil(viewModel.errorMessage)
            XCTAssertFalse(viewModel.isRecording)
        }
    }
} 