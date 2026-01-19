//
//  SettingsView.swift
//  fifteen
//

import SwiftUI

@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    private let rightHandModeKey = "rightHandMode"
    
    var isRightHandMode: Bool {
        didSet {
            UserDefaults.standard.set(isRightHandMode, forKey: rightHandModeKey)
        }
    }
    
    private init() {
        self.isRightHandMode = UserDefaults.standard.bool(forKey: rightHandModeKey)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsManager = SettingsManager.shared
    
    // 假设项目中已定义类似 Color(hex:) 的扩展，或者我们可以直接使用系统颜色
    // 如果没有 hex 扩展，这里可以使用 Color.indigo 替代
    private let primaryColor = Color(red: 99/255, green: 102/255, blue: 241/255) // #6366F1
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $settingsManager.isRightHandMode) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.point.right")
                                .font(.system(size: 20))
                                .foregroundStyle(primaryColor)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("右手模式")
                                    .font(.system(size: 16, weight: .regular))
                                
                                Text("将发送按钮移至右侧")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(primaryColor)
                } header: {
                    Text("布局")
                } footer: {
                    Text("开启后，底部工具栏的按钮排列将左右反转，方便右手操作。")
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
                    .tint(primaryColor)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
