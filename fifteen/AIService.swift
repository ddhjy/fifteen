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
        
        let combinedMessage = "\(prompt)\n\n---\n\n\(text)"
        
        let body: [String: Any] = [
            "model": "kimi-k2",
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

    func recommendTags(for text: String, from availableTags: [String], maxCount: Int = 8) async throws -> [String] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return [] }

        let cleanedTags = availableTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedTags.isEmpty else { return [] }

        let uniqueTags = Array(Set(cleanedTags)).sorted()
        let limitedCount = max(1, min(maxCount, uniqueTags.count))

        let prompt = """
        你是标签推荐器。请根据正文内容，从候选标签中选出最相关的标签并按相关性从高到低排序。

        要求：
        1. 只能从候选标签中选择，不能新增、改写或合并标签。
        2. 最多返回 \(limitedCount) 个标签。
        3. 只返回 JSON 数组，例如 ["标签A","标签B"]，不要输出其它文字。

        候选标签：
        \(uniqueTags.joined(separator: " | "))
        """

        let raw = try await process(text: trimmedText, prompt: prompt)
        return parseRecommendedTags(raw, candidates: uniqueTags, maxCount: limitedCount)
    }

    private func parseRecommendedTags(_ raw: String, candidates: [String], maxCount: Int) -> [String] {
        var candidateMap: [String: String] = [:]
        for candidate in candidates {
            let key = candidate.lowercased()
            if candidateMap[key] == nil {
                candidateMap[key] = candidate
            }
        }
        var seen = Set<String>()
        var results: [String] = []

        func appendIfMatch(_ token: String) {
            let normalized = token
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'[]"))
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard !normalized.isEmpty else { return }
            guard let matched = candidateMap[normalized.lowercased()] else { return }
            guard !seen.contains(matched) else { return }
            seen.insert(matched)
            results.append(matched)
        }

        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            for token in decoded {
                appendIfMatch(token)
                if results.count >= maxCount { return results }
            }
            return results
        }

        let separators = CharacterSet(charactersIn: ",\n")
        for part in cleaned.components(separatedBy: separators) {
            appendIfMatch(part)
            if results.count >= maxCount { break }
        }

        return results
    }
}

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

struct AIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}
