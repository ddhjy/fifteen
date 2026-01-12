//
//  TagPickerView.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import SwiftUI
import UIKit

struct TagPickerView: View {
    let item: HistoryItem
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateTag = false
    @State private var editingTag: Tag? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 预览区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容预览")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                    
                    Text(item.preview)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.label))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // 标签列表
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("选择标签")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                        
                        Spacer()
                        
                        Button(action: { showCreateTag = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("新建")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color(hex: 0x6366F1))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    if tagManager.tags.isEmpty {
                        emptyTagsView
                    } else {
                        VStack(spacing: 0) {
                            ForEach(tagManager.tags) { tag in
                                TagRowView(
                                    tag: tag,
                                    isSelected: item.tagIds.contains(tag.id),
                                    onToggle: { toggleTag(tag) },
                                    onEdit: { editingTag = tag }
                                )
                                
                                if tag.id != tagManager.tags.last?.id {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.regularMaterial)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 24)
                
                Spacer()
            }
            .background(
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
            )
            .navigationTitle("标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tint(Color(hex: 0x6366F1))
                }
            }
            .sheet(isPresented: $showCreateTag) {
                TagEditSheet(mode: .create)
            }
            .sheet(item: $editingTag) { tag in
                TagEditSheet(mode: .edit(tag))
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private var emptyTagsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color(.tertiaryLabel))
            
            Text("还没有标签")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
            
            Text("点击上方「新建」创建您的第一个标签")
                .font(.system(size: 13))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .padding(.horizontal, 16)
    }
    
    private func toggleTag(_ tag: Tag) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            historyManager.toggleTag(for: item.id, tagId: tag.id)
        }
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // 选中状态
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(hex: 0x6366F1) : Color(.tertiaryLabel), lineWidth: 2)
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
                    
                    Text(tag.name)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.label))
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 编辑按钮
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Tag Edit Sheet

enum TagEditMode: Identifiable {
    case create
    case edit(Tag)
    
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let tag): return tag.id.uuidString
        }
    }
}

struct TagEditSheet: View {
    let mode: TagEditMode
    @State private var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var tagName: String = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isInputFocused: Bool
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var editingTag: Tag? {
        if case .edit(let tag) = mode { return tag }
        return nil
    }
    
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
                
                if isEditing {
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除标签")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: 0xFF3B30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: 0xFF3B30).opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .background(
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
            )
            .navigationTitle(isEditing ? "编辑标签" : "新建标签")
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
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("确定要删除这个标签吗？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let tag = editingTag {
                        tagManager.deleteTag(tag.id)
                    }
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("删除后，已使用该标签的记录将不再显示此标签。")
            }
            .onAppear {
                if let tag = editingTag {
                    tagName = tag.name
                }
                isInputFocused = true
            }
        }
        .presentationDetents([.height(isEditing ? 280 : 200)])
        .presentationDragIndicator(.visible)
    }
    
    private func saveTag() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if let tag = editingTag {
            tagManager.updateTag(tag.id, newName: tagName)
        } else {
            _ = tagManager.createTag(name: tagName)
        }
        dismiss()
    }
}

// MARK: - Tag Badge View (用于在历史记录行中显示)

struct TagBadgeView: View {
    let tag: Tag
    
    var body: some View {
        Text(tag.name)
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
    @Binding var selectedTagId: UUID?
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
                        isSelected: selectedTagId == nil
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTagId = nil
                        }
                    }
                    
                    // 各个标签筛选
                    ForEach(tagManager.tags) { tag in
                        FilterChip(
                            title: tag.name,
                            isSelected: selectedTagId == tag.id
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTagId = selectedTagId == tag.id ? nil : tag.id
                            }
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
    TagPickerView(item: HistoryItem(text: "这是一条测试历史记录内容"))
}
