import SwiftUI

struct WorkflowConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    @State private var showAddNode = false
    @State private var editingNode: WorkflowNode? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var renamingWorkflowId: UUID? = nil
    @State private var iconPickerWorkflowId: UUID? = nil
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(workflowManager.workflows) { workflow in
                        let isActive = workflow.id == workflowManager.activeWorkflowId
                        
                        HStack(spacing: 12) {
                            Image(systemName: workflow.icon)
                                .foregroundStyle(isActive ? primaryColor : Color(.tertiaryLabel))
                                .font(.system(size: 20))
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workflow.name)
                                    .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                                
                                let enabledCount = workflow.nodes.filter { $0.isEnabled }.count
                                let totalCount = workflow.nodes.count
                                Text("\(enabledCount)/\(totalCount) 个节点启用")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(primaryColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            workflowManager.setActiveWorkflow(workflow.id)
                        }
                        .contextMenu {
                            Button {
                                iconPickerWorkflowId = workflow.id
                            } label: {
                                Label("更换图标", systemImage: "square.grid.2x2")
                            }
                            Button {
                                renamingWorkflowId = workflow.id
                                renameText = workflow.name
                                showRenameAlert = true
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button {
                                workflowManager.duplicateWorkflow(workflow.id)
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            if workflowManager.workflows.count > 1 {
                                Divider()
                                Button(role: .destructive) {
                                    withAnimation { workflowManager.deleteWorkflow(workflow.id) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    Button {
                        let count = workflowManager.workflows.count + 1
                        let newWf = Workflow(name: "Workflow \(count)")
                        workflowManager.addWorkflow(newWf)
                        workflowManager.setActiveWorkflow(newWf.id)
                    } label: {
                        Label("新建 Workflow", systemImage: "plus.circle")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Workflow")
                }
                
                Section {
                    ForEach(workflowManager.nodes) { node in
                        NodeRowView(node: node, onEdit: { editingNode = node })
                    }
                    .onMove { workflowManager.moveNode(from: $0, to: $1) }
                    .onDelete { workflowManager.deleteNodes(at: $0) }
                } header: {
                    Text("处理节点")
                } footer: {
                    Text("拖动调整顺序，点击发送时将按顺序执行启用的节点")
                }
                
                Section {
                    Button {
                        showAddNode = true
                    } label: {
                        Label("添加节点", systemImage: "plus.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Workflow 配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddNode) { AddNodeSheet() }
            .sheet(item: $editingNode) { node in EditNodeSheet(node: node) }
            .alert("重命名", isPresented: $showRenameAlert) {
                TextField("名称", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("确定") {
                    guard let id = renamingWorkflowId,
                          var wf = workflowManager.workflows.first(where: { $0.id == id }) else { return }
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    wf.name = trimmed
                    workflowManager.updateWorkflow(wf)
                }
            }
            .sheet(item: $iconPickerWorkflowId) { workflowId in
                IconPickerView(
                    selectedIcon: workflowManager.workflows.first(where: { $0.id == workflowId })?.icon ?? "arrow.triangle.branch"
                ) { newIcon in
                    guard var wf = workflowManager.workflows.first(where: { $0.id == workflowId }) else { return }
                    wf.icon = newIcon
                    workflowManager.updateWorkflow(wf)
                }
            }
        }
    }
}


struct WorkflowListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var renamingWorkflowId: UUID? = nil
    @State private var iconPickerWorkflowId: UUID? = nil
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workflowManager.workflows) { workflow in
                    let isActive = workflow.id == workflowManager.activeWorkflowId
                    
                    HStack(spacing: 12) {
                        Image(systemName: workflow.icon)
                            .foregroundStyle(isActive ? primaryColor : Color(.tertiaryLabel))
                            .font(.system(size: 20))
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workflow.name)
                                .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                            
                            let enabledCount = workflow.nodes.filter { $0.isEnabled }.count
                            let totalCount = workflow.nodes.count
                            Text("\(enabledCount)/\(totalCount) 个节点启用")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workflowManager.setActiveWorkflow(workflow.id)
                        dismiss()
                    }
                    .contextMenu {
                        Button {
                            iconPickerWorkflowId = workflow.id
                        } label: {
                            Label("更换图标", systemImage: "square.grid.2x2")
                        }
                        
                        Button {
                            renamingWorkflowId = workflow.id
                            renameText = workflow.name
                            showRenameAlert = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        
                        Button {
                            workflowManager.duplicateWorkflow(workflow.id)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        
                        if workflowManager.workflows.count > 1 {
                            Divider()
                            Button(role: .destructive) {
                                withAnimation { workflowManager.deleteWorkflow(workflow.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                
                Button {
                    let count = workflowManager.workflows.count + 1
                    let newWf = Workflow(name: "Workflow \(count)")
                    workflowManager.addWorkflow(newWf)
                    workflowManager.setActiveWorkflow(newWf.id)
                    dismiss()
                } label: {
                    Label("新建 Workflow", systemImage: "plus.circle")
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("所有 Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("重命名", isPresented: $showRenameAlert) {
                TextField("名称", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("确定") {
                    guard let id = renamingWorkflowId,
                          var wf = workflowManager.workflows.first(where: { $0.id == id }) else { return }
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    wf.name = trimmed
                    workflowManager.updateWorkflow(wf)
                }
            }
            .sheet(item: $iconPickerWorkflowId) { workflowId in
                IconPickerView(selectedIcon: currentIcon(for: workflowId)) { newIcon in
                    guard var wf = workflowManager.workflows.first(where: { $0.id == workflowId }) else { return }
                    wf.icon = newIcon
                    workflowManager.updateWorkflow(wf)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func currentIcon(for id: UUID) -> String {
        workflowManager.workflows.first(where: { $0.id == id })?.icon ?? "arrow.triangle.branch"
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}


struct NodeRowView: View {
    let node: WorkflowNode
    let onEdit: () -> Void
    @State private var workflowManager = WorkflowManager.shared
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.type.displayName)
                    .font(.system(size: 16))
                
                if node.type == .aiProcess, let prompt = node.config.aiPrompt {
                    Text(prompt)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if node.type == .httpPost {
                    let host = node.config.httpHost ?? "localhost"
                    let port = node.config.httpPort ?? 9999
                    Text("\(host):\(port)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { node.isEnabled },
                set: { newValue in
                    var updated = node
                    updated.isEnabled = newValue
                    workflowManager.updateNode(updated)
                }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}


struct AddNodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(
                    WorkflowNodeType.allCases.filter { $0 != .copyToClipboard && $0 != .save },
                    id: \.self
                ) { type in
                    Button {
                        let newNode = WorkflowNode(type: type)
                        workflowManager.addNode(newNode)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(.primary)
                                .frame(width: 28)
                            Text(type.displayName)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .tint(primaryColor)
            .navigationTitle("添加节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .tint(primaryColor)
                }
            }
        }
        .presentationDetents([.medium])
    }
}


struct EditNodeSheet: View {
    let node: WorkflowNode
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    @State private var aiPrompt: String = ""
    @State private var skipConfirmation: Bool = false
    @State private var httpHost: String = ""
    @State private var httpPort: String = ""
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        NavigationStack {
            Form {
                if node.type == .aiProcess {
                    Section("提示词") {
                        TextEditor(text: $aiPrompt)
                            .frame(minHeight: 120)
                    }
                }
                
                if node.type == .httpPost {
                    Section {
                        TextField("主机地址", text: $httpHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                        TextField("端口", text: $httpPort)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("HTTP 配置")
                    } footer: {
                        Text("将输入内容以 POST 请求发送到 http://主机地址:端口")
                    }
                }
                
                if node.type == .save {
                    Section {
                        Toggle("跳过确认直接保存", isOn: $skipConfirmation)
                    } footer: {
                        Text("开启后，处理完成将直接保存，不显示预览弹窗")
                    }
                }
            }
            .navigationTitle("编辑节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveChanges() }
                        .fontWeight(.semibold)
                        .tint(.primary)
                }
            }
            .onAppear {
                aiPrompt = node.config.aiPrompt ?? ""
                skipConfirmation = node.config.skipConfirmation ?? false
                httpHost = node.config.httpHost ?? "localhost"
                httpPort = "\(node.config.httpPort ?? 9999)"
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveChanges() {
        var updated = node
        updated.config.aiPrompt = aiPrompt.isEmpty ? nil : aiPrompt
        updated.config.skipConfirmation = skipConfirmation
        updated.config.httpHost = httpHost.isEmpty ? nil : httpHost
        updated.config.httpPort = Int(httpPort)
        workflowManager.updateNode(updated)
        dismiss()
    }
}


struct IconPickerView: View {
    let selectedIcon: String
    let onSelect: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    private let icons: [(category: String, symbols: [String])] = [
        ("常用", [
            "arrow.triangle.branch", "bolt.fill", "wand.and.stars",
            "sparkles", "gearshape.fill", "terminal.fill",
            "text.bubble.fill", "envelope.fill", "paperplane.fill",
            "doc.text.fill", "folder.fill", "tray.full.fill"
        ]),
        ("工作", [
            "briefcase.fill", "chart.bar.fill", "calendar",
            "clock.fill", "flag.fill", "bookmark.fill",
            "link", "network", "externaldrive.fill",
            "server.rack", "cpu.fill", "memorychip.fill"
        ]),
        ("创意", [
            "paintbrush.fill", "pencil.and.outline", "scissors",
            "wand.and.rays", "camera.fill", "photo.fill",
            "music.note", "film.fill", "theatermasks.fill",
            "lightbulb.fill", "star.fill", "heart.fill"
        ]),
        ("沟通", [
            "bubble.left.fill", "bubble.left.and.bubble.right.fill",
            "phone.fill", "video.fill", "mic.fill",
            "megaphone.fill", "bell.fill", "hand.wave.fill",
            "person.fill", "person.2.fill", "globe",
            "antenna.radiowaves.left.and.right"
        ]),
        ("符号", [
            "checkmark.seal.fill", "xmark.octagon.fill",
            "exclamationmark.triangle.fill", "info.circle.fill",
            "questionmark.circle.fill", "plus.circle.fill",
            "minus.circle.fill", "arrow.clockwise",
            "shuffle", "repeat", "infinity", "number"
        ])
    ]
    
    private var filteredIcons: [(category: String, symbols: [String])] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return icons }
        return icons.compactMap { group in
            let filtered = group.symbols.filter { $0.lowercased().contains(trimmed) }
            return filtered.isEmpty ? nil : (group.category, filtered)
        }
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(filteredIcons, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.category)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(group.symbols, id: \.self) { symbol in
                                    let isSelected = symbol == selectedIcon
                                    Button {
                                        onSelect(symbol)
                                        dismiss()
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.system(size: 22))
                                            .frame(width: 48, height: 48)
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(isSelected ? primaryColor : Color(.tertiarySystemFill))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索图标名称")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
