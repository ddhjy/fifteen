//
//  HistoryView.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var historyManager = HistoryManager.shared
    @State private var showClearConfirmation = false
    @State private var copiedItemId: UUID?
    @State private var appearAnimation = false
    @State private var isEditMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var selectedTags: [String] = []
    @State private var tagPickerItem: HistoryItem? = nil
    @State private var isExporting = false
    @State private var exportedFileURL: URL? = nil
    @State private var searchText = ""
    @State private var committedSearchText = ""
    @State private var isSearchTextComposing = false
    @State private var searchUpdateWorkItem: DispatchWorkItem?
    @State private var showStatistics = false
    @State private var isRandomMode = false
    @State private var randomShuffleSeed: UInt64 = 0
    
    private var filteredItems: [HistoryItem] {
        var items = historyManager.getSavedItems(filteredBy: selectedTags)
        
        // 搜索过滤：同时匹配正文和标签名
        if !effectiveSearchText.isEmpty {
            items = items.filter { item in
                let textMatch = item.text.localizedCaseInsensitiveContains(effectiveSearchText)
                let tagMatch = item.tags.contains { $0.localizedCaseInsensitiveContains(effectiveSearchText) }
                return textMatch || tagMatch
            }
        }
        
        return items
    }

    private var displayedItems: [HistoryItem] {
        let items = filteredItems
        guard isRandomMode, randomShuffleSeed != 0 else { return items }
        var generator = SeededGenerator(seed: randomShuffleSeed)
        return items.shuffled(using: &generator)
    }
    
    /// 仅应用搜索过滤、不应用标签筛选的记录（用于计算可选标签）
    private var filteredItemsWithoutTagFilter: [HistoryItem] {
        var items = historyManager.savedItems
        
        if !effectiveSearchText.isEmpty {
            items = items.filter { item in
                let textMatch = item.text.localizedCaseInsensitiveContains(effectiveSearchText)
                let tagMatch = item.tags.contains { $0.localizedCaseInsensitiveContains(effectiveSearchText) }
                return textMatch || tagMatch
            }
        }
        
        return items
    }

    private var effectiveSearchText: String {
        committedSearchText
    }
    
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()
            
            if historyManager.savedItems.isEmpty {
                emptyStateView
            } else {
                historyContent
            }
        }
        .navigationTitle("随心记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !historyManager.savedItems.isEmpty {
                    if isEditMode {
                        // 编辑模式下显示完成按钮
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isEditMode = false
                                selectedItems.removeAll()
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .tint(.primary)
                    } else {
                        
                        // 更多菜单
                        Menu {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isEditMode = true
                                }
                            }) {
                                Label("编辑", systemImage: "pencil")
                            }
                            
                            Button(action: { showStatistics = true }) {
                                Label("统计", systemImage: "chart.bar")
                            }
                            
                            Button(action: exportNotes) {
                                Label("导出", systemImage: "square.and.arrow.up")
                            }
                            .disabled(isExporting)
                        } label: {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 17, weight: .regular))
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            
            // 编辑模式底部工具栏
            ToolbarItemGroup(placement: .bottomBar) {
                if isEditMode && !selectedItems.isEmpty {
                    Button(action: {
                        if selectedItems.count == filteredItems.count {
                            selectedItems.removeAll()
                        } else {
                            selectedItems = Set(filteredItems.map { $0.id })
                        }
                    }) {
                        Text(selectedItems.count == filteredItems.count ? "取消全选" : "全选")
                            .font(.system(size: 17))
                    }
                    .tint(Color(hex: 0x6366F1))
                    
                    Spacer()
                    
                    Text("已选择 \(selectedItems.count) 项")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize()
                    
                    Spacer()
                    
                    Button(action: { showClearConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                    }
                    .tint(Color(hex: 0xFF3B30))
                }
            }
        }
        .toolbarBackgroundVisibility(.visible, for: .bottomBar)
        .onChange(of: isRandomMode) { _, newValue in
            if !newValue {
                randomShuffleSeed = 0
            } else if randomShuffleSeed == 0 {
                randomShuffleSeed = UInt64.random(in: 1...UInt64.max)
            }
        }
        .alert("确定要删除选中的 \(selectedItems.count) 条记录吗？", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    deleteSelectedItems()
                }
            }
        } message: {
            Text("此操作无法撤销")
        }
        .sheet(item: $tagPickerItem) { item in
            TagPickerView(itemId: item.id)
        }
        .sheet(isPresented: Binding(
            get: { exportedFileURL != nil },
            set: { if !$0 { exportedFileURL = nil } }
        )) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(items: historyManager.savedItems)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appearAnimation = true
            }
        }
    }
    
    private func deleteSelectedItems() {
        // 使用批量删除接口，一次性删除所有选中项，避免循环调用
        historyManager.deleteRecords(ids: selectedItems)
        selectedItems.removeAll()
        if historyManager.savedItems.isEmpty {
            isEditMode = false
        }
    }
    
    private func exportNotes() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try historyManager.exportAllNotes()
                DispatchQueue.main.async {
                    isExporting = false
                    exportedFileURL = url
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    print("Export failed: \(error)")
                }
            }
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        searchUpdateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [newValue] in
            let responder = UIApplication.shared.currentFirstResponder()
            let textField = responder as? UITextField
            let hasMarkedText = textField?.markedTextRange != nil
            let isChineseInput = textField?.textInputMode?.primaryLanguage?.hasPrefix("zh") == true
            let containsHanCharacters = newValue.range(of: "\\p{Han}", options: .regularExpression) != nil
            let shouldDeferUpdate = hasMarkedText || (isChineseInput && !containsHanCharacters && !newValue.isEmpty)
            
            if isSearchTextComposing != shouldDeferUpdate {
                isSearchTextComposing = shouldDeferUpdate
            }
            
            guard !shouldDeferUpdate else { return }
            committedSearchText = newValue
        }
        
        searchUpdateWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func randomizeDisplayOrder() {
        isRandomMode = true
        randomShuffleSeed = UInt64.random(in: 1...UInt64.max)
    }
    
    @ViewBuilder
    private var historyContent: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 0) {
                    if !effectiveSearchText.isEmpty {
                        searchEmptyStateView
                    } else {
                        filteredEmptyStateView
                    }
                }
            } else {
                historyList
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TagFilterBar(
                selectedTags: $selectedTags,
                isRandomMode: $isRandomMode,
                availableItems: filteredItemsWithoutTagFilter,
                onRandomize: randomizeDisplayOrder
            )
            .background {
                Color.clear
                    .background(.bar)
            }
        }
        .searchable(text: $searchText, prompt: "搜索记录")
        .onChange(of: searchText) { _, newValue in
            handleSearchTextChange(newValue)
        }
        .onSubmit(of: .search) {
            searchUpdateWorkItem?.cancel()
            isSearchTextComposing = false
            committedSearchText = searchText
        }
        .toolbar {
            if !isEditMode {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标容器 - Liquid Glass 风格
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .glassEffect(.regular, in: Circle())
                
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .opacity(appearAnimation ? 1 : 0)
            .scaleEffect(appearAnimation ? 1 : 0.8)
            
            VStack(spacing: 8) {
                Text("暂无记录")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(.label))
                
                Text("复制的文本会自动保存在这里")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 10)
        }
        .padding(.horizontal, 40)
    }
    
    private var filteredEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color(.tertiaryLabel))
            
            Text("没有符合筛选条件的记录")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color(.tertiaryLabel))
            
            Text("没有找到 \"\(effectiveSearchText)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(displayedItems) { item in
                    HistoryRowView(
                        item: item,
                        isCopied: copiedItemId == item.id,
                        isEditMode: isEditMode,
                        isSelected: selectedItems.contains(item.id),
                        filteredTags: selectedTags,
                        searchText: effectiveSearchText,
                        onCopy: { copyItem(item) },
                        onToggleSelection: { toggleSelection(item) },
                        onTagTap: { tagPickerItem = item },
                        onEdit: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isEditMode = true
                                selectedItems.insert(item.id)
                            }
                        },
                        onDelete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                historyManager.deleteRecord(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }
    
    private func toggleSelection(_ item: HistoryItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        }
    }
    
    private func copyItem(_ item: HistoryItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        UIPasteboard.general.string = item.text
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copiedItemId = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                if copiedItemId == item.id {
                    copiedItemId = nil
                }
            }
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private final class FirstResponderTracker {
    static weak var current: UIResponder?
}

private extension UIResponder {
    @objc func captureFirstResponder() {
        FirstResponderTracker.current = self
    }
}

private extension UIApplication {
    func currentFirstResponder() -> UIResponder? {
        FirstResponderTracker.current = nil
        sendAction(#selector(UIResponder.captureFirstResponder), to: nil, from: nil, for: nil)
        return FirstResponderTracker.current
    }
}

struct HistoryRowView: View {
    let item: HistoryItem
    let isCopied: Bool
    let isEditMode: Bool
    let isSelected: Bool
    var filteredTags: [String] = []
    var searchText: String = ""
    let onCopy: () -> Void
    let onToggleSelection: () -> Void
    let onTagTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // 编辑模式下的选择圆圈
            if isEditMode {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color(hex: 0x6366F1) : Color(.quaternaryLabel),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x6366F1), Color(hex: 0x818CF8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // 主内容
            VStack(alignment: .leading, spacing: 8) {
                highlightedText(item.preview, searchText: searchText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.leading)
                    
                    // 分割线
                    Rectangle()
                        .fill(Color(.separator).opacity(0.5))
                        .frame(height: 1)
                    
                    // 底部信息区 - 固定高度防止标签增减时抖动
                    HStack(spacing: 8) {
                        // 日期
                        Text(item.formattedDate)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                        
                        // 标签 (内联显示，排除当前筛选的标签)
                        let displayTags = item.tags.filter { !filteredTags.contains($0) }
                        if !displayTags.isEmpty && !isEditMode {
                            ForEach(displayTags.prefix(4), id: \.self) { tagName in
                                Text(tagName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color(hex: 0x6366F1))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: 0x6366F1).opacity(0.08))
                                    )
                            }
                            
                            if displayTags.count > 4 {
                                Text("+\(displayTags.count - 4)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                        
                        Spacer()
                        
                        // 更多按钮
                        if !isEditMode {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .frame(width: 32, height: 16, alignment: .trailing)
                        }
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isEditMode {
                        onTagTap()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                onToggleSelection()
            }
        }
        .contextMenu {
            if !isEditMode {
                Button {
                    onCopy()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                
                Button {
                    onTagTap()
                } label: {
                    Label("标签", systemImage: "tag")
                }
                
                Button {
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "checkmark.circle")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
    
    /// 创建高亮显示搜索关键词的文本
    @ViewBuilder
    private func highlightedText(_ text: String, searchText: String) -> some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            let attributedString = createHighlightedAttributedString(text: text, searchText: searchText)
            Text(attributedString)
        }
    }
    
    /// 创建带高亮的 AttributedString
    private func createHighlightedAttributedString(text: String, searchText: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // 使用不区分大小写的搜索
        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        
        while let range = lowercasedText.range(of: lowercasedSearch, range: searchStartIndex..<lowercasedText.endIndex) {
            // 转换为 AttributedString 的范围
            if let attributedRange = Range(NSRange(range, in: text), in: attributedString) {
                attributedString[attributedRange].backgroundColor = Color(hex: 0x6366F1).opacity(0.25)
                attributedString[attributedRange].foregroundColor = Color(hex: 0x6366F1)
            }
            
            // 移动搜索起始位置
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
    
    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            // 选中状态：带边框的高亮背景
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0x6366F1).opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: 0x6366F1).opacity(0.25), lineWidth: 1.5)
                )
        } else {
            // 默认状态：使用轻量级白色背景
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 2)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Statistics View

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [HistoryItem]
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    
    private let calendar = Calendar.current
    
    /// 根据选中日期过滤后的记录
    private var filteredItems: [HistoryItem] {
        guard let selectedDate = selectedDate else { return items }
        return items.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
    }
    
    private var totalRecords: Int {
        filteredItems.count
    }
    
    private var totalCharacters: Int {
        filteredItems.reduce(0) { $0 + $1.text.count }
    }
    
    private var tagStatistics: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for item in filteredItems {
            for tag in item.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts.map { ($0.key, $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var untaggedCount: Int {
        filteredItems.filter { $0.tags.isEmpty }.count
    }
    
    /// 按日期统计记录数（用于日历显示）
    private var recordsByDate: [Date: Int] {
        var counts: [Date: Int] = [:]
        for item in items {
            let dateOnly = calendar.startOfDay(for: item.createdAt)
            counts[dateOnly, default: 0] += 1
        }
        return counts
    }
    
    private var selectedDateString: String {
        guard let date = selectedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 日历
                Section {
                    CalendarGridView(
                        displayedMonth: $displayedMonth,
                        selectedDate: $selectedDate,
                        recordsByDate: recordsByDate
                    )
                } header: {
                    HStack {
                        Text("记录日历")
                        Spacer()
                        if selectedDate != nil {
                            Button("查看全部") {
                                withAnimation {
                                    selectedDate = nil
                                }
                            }
                            .font(.system(size: 12))
                            .textCase(nil)
                        }
                    }
                }
                
                // 总览
                Section {
                    HStack {
                        Label("记录数", systemImage: "doc.text")
                        Spacer()
                        Text("\(totalRecords)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("总字数", systemImage: "character.cursor.ibeam")
                        Spacer()
                        Text("\(totalCharacters)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    if let _ = selectedDate {
                        Text("\(selectedDateString) 统计")
                    } else {
                        Text("总览")
                    }
                }
                
                // 标签统计
                if !tagStatistics.isEmpty || untaggedCount > 0 {
                    Section {
                        ForEach(tagStatistics, id: \.tag) { stat in
                            HStack {
                                Text(stat.tag)
                                Spacer()
                                Text("\(stat.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if untaggedCount > 0 {
                            HStack {
                                Text("无标签")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(untaggedCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("标签统计")
                    }
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    let recordsByDate: [Date: Int]
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: displayedMonth)
    }
    
    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 月份导航
            HStack {
                Button {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x6366F1))
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x6366F1))
                }
            }
            .padding(.horizontal, 8)
            
            // 星期标题
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: 24)
                }
            }
            
            // 日期格子
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let dateOnly = calendar.startOfDay(for: date)
                        let count = recordsByDate[dateOnly] ?? 0
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .white : (isToday ? Color(hex: 0x6366F1) : .primary))
                            
                            if count > 0 && !isSelected {
                                Circle()
                                    .fill(Color.green.opacity(min(Double(count) / 5.0, 1.0) * 0.7 + 0.3))
                                    .frame(width: 6, height: 6)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isSelected ? Color(hex: 0x6366F1) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if count > 0 {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    if isSelected {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = dateOnly
                                    }
                                }
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
