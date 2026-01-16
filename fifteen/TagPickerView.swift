//
//  TagPickerView.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import SwiftUI
import UIKit

struct TagPickerView: View {
    let itemId: UUID
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateTag = false
    @State private var editingTagName: String? = nil
    @State private var isReordering = false
    
    private var currentItem: HistoryItem? {
        historyManager.items.first { $0.id == itemId }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if tagManager.tags.isEmpty {
                    emptyTagsView
                    Spacer()
                } else {
                    if isReordering {
                        // 排序模式：使用 List 支持拖拽
                        List {
                            ForEach(tagManager.tags, id: \.self) { tagName in
                                HStack(spacing: 12) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(.secondaryLabel))
                                    
                                    Text(tagName)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color(.label))
                                    
                                    Spacer()
                                }
                                .listRowBackground(Color(hex: 0xF2F2F6))
                            }
                            .onMove { source, destination in
                                tagManager.moveTag(from: source, to: destination)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .environment(\.editMode, .constant(.active))
                    } else {
                        // 普通模式：选择标签
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(tagManager.tags, id: \.self) { tagName in
                                    TagRowView(
                                        tagName: tagName,
                                        isSelected: currentItem?.tags.contains(tagName) ?? false,
                                        onToggle: { toggleTag(tagName) },
                                        onEdit: { editingTagName = tagName }
                                    )
                                    
                                    if tagName != tagManager.tags.last {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .padding(.top, 16)
                        }
                        Spacer()
                    }
                }
            }
            .background(
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
            )
            .navigationTitle(isReordering ? "调整顺序" : "标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isReordering {
                        Button("完成") {
                            isReordering = false
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .tint(Color(hex: 0x6366F1))
                    } else {
                        HStack(spacing: 16) {
                            Button(action: { showCreateTag = true }) {
                                Image(systemName: "plus")
                            }
                            .tint(Color(hex: 0x6366F1))
                            
                            if !tagManager.tags.isEmpty {
                                Button(action: { isReordering = true }) {
                                    Image(systemName: "arrow.up.arrow.down")
                                }
                                .tint(Color(hex: 0x6366F1))
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !isReordering {
                        Button("完成") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .tint(Color(hex: 0x6366F1))
                    }
                }
            }
            .sheet(isPresented: $showCreateTag) {
                TagCreateSheet(itemId: itemId)
            }
            .sheet(item: $editingTagName) { tagName in
                TagEditSheet(tagName: tagName)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private var emptyTagsView: some View {
        VStack(spacing: 8) {
            Text("暂无标签")
                .font(.system(size: 15))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func toggleTag(_ tagName: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            historyManager.toggleTag(for: itemId, tagName: tagName)
        }
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    let tagName: String
    let isSelected: Bool
    let onToggle: () -> Void
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // 选中状态
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(hex: 0x6366F1) : Color(.secondaryLabel), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if isSelected {
                            Circle()
                                .fill(Color(hex: 0x6366F1))
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Text(tagName)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.label))
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Tag Edit Sheet

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct TagEditSheet: View {
    let tagName: String
    @State private var historyManager = HistoryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newTagName: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("标签名称", text: $newTagName)
                    .font(.system(size: 17))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 16)
                    .focused($isInputFocused)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
            )
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveTag()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tint(Color(hex: 0x6366F1))
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                newTagName = tagName
                isInputFocused = true
            }
        }
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
    }
    
    private func saveTag() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        historyManager.renameTag(from: tagName, to: newTagName)
        dismiss()
    }
}

// MARK: - Tag Create Sheet

struct TagCreateSheet: View {
    let itemId: UUID
    @State private var historyManager = HistoryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var tagName: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("标签名称", text: $tagName)
                    .font(.system(size: 17))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 16)
                    .focused($isInputFocused)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
            )
            .navigationTitle("新建标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加") {
                        addTag()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tint(Color(hex: 0x6366F1))
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
    }
    
    private func addTag() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        historyManager.addTag(to: itemId, tagName: tagName)
        dismiss()
    }
}

// MARK: - Tag Badge View (用于在历史记录行中显示)

struct TagBadgeView: View {
    let tagName: String
    
    var body: some View {
        Text(tagName)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            )
            .foregroundStyle(Color(.secondaryLabel))
    }
}

// MARK: - Tag Filter Bar (用于筛选)

struct TagFilterBar: View {
    @Binding var selectedTagName: String?
    @State private var tagManager = TagManager.shared
    
    var body: some View {
        if tagManager.tags.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "全部" 按钮
                    FilterChip(
                        title: "全部",
                        isSelected: selectedTagName == nil
                    ) {
                        selectedTagName = nil
                    }
                    
                    // 各个标签筛选
                    ForEach(tagManager.tags, id: \.self) { tagName in
                        FilterChip(
                            title: tagName,
                            isSelected: selectedTagName == tagName
                        ) {
                            selectedTagName = selectedTagName == tagName ? nil : tagName
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: 0x6366F1).opacity(0.15) : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? Color(hex: 0x6366F1) : Color(.secondaryLabel))
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color(hex: 0x6366F1).opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TagPickerView(itemId: UUID())
}
