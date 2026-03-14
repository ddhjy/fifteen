import SwiftUI

struct ContentView: View {
    @State private var showHistory: Bool = false
    @State private var showTagSelector: Bool = false
    @State private var showDebugView: Bool = false
    @State private var historyManager = HistoryManager.shared
    @State private var tagManager = TagManager.shared
    
    @State private var showSettings: Bool = false

    @State private var isTextEditorFocused: Bool = false
    
    @State private var showWorkflowConfig = false
    @State private var workflowManager = WorkflowManager.shared
    @State private var processingWorkflowId: UUID? = nil
    @State private var workflowError: Error? = nil
    
    @State private var isKeyboardAnimating: Bool = false
    
    @State private var keyboardTask: Task<Void, Never>?
    
    @State private var hasLaunched = false
    
    @State private var showWorkflowError = false
    @State private var hapticTrigger = 0
    
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
                    Button("记录", systemImage: "rectangle.stack", action: navigateToHistory)
                        .labelStyle(.iconOnly)
                        .tint(.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("设置", systemImage: "ellipsis") { showSettings = true }
                        .labelStyle(.iconOnly)
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
            .alert("Workflow 执行出错", isPresented: $showWorkflowError) {
                Button("确定") { workflowError = nil }
            } message: {
                Text(workflowError?.localizedDescription ?? "出了点问题，请稍后再试")
            }

        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .onAppear {
            historyManager.loadItemsIfNeeded()
            if !hasLaunched {
                hasLaunched = true
                isTextEditorFocused = true
            } else {
                scheduleKeyboardShow(delay: 0.5)
            }
        }
        .onChange(of: showHistory) { _, isShowing in
            if isShowing {
                keyboardTask?.cancel()
                keyboardTask = nil
                isKeyboardAnimating = false
            } else {
                scheduleKeyboardShow(delay: 0.5)
            }
        }
        .onChange(of: isTextEditorFocused) { _, isFocused in
            UIApplication.shared.isIdleTimerDisabled = isFocused
        }
    }
    
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                workflowControlGroup

                if !tagManager.tags.isEmpty {
                    tagButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            
            Button("清除", systemImage: "trash", action: clearText)
                .labelStyle(.iconOnly)
                .tint(.primary)
            .padding(14)
            .glassEffect(.regular.interactive(), in: Circle())
            .disabled(processingWorkflowId != nil)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 8)
    }
    
    private var workflowControlGroup: some View {
        HStack(spacing: 4) {
            workflowSettingsButton
            
            ForEach(workflowManager.openWorkflows) { workflow in
                workflowButton(for: workflow)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 46)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    @ViewBuilder
    private var tagButton: some View {
        if selectedTags.isEmpty {
            Button(action: { showTagSelector = true }) {
                Image(systemName: "tag")
                    .font(.system(size: 18))
                    .frame(width: 20, height: 20)
            }
            .tint(.primary)
            .padding(14)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("标签")
            .disabled(processingWorkflowId != nil)
        } else {
            Button(action: { showTagSelector = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.system(size: 18))
                    
                    let tagFont: Font = selectedTags.count == 1 ? .footnote : .caption
                    
                    VStack(alignment: .leading, spacing: 1) {
                        if let first = selectedTags.first {
                            Text(first)
                                .font(tagFont)
                                .lineLimit(1)
                        }
                        if selectedTags.count >= 2 {
                            HStack(spacing: 3) {
                                Text(selectedTags[1])
                                    .font(tagFont)
                                    .lineLimit(1)
                                if selectedTags.count > 2 {
                                    Text("+\(selectedTags.count - 2)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(height: 20)
            }
            .tint(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: Capsule())
            .accessibilityLabel("标签")
            .disabled(processingWorkflowId != nil)
        }
    }
    
    private var workflowSettingsButton: some View {
        Button {
            showWorkflowConfig = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 20, height: 20)
        }
        .tint(.primary)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel("工作流设置")
        .disabled(processingWorkflowId != nil)
    }
    
    private func workflowButton(for workflow: Workflow) -> some View {
        Button {
            handleWorkflowTap(workflow)
        } label: {
            Group {
                if processingWorkflowId == workflow.id {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: workflow.icon)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .frame(width: 20, height: 20)
        }
        .disabled(processingWorkflowId != nil)
        .tint(workflowTintColor(for: workflow))
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel(workflow.name)
    }
    
    private var fullScreenEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if draftText.isEmpty {
                    Text("开始输入...")
                        .font(.body)
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
        keyboardTask?.cancel()
        
        isKeyboardAnimating = true
        
        keyboardTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, !showHistory else {
                isKeyboardAnimating = false
                return
            }
            isTextEditorFocused = true
            
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, !showHistory, !isTextEditorFocused else { return }
            isTextEditorFocused = true
            
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, !showHistory, !isTextEditorFocused else { return }
            isTextEditorFocused = true
            
            try? await Task.sleep(for: .milliseconds(150))
            isKeyboardAnimating = false
        }
    }
    
    private func navigateToHistory() {
        historyManager.loadItemsIfNeeded()
        isTextEditorFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task { @MainActor in
            showHistory = true
        }
    }
    
    private func clearText() {
        hapticTrigger += 1
        withAnimation(.easeOut(duration: 0.25)) {
            historyManager.clearDraft()
        }
    }
    
    private func handleWorkflowTap(_ workflow: Workflow) {
        hapticTrigger += 1
        
        guard !draftText.isEmpty else { return }
        
        if draftText.hasPrefix("打开调试模式") {
            historyManager.clearDraft()
            showDebugView = true
            return
        }
        
        executeWorkflow(workflow)
    }
    
    private func executeWorkflow(_ workflow: Workflow) {
        processingWorkflowId = workflow.id
        let startTime = Date()
        let minimumLoadingDuration: TimeInterval = 0.2

        let waitMinimumDurationIfNeeded: () async -> Void = {
            let elapsed = Date().timeIntervalSince(startTime)
            guard elapsed < minimumLoadingDuration else { return }
            let remaining = minimumLoadingDuration - elapsed
            guard remaining > 0 else { return }
            try? await Task.sleep(for: .seconds(remaining))
        }

        Task {
            do {
                let result = try await workflowManager.execute(
                    workflowID: workflow.id,
                    input: draftText,
                    tags: selectedTags
                )

                await waitMinimumDurationIfNeeded()

                await MainActor.run {
                    processingWorkflowId = nil
                    
                    if result.shouldSave {
                        performSave(text: result.finalText)
                    } else {
                        historyManager.clearDraft()
                    }
                }
            } catch {
                await waitMinimumDurationIfNeeded()

                await MainActor.run {
                    processingWorkflowId = nil
                    workflowError = error
                    showWorkflowError = true
                }
            }
        }
    }
    
    private func workflowTintColor(for workflow: Workflow) -> Color {
        if processingWorkflowId == workflow.id {
            return Design.primaryColor
        }
        
        return workflowManager.areTerminalNodesAllDisabled(for: workflow) ? Color.yellow : .primary
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


#Preview {
    ContentView()
}
