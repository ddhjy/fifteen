import SwiftUI
import UIKit

struct TagPickerView: View {
    let itemId: UUID
    var reselectMode: Bool = false
    
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateTag = false
    @State private var editingTagName: String? = nil
    @State private var searchText: String = ""
    
    @State private var frozenSortedTags: [String] = []
    
    @State private var pendingRenameOperation: (from: String, to: String)? = nil
    
    @State private var localSelectedTags: Set<String> = []
    
    @State private var initialSelectedTags: Set<String> = []
    
    @State private var previousSelectedTags: Set<String> = []
    
    @State private var hasStartedReselection: Bool = false
    
    private var currentItem: HistoryItem? {
        historyManager.items.first { $0.id == itemId }
    }
    
    private var selectedTagCount: Int {
        localSelectedTags.count
    }
    
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
    
    private func computeInitialSortedTags() -> [String] {
        let selectedTagsSet = Set(currentItem?.tags ?? [String]())
        return tagManager.tags.sorted { tag1, tag2 in
            let tag1Selected = selectedTagsSet.contains(tag1)
            let tag2Selected = selectedTagsSet.contains(tag2)
            if tag1Selected != tag2Selected {
                return tag1Selected
            }
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
                    .tint(.primary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tint(.primary)
                }
            }
            .sheet(isPresented: $showCreateTag, onDismiss: {
                for tag in tagManager.tags {
                    if !frozenSortedTags.contains(tag) {
                        frozenSortedTags.insert(tag, at: 0)
                    }
                }
            }) {
                TagCreateSheet(itemId: itemId)
            }
            .sheet(item: $editingTagName, onDismiss: {
                if let operation = pendingRenameOperation {
                    historyManager.renameTag(from: operation.from, to: operation.to)
                    if let index = frozenSortedTags.firstIndex(of: operation.from) {
                        frozenSortedTags[index] = operation.to
                    }
                    pendingRenameOperation = nil
                }
            }) { tagName in
                TagEditSheet(tagName: tagName) { newName in
                    pendingRenameOperation = (from: tagName, to: newName)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if frozenSortedTags.isEmpty {
                let currentTags = Set(currentItem?.tags ?? [])
                initialSelectedTags = currentTags
                
                if reselectMode {
                    localSelectedTags = []
                    previousSelectedTags = currentTags
                    hasStartedReselection = false
                } else {
                    localSelectedTags = currentTags
                }
                
                frozenSortedTags = computeInitialSortedTags()
            }
        }
        .onDisappear {
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
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if reselectMode && !hasStartedReselection {
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

struct TagRowView: View {
    let tagName: String
    let isSelected: Bool
    var isPreviousSelected: Bool = false
    let onToggle: () -> Void
    var onEdit: (() -> Void)? = nil
    
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
                    .tint(.primary)
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
            onSave(trimmedName)
        } else {
            HistoryManager.shared.renameTag(from: tagName, to: trimmedName)
        }
        dismiss()
    }
}

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
                    .tint(.primary)
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

enum TagSelectionState: Equatable {
    case positive
    case negative
}

struct TagSelection: Equatable {
    var tag: String
    var state: TagSelectionState
    
    static let noTagIdentifier = "__NO_TAG__"
    
    var isNoTagSelection: Bool {
        tag == Self.noTagIdentifier
    }
}

struct TagFilterBar: View {
    @Binding var selectedTags: [TagSelection]
    @Binding var isRandomMode: Bool
    var availableItems: [HistoryItem]
    var isSearching: Bool = false
    var onRandomize: () -> Void
    
    @State private var tagManager = TagManager.shared
    let historyManager = HistoryManager.shared
    
    private func computeAvailableTagsFromItems() -> Set<String> {
        var tags = Set<String>()
        for item in availableItems {
            for tag in item.tags {
                tags.insert(tag)
            }
        }
        return tags
    }
    
    private func selectionState(for tagName: String, at level: Int) -> TagSelectionState? {
        guard level < selectedTags.count else { return nil }
        let selection = selectedTags[level]
        return selection.tag == tagName ? selection.state : nil
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
                                    selectionState: level >= selectedTags.count && !(level == 0 && isRandomMode) ? .positive : nil,
                                    count: isSearching ? filteredItemCount : nil
                                ) {
                                    selectAll(at: level)
                                }

                                if level == 0 {
                                    let noTagCount = getNoTagCount(at: level)
                                    if noTagCount > 0 {
                                        FilterIconChipWithState(
                                            systemImage: "tag.slash",
                                            accessibilityLabel: "无标签",
                                            selectionState: selectionState(for: TagSelection.noTagIdentifier, at: level)
                                        ) {
                                            handleTagTap(TagSelection.noTagIdentifier, at: level)
                                        }
                                    }
                                    
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
                                        selectionState: selectionState(for: item.tag, at: level),
                                        count: isSearching ? item.count : nil
                                    ) {
                                        handleTagTap(item.tag, at: level)
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
        let currentSelections = Array(selectedTags.prefix(level))
        if currentSelections.isEmpty {
            return availableItems.count
        }
        return availableItems.reduce(into: 0) { count, item in
            if matchesSelections(item: item, selections: currentSelections) {
                count += 1
            }
        }
    }
    
    private func getNoTagCount(at level: Int) -> Int {
        let currentSelections = Array(selectedTags.prefix(level))
        return availableItems.reduce(into: 0) { count, item in
            if item.tags.isEmpty && matchesSelections(item: item, selections: currentSelections) {
                count += 1
            }
        }
    }
    
    private func matchesSelections(item: HistoryItem, selections: [TagSelection]) -> Bool {
        for selection in selections {
            if selection.isNoTagSelection {
                switch selection.state {
                case .positive:
                    if !item.tags.isEmpty { return false }
                case .negative:
                    if item.tags.isEmpty { return false }
                }
            } else {
                switch selection.state {
                case .positive:
                    if !item.tags.contains(selection.tag) { return false }
                case .negative:
                    if item.tags.contains(selection.tag) { return false }
                }
            }
        }
        return true
    }
    
    private func getAvailableTagsWithCounts(at level: Int, availableTagsFromItems: Set<String>) -> [(tag: String, count: Int)] {
        let currentSelections = Array(selectedTags.prefix(level))
        let usedTags = Set(currentSelections.map { $0.tag })
        
        var filteredItems = availableItems
        if !currentSelections.isEmpty {
            filteredItems = filteredItems.filter { item in
                matchesSelections(item: item, selections: currentSelections)
            }
        }
        
        guard !filteredItems.isEmpty else { return [] }
        
        var tagCounts: [String: Int] = [:]
        for item in filteredItems {
            for tag in item.tags {
                if !usedTags.contains(tag) && availableTagsFromItems.contains(tag) {
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
    
    private func selectAll(at level: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if level < selectedTags.count {
                selectedTags = Array(selectedTags.prefix(level))
            }
            isRandomMode = false
        }
    }
    
    private func handleTagTap(_ tagName: String, at level: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if level < selectedTags.count && selectedTags[level].tag == tagName {
                let currentState = selectedTags[level].state
                switch currentState {
                case .positive:
                    var newTags = Array(selectedTags.prefix(level))
                    newTags.append(TagSelection(tag: tagName, state: .negative))
                    selectedTags = newTags
                case .negative:
                    selectedTags = Array(selectedTags.prefix(level))
                }
            } else {
                var newTags = Array(selectedTags.prefix(level))
                newTags.append(TagSelection(tag: tagName, state: .positive))
                selectedTags = newTags
            }
            isRandomMode = false
        }
    }

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
    var selectionState: TagSelectionState? = nil
    var count: Int? = nil
    let action: () -> Void
    
    private var isSelected: Bool { selectionState != nil }
    private var isNegative: Bool { selectionState == .negative }
    
    private var primaryColor: Color { Color(hex: 0x6366F1) }
    private var negativeColor: Color { Color(hex: 0xEF4444) }
    
    private var activeColor: Color {
        isNegative ? negativeColor : primaryColor
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(isNegative, color: negativeColor)
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(isSelected ? activeColor.opacity(0.7) : Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? activeColor.opacity(0.15) : Color(.tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? activeColor : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
        .animation(.none, value: selectionState)
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

struct FilterIconChipWithState: View {
    let systemImage: String
    let accessibilityLabel: String
    let selectionState: TagSelectionState?
    let action: () -> Void
    
    private var isSelected: Bool { selectionState != nil }
    private var isNegative: Bool { selectionState == .negative }
    
    private var primaryColor: Color { Color(hex: 0x6366F1) }
    private var negativeColor: Color { Color(hex: 0xEF4444) }
    
    private var activeColor: Color {
        isNegative ? negativeColor : primaryColor
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(height: 16)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? activeColor.opacity(0.15) : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? activeColor : Color(.secondaryLabel))
                .overlay(
                    isNegative ? 
                        Capsule()
                            .stroke(negativeColor.opacity(0.3), lineWidth: 1)
                        : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .animation(.none, value: selectionState)
    }
}

struct BatchTagPickerView: View {
    let itemIds: Set<UUID>
    
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateTag = false
    @State private var searchText: String = ""
    @State private var frozenSortedTags: [String] = []
    
    @State private var tagStates: [String: Bool?] = [:]
    @State private var initialTagStates: [String: Bool?] = [:]
    
    private var sortedTags: [String] { frozenSortedTags }
    
    private var displayedTags: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return sortedTags }
        return sortedTags.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }
    
    private func computeTagStates() -> [String: Bool?] {
        let items = historyManager.items.filter { itemIds.contains($0.id) }
        var states: [String: Bool?] = [:]
        for tag in tagManager.tags {
            let count = items.filter { $0.tags.contains(tag) }.count
            if count == 0 {
                states[tag] = false
            } else if count == items.count {
                states[tag] = true
            } else {
                states[tag] = nil
            }
        }
        return states
    }
    
    private func computeSortedTags() -> [String] {
        tagManager.tags.sorted { tag1, tag2 in
            let s1 = tagStates[tag1] ?? nil
            let s2 = tagStates[tag2] ?? nil
            let order1 = s1 == true ? 0 : (s1 == nil ? 1 : 2)
            let order2 = s2 == true ? 0 : (s2 == nil ? 1 : 2)
            if order1 != order2 { return order1 < order2 }
            return tagManager.count(for: tag1) > tagManager.count(for: tag2)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if tagManager.tags.isEmpty {
                    VStack(spacing: 8) {
                        Text("暂无标签")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    Spacer()
                } else {
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
                                    let state = tagStates[tagName] ?? nil
                                    
                                    BatchTagRowView(
                                        tagName: tagName,
                                        state: state,
                                        onToggle: { toggleTag(tagName) }
                                    )
                                    
                                    if index != displayedTags.count - 1 {
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }
            .background(Color(hex: 0xF2F2F6).ignoresSafeArea())
            .navigationTitle("批量标签 (\(itemIds.count)项)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标签")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showCreateTag = true }) {
                        Image(systemName: "plus")
                    }
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .tint(.primary)
                }
            }
            .sheet(isPresented: $showCreateTag, onDismiss: {
                let newStates = computeTagStates()
                for tag in tagManager.tags where !frozenSortedTags.contains(tag) {
                    frozenSortedTags.insert(tag, at: 0)
                    tagStates[tag] = newStates[tag] ?? false
                    initialTagStates[tag] = newStates[tag] ?? false
                }
            }) {
                TagCreateSheet(itemId: itemIds.first ?? UUID())
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            tagStates = computeTagStates()
            initialTagStates = tagStates
            frozenSortedTags = computeSortedTags()
        }
        .onDisappear {
            applyChanges()
        }
    }
    
    private func toggleTag(_ tagName: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            let current = tagStates[tagName] ?? nil
            switch current {
            case true:
                tagStates[tagName] = false
            case false:
                tagStates[tagName] = true
            case nil:
                tagStates[tagName] = true
            default:
                tagStates[tagName] = true
            }
        }
    }
    
    private func applyChanges() {
        for (tag, newState) in tagStates {
            let oldState = initialTagStates[tag] ?? false
            guard newState != oldState else { continue }
            
            switch newState {
            case true:
                historyManager.batchAddTag(to: itemIds, tagName: tag)
            case false:
                historyManager.batchRemoveTag(from: itemIds, tagName: tag)
            default:
                break
            }
        }
    }
}

struct BatchTagRowView: View {
    let tagName: String
    let state: Bool?
    let onToggle: () -> Void
    
    private var circleColor: Color {
        switch state {
        case true: return Color(hex: 0x6366F1)
        case nil: return Color(hex: 0x6366F1).opacity(0.5)
        default: return Color(.secondaryLabel)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(circleColor, lineWidth: 2)
                    .frame(width: 22, height: 22)
                
                if state == true {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else if state == nil {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 22, height: 22)
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            
            Text(tagName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(.label))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

#Preview {
    TagPickerView(itemId: UUID())
}
