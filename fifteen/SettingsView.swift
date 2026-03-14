import SwiftUI

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
                UserDefaults.standard.set(token, forKey: aiApiTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: aiApiTokenKey)
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
        self.aiApiToken = UserDefaults.standard.string(forKey: aiApiTokenKey)
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
    
    private let primaryColor = Color(red: 99/255, green: 102/255, blue: 241/255)
    
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
                    Text("用于 Workflow 中的 AI 处理节点")
                }

                Section {
                    Toggle(isOn: $settingsManager.autoPasteSyncEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 20))
                                .foregroundStyle(.primary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("实时同步到 AutoPaste")
                                    .font(.system(size: 16, weight: .regular))

                                Text("把当前草稿实时镜像到同局域网 Mac")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(primaryColor)

                    TextField("AutoPaste 主机地址", text: $settingsManager.autoPasteHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("AutoPaste 端口", text: Binding(
                        get: { String(settingsManager.autoPastePort) },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            settingsManager.autoPastePort = Int(trimmed) ?? 7788
                        }
                    ))
                    .keyboardType(.numberPad)
                } header: {
                    Text("AutoPaste Sync")
                } footer: {
                    Text("填写运行 AutoPaste 的 Mac 局域网 IP 和端口。默认端口为 7788。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .tint(.primary)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
