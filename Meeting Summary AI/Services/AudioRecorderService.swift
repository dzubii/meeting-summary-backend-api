import Foundation
import AVFoundation

class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    private func checkPermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                DispatchQueue.main.async {
                    self.permissionGranted = true
                    self.setupAudioSession()
                }
            case .denied:
                DispatchQueue.main.async {
                    self.permissionGranted = false
                    self.errorMessage = "Microphone access denied"
                }
            case .undetermined:
                // Don't request permission here, wait for explicit request
                DispatchQueue.main.async {
                    self.permissionGranted = false
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.permissionGranted = false
                    self.errorMessage = "Unknown permission status"
                }
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                DispatchQueue.main.async {
                    self.permissionGranted = true
                    self.setupAudioSession()
                }
            case .denied:
                DispatchQueue.main.async {
                    self.permissionGranted = false
                    self.errorMessage = "Microphone access denied"
                }
            case .undetermined:
                // Don't request permission here, wait for explicit request
                DispatchQueue.main.async {
                    self.permissionGranted = false
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.permissionGranted = false
                    self.errorMessage = "Unknown permission status"
                }
            }
        }
    }
    
    func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupAudioSession()
                    } else {
                        self?.errorMessage = "Microphone access denied"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupAudioSession()
                    } else {
                        self?.errorMessage = "Microphone access denied"
                    }
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session setup successful")
        } catch {
            print("Failed to set up audio session: \(error)")
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
        }
    }
    
    func startRecording() -> URL? {
        guard permissionGranted else {
            print("Microphone permission not granted")
            errorMessage = "Microphone permission not granted"
            return nil
        }
        
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
            errorMessage = "Failed to activate audio session: \(error.localizedDescription)"
            return nil
        }
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
            if audioRecorder?.record() == true {
                print("AVAudioRecorder isRecording: \(audioRecorder?.isRecording ?? false)")
                // Reset state before starting
                timer?.invalidate()
                timer = nil
                startTime = nil
                recordingTime = 0
                
                // Start recording
                isRecording = true
                startTime = Date()
                
                // Start timer on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                        guard let self = self, let startTime = self.startTime else { return }
                        self.recordingTime = Date().timeIntervalSince(startTime)
                        print("Timer fired: \(self.recordingTime)")
                    }
                    if let timer = self.timer {
                        RunLoop.current.add(timer, forMode: .common)
                    }
                }
                
                print("Recording started successfully")
                return audioFilename
            } else {
                print("Failed to start recording")
                errorMessage = "Failed to start recording"
                return nil
            }
        } catch {
            print("Could not start recording: \(error)")
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            return nil
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop recording first
        audioRecorder?.stop()
        
        // Then update state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer?.invalidate()
            self.timer = nil
            self.startTime = nil
            self.isRecording = false
            self.recordingTime = 0
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
        print("Recording stopped")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            if !flag {
                print("Recording finished unsuccessfully")
                self?.errorMessage = "Recording finished unsuccessfully"
            }
            self?.isRecording = false
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                print("Recording error: \(error)")
                self?.errorMessage = "Recording error: \(error.localizedDescription)"
            }
            self?.isRecording = false
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }
} 