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
    @State private var isSearchActive = false
    
    private var filteredItems: [HistoryItem] {
        var items = historyManager.getSavedItems(filteredBy: selectedTags)
        
        // 搜索过滤
        if !searchText.isEmpty {
            items = items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        
        return items
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
        .navigationTitle("记录")
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
                        // 搜索按钮
                        Button(action: {
                            isSearchActive = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17, weight: .regular))
                        }
                        .tint(.primary)
                        
                        // 更多菜单
                        Menu {
                            Button(action: exportNotes) {
                                Label("导出", systemImage: "square.and.arrow.up")
                            }
                            .disabled(isExporting)
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isEditMode = true
                                }
                            }) {
                                Label("编辑", systemImage: "pencil")
                            }
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appearAnimation = true
            }
        }
        .onChange(of: isSearchActive) { oldValue, newValue in
            // 搜索被关闭时清空搜索文本
            if !newValue {
                searchText = ""
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
    
    @ViewBuilder
    private var historyContent: some View {
        let content = VStack(spacing: 0) {
            // 标签筛选栏
            TagFilterBar(selectedTags: $selectedTags)
            
            if filteredItems.isEmpty {
                if !searchText.isEmpty {
                    searchEmptyStateView
                } else {
                    filteredEmptyStateView
                }
            } else {
                historyList
            }
        }
        
        if isSearchActive {
            content
                .searchable(text: $searchText, isPresented: $isSearchActive, placement: .toolbar, prompt: "搜索记录")
        } else {
            content
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
            
            Text("没有找到 \"\(searchText)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    HistoryRowView(
                        item: item,
                        isCopied: copiedItemId == item.id,
                        isEditMode: isEditMode,
                        isSelected: selectedItems.contains(item.id),
                        filteredTags: selectedTags,
                        onCopy: { copyItem(item) },
                        onToggleSelection: { toggleSelection(item) },
                        onTagTap: { tagPickerItem = item }
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

struct HistoryRowView: View {
    let item: HistoryItem
    let isCopied: Bool
    let isEditMode: Bool
    let isSelected: Bool
    var filteredTags: [String] = []
    let onCopy: () -> Void
    let onToggleSelection: () -> Void
    let onTagTap: () -> Void
    
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
                Text(item.preview)
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
                            ForEach(displayTags.prefix(2), id: \.self) { tagName in
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
                            
                            if displayTags.count > 2 {
                                Text("+\(displayTags.count - 2)")
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
            }
        }
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
