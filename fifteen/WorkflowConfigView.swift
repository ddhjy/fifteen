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
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(workflowManager.openWorkflows) { workflow in
                        workflowRow(for: workflow)
                    }
                    .onMove { workflowManager.moveWorkflows(inOpenState: true, from: $0, to: $1) }
                } header: {
                    Text("显示中")
                } footer: {
                    Text("这些 Workflow 显示在主页工具栏，可拖动排序")
                }
                
                if !workflowManager.closedWorkflows.isEmpty {
                    Section {
                        ForEach(workflowManager.closedWorkflows) { workflow in
                            workflowRow(for: workflow)
                        }
                        .onMove { workflowManager.moveWorkflows(inOpenState: false, from: $0, to: $1) }
                    } header: {
                        Text("已隐藏")
                    } footer: {
                        Text("未显示在主页，仅在此处管理")
                    }
                }
                
                Section {
                    
                    Button {
                        let count = workflowManager.workflows.count + 1
                        let newWf = Workflow(name: "Workflow \(count)", kind: .manual)
                        workflowManager.addWorkflow(newWf)
                        workflowManager.selectWorkflow(newWf.id)
                    } label: {
                        Label("新建 Workflow", systemImage: "plus.circle")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("管理")
                } footer: {
                    Text("点选 Workflow 可编辑配置，特殊 Workflow 会显示专属设置")
                }

                if workflowManager.selectedWorkflow.kind == .autoPasteSync {
                    autoPasteSyncSection(for: workflowManager.selectedWorkflow)
                } else {
                    Section {
                        ForEach(workflowManager.nodes) { node in
                            NodeRowView(node: node, onEdit: { editingNode = node })
                        }
                        .onMove { workflowManager.moveNode(from: $0, to: $1) }
                        .onDelete { workflowManager.deleteNodes(at: $0) }
                    } header: {
                        Text("处理节点")
                    } footer: {
                        Text("拖动排序，执行时按从上到下顺序运行")
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
            }
            .navigationTitle("Workflow 配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
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
    
    @ViewBuilder
    private func workflowRow(for workflow: Workflow) -> some View {
        let isSelected = workflow.id == workflowManager.selectedWorkflowId
        
        HStack(spacing: 12) {
            Image(systemName: workflow.icon)
                .foregroundStyle(workflowRowIconColor(for: workflow, isSelected: isSelected))
                .font(.system(size: 20))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.name)
                    .font(isSelected ? .callout.bold() : .callout)
                
                Text(workflowSummary(for: workflow))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Design.primaryColor)
            }
            
            Button {
                workflowManager.toggleWorkflowOpen(workflow.id)
            } label: {
                Image(systemName: workflow.isOpen ? "eye" : "eye.slash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(workflow.isOpen ? Design.primaryColor : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!workflowManager.canCloseWorkflow(workflow.id))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            workflowManager.selectWorkflow(workflow.id)
        }
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button {
                workflowManager.toggleWorkflowOpen(workflow.id)
            } label: {
                Label(workflow.isOpen ? "从主页隐藏" : "显示到主页", systemImage: workflow.isOpen ? "eye.slash" : "eye")
            }
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
            if workflowManager.canDuplicateWorkflow(workflow.id) {
                Button {
                    workflowManager.duplicateWorkflow(workflow.id)
                } label: {
                    Label("创建副本", systemImage: "doc.on.doc")
                }
            }
            if workflowManager.canDeleteWorkflow(workflow.id) {
                Divider()
                Button(role: .destructive) {
                    withAnimation { workflowManager.deleteWorkflow(workflow.id) }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func autoPasteSyncSection(for workflow: Workflow) -> some View {
        Section {
            Toggle("主页按钮控制同步状态", isOn: Binding(
                get: { workflowManager.workflows.first(where: { $0.id == workflow.id })?.isActive ?? false },
                set: { _ in
                    workflowManager.toggleWorkflowActive(workflow.id)
                }
            ))
            .tint(Design.primaryColor)

            TextField("AutoPaste 主机地址", text: Binding(
                get: { workflowManager.workflows.first(where: { $0.id == workflow.id })?.syncConfig.host ?? "" },
                set: { workflowManager.updateAutoPasteSyncConfig(workflowID: workflow.id, host: $0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            TextField("AutoPaste 端口", value: Binding(
                get: { workflowManager.workflows.first(where: { $0.id == workflow.id })?.syncConfig.port ?? 7788 },
                set: { workflowManager.updateAutoPasteSyncConfig(workflowID: workflow.id, port: $0) }
            ), format: .number)
            .keyboardType(.numberPad)
        } header: {
            Text("同步配置")
        } footer: {
            Text("这是一个开关型 Workflow。主页点亮后会实时同步当前草稿，并接收远端清空指令。可通过创建副本配置多个目标，但同一时间只允许一个开启同步、一个显示在主页。")
        }
    }

    private func workflowSummary(for workflow: Workflow) -> String {
        let visibility = workflow.isOpen ? "主页显示" : "未在主页显示"

        if workflow.kind == .autoPasteSync {
            let state = workflow.isActive ? "同步已开启" : "同步已关闭"
            let host = workflow.syncConfig.host.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = host.isEmpty ? "未配置目标" : "\(host):\(workflow.syncConfig.port)"
            return "\(visibility) · \(state) · \(target)"
        }

        let enabledCount = workflow.nodes.filter { $0.isEnabled }.count
        let totalCount = workflow.nodes.count
        return "\(visibility) · \(enabledCount)/\(totalCount) 节点启用"
    }

    private func workflowRowIconColor(for workflow: Workflow, isSelected: Bool) -> Color {
        if isSelected || (workflow.kind == .autoPasteSync && workflow.isActive) {
            return Design.primaryColor
        }
        return Color(.tertiaryLabel)
    }
}


struct WorkflowListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var renamingWorkflowId: UUID? = nil
    @State private var iconPickerWorkflowId: UUID? = nil
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workflowManager.openWorkflows) { workflow in
                    let isSelected = workflow.id == workflowManager.selectedWorkflowId
                    
                    HStack(spacing: 12) {
                        Image(systemName: workflow.icon)
                            .foregroundStyle(workflowRowIconColor(for: workflow, isSelected: isSelected))
                            .font(.system(size: 20))
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workflow.name)
                                .font(isSelected ? .callout.bold() : .callout)
                            
                            Text(workflowSummary(for: workflow))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workflowManager.selectWorkflow(workflow.id)
                        dismiss()
                    }
                    .accessibilityAddTraits(.isButton)
                    .contextMenu {
                        Button {
                            workflowManager.toggleWorkflowOpen(workflow.id)
                        } label: {
                            Label(workflow.isOpen ? "从主页隐藏" : "显示到主页", systemImage: workflow.isOpen ? "eye.slash" : "eye")
                        }
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
                        
                        if workflowManager.canDuplicateWorkflow(workflow.id) {
                            Button {
                                workflowManager.duplicateWorkflow(workflow.id)
                            } label: {
                                Label("创建副本", systemImage: "doc.on.doc")
                            }
                        }
                        
                        if workflowManager.canDeleteWorkflow(workflow.id) {
                            Divider()
                            Button(role: .destructive) {
                                withAnimation { workflowManager.deleteWorkflow(workflow.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                
                if !workflowManager.closedWorkflows.isEmpty {
                    Section("已隐藏") {
                        ForEach(workflowManager.closedWorkflows) { workflow in
                            let isSelected = workflow.id == workflowManager.selectedWorkflowId
                            
                            HStack(spacing: 12) {
                                Image(systemName: workflow.icon)
                                    .foregroundStyle(workflowRowIconColor(for: workflow, isSelected: isSelected))
                                    .font(.system(size: 20))
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workflow.name)
                                        .font(isSelected ? .callout.bold() : .callout)
                                    
                                    Text(workflowSummary(for: workflow))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                workflowManager.selectWorkflow(workflow.id)
                                dismiss()
                            }
                            .accessibilityAddTraits(.isButton)
                            .contextMenu {
                                Button {
                                    workflowManager.toggleWorkflowOpen(workflow.id)
                                } label: {
                                    Label("显示到主页", systemImage: "eye")
                                }
                            }
                        }
                    }
                }
                
                Button {
                    let count = workflowManager.workflows.count + 1
                    let newWf = Workflow(name: "Workflow \(count)", kind: .manual)
                    workflowManager.addWorkflow(newWf)
                    workflowManager.selectWorkflow(newWf.id)
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
                        .fontWeight(.semibold)
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

    private func workflowSummary(for workflow: Workflow) -> String {
        let visibility = workflow.isOpen ? "主页显示" : "未在主页显示"

        if workflow.kind == .autoPasteSync {
            let state = workflow.isActive ? "同步已开启" : "同步已关闭"
            let host = workflow.syncConfig.host.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = host.isEmpty ? "未配置目标" : "\(host):\(workflow.syncConfig.port)"
            return "\(visibility) · \(state) · \(target)"
        }

        let enabledCount = workflow.nodes.filter { $0.isEnabled }.count
        let totalCount = workflow.nodes.count
        return "\(visibility) · \(enabledCount)/\(totalCount) 节点启用"
    }

    private func workflowRowIconColor(for workflow: Workflow, isSelected: Bool) -> Color {
        if isSelected || (workflow.kind == .autoPasteSync && workflow.isActive) {
            return Design.primaryColor
        }
        return Color(.tertiaryLabel)
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}


struct NodeRowView: View {
    let node: WorkflowNode
    let onEdit: () -> Void
    @State private var workflowManager = WorkflowManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.type.displayName)
                    .font(.callout)
                
                if node.type == .aiProcess, let prompt = node.config.aiPrompt {
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if node.type == .httpPost {
                    let host = node.config.httpHost ?? "localhost"
                    let port = node.config.httpPort ?? 9999
                    Text("\(host):\(port)")
                        .font(.caption)
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
            .tint(Design.primaryColor)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .accessibilityAddTraits(.isButton)
    }
}


struct AddNodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(WorkflowNodeType.allCases, id: \.self) { type in
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
            .tint(Design.primaryColor)
            .navigationTitle("添加节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
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
    @State private var httpHost: String = ""
    @State private var httpPort: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                if node.type == .aiProcess {
                    Section("提示词") {
                        TextField("输入 AI 提示词", text: $aiPrompt, axis: .vertical)
                            .lineLimit(5...)
                    }
                }
                
                if node.type == .httpPost {
                    Section {
                        TextField("主机地址", text: $httpHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                            .keyboardType(.URL)
                        TextField("端口", text: $httpPort)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("HTTP 配置")
                    } footer: {
                        Text("内容将发送到以下地址")
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
                }
            }
            .onAppear {
                aiPrompt = node.config.aiPrompt ?? ""
                httpHost = node.config.httpHost ?? "localhost"
                httpPort = "\(node.config.httpPort ?? 9999)"
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveChanges() {
        var updated = node
        updated.config.aiPrompt = aiPrompt.isEmpty ? nil : aiPrompt
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
    
    private let icons: [(category: String, symbols: [String])] = [
        ("常用", [
            "arrow.triangle.branch", "bolt", "wand.and.stars",
            "sparkles", "gearshape", "terminal",
            "text.bubble", "envelope", "paperplane",
            "doc.text", "folder", "tray.full",
            "square.and.arrow.up", "square.and.arrow.down", "arrow.right.circle",
            "arrow.2.circlepath", "arrow.up.forward.app", "play",
            "stop", "forward", "backward",
            "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath"
        ]),
        ("工作", [
            "briefcase", "chart.bar", "calendar",
            "clock", "flag", "bookmark",
            "link", "network", "externaldrive",
            "server.rack", "cpu", "memorychip",
            "desktopcomputer", "laptopcomputer", "printer",
            "doc.richtext", "doc.append", "list.bullet.clipboard",
            "chart.pie", "chart.line.uptrend.xyaxis", "building.2",
            "banknote", "creditcard", "cart"
        ]),
        ("创意", [
            "paintbrush", "pencil.and.outline", "scissors",
            "wand.and.rays", "camera", "photo",
            "music.note", "film", "theatermasks",
            "lightbulb", "star", "heart",
            "paintpalette", "eyedropper.halffull", "swatchpalette",
            "pianokeys", "guitars", "music.mic",
            "photo.on.rectangle.angled", "camera.aperture", "wand.and.stars.inverse",
            "sparkle", "flame", "leaf"
        ]),
        ("沟通", [
            "bubble.left", "bubble.left.and.bubble.right",
            "phone", "video", "mic",
            "megaphone", "bell", "hand.wave",
            "person", "person.2", "globe",
            "antenna.radiowaves.left.and.right",
            "bubble.middle.bottom", "ellipsis.bubble",
            "phone.arrow.up.right", "envelope.open",
            "person.3", "person.crop.circle",
            "shared.with.you", "hand.thumbsup", "hand.raised",
            "ear", "eye", "mouth"
        ]),
        ("符号", [
            "checkmark.seal", "xmark.octagon",
            "exclamationmark.triangle", "info.circle",
            "questionmark.circle", "plus.circle",
            "minus.circle", "shuffle",
            "repeat", "infinity", "number",
            "equal.circle", "lessthan.circle", "greaterthan.circle",
            "chevron.left.forwardslash.chevron.right", "curlybraces",
            "at", "hashtag", "percent", "textformat"
        ]),
        ("自然与天气", [
            "sun.max", "moon", "cloud",
            "cloud.rain", "cloud.bolt", "snowflake",
            "wind", "tornado", "rainbow",
            "drop", "leaf", "tree",
            "mountain.2", "water.waves", "sun.haze"
        ]),
        ("出行与地图", [
            "car", "bus", "tram",
            "airplane", "ferry", "bicycle",
            "figure.walk", "figure.run", "map",
            "mappin.and.ellipse", "location", "compass.drawing",
            "fuelpump", "ev.charger", "parking"
        ]),
        ("安全与隐私", [
            "lock", "lock.open", "key",
            "shield", "shield.checkered", "lock.shield",
            "faceid", "touchid", "opticid",
            "eye.slash", "hand.raised.slash", "exclamationmark.lock"
        ]),
        ("健康与生活", [
            "heart.text.square", "cross.case", "pills",
            "bed.double", "cup.and.saucer", "fork.knife",
            "house", "sofa", "washer",
            "dumbbell", "sportscourt", "figure.yoga",
            "pawprint", "gift", "party.popper"
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
                                .font(.footnote.bold())
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
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(isSelected ? Design.primaryColor : Color(.tertiarySystemFill))
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
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
