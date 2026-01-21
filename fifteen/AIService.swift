//
//  AIService.swift
//  fifteen
//

import Foundation

@Observable
class AIService {
    static let shared = AIService()
    
    private let baseURL = "https://idea.bytedance.net/llm_middleware/v1/chat/completions"
    
    private init() {}
    
    func process(text: String, prompt: String) async throws -> String {
        guard let token = SettingsManager.shared.aiApiToken, !token.isEmpty else {
            throw AIServiceError.missingToken
        }
        
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        // 将提示词和用户文本组合成一条消息，确保 AI 能理解要处理的内容
        let combinedMessage = "\(prompt)\n\n---\n\n\(text)"
        
        let body: [String: Any] = [
            "model": "gemini-3-flash",
            "messages": [
                ["role": "user", "content": combinedMessage]
            ],
            "stream": false,
            "temperature": 0.7,
            "max_tokens": 4096
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.requestFailed
        }
        
        let result = try JSONDecoder().decode(AIResponse.self, from: data)
        
        guard let content = result.choices.first?.message.content else {
            throw AIServiceError.emptyResponse
        }
        
        return content
    }
}

// MARK: - Error Types

enum AIServiceError: LocalizedError {
    case missingToken
    case invalidURL
    case requestFailed
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .missingToken: return "请先在设置中配置 AI API Token"
        case .invalidURL: return "无效的 API 地址"
        case .requestFailed: return "AI 请求失败，请稍后重试"
        case .emptyResponse: return "AI 返回结果为空"
        }
    }
}

// MARK: - Response Models

struct AIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}
