import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var showHistory: Bool = false
    @State private var shimmerOffset: CGFloat = -80
    @State private var viewWidth: CGFloat = 0

    @FocusState private var isTextEditorFocused: Bool
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    private var characterCount: Int { inputText.count }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(hex: 0xF2F2F6)
                        .ignoresSafeArea()
                        .onAppear {
                            viewWidth = geometry.size.width
                        }
                        .onChange(of: geometry.size.width) { _, newWidth in
                            viewWidth = newWidth
                        }
                    
                    VStack(spacing: 0) {
                        editorArea
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                        
                        bottomBar
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: navigateToHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("语音输入")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
                    .onAppear {
                        // 跳转完成后静默收起键盘
                        isTextEditorFocused = false
                    }
                    .onDisappear {
                        // 返回后直接弹出键盘
                        isTextEditorFocused = true
                    }
            }
        }
        .onAppear {
            // 延迟弹出键盘，等待页面动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
        .onChange(of: isTextEditorFocused) { _, isFocused in
            // 输入状态时阻止息屏
            UIApplication.shared.isIdleTimerDisabled = isFocused
        }
    }
    
    private var statusBar: some View {
        Text("\(characterCount) 字")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color(.tertiaryLabel))
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.2), value: characterCount)
    }
    
    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $inputText)
                .focused($isTextEditorFocused)
                .font(.system(size: 17, weight: .regular, design: .default))
                .scrollContentBackground(.hidden)
                .padding(16)
                .padding(.bottom, 32) // 为底部状态栏留出空间
            
            // 状态显示移到右下角
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    statusBar
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }
            }
            
            // 玻璃光掠过效果
            shimmerOverlay
        }
        .frame(minHeight: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.4),
                    Color.white.opacity(0.6),
                    Color.white.opacity(0.4),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: geometry.size.height * 2)
            .rotationEffect(.degrees(-45))
            .blur(radius: 6)
            .offset(x: shimmerOffset, y: -shimmerOffset * 0.7)
        }
        .allowsHitTesting(false) // 确保不影响触摸交互
    }
    
    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button(action: copyAndClear) {
                Label("复制", systemImage: "paperplane.fill")
            }
            .buttonStyle(.glassProminent)
            .tint(Color(hex: 0x6366F1))
            
            Button(action: clearText) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.glass)
            
            Spacer()
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
        
        // 触发玻璃光掠过动画（仅从左到右）
        withAnimation(.easeInOut(duration: 0.5)) {
            shimmerOffset = viewWidth + 80
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shimmerOffset = -80  // 无动画地重置回起点
        }
        
        // 动画走到一半时清空输入框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.25)) {
                inputText = ""
            }
        }
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
