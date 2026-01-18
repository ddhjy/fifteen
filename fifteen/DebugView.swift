import SwiftUI

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("调试功能开关将在此处显示")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("调试模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DebugView()
}
