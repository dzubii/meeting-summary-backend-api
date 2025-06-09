import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private init() {}
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        let boundary = UUID().uuidString
        let urlString = "\(APIConfig.baseURL)/api/transcribe"
        print("Attempting to create URL with string: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Failed to create URL from string: \(urlString)")
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
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
        
        print("Making POST request to: \(urlString)")
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response received: \(response)")
                throw APIError.invalidResponse
            }
            
            print("Received HTTP response status code: \(httpResponse.statusCode)")
            print("Received response data: \(String(data: responseData, encoding: .utf8) ?? "Unable to decode data as UTF-8")")
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                    print("Server error response: \(errorResponse.error)")
                    throw APIError.serverError(errorResponse.error)
                }
                print("Server returned non-200 status with no error response: \(httpResponse.statusCode)")
                throw APIError.serverError("Unknown error occurred with status code \(httpResponse.statusCode)")
            }
            
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: responseData)
            print("Successfully transcribed audio")
            return transcriptionResponse.text
        } catch {
            print("Network or processing error during transcription: \(error.localizedDescription)")
            // Re-throw the error or wrap it in your APIError
            throw error
        }
    }
    
    func summarizeTranscript(_ transcript: String) async throws -> (keyPoints: String, nextSteps: String) {
        let urlString = "\(APIConfig.baseURL)/api/summarize"
        print("Attempting to create URL with string: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Failed to create URL from string: \(urlString)")
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Ensure Content-Type is JSON for summary
        
        let requestBody = ["transcript": transcript]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("Making POST request to: \(urlString)")
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                 print("Invalid response received: \(response)")
                throw APIError.invalidResponse
            }
            
            print("Received HTTP response status code: \(httpResponse.statusCode)")
             print("Received response data: \(String(data: responseData, encoding: .utf8) ?? "Unable to decode data as UTF-8")")
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                     print("Server error response: \(errorResponse.error)")
                    throw APIError.serverError(errorResponse.error)
                }
                 print("Server returned non-200 status with no error response: \(httpResponse.statusCode)")
                throw APIError.serverError("Unknown error occurred with status code \(httpResponse.statusCode)")
            }
            
            let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: responseData)
            print("Successfully summarized transcript")
            return (summaryResponse.keyPoints, summaryResponse.nextSteps)
        } catch {
            print("Network or processing error during summarization: \(error.localizedDescription)")
            // Re-throw the error or wrap it in your APIError
            throw error
        }
    }

    // New function to generate a short title summary
    func generateTitleSummary(_ transcript: String) async throws -> String {
        let urlString = "\(APIConfig.baseURL)/api/generate-title"
        print("Attempting to create URL for title summary with string: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Failed to create URL for title summary from string: \(urlString)")
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["transcript": transcript]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("Making POST request to: \(urlString) for title summary")

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response received for title summary: \(response)")
                throw APIError.invalidResponse
            }

            print("Received HTTP response status code for title summary: \(httpResponse.statusCode)")
            print("Received response data for title summary: \(String(data: responseData, encoding: .utf8) ?? "Unable to decode data as UTF-8")")

            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                    print("Server error response for title summary: \(errorResponse.error)")
                    throw APIError.serverError(errorResponse.error)
                }
                print("Server returned non-200 status for title summary with no error response: \(httpResponse.statusCode)")
                throw APIError.serverError("Unknown error occurred with status code \(httpResponse.statusCode)")
            }

            let titleSummaryResponse = try JSONDecoder().decode(TitleSummaryResponse.self, from: responseData)
            print("Successfully generated title summary")
            return titleSummaryResponse.title
        } catch let error as APIError {
            print("API Error during title summarization: \(error)")
            throw error
        } catch {
            print("Unknown error during title summarization: \(error.localizedDescription)")
            throw APIError.serverError("Unknown error during title summarization: \(error.localizedDescription)")
        }
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

// New response model for title summary
struct TitleSummaryResponse: Codable {
    let title: String
}

struct ErrorResponse: Codable {
    let error: String
}

enum APIError: Error {
    case invalidResponse
    case serverError(String)
    case invalidURL
} 