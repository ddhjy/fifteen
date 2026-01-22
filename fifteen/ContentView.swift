import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showHistory: Bool = false
    @State private var showTagSelector: Bool = false
    @State private var showDebugView: Bool = false
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    
    @State private var showSettings: Bool = false
    @State private var settingsManager = SettingsManager.shared

    @State private var isTextEditorFocused: Bool = false
    
    @State private var showWorkflowConfig = false
    @State private var workflowManager = WorkflowManager.shared
    @State private var isProcessingWorkflow = false
    @State private var workflowResult: WorkflowExecutionResult? = nil
    @State private var workflowError: Error? = nil
    
    // 键盘动画期间禁用编辑框交互，避免用户误触导致 AutoFill 弹窗
    @State private var isKeyboardAnimating: Bool = false
    
    // 使用静态变量存储键盘弹出任务，可以被取消
    private static var keyboardWorkItem: DispatchWorkItem?
    
    // 追踪是否是首次启动，首次启动时直接弹出键盘无需延迟
    private static var isFirstLaunch: Bool = true
    
    private let primaryColor = Color(hex: 0x6366F1)
    private let warningColor = Color.yellow
    
    // 从草稿获取当前文本
    private var draftText: String {
        historyManager.currentDraft.text
    }
    
    // 从草稿获取当前标签
    private var selectedTags: [String] {
        historyManager.currentDraft.tags
    }

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
                    Button(action: { showSettings = true }) {
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
                TagPickerView(itemId: historyManager.currentDraft.id)
            }
            .sheet(isPresented: $showDebugView) {
                DebugView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showWorkflowConfig) {
                WorkflowConfigView()
            }
            .sheet(item: $workflowResult) { result in
                WorkflowPreviewView(
                    result: result,
                    onSave: { performSave(text: result.finalText) },
                    onCancel: { }
                )
            }
            .alert("处理失败", isPresented: Binding(
                get: { workflowError != nil },
                set: { if !$0 { workflowError = nil } }
            )) {
                Button("确定") { workflowError = nil }
            } message: {
                Text(workflowError?.localizedDescription ?? "未知错误")
            }

        }
        .onAppear {
            if Self.isFirstLaunch {
                // 首次启动时直接弹出键盘，无需延迟
                Self.isFirstLaunch = false
                isTextEditorFocused = true
            } else {
                scheduleKeyboardShow(delay: 0.5)
            }
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
            if settingsManager.isRightHandMode {
                // 右手模式：删除按钮在左，发送和标签在右
                Button(action: clearText) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                }
                .tint(.primary)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
                
                Spacer()
                
                // Workflow 配置按钮
                Button(action: { showWorkflowConfig = true }) {
                    if isProcessingWorkflow {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 18))
                    }
                }
                .tint(
                    isProcessingWorkflow
                        ? primaryColor
                        : (workflowManager.areTerminalNodesAllDisabled ? warningColor : .primary)
                )
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
                
                // 标签选择按钮
                if !tagManager.tags.isEmpty {
                    tagButton
                }
                
                Button(action: copyAndClear) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20))
                }
                .tint(primaryColor)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
            } else {
                // 默认模式：发送和标签在左，删除按钮在右
                Button(action: copyAndClear) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20))
                }
                .tint(primaryColor)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
                
                // 标签选择按钮
                if !tagManager.tags.isEmpty {
                    tagButton
                }
                
                // Workflow 配置按钮
                Button(action: { showWorkflowConfig = true }) {
                    if isProcessingWorkflow {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 18))
                    }
                }
                .tint(
                    isProcessingWorkflow
                        ? primaryColor
                        : (workflowManager.areTerminalNodesAllDisabled ? warningColor : .primary)
                )
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
                
                Spacer()
                
                Button(action: clearText) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                }
                .tint(.primary)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var tagButton: some View {
        Button(action: { showTagSelector = true }) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 18))
                
                if !selectedTags.isEmpty {
                    let fontSize: CGFloat = selectedTags.count == 1 ? 13 : 11
                    
                    VStack(alignment: .leading, spacing: 1) {
                        if let first = selectedTags.first {
                            Text(first)
                                .font(.system(size: fontSize, weight: .medium))
                                .lineLimit(1)
                        }
                        if selectedTags.count >= 2 {
                            HStack(spacing: 3) {
                                Text(selectedTags[1])
                                    .font(.system(size: fontSize, weight: .medium))
                                    .lineLimit(1)
                                if selectedTags.count > 2 {
                                    Text("+\(selectedTags.count - 2)")
                                        .font(.system(size: fontSize - 1, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 20)
        }
        .tint(selectedTags.isEmpty ? .primary : primaryColor)
        .padding(.horizontal, selectedTags.isEmpty ? 14 : 16)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
    
    private var fullScreenEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 正文输入区
            ZStack(alignment: .topLeading) {
                if draftText.isEmpty {
                    Text("开始输入...")
                        .font(.system(size: 17))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                
                DraftTextView(
                    text: Binding(
                        get: { draftText },
                        set: { historyManager.updateDraftText($0) }
                    ),
                    isFocused: $isTextEditorFocused,
                    isScrollEnabled: !draftText.isEmpty,
                    isUserInteractionEnabled: !isKeyboardAnimating,
                    font: UIFont.systemFont(ofSize: 17, weight: .regular)
                )
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity)
        }
    }
    

    
    /// 安全地调度键盘弹出任务，使用 DispatchWorkItem 实现可取消的延迟任务
    private func scheduleKeyboardShow(delay: Double) {
        Self.keyboardWorkItem?.cancel()
        
        // 动画期间禁用编辑框点击
        isKeyboardAnimating = true
        
        let workItem = DispatchWorkItem { [self] in
            guard !showHistory else {
                isKeyboardAnimating = false
                return
            }
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
            
            // 键盘动画完成后恢复编辑框交互（iOS 键盘动画约 0.25-0.3 秒）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [self] in
                isKeyboardAnimating = false
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
            historyManager.updateDraftText("")
        }
    }
    
    private func copyAndClear() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        guard !draftText.isEmpty else { return }
        
        // 检测是否是调试模式触发命令
        if draftText.hasPrefix("打开调试模式") {
            historyManager.updateDraftText("")
            showDebugView = true
            return
        }
        
        // 执行 Workflow
        executeWorkflow()
    }
    
    private func executeWorkflow() {
        // 延迟显示 loading 态，0.1 秒内返回则不显示
        let showLoadingTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            if !Task.isCancelled {
                await MainActor.run {
                    isProcessingWorkflow = true
                }
            }
        }
        
        Task {
            do {
                let result = try await workflowManager.execute(
                    input: draftText,
                    tags: selectedTags
                )
                
                showLoadingTask.cancel()
                
                await MainActor.run {
                    isProcessingWorkflow = false
                    
                    if result.shouldSave {
                        if result.skipConfirmation {
                            performSave(text: result.finalText)
                        } else {
                            workflowResult = result
                        }
                    } else {
                        if result.didCopyToClipboard {
                            historyManager.updateDraftText("")
                        } else {
                            historyManager.updateDraftText(result.finalText)
                        }
                    }
                }
            } catch {
                showLoadingTask.cancel()
                
                await MainActor.run {
                    isProcessingWorkflow = false
                    workflowError = error
                }
            }
        }
    }
    
    private func performSave(text: String) {
        // 更新草稿文本为处理后的结果
        historyManager.updateDraftText(text)
        // 调用原有的保存逻辑
        historyManager.finalizeDraft()
    }
}

struct DraftTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let isScrollEnabled: Bool
    let isUserInteractionEnabled: Bool
    let font: UIFont
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = font
        textView.text = text
        textView.isScrollEnabled = isScrollEnabled
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font
        uiView.isScrollEnabled = isScrollEnabled
        uiView.isUserInteractionEnabled = isUserInteractionEnabled
        
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        
        if context.coordinator.lastText != text {
            let wasNonEmpty = !context.coordinator.lastText.isEmpty
            let isNowEmpty = text.isEmpty
            context.coordinator.lastText = text
            
            if wasNonEmpty && isNowEmpty {
                uiView.setContentOffset(.zero, animated: false)
                uiView.selectedRange = NSRange(location: 0, length: 0)
                uiView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DraftTextView
        var lastText: String
        
        init(_ parent: DraftTextView) {
            self.parent = parent
            self.lastText = parent.text
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused {
                parent.isFocused = false
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
