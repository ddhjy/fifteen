import SwiftUI

@MainActor
@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    private let aiApiTokenKey = "aiApiToken"
    
    var aiApiToken: String? {
        didSet {
            if let token = aiApiToken {
                KeychainHelper.saveString(token, forKey: aiApiTokenKey)
            } else {
                KeychainHelper.delete(forKey: aiApiTokenKey)
            }
        }
    }
    
    private init() {
        if let legacyToken = UserDefaults.standard.string(forKey: aiApiTokenKey) {
            KeychainHelper.saveString(legacyToken, forKey: aiApiTokenKey)
            UserDefaults.standard.removeObject(forKey: aiApiTokenKey)
        }
        self.aiApiToken = KeychainHelper.loadString(forKey: aiApiTokenKey)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsManager = SettingsManager.shared
    
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    SecureField("API Token", text: Binding(
                        get: { settingsManager.aiApiToken ?? "" },
                        set: { settingsManager.aiApiToken = $0.isEmpty ? nil : $0 }
                    ))
                } header: {
                    Text("AI 配置")
                } footer: {
                    Text("填写后可在 Workflow 中使用 AI 能力")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
