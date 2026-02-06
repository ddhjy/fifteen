//
//  WorkflowManager.swift
//  fifteen
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Node Types

enum WorkflowNodeType: String, Codable, CaseIterable {
    case aiProcess = "ai_process"
    case copyToClipboard = "copy"
    case save = "save"
    case httpPost = "http_post"
    
    var displayName: String {
        switch self {
        case .aiProcess: return "AI 处理"
        case .copyToClipboard: return "复制"
        case .save: return "保存记录"
        case .httpPost: return "HTTP 发送"
        }
    }
    
    var icon: String {
        switch self {
        case .aiProcess: return "sparkles"
        case .copyToClipboard: return "doc.on.doc"
        case .save: return "square.and.arrow.down"
        case .httpPost: return "paperplane.circle"
        }
    }
}

// MARK: - Workflow Node

struct WorkflowNode: Identifiable, Codable, Equatable {
    let id: UUID
    var type: WorkflowNodeType
    var isEnabled: Bool
    var config: NodeConfig
    
    struct NodeConfig: Codable, Equatable {
        var aiPrompt: String?
        var skipConfirmation: Bool?
        var httpHost: String?
        var httpPort: Int?
    }
    
    init(id: UUID = UUID(), type: WorkflowNodeType, isEnabled: Bool = true, config: NodeConfig = NodeConfig()) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.config = config
    }
    
    static func defaultNodes() -> [WorkflowNode] {
        [
            WorkflowNode(type: .copyToClipboard, isEnabled: false),
            WorkflowNode(type: .save, isEnabled: true, config: NodeConfig(skipConfirmation: false))
        ]
    }
}

// MARK: - Workflow Execution Result

struct WorkflowExecutionResult: Identifiable {
    let id = UUID()
    let finalText: String
    let originalText: String
    let tags: [String]
    let shouldSave: Bool
    let skipConfirmation: Bool
    let didCopyToClipboard: Bool
}

// MARK: - Workflow Manager

@Observable
class WorkflowManager {
    static let shared = WorkflowManager()
    
    var nodes: [WorkflowNode] = []
    var isExecuting: Bool = false
    var currentNodeIndex: Int = 0
    var executionError: Error?
    
    private let storageKey = "workflowNodes"
    private let mandatoryTerminalOrder: [WorkflowNodeType] = [.copyToClipboard, .save]
    
    private init() {
        loadNodes()
    }
    
    // MARK: - Terminal Node Helpers
    
    private func isMandatoryTerminal(_ type: WorkflowNodeType) -> Bool {
        mandatoryTerminalOrder.contains(type)
    }
    
    var areTerminalNodesAllDisabled: Bool {
        let saveEnabled = nodes.first(where: { $0.type == .save })?.isEnabled ?? false
        return !saveEnabled
    }
    
    private func normalizeNodesIfNeeded() {
        var seen = Set<WorkflowNodeType>()
        nodes = nodes.filter { node in
            guard isMandatoryTerminal(node.type) else { return true }
            if seen.contains(node.type) { return false }
            seen.insert(node.type)
            return true
        }
        
        for type in mandatoryTerminalOrder {
            if !nodes.contains(where: { $0.type == type }) {
                nodes.append(WorkflowNode(type: type, isEnabled: false))
            }
        }
        
        let others = nodes.filter { !isMandatoryTerminal($0.type) }
        let terminal = mandatoryTerminalOrder.compactMap { type in
            nodes.first(where: { $0.type == type })
        }
        nodes = others + terminal
    }
    
    // MARK: - Persistence
    
    private func loadNodes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let savedNodes = try? JSONDecoder().decode([WorkflowNode].self, from: data) else {
            nodes = WorkflowNode.defaultNodes()
            normalizeNodesIfNeeded()
            saveNodes()
            return
        }
        nodes = savedNodes
        normalizeNodesIfNeeded()
        saveNodes()
    }
    
    func saveNodes() {
        normalizeNodesIfNeeded()
        if let data = try? JSONEncoder().encode(nodes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    // MARK: - Node Management
    
    func addNode(_ node: WorkflowNode) {
        nodes.append(node)
        saveNodes()
    }
    
    func removeNode(at index: Int) {
        nodes.remove(at: index)
        saveNodes()
    }
    
    func moveNode(from source: IndexSet, to destination: Int) {
        nodes.move(fromOffsets: source, toOffset: destination)
        saveNodes()
    }
    
    func updateNode(_ node: WorkflowNode) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
            saveNodes()
        }
    }
    
    func deleteNodes(at offsets: IndexSet) {
        let removable = offsets.filter { idx in
            guard nodes.indices.contains(idx) else { return false }
            return !isMandatoryTerminal(nodes[idx].type)
        }
        nodes.remove(atOffsets: IndexSet(removable))
        saveNodes()
    }
    
    // MARK: - Execution
    
    func execute(input: String, tags: [String]) async throws -> WorkflowExecutionResult {
        await MainActor.run {
            isExecuting = true
            currentNodeIndex = 0
            executionError = nil
        }
        
        defer {
            Task { @MainActor in
                isExecuting = false
            }
        }
        
        var currentText = input
        let enabledNodes = nodes.filter { $0.isEnabled }
        var didCopy = false
        var shouldSave = false
        var skipConfirmation = false
        
        for (index, node) in enabledNodes.enumerated() {
            await MainActor.run {
                currentNodeIndex = index
            }
            
            switch node.type {
            case .aiProcess:
                if let prompt = node.config.aiPrompt, !prompt.isEmpty {
                    currentText = try await AIService.shared.process(text: currentText, prompt: prompt)
                }
                
            case .httpPost:
                let host = node.config.httpHost ?? "localhost"
                let port = node.config.httpPort ?? 9999
                let urlString = "http://\(host):\(port)"
                guard let url = URL(string: urlString) else {
                    throw NSError(domain: "WorkflowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL: \(urlString)"])
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = currentText.data(using: .utf8)
                request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    throw NSError(domain: "WorkflowManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP 请求失败，状态码: \(httpResponse.statusCode)"])
                }

            case .copyToClipboard:
                let textToCopy = currentText
                await MainActor.run {
                    UIPasteboard.general.string = textToCopy
                }
                didCopy = true
                
            case .save:
                shouldSave = true
                skipConfirmation = node.config.skipConfirmation ?? false
            }
        }
        
        return WorkflowExecutionResult(
            finalText: currentText,
            originalText: input,
            tags: tags,
            shouldSave: shouldSave,
            skipConfirmation: skipConfirmation,
            didCopyToClipboard: didCopy
        )
    }
}
