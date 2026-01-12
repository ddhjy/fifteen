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
                historyList
            }
        }
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !historyManager.items.isEmpty {
                    Button(action: { showClearConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.glass)
                    .tint(Color(hex: 0xFF3B30))
                }
            }
        }
        .confirmationDialog("确定要清空所有历史记录吗？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空全部", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    historyManager.clearAll()
                }
            }
            Button("取消", role: .cancel) { }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appearAnimation = true
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
                Text("暂无历史记录")
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
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(historyManager.items.enumerated()), id: \.element.id) { index, item in
                    HistoryRowView(
                        item: item,
                        isCopied: copiedItemId == item.id,
                        onCopy: { copyItem(item) },
                        onDelete: { deleteItem(item) }
                    )
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                        .delay(Double(index) * 0.05),
                        value: appearAnimation
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
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
    
    private func deleteItem(_ item: HistoryItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if let index = historyManager.items.firstIndex(where: { $0.id == item.id }) {
                historyManager.deleteRecords(at: IndexSet(integer: index))
            }
        }
    }
}

struct HistoryRowView: View {
    let item: HistoryItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var offset: CGFloat = 0
    @State private var showDeleteButton = false
    
    private let deleteThreshold: CGFloat = -80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 删除按钮背景
            if showDeleteButton {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: 0xFF3B30), Color(hex: 0xFF6B6B)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
            
            // 主卡片内容
            Button(action: onCopy) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.preview)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(.label))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        // 时间标签
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text(item.formattedDate)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color(.tertiaryLabel))
                        
                        Spacer()
                        
                        // 复制成功标识
                        if isCopied {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("已复制")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: 0x34C759))
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(isPressed ? 0.98 : 1)
                .scaleEffect(isCopied ? 1.02 : 1)
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation < 0 {
                            offset = translation * 0.8
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDeleteButton = translation < deleteThreshold
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if value.translation.width < deleteThreshold {
                                offset = deleteThreshold
                                showDeleteButton = true
                            } else {
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if showDeleteButton {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                withAnimation(.easeOut(duration: 0.15)) {
                    isPressed = pressing
                }
            }) { }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
