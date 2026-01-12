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
                            ForEach(tagManager.tags, id: \.self) { tagName in
                                TagRowView(
                                    tagName: tagName,
                                    isSelected: item.tags.contains(tagName),
                                    onToggle: { toggleTag(tagName) }
                                )
                                
                                if tagName != tagManager.tags.last {
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
                TagCreateSheet(itemId: item.id)
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
    
    private func toggleTag(_ tagName: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            historyManager.toggleTag(for: item.id, tagName: tagName)
        }
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    let tagName: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
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
                
                Text(tagName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.label))
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTagName = nil
                        }
                    }
                    
                    // 各个标签筛选
                    ForEach(tagManager.tags, id: \.self) { tagName in
                        FilterChip(
                            title: tagName,
                            isSelected: selectedTagName == tagName
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTagName = selectedTagName == tagName ? nil : tagName
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
    TagPickerView(item: HistoryItem(fileName: "test.md", text: "这是一条测试记录内容"))
}
