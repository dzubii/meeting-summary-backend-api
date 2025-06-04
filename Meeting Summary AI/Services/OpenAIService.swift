import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private init() {}
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/transcribe")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.headers
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add file data
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        data.append(try Data(contentsOf: fileURL))
        data.append("\r\n".data(using: .utf8)!)
        
        // Add final boundary
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Unknown error occurred")
        }
        
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: responseData)
        return transcriptionResponse.text
    }
    
    func summarizeTranscript(_ transcript: String) async throws -> (keyPoints: String, nextSteps: String) {
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/summarize")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.headers
        
        let requestBody = ["transcript": transcript]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Unknown error occurred")
        }
        
        let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: responseData)
        return (summaryResponse.keyPoints, summaryResponse.nextSteps)
    }
}

// Response models
struct TranscriptionResponse: Codable {
    let text: String
}

struct SummaryResponse: Codable {
    let keyPoints: String
    let nextSteps: String
}

struct ErrorResponse: Codable {
    let error: String
}

enum APIError: Error {
    case invalidResponse
    case serverError(String)
} 