import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var showHistory: Bool = false
    @State private var selectedTags: Set<String> = []
    @State private var showTagSelector: Bool = false
    @State private var tagManager = TagManager.shared

    @FocusState private var isTextEditorFocused: Bool
    
    // 使用静态变量存储键盘弹出任务，可以被取消
    private static var keyboardWorkItem: DispatchWorkItem?
    
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
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: navigateToHistory) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .tint(.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .tint(.primary)
                }
            }

            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
            .safeAreaBar(edge: .bottom) {
                bottomToolbar
            }
            .sheet(isPresented: $showTagSelector) {
                EditPageTagSelector(
                    initialSelectedTags: selectedTags,
                    onSelectionChanged: { selectedTags = $0 }
                )
            }
        }
        .onAppear {
            scheduleKeyboardShow(delay: 0.5)
        }
        .onChange(of: showHistory) { _, isShowing in
            if isShowing {
                // 跳转到历史页面时隐藏键盘并取消任务
                Self.keyboardWorkItem?.cancel()
                Self.keyboardWorkItem = nil
                isTextEditorFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } else {
                // 返回时延迟弹出键盘
                scheduleKeyboardShow(delay: 0.5)
            }
        }
        .onChange(of: isTextEditorFocused) { _, isFocused in
            UIApplication.shared.isIdleTimerDisabled = isFocused
        }
    }
    
    private var bottomToolbar: some View {
        HStack {
            Button(action: copyAndClear) {
                Image(systemName: "paperplane")
                    .font(.system(size: 20))
            }
            .tint(primaryColor)
            .padding(14)
            .glassEffect(.regular.interactive(), in: Circle())
            
            // 标签选择按钮
            if !tagManager.tags.isEmpty {
                Button(action: { showTagSelector = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .font(.system(size: 18))
                        
                        if selectedTags.count == 1, let tagName = selectedTags.first {
                            Text(tagName)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        } else if selectedTags.count > 1 {
                            Text("\(selectedTags.count)")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                .tint(selectedTags.isEmpty ? .primary : primaryColor)
                .padding(.horizontal, selectedTags.isEmpty ? 14 : 16)
                .padding(.vertical, 14)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            
            Spacer()
            
            Button(action: clearText) {
                Image(systemName: "trash")
                    .font(.system(size: 20))
            }
            .tint(.primary)
            .padding(14)
            .glassEffect(.regular.interactive(), in: Circle())
        }
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
    

    
    /// 安全地调度键盘弹出任务，使用 DispatchWorkItem 实现可取消的延迟任务
    private func scheduleKeyboardShow(delay: Double) {
        Self.keyboardWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [self] in
            guard !showHistory else { return }
            isTextEditorFocused = true
            
            // 重试机制，确保视图完全就绪后焦点能正确设置
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                guard !showHistory, !isTextEditorFocused else { return }
                isTextEditorFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                guard !showHistory, !isTextEditorFocused else { return }
                isTextEditorFocused = true
            }
        }
        Self.keyboardWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
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
        HistoryManager.shared.addRecord(inputText, tags: Array(selectedTags))
        
        // 只清空输入框，保留选中的标签供下次使用
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
