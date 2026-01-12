//
//  HistoryManager.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import Foundation
import SwiftUI

// MARK: - Tag Model

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let colorHex: UInt
    let emoji: String
    
    init(id: UUID = UUID(), name: String, colorHex: UInt, emoji: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.emoji = emoji
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Preset Tags

struct PresetTags {
    static let important = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "重要",
        colorHex: 0xFF3B30,
        emoji: "🔴"
    )
    static let pending = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "待处理",
        colorHex: 0xFFCC00,
        emoji: "🟡"
    )
    static let completed = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "已完成",
        colorHex: 0x34C759,
        emoji: "🟢"
    )
    static let work = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "工作",
        colorHex: 0x007AFF,
        emoji: "🔵"
    )
    static let personal = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "个人",
        colorHex: 0xAF52DE,
        emoji: "🟣"
    )
    
    static let all: [Tag] = [important, pending, completed, work, personal]
}

// MARK: - History Item

struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var tagIds: [UUID]
    
    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), tagIds: [UUID] = []) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.tagIds = tagIds
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
    
    var tags: [Tag] {
        tagIds.compactMap { tagId in
            PresetTags.all.first { $0.id == tagId }
        }
    }
}

// MARK: - History Manager

@Observable
class HistoryManager {
    static let shared = HistoryManager()
    
    private let storageKey = "clipboard_history"
    private let maxItems = 100
    
    var items: [HistoryItem] = []
    
    private init() {
        loadItems()
    }
    
    // MARK: - Record Management
    
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
    
    // MARK: - Tag Management
    
    func addTag(to itemId: UUID, tagId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        if !items[index].tagIds.contains(tagId) {
            items[index].tagIds.append(tagId)
            saveItems()
        }
    }
    
    func removeTag(from itemId: UUID, tagId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        items[index].tagIds.removeAll { $0 == tagId }
        saveItems()
    }
    
    func toggleTag(for itemId: UUID, tagId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        if items[index].tagIds.contains(tagId) {
            items[index].tagIds.removeAll { $0 == tagId }
        } else {
            items[index].tagIds.append(tagId)
        }
        saveItems()
    }
    
    func getItems(filteredBy tagId: UUID?) -> [HistoryItem] {
        guard let tagId = tagId else { return items }
        return items.filter { $0.tagIds.contains(tagId) }
    }
    
    // MARK: - Persistence
    
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
