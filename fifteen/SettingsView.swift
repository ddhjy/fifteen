import SwiftUI

@MainActor
@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    private let aiApiTokenKey = "aiApiToken"
    private let autoPasteSyncEnabledKey = "autoPasteSyncEnabled"
    private let autoPasteHostKey = "autoPasteHost"
    private let autoPastePortKey = "autoPastePort"
    
    var aiApiToken: String? {
        didSet {
            if let token = aiApiToken {
                KeychainHelper.saveString(token, forKey: aiApiTokenKey)
            } else {
                KeychainHelper.delete(forKey: aiApiTokenKey)
            }
        }
    }

    var autoPasteSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoPasteSyncEnabled, forKey: autoPasteSyncEnabledKey)
            notifyAutoPasteSyncSettingsChanged()
        }
    }

    var autoPasteHost: String {
        didSet {
            UserDefaults.standard.set(autoPasteHost, forKey: autoPasteHostKey)
            notifyAutoPasteSyncSettingsChanged()
        }
    }

    var autoPastePort: Int {
        didSet {
            let normalizedPort = Self.normalizedPort(autoPastePort)
            if autoPastePort != normalizedPort {
                autoPastePort = normalizedPort
                return
            }
            UserDefaults.standard.set(normalizedPort, forKey: autoPastePortKey)
            notifyAutoPasteSyncSettingsChanged()
        }
    }
    
    private init() {
        if let legacyToken = UserDefaults.standard.string(forKey: aiApiTokenKey) {
            KeychainHelper.saveString(legacyToken, forKey: aiApiTokenKey)
            UserDefaults.standard.removeObject(forKey: aiApiTokenKey)
        }
        self.aiApiToken = KeychainHelper.loadString(forKey: aiApiTokenKey)
        self.autoPasteSyncEnabled = UserDefaults.standard.bool(forKey: autoPasteSyncEnabledKey)
        self.autoPasteHost = UserDefaults.standard.string(forKey: autoPasteHostKey) ?? ""

        let savedPort = UserDefaults.standard.integer(forKey: autoPastePortKey)
        self.autoPastePort = savedPort == 0 ? 7788 : Self.normalizedPort(savedPort)
    }

    private func notifyAutoPasteSyncSettingsChanged() {
        Task { @MainActor in
            AutoPasteSyncManager.shared.settingsDidChange()
        }
    }

    private static func normalizedPort(_ value: Int) -> Int {
        min(max(value, 1), 65535)
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

                Section {
                    Toggle(isOn: $settingsManager.autoPasteSyncEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "wave.3.right")
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("实时同步到 AutoPaste")
                                    .font(.callout)

                                Text("输入时自动同步到局域网内的 Mac")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(Design.primaryColor)

                    TextField("AutoPaste 主机地址", text: $settingsManager.autoPasteHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("AutoPaste 端口", value: $settingsManager.autoPastePort, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text("AutoPaste Sync")
                } footer: {
                    Text("填写 Mac 的局域网 IP，默认端口 7788")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.callout.bold())
                    .tint(.primary)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
