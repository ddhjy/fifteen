import SwiftUI

struct WorkflowPreviewView: View {
    let result: WorkflowExecutionResult
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let primaryColor = Color(hex: 0x6366F1)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(result.finalText)
                        .font(.system(size: 16))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .padding()
            }
            .navigationTitle("处理结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(primaryColor)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = result.finalText
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.bar)
            }
        }
    }
}
