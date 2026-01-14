import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var showHistory: Bool = false


    @FocusState private var isTextEditorFocused: Bool
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    private var characterCount: Int { inputText.count }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 全屏编辑区域
                    fullScreenEditor
                }
        }
            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: navigateToHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .tint(.primary)
                }
            }

            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
                    .onDisappear {
                        // 返回时延迟弹出键盘
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTextEditorFocused = true
                        }
                    }
            }
            .safeAreaBar(edge: .bottom) {
                bottomToolbar
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
        .onChange(of: showHistory) { _, isShowing in
            if isShowing {
                // 跳转到历史页面时隐藏键盘
                isTextEditorFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } else {
                // 返回时延迟弹出键盘，等待动画完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextEditorFocused = true
                }
            }
        }
        .onChange(of: isTextEditorFocused) { _, isFocused in
            UIApplication.shared.isIdleTimerDisabled = isFocused
        }
    }
    
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Button(action: copyAndClear) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
            }
            .tint(primaryColor)
            .padding(14)
            .glassEffect(.regular.interactive(), in: Circle())
            
            Button(action: clearText) {
                Image(systemName: "trash")
                    .font(.system(size: 20))
            }
            .tint(.primary)
            .padding(14)
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var fullScreenEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 正文输入区
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("开始输入...")
                        .font(.system(size: 17))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                
                TextEditor(text: $inputText)
                    .focused($isTextEditorFocused)
                    .font(.system(size: 17, weight: .regular))
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(inputText.isEmpty)
                    .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity)
        }
    }
    

    
    private func navigateToHistory() {
        showHistory = true
    }
    
    private func clearText() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeOut(duration: 0.25)) {
            inputText = ""
        }
    }
    
    private func copyAndClear() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        guard !inputText.isEmpty else { return }
        
        UIPasteboard.general.string = inputText
        HistoryManager.shared.addRecord(inputText)
        
        // 直接清空输入框
        inputText = ""
    }
}

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
