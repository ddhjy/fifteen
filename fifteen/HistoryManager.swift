//
//  HistoryManager.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import Foundation
import SwiftUI

struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    
    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
    
    var preview: String {
        if text.count <= 50 {
            return text
        }
        return String(text.prefix(50)) + "..."
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

@Observable
class HistoryManager {
    static let shared = HistoryManager()
    
    private let storageKey = "clipboard_history"
    private let maxItems = 100
    
    var items: [HistoryItem] = []
    
    private init() {
        loadItems()
    }
    
    func addRecord(_ text: String) {
        guard !text.isEmpty else { return }
        
        // 避免重复添加相同内容
        if let existingIndex = items.firstIndex(where: { $0.text == text }) {
            items.remove(at: existingIndex)
        }
        
        let newItem = HistoryItem(text: text)
        items.insert(newItem, at: 0)
        
        // 限制最大条数
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        
        saveItems()
    }
    
    func deleteRecord(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func deleteRecords(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveItems()
    }
    
    func clearAll() {
        items.removeAll()
        saveItems()
    }
    
    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("Failed to decode history items: \(error)")
        }
    }
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode history items: \(error)")
        }
    }
}
