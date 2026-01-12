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
    
    var body: some View {
        ZStack {
            Color(hex: 0xF2F2F6)
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
                            .font(.system(size: 14, weight: .medium))
                    }
                    .tint(Color(hex: 0xFF3B30))
                }
            }
        }
        .confirmationDialog("确定要清空所有历史记录吗？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空全部", role: .destructive) {
                withAnimation {
                    historyManager.clearAll()
                }
            }
            Button("取消", role: .cancel) { }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color(.tertiaryLabel))
            
            Text("暂无历史记录")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
            
            Text("复制的文本会自动保存在这里")
                .font(.system(size: 14))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }
    
    private var historyList: some View {
        List {
            ForEach(historyManager.items) { item in
                HistoryRowView(
                    item: item,
                    isCopied: copiedItemId == item.id,
                    onCopy: { copyItem(item) }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete { offsets in
                withAnimation {
                    historyManager.deleteRecords(at: offsets)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func copyItem(_ item: HistoryItem) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        UIPasteboard.general.string = item.text
        
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedItemId = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
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
    let onCopy: () -> Void
    
    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.preview)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text(item.formattedDate)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(.tertiaryLabel))
                    
                    Spacer()
                    
                    if isCopied {
                        Label("已复制", systemImage: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: 0x34C759))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
