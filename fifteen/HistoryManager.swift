//
//  HistoryManager.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import Foundation
import SwiftUI

// MARK: - Tag Model (纯文本，支持用户自定义)

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Tag Manager (管理用户自定义标签)

@Observable
class TagManager {
    static let shared = TagManager()
    
    private let storageKey = "user_tags"
    
    var tags: [Tag] = []
    
    private init() {
        loadTags()
    }
    
    func createTag(name: String) -> Tag? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        
        // 检查是否已存在同名标签
        if tags.contains(where: { $0.name == trimmedName }) {
            return nil
        }
        
        let newTag = Tag(name: trimmedName)
        tags.append(newTag)
        saveTags()
        return newTag
    }
    
    func updateTag(_ tagId: UUID, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // 检查是否存在其他同名标签
        if tags.contains(where: { $0.id != tagId && $0.name == trimmedName }) {
            return
        }
        
        if let index = tags.firstIndex(where: { $0.id == tagId }) {
            tags[index].name = trimmedName
            saveTags()
        }
    }
    
    func deleteTag(_ tagId: UUID) {
        tags.removeAll { $0.id == tagId }
        saveTags()
        
        // 同时从所有历史记录中移除该标签
        HistoryManager.shared.removeTagFromAllItems(tagId: tagId)
    }
    
    func getTag(by id: UUID) -> Tag? {
        tags.first { $0.id == id }
    }
    
    private func loadTags() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            tags = try JSONDecoder().decode([Tag].self, from: data)
        } catch {
            print("Failed to decode tags: \(error)")
        }
    }
    
    private func saveTags() {
        do {
            let data = try JSONEncoder().encode(tags)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode tags: \(error)")
        }
    }
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
            TagManager.shared.getTag(by: tagId)
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
    
    func removeTagFromAllItems(tagId: UUID) {
        for index in items.indices {
            items[index].tagIds.removeAll { $0 == tagId }
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

