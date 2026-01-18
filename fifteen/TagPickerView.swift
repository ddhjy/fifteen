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
    
    /// 冻结的排序标签列表，只在视图首次出现时计算，避免编辑过程中顺序变化
    @State private var frozenSortedTags: [String] = []
    
    /// 待执行的标签重命名操作（编辑框关闭后执行）
    @State private var pendingRenameOperation: (from: String, to: String)? = nil
    
    /// 本地选中的标签（页面关闭时才同步到 historyManager）
    @State private var localSelectedTags: Set<String> = []
    
    /// 初始选中的标签（用于对比变化）
    @State private var initialSelectedTags: Set<String> = []
    
    private var currentItem: HistoryItem? {
        historyManager.items.first { $0.id == itemId }
    }
    
    /// 当前选中的标签数量（使用本地状态）
    private var selectedTagCount: Int {
        localSelectedTags.count
    }
    
    /// 使用冻结的排序列表，如果还没计算则返回空数组
    private var sortedTags: [String] {
        return frozenSortedTags
    }
    
    /// 计算初始排序：选中的标签优先，然后按出现次数排序
    private func computeInitialSortedTags() -> [String] {
        let selectedTagsSet = Set(currentItem?.tags ?? [String]())
        return tagManager.tags.sorted { tag1, tag2 in
            let tag1Selected = selectedTagsSet.contains(tag1)
            let tag2Selected = selectedTagsSet.contains(tag2)
            // 选中的标签优先
            if tag1Selected != tag2Selected {
                return tag1Selected
            }
            // 其次按出现次数排序
            return tagManager.count(for: tag1) > tagManager.count(for: tag2)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if tagManager.tags.isEmpty {
                    emptyTagsView
                    Spacer()
                } else {
                    // 普通模式：选择标签
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(sortedTags, id: \.self) { tagName in
                                TagRowView(
                                    tagName: tagName,
                                    isSelected: localSelectedTags.contains(tagName),
                                    onToggle: { toggleTag(tagName) },
                                    onEdit: { editingTagName = tagName }
                                )
                                
                                if tagName != sortedTags.last {
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
            .background(
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
            )
            .navigationTitle(selectedTagCount > 0 ? "标签 (\(selectedTagCount))" : "标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showCreateTag = true }) {
                        Image(systemName: "plus")
                    }
                    .tint(Color(hex: 0x6366F1))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tint(Color(hex: 0x6366F1))
                }
            }
            .sheet(isPresented: $showCreateTag, onDismiss: {
                // 新增标签后，将新标签添加到列表顶部
                for tag in tagManager.tags {
                    if !frozenSortedTags.contains(tag) {
                        frozenSortedTags.insert(tag, at: 0)
                    }
                }
            }) {
                TagCreateSheet(itemId: itemId)
            }
            .sheet(item: $editingTagName, onDismiss: {
                // 编辑框消失后再执行重命名操作，避免编辑过程中列表实时刷新
                if let operation = pendingRenameOperation {
                    historyManager.renameTag(from: operation.from, to: operation.to)
                    // 更新冻结的标签列表
                    if let index = frozenSortedTags.firstIndex(of: operation.from) {
                        frozenSortedTags[index] = operation.to
                    }
                    pendingRenameOperation = nil
                }
            }) { tagName in
                TagEditSheet(tagName: tagName) { newName in
                    // 保存重命名操作，延迟到 sheet 关闭后执行
                    pendingRenameOperation = (from: tagName, to: newName)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            // 只在首次出现时初始化
            if frozenSortedTags.isEmpty {
                // 初始化本地选中状态
                let currentTags = Set(currentItem?.tags ?? [])
                localSelectedTags = currentTags
                initialSelectedTags = currentTags
                // 计算排序
                frozenSortedTags = computeInitialSortedTags()
            }
        }
        .onDisappear {
            // 页面关闭时，同步标签变更到 historyManager
            let addedTags = localSelectedTags.subtracting(initialSelectedTags)
            let removedTags = initialSelectedTags.subtracting(localSelectedTags)
            
            for tag in addedTags {
                historyManager.addTag(to: itemId, tagName: tag)
            }
            for tag in removedTags {
                historyManager.removeTag(from: itemId, tagName: tag)
            }
        }
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
        
        // 只更新本地状态，不立即同步到 historyManager
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if localSelectedTags.contains(tagName) {
                localSelectedTags.remove(tagName)
            } else {
                localSelectedTags.insert(tagName)
            }
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
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Tag Edit Sheet

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct TagEditSheet: View {
    let tagName: String
    var onSave: ((String) -> Void)? = nil
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
        
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let onSave = onSave {
            // 使用回调延迟执行
            onSave(trimmedName)
        } else {
            // 兼容直接调用的情况
            HistoryManager.shared.renameTag(from: tagName, to: trimmedName)
        }
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
    @Binding var selectedTags: [String]
    @State private var tagManager = TagManager.shared
    let historyManager = HistoryManager.shared
    
    var body: some View {
        if tagManager.tags.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                // 渲染每一级筛选条
                ForEach(0...selectedTags.count, id: \.self) { level in
                    let availableTags = getAvailableTags(at: level)
                    
                    // 只有当有可选标签时才显示该级
                    if !availableTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // "全部" 按钮
                                FilterChip(
                                    title: "全部",
                                    isSelected: level >= selectedTags.count
                                ) {
                                    selectAll(at: level)
                                }
                                
                                // 各个标签筛选
                                ForEach(availableTags, id: \.self) { tagName in
                                    FilterChip(
                                        title: tagName,
                                        isSelected: level < selectedTags.count && selectedTags[level] == tagName
                                    ) {
                                        selectTag(tagName, at: level)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
    
    /// 获取某一级可用的标签
    private func getAvailableTags(at level: Int) -> [String] {
        // 获取当前已选标签筛选后的结果
        let currentSelectedTags = Array(selectedTags.prefix(level))
        let filteredItems = historyManager.getSavedItems(filteredBy: currentSelectedTags)
        
        // 如果没有筛选结果，返回空
        guard !filteredItems.isEmpty else { return [] }
        
        // 收集筛选结果中所有标签，同时计算每个标签的出现次数
        var tagCounts: [String: Int] = [:]
        for item in filteredItems {
            for tag in item.tags {
                // 排除已选标签
                if !currentSelectedTags.contains(tag) {
                    tagCounts[tag, default: 0] += 1
                }
            }
        }
        
        // 如果没有可选标签，返回空
        guard !tagCounts.isEmpty else { return [] }
        
        // 按计数降序排序，计数相同时按标签名排序以保证稳定性
        return tagCounts.keys.sorted { 
            let count0 = tagCounts[$0, default: 0]
            let count1 = tagCounts[$1, default: 0]
            if count0 != count1 {
                return count0 > count1
            }
            return $0 < $1
        }
    }
    
    /// 选择某一级的 "全部"
    private func selectAll(at level: Int) {
        // 清除该级及之后的所有选择
        if level < selectedTags.count {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTags = Array(selectedTags.prefix(level))
            }
        }
    }
    
    /// 选择某一级的标签
    private func selectTag(_ tagName: String, at level: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if level < selectedTags.count {
                // 替换该级选择并清除后续选择
                var newTags = Array(selectedTags.prefix(level))
                newTags.append(tagName)
                selectedTags = newTags
            } else {
                // 添加新的选择
                selectedTags.append(tagName)
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
        }
        .buttonStyle(.plain)
        .animation(.none, value: isSelected)
    }
}

#Preview {
    TagPickerView(itemId: UUID())
}
