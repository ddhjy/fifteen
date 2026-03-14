import Foundation
import SwiftUI
import UIKit


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


struct WorkflowNode: Identifiable, Codable, Equatable {
    let id: UUID
    var type: WorkflowNodeType
    var isEnabled: Bool
    var config: NodeConfig
    
    struct NodeConfig: Codable, Equatable {
        var aiPrompt: String?
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
            WorkflowNode(type: .save, isEnabled: true)
        ]
    }
}


struct Workflow: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var isOpen: Bool
    var nodes: [WorkflowNode]
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, isOpen, nodes
    }
    
    init(
        id: UUID = UUID(),
        name: String = "默认 Workflow",
        icon: String = "arrow.triangle.branch",
        isOpen: Bool = true,
        nodes: [WorkflowNode] = WorkflowNode.defaultNodes()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isOpen = isOpen
        self.nodes = nodes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "arrow.triangle.branch"
        isOpen = try container.decodeIfPresent(Bool.self, forKey: .isOpen) ?? false
        nodes = try container.decode([WorkflowNode].self, forKey: .nodes)
    }
}


struct WorkflowExecutionResult: Identifiable {
    let id = UUID()
    let finalText: String
    let originalText: String
    let tags: [String]
    let shouldSave: Bool
    let didCopyToClipboard: Bool
}


@MainActor
@Observable
class WorkflowManager {
    static let shared = WorkflowManager()
    
    var workflows: [Workflow] = []
    var selectedWorkflowId: UUID?
    var isExecuting: Bool = false
    var currentNodeIndex: Int = 0
    var executionError: Error?
    
    private let workflowsStorageKey = "workflows_v2"
    private let selectedWorkflowIdKey = "selectedWorkflowId"
    private let legacyActiveWorkflowIdKey = "activeWorkflowId"
    private init() {
        loadWorkflows()
    }
    
    var selectedWorkflow: Workflow {
        if let id = selectedWorkflowId,
           let wf = workflows.first(where: { $0.id == id }) {
            return wf
        }
        return workflows.first ?? Workflow()
    }
    
    var openWorkflows: [Workflow] {
        workflows.filter(\.isOpen)
    }
    
    var nodes: [WorkflowNode] {
        get { selectedWorkflow.nodes }
        set {
            guard let idx = workflows.firstIndex(where: { $0.id == selectedWorkflow.id }) else { return }
            workflows[idx].nodes = newValue
            saveWorkflows()
        }
    }
    
    func areTerminalNodesAllDisabled(for workflow: Workflow) -> Bool {
        let saveEnabled = workflow.nodes.first(where: { $0.type == .save })?.isEnabled ?? false
        return !saveEnabled
    }
    
    func selectWorkflow(_ id: UUID) {
        selectedWorkflowId = id
        UserDefaults.standard.set(id.uuidString, forKey: selectedWorkflowIdKey)
    }
    
    func canCloseWorkflow(_ id: UUID) -> Bool {
        guard let workflow = workflows.first(where: { $0.id == id }), workflow.isOpen else {
            return true
        }
        return openWorkflows.count > 1
    }
    
    func toggleWorkflowOpen(_ id: UUID) {
        guard let idx = workflows.firstIndex(where: { $0.id == id }) else { return }
        let shouldOpen = !workflows[idx].isOpen
        if !shouldOpen && !canCloseWorkflow(id) {
            return
        }
        workflows[idx].isOpen = shouldOpen
        saveWorkflows()
    }
    
    func addWorkflow(_ workflow: Workflow) {
        var wf = workflow
        normalizeNodes(&wf.nodes)
        workflows.append(wf)
        if selectedWorkflowId == nil {
            selectWorkflow(wf.id)
        }
        saveWorkflows()
    }
    
    func deleteWorkflow(_ id: UUID) {
        guard workflows.count > 1 else { return }
        workflows.removeAll { $0.id == id }
        if selectedWorkflowId == id, let firstWorkflowId = workflows.first?.id {
            selectWorkflow(firstWorkflowId)
        }
        ensureOpenWorkflowExists()
        saveWorkflows()
    }
    
    func updateWorkflow(_ workflow: Workflow) {
        if let idx = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[idx] = workflow
            ensureOpenWorkflowExists()
            saveWorkflows()
        }
    }
    
    func duplicateWorkflow(_ id: UUID) {
        guard let source = workflows.first(where: { $0.id == id }) else { return }
        let copy = Workflow(name: source.name + " 副本", icon: source.icon, isOpen: source.isOpen, nodes: source.nodes)
        workflows.append(copy)
        saveWorkflows()
    }
    
    func addNode(_ node: WorkflowNode) {
        guard let idx = workflows.firstIndex(where: { $0.id == selectedWorkflow.id }) else { return }
        workflows[idx].nodes.append(node)
        saveWorkflows()
    }
    
    func updateNode(_ node: WorkflowNode) {
        guard let wIdx = workflows.firstIndex(where: { $0.id == selectedWorkflow.id }),
              let nIdx = workflows[wIdx].nodes.firstIndex(where: { $0.id == node.id }) else { return }
        workflows[wIdx].nodes[nIdx] = node
        saveWorkflows()
    }
    
    func moveNode(from source: IndexSet, to destination: Int) {
        guard let idx = workflows.firstIndex(where: { $0.id == selectedWorkflow.id }) else { return }
        workflows[idx].nodes.move(fromOffsets: source, toOffset: destination)
        saveWorkflows()
    }
    
    func deleteNodes(at offsets: IndexSet) {
        guard let idx = workflows.firstIndex(where: { $0.id == selectedWorkflow.id }) else { return }
        workflows[idx].nodes.remove(atOffsets: offsets)
        saveWorkflows()
    }
    
    func saveNodes() { saveWorkflows() }
    
    private func loadWorkflows() {
        if let data = UserDefaults.standard.data(forKey: workflowsStorageKey),
           let saved = try? JSONDecoder().decode([Workflow].self, from: data),
           !saved.isEmpty {
            workflows = saved
        } else {
            workflows = [Workflow()]
        }
        
        let persistedSelection = UserDefaults.standard.string(forKey: selectedWorkflowIdKey)
            ?? UserDefaults.standard.string(forKey: legacyActiveWorkflowIdKey)
        
        if let idStr = persistedSelection,
           let id = UUID(uuidString: idStr),
           workflows.contains(where: { $0.id == id }) {
            selectedWorkflowId = id
        } else {
            selectedWorkflowId = workflows.first?.id
        }
        
        for i in workflows.indices {
            normalizeNodes(&workflows[i].nodes)
        }
        ensureOpenWorkflowExists()
        saveWorkflows()
    }
    
    func saveWorkflows() {
        for i in workflows.indices {
            normalizeNodes(&workflows[i].nodes)
        }
        if let data = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(data, forKey: workflowsStorageKey)
        }
    }
    
    private func normalizeNodes(_ nodes: inout [WorkflowNode]) {
    }
    
    func execute(workflowID: UUID, input: String, tags: [String]) async throws -> WorkflowExecutionResult {
        guard let workflow = workflows.first(where: { $0.id == workflowID }) else {
            throw NSError(
                domain: "WorkflowManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "未找到对应的 Workflow"]
            )
        }
        
        isExecuting = true
        currentNodeIndex = 0
        executionError = nil
        
        defer {
            isExecuting = false
        }
        
        var currentText = input
        let enabledNodes = workflow.nodes.filter { $0.isEnabled }
        var didCopy = false
        var shouldSave = false
        
        for (index, node) in enabledNodes.enumerated() {
            currentNodeIndex = index
            
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
            }
        }
        
        return WorkflowExecutionResult(
            finalText: currentText,
            originalText: input,
            tags: tags,
            shouldSave: shouldSave,
            didCopyToClipboard: didCopy
        )
    }
    
    private func ensureOpenWorkflowExists() {
        guard !workflows.isEmpty else { return }
        guard !workflows.contains(where: \.isOpen) else { return }
        
        if let selectedWorkflowId,
           let idx = workflows.firstIndex(where: { $0.id == selectedWorkflowId }) {
            workflows[idx].isOpen = true
        } else {
            workflows[0].isOpen = true
        }
    }
}
