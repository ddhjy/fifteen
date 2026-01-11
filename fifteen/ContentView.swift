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
    @State private var copyStatus: String = "等待输入..."
    @State private var statusColor: Color = .secondary
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态显示（持续显示）
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(copyStatus)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Button(action: {
                    inputText = ""
                }) {
                    Text("清空")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            // 多行文本编辑器
            TextEditor(text: $inputText)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .onChange(of: inputText) { _, newValue in
                    copyToClipboard(newValue)
                }
            
            Spacer()
        }
        .padding(.top)
    }
    
    private func copyToClipboard(_ text: String) {
        if text.isEmpty {
            statusColor = .secondary
            copyStatus = "等待输入..."
        } else {
            UIPasteboard.general.string = text
            statusColor = .green
            copyStatus = "已复制 \(text.count) 个字符"
        }
    }
}

#Preview {
    ContentView()
}
