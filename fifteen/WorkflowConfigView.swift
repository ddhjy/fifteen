//
//  WorkflowConfigView.swift
//  fifteen
//

import SwiftUI

struct WorkflowConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    @State private var showAddNode = false
    @State private var editingNode: WorkflowNode? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(workflowManager.nodes) { node in
                        NodeRowView(node: node, onEdit: { editingNode = node })
                    }
                    .onMove { workflowManager.moveNode(from: $0, to: $1) }
                    .onDelete { workflowManager.nodes.remove(atOffsets: $0); workflowManager.saveNodes() }
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
            .sheet(isPresented: $showAddNode) {
                AddNodeSheet()
            }
            .sheet(item: $editingNode) { node in
                EditNodeSheet(node: node)
            }
        }
    }
}

// MARK: - Node Row

struct NodeRowView: View {
    let node: WorkflowNode
    let onEdit: () -> Void
    @State private var workflowManager = WorkflowManager.shared
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(node.isEnabled ? primaryColor : .secondary)
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

// MARK: - Add Node Sheet

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
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            }
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

// MARK: - Edit Node Sheet

struct EditNodeSheet: View {
    let node: WorkflowNode
    @Environment(\.dismiss) private var dismiss
    @State private var workflowManager = WorkflowManager.shared
    @State private var aiPrompt: String = ""
    @State private var skipConfirmation: Bool = false
    
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
                        .tint(primaryColor)
                }
            }
            .onAppear {
                aiPrompt = node.config.aiPrompt ?? ""
                skipConfirmation = node.config.skipConfirmation ?? false
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveChanges() {
        var updated = node
        updated.config.aiPrompt = aiPrompt.isEmpty ? nil : aiPrompt
        updated.config.skipConfirmation = skipConfirmation
        workflowManager.updateNode(updated)
        dismiss()
    }
}
