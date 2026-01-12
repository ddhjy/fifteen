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
    @Environment(\.dismiss) private var dismiss
    
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
                    Text("选择标签")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(PresetTags.all) { tag in
                            TagRowView(
                                tag: tag,
                                isSelected: item.tagIds.contains(tag.id),
                                onToggle: {
                                    toggleTag(tag)
                                }
                            )
                            
                            if tag.id != PresetTags.all.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 16)
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
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func toggleTag(_ tag: Tag) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            historyManager.toggleTag(for: item.id, tagId: tag.id)
        }
    }
}

struct TagRowView: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Text(tag.emoji)
                    .font(.system(size: 22))
                
                Text(tag.name)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.label))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x6366F1))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Badge View (用于在历史记录行中显示)

struct TagBadgeView: View {
    let tag: Tag
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag.emoji)
                .font(.system(size: 10))
            Text(tag.name)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tag.color.opacity(0.15))
        )
        .foregroundStyle(tag.color)
    }
}

// MARK: - Tag Filter Bar (用于筛选)

struct TagFilterBar: View {
    @Binding var selectedTagId: UUID?
    let tags: [Tag]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "全部" 按钮
                FilterChip(
                    title: "全部",
                    emoji: nil,
                    isSelected: selectedTagId == nil,
                    color: Color(hex: 0x6366F1)
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTagId = nil
                    }
                }
                
                // 各个标签筛选
                ForEach(tags) { tag in
                    FilterChip(
                        title: tag.name,
                        emoji: tag.emoji,
                        isSelected: selectedTagId == tag.id,
                        color: tag.color
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

struct FilterChip: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 4) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color(.tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? color : Color(.secondaryLabel))
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TagPickerView(item: HistoryItem(text: "这是一条测试历史记录内容"))
}
