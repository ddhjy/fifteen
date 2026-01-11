//
//  ContentView.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var isCopied: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    // 主题配色 - 参考截图风格
    private let primaryColor = Color(hex: 0x6366F1)  // 紫罗兰色主色调
    
    private var characterCount: Int { inputText.count }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 纯净背景
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部状态区域 - 极简风格
                    statusBar
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                    
                    // 主编辑区域 - 大量留白
                    editorArea
                        .padding(.top, 32)
                        .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // 底部操作栏 - 简洁克制
                    bottomBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            isTextEditorFocused = true
        }
        .onChange(of: isTextEditorFocused) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextEditorFocused = true
                }
            }
        }
    }
    
    // MARK: - 状态栏
    private var statusBar: some View {
        HStack(alignment: .center) {
            // 状态指示器 - 精致动画
            HStack(spacing: 10) {
                Circle()
                    .fill(isCopied ? Color(hex: 0x34C759) : Color(.tertiaryLabel))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isCopied ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isCopied)
                
                Text(statusText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isCopied ? Color(hex: 0x34C759) : Color(.tertiaryLabel))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: characterCount)
            }
            
            Spacer()
        }
    }
    
    private var statusText: String {
        if isCopied {
            return "已复制 \(characterCount) 字符"
        } else if inputText.isEmpty {
            return "等待输入"
        } else {
            return "\(characterCount) 字符"
        }
    }
    
    // MARK: - 编辑区域
    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            // 编辑器容器 - 柔和阴影
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            
            // 文本编辑器
            TextEditor(text: $inputText)
                .focused($isTextEditorFocused)
                .font(.system(size: 17, weight: .regular, design: .default))
                .scrollContentBackground(.hidden)
                .padding(16)
                .onChange(of: inputText) { _, _ in
                    isCopied = false
                }
            
            // 占位符文字
            if inputText.isEmpty {
                Text("开始输入...")
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundStyle(Color(.placeholderText))
                    .padding(16)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 280)
    }
    
    // MARK: - 底部操作栏
    private var bottomBar: some View {
        HStack(spacing: 16) {
            // 复制按钮 - Liquid Glass Prominent 风格（主要操作）
            Button(action: copyAndClear) {
                Label("复制", systemImage: "doc.on.doc")
            }
            .buttonStyle(.glassProminent)
            .tint(Color(hex: 0x6366F1))
            .disabled(inputText.isEmpty)
            .opacity(inputText.isEmpty ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
            
            // 清空按钮 - Liquid Glass 风格
            Button(action: clearText) {
                Label("清空", systemImage: "xmark.circle")
            }
            .buttonStyle(.glass)
            .disabled(inputText.isEmpty)
            .opacity(inputText.isEmpty ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    private func clearText() {
        // 轻触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeOut(duration: 0.25)) {
            inputText = ""
        }
    }
    
    private func copyAndClear() {
        guard !inputText.isEmpty else { return }
        
        // 轻触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 复制到剪贴板
        UIPasteboard.general.string = inputText
        
        // 清空输入
        withAnimation(.easeOut(duration: 0.25)) {
            inputText = ""
        }
        
        // 显示已复制状态
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

#Preview {
    ContentView()
}
