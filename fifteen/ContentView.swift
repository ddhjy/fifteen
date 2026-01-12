import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var isCopied: Bool = false
    @State private var showHistoryAlert: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    private var characterCount: Int { inputText.count }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: 0xF2F2F6)
                    .ignoresSafeArea()
                
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
        .onAppear {
            isTextEditorFocused = true
        }
    }
    
    private var statusBar: some View {
        Text(statusText)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(isCopied ? Color(hex: 0x34C759) : Color(.tertiaryLabel))
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.2), value: characterCount)
    }
    
    private var statusText: String {
        if isCopied {
            return "已复制 \(characterCount) 字"
        } else {
            return "\(characterCount) 字"
        }
    }
    
    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            TextField("开始输入...", text: $inputText, axis: .vertical)
                .focused($isTextEditorFocused)
                .font(.system(size: 17, weight: .regular, design: .default))
                .padding(16)
                .padding(.bottom, 32) // 为底部状态栏留出空间
                .onChange(of: inputText) { _, _ in
                    isCopied = false
                }
            
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
        }
        .frame(minHeight: 280)
        .contentShape(Rectangle())
        .onTapGesture {
            isTextEditorFocused = true
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            
            Button(action: { showHistoryAlert = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.glass)
        }
        .alert("历史记录", isPresented: $showHistoryAlert) {
            Button("好的", role: .cancel) { }
        } message: {
            Text("此功能即将推出，敬请期待！")
        }
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
        
        withAnimation(.easeOut(duration: 0.25)) {
            inputText = ""
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
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
