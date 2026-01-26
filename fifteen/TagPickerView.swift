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
    /// 重选模式：初始选中用灰色显示，点击任意标签时清除旧选择
    var reselectMode: Bool = false
    
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateTag = false
    @State private var editingTagName: String? = nil
    @State private var searchText: String = ""
    
    /// 冻结的排序标签列表，只在视图首次出现时计算，避免编辑过程中顺序变化
    @State private var frozenSortedTags: [String] = []
    
    /// 待执行的标签重命名操作（编辑框关闭后执行）
    @State private var pendingRenameOperation: (from: String, to: String)? = nil
    
    /// 本地选中的标签（页面关闭时才同步到 historyManager）
    @State private var localSelectedTags: Set<String> = []
    
    /// 初始选中的标签（用于对比变化）
    @State private var initialSelectedTags: Set<String> = []
    
    /// 重选模式下，用于显示灰色"之前选中"状态的标签
    @State private var previousSelectedTags: Set<String> = []
    
    /// 重选模式下，用户是否已开始新的选择（一旦开始，灰色状态清除）
    @State private var hasStartedReselection: Bool = false
    
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

    private var displayedTags: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return sortedTags
        }
        return sortedTags.filter { $0.localizedCaseInsensitiveContains(trimmed) }
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
                            if displayedTags.isEmpty {
                                VStack(spacing: 8) {
                                    Text("无匹配标签")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                ForEach(displayedTags.indices, id: \.self) { index in
                                    let tagName = displayedTags[index]
                                    let isCurrentlySelected = localSelectedTags.contains(tagName)
                                    let isPreviouslySelected = reselectMode && !hasStartedReselection && previousSelectedTags.contains(tagName)
                                    TagRowView(
                                        tagName: tagName,
                                        isSelected: isCurrentlySelected,
                                        isPreviousSelected: isPreviouslySelected,
                                        onToggle: { toggleTag(tagName) },
                                        onEdit: { editingTagName = tagName }
                                    )
                                    
                                    if index != displayedTags.count - 1 {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标签")
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // 只在首次出现时初始化
            if frozenSortedTags.isEmpty {
                // 初始化本地选中状态
                let currentTags = Set(currentItem?.tags ?? [])
                initialSelectedTags = currentTags
                
                if reselectMode {
                    // 重选模式：初始不选中任何标签，但记录之前的选择用于灰色显示
                    localSelectedTags = []
                    previousSelectedTags = currentTags
                    hasStartedReselection = false
                } else {
                    // 普通模式：保持原有选中
                    localSelectedTags = currentTags
                }
                
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
            if reselectMode && !hasStartedReselection {
                // 重选模式首次点击：清除灰色状态，选中新标签
                hasStartedReselection = true
                previousSelectedTags = []
                localSelectedTags = [tagName]
            } else if localSelectedTags.contains(tagName) {
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
    /// 重选模式下的"之前选中"状态（用灰色显示）
    var isPreviousSelected: Bool = false
    let onToggle: () -> Void
    var onEdit: (() -> Void)? = nil
    
    /// 圆圈的颜色
    private var circleColor: Color {
        if isSelected {
            return Color(hex: 0x6366F1)
        } else if isPreviousSelected {
            return Color(.systemGray3)
        } else {
            return Color(.secondaryLabel)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 选中状态
            ZStack {
                Circle()
                    .stroke(circleColor, lineWidth: 2)
                    .frame(width: 22, height: 22)
                
                if isSelected || isPreviousSelected {
                    Circle()
                        .fill(circleColor)
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
    @Binding var isRandomMode: Bool
    var availableItems: [HistoryItem]
    var isSearching: Bool = false
    var onRandomize: () -> Void
    
    @State private var tagManager = TagManager.shared
    let historyManager = HistoryManager.shared
    
    /// 从搜索结果中提取可用标签
    private func computeAvailableTagsFromItems() -> Set<String> {
        var tags = Set<String>()
        for item in availableItems {
            for tag in item.tags {
                tags.insert(tag)
            }
        }
        return tags
    }
    
    var body: some View {
        let availableTagsFromItems = computeAvailableTagsFromItems()
        
        if availableTagsFromItems.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                ForEach(0...selectedTags.count, id: \.self) { level in
                    let filteredItemCount = getFilteredItemCount(at: level)
                    let availableTagsWithCounts = getAvailableTagsWithCounts(at: level, availableTagsFromItems: availableTagsFromItems)
                    
                    if !availableTagsWithCounts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(
                                    title: "全部",
                                    isSelected: level >= selectedTags.count && !(level == 0 && isRandomMode),
                                    count: isSearching ? filteredItemCount : nil
                                ) {
                                    selectAll(at: level)
                                }

                                if level == 0 {
                                    FilterIconChip(
                                        systemImage: "shuffle",
                                        accessibilityLabel: "随机",
                                        isSelected: isRandomMode,
                                        usesDiceHaptics: true
                                    ) {
                                        selectRandom()
                                    }
                                }
                                
                                ForEach(availableTagsWithCounts, id: \.tag) { item in
                                    FilterChip(
                                        title: item.tag,
                                        isSelected: level < selectedTags.count && selectedTags[level] == item.tag,
                                        count: isSearching ? item.count : nil
                                    ) {
                                        selectTag(item.tag, at: level)
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
    
    private func getFilteredItemCount(at level: Int) -> Int {
        let currentSelectedTags = Array(selectedTags.prefix(level))
        if currentSelectedTags.isEmpty {
            return availableItems.count
        }
        return availableItems.reduce(into: 0) { count, item in
            if currentSelectedTags.allSatisfy({ item.tags.contains($0) }) {
                count += 1
            }
        }
    }
    
    private func getAvailableTagsWithCounts(at level: Int, availableTagsFromItems: Set<String>) -> [(tag: String, count: Int)] {
        let currentSelectedTags = Array(selectedTags.prefix(level))
        
        var filteredItems = availableItems
        if !currentSelectedTags.isEmpty {
            filteredItems = filteredItems.filter { item in
                currentSelectedTags.allSatisfy { item.tags.contains($0) }
            }
        }
        
        guard !filteredItems.isEmpty else { return [] }
        
        var tagCounts: [String: Int] = [:]
        for item in filteredItems {
            for tag in item.tags {
                if !currentSelectedTags.contains(tag) && availableTagsFromItems.contains(tag) {
                    tagCounts[tag, default: 0] += 1
                }
            }
        }
        
        guard !tagCounts.isEmpty else { return [] }
        
        return tagCounts.map { (tag: $0.key, count: $0.value) }.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.tag < $1.tag
        }
    }
    
    /// 选择某一级的 "全部"
    private func selectAll(at level: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            // 清除该级及之后的所有选择
            if level < selectedTags.count {
                selectedTags = Array(selectedTags.prefix(level))
            }
            isRandomMode = false
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
            isRandomMode = false
        }
    }

    /// 选择随机标签
    private func selectRandom() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if !selectedTags.isEmpty {
                selectedTags = []
            }
            isRandomMode = true
        }
        onRandomize()
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isSelected ? Color(hex: 0x6366F1).opacity(0.7) : Color(.tertiaryLabel))
                }
            }
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

struct FilterIconChip: View {
    let systemImage: String
    let accessibilityLabel: String
    let isSelected: Bool
    var usesDiceHaptics: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if usesDiceHaptics {
                playDiceHaptics()
            } else {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(height: 16)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: 0x6366F1).opacity(0.15) : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? Color(hex: 0x6366F1) : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .animation(.none, value: isSelected)
    }
    
    private func playDiceHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        
        let pattern: [(delay: Double, intensity: CGFloat)] = [
            (0.00, 0.90),
            (0.06, 0.55),
            (0.12, 0.75),
            (0.18, 0.50),
            (0.24, 0.70),
            (0.30, 0.45)
        ]
        
        for step in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                generator.impactOccurred(intensity: step.intensity)
            }
        }
    }
}

#Preview {
    TagPickerView(itemId: UUID())
}
