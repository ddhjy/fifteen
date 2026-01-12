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
    @State private var selectedTagFilter: UUID? = nil
    @State private var tagPickerItem: HistoryItem? = nil
    
    private var filteredItems: [HistoryItem] {
        historyManager.getItems(filteredBy: selectedTagFilter)
    }
    
    var body: some View {
        ZStack {
            // 背景渐变 - iOS 26 风格
            LinearGradient(
                colors: [
                    Color(hex: 0xF8F9FA),
                    Color(hex: 0xF2F2F6),
                    Color(hex: 0xEBECF0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if historyManager.items.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // 标签筛选栏
                    TagFilterBar(selectedTagId: $selectedTagFilter)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : -10)
                    
                    if filteredItems.isEmpty {
                        filteredEmptyStateView
                    } else {
                        historyList
                    }
                }
            }
            
            // 编辑模式下的底部操作栏
            if isEditMode && !selectedItems.isEmpty {
                VStack {
                    Spacer()
                    editModeBottomBar
                }
            }
        }
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !historyManager.items.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedItems.removeAll()
                            }
                        }
                    }) {
                        Text(isEditMode ? "完成" : "编辑")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .tint(Color(hex: 0x6366F1))
                }
            }
        }
        .confirmationDialog("确定要删除选中的 \(selectedItems.count) 条记录吗？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("删除选中", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    deleteSelectedItems()
                }
            }
            Button("取消", role: .cancel) { }
        }
        .sheet(item: $tagPickerItem) { item in
            TagPickerView(item: item)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appearAnimation = true
            }
        }
    }
    
    private var editModeBottomBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                // 全选/取消全选
                if selectedItems.count == filteredItems.count {
                    selectedItems.removeAll()
                } else {
                    selectedItems = Set(filteredItems.map { $0.id })
                }
            }) {
                Text(selectedItems.count == filteredItems.count ? "取消全选" : "全选")
                    .font(.system(size: 15, weight: .medium))
            }
            .tint(Color(hex: 0x6366F1))
            
            Spacer()
            
            Text("已选择 \(selectedItems.count) 项")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
            
            Spacer()
            
            Button(action: { showClearConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
            }
            .tint(Color(hex: 0xFF3B30))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func deleteSelectedItems() {
        let idsToDelete = selectedItems
        for id in idsToDelete {
            if let index = historyManager.items.firstIndex(where: { $0.id == id }) {
                historyManager.deleteRecords(at: IndexSet(integer: index))
            }
        }
        selectedItems.removeAll()
        if historyManager.items.isEmpty {
            isEditMode = false
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
                
                Image(systemName: "clock.arrow.circlepath")
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
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    HistoryRowView(
                        item: item,
                        isCopied: copiedItemId == item.id,
                        isEditMode: isEditMode,
                        isSelected: selectedItems.contains(item.id),
                        onCopy: { copyItem(item) },
                        onToggleSelection: { toggleSelection(item) },
                        onTagTap: { tagPickerItem = item }
                    )
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                        .delay(Double(index) * 0.03),
                        value: appearAnimation
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, isEditMode ? 80 : 0) // 为底部操作栏留空间
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
    let onCopy: () -> Void
    let onToggleSelection: () -> Void
    let onTagTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if isEditMode {
                onToggleSelection()
            } else {
                onCopy()
            }
        }) {
            HStack(spacing: 12) {
                // 编辑模式下的选择圆圈
                if isEditMode {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(hex: 0x6366F1) : Color(.tertiaryLabel), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color(hex: 0x6366F1))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // 主内容
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.preview)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.label))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // 标签显示区域
                    if !item.tags.isEmpty && !isEditMode {
                        HStack(spacing: 6) {
                            ForEach(item.tags) { tag in
                                TagBadgeView(tag: tag)
                            }
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(item.formattedDate)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(.tertiaryLabel))
                        
                        Spacer()
                        
                        // 标签按钮
                        if !isEditMode {
                            Button(action: onTagTap) {
                                Image(systemName: item.tags.isEmpty ? "tag" : "tag.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(item.tags.isEmpty ? Color(.tertiaryLabel) : Color(hex: 0x6366F1))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // 复制成功标识
                        if isCopied && !isEditMode {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("已复制")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Color(hex: 0x34C759))
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color(hex: 0x6366F1).opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isPressed ? 0.98 : 1)
            .scaleEffect(isCopied && !isEditMode ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressed = pressing
            }
        }) { }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}

