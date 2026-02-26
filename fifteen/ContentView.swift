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
    
    @State private var isKeyboardAnimating: Bool = false
    
    private static var keyboardWorkItem: DispatchWorkItem?
    
    private static var isFirstLaunch: Bool = true
    
    private let primaryColor = Color(hex: 0x6366F1)
    private let warningColor = Color.yellow
    
    private var draftText: String {
        historyManager.currentDraft.text
    }
    
    private var selectedTags: [String] {
        historyManager.currentDraft.tags
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
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
            .safeAreaInset(edge: .bottom) {
                bottomToolbar
            }
            .sheet(isPresented: $showTagSelector) {
                TagPickerView(itemId: historyManager.currentDraft.id, reselectMode: true)
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
                Self.isFirstLaunch = false
                isTextEditorFocused = true
            } else {
                scheduleKeyboardShow(delay: 0.5)
            }
        }
        .onChange(of: showHistory) { _, isShowing in
            if isShowing {
                Self.keyboardWorkItem?.cancel()
                Self.keyboardWorkItem = nil
                isTextEditorFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } else {
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
                Button(action: clearText) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                }
                .tint(.primary)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
                
                Spacer()
                
                if !tagManager.tags.isEmpty {
                    tagButton
                }

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
                
                Button(action: copyAndClear) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                }
                .tint(primaryColor)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
            } else {
                Button(action: copyAndClear) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                }
                .tint(primaryColor)
                .padding(14)
                .glassEffect(.regular.interactive(), in: Circle())
                
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

                if !tagManager.tags.isEmpty {
                    tagButton
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
        .tint(.primary)
        .padding(.horizontal, selectedTags.isEmpty ? 14 : 16)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
    
    private var fullScreenEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    
    private func scheduleKeyboardShow(delay: Double) {
        Self.keyboardWorkItem?.cancel()
        
        isKeyboardAnimating = true
        
        let workItem = DispatchWorkItem { [self] in
            guard !showHistory else {
                isKeyboardAnimating = false
                return
            }
            isTextEditorFocused = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                guard !showHistory, !isTextEditorFocused else { return }
                isTextEditorFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                guard !showHistory, !isTextEditorFocused else { return }
                isTextEditorFocused = true
            }
            
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
        
        if draftText.hasPrefix("打开调试模式") {
            historyManager.updateDraftText("")
            showDebugView = true
            return
        }
        
        executeWorkflow()
    }
    
    private func executeWorkflow() {
        isProcessingWorkflow = true
        let startTime = Date()
        let minimumLoadingDuration: TimeInterval = 0.2

        let waitMinimumDurationIfNeeded: () async -> Void = {
            let elapsed = Date().timeIntervalSince(startTime)
            guard elapsed < minimumLoadingDuration else { return }
            let remaining = minimumLoadingDuration - elapsed
            guard remaining > 0 else { return }
            let nanoseconds = UInt64((remaining * 1_000_000_000).rounded(.up))
            try? await Task.sleep(nanoseconds: nanoseconds)
        }

        Task {
            do {
                let result = try await workflowManager.execute(
                    input: draftText,
                    tags: selectedTags
                )

                await waitMinimumDurationIfNeeded()

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
                await waitMinimumDurationIfNeeded()

                await MainActor.run {
                    isProcessingWorkflow = false
                    workflowError = error
                }
            }
        }
    }
    
    private func performSave(text: String) {
        historyManager.updateDraftText(text)
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
