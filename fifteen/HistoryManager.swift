//
//  HistoryManager.swift
//  fifteen
//
//  Created by zengkai on 2026/1/12.
//

import Foundation
import SwiftUI

// MARK: - History Item

struct HistoryItem: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let text: String
    let createdAt: Date
    var description: String
    var tags: [String]
    
    init(id: UUID = UUID(), fileName: String, text: String, createdAt: Date = Date(), description: String = "", tags: [String] = []) {
        self.id = id
        self.fileName = fileName
        self.text = text
        self.createdAt = createdAt
        self.description = description.isEmpty ? String(text.prefix(50)) : description
        self.tags = tags
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

// MARK: - Tag Manager (从记录中动态聚合标签)

@Observable
class TagManager {
    static let shared = TagManager()
    
    var tags: [String] = []
    
    private init() {}
    
    func refreshTags(from items: [HistoryItem]) {
        var uniqueTags = Set<String>()
        for item in items {
            for tag in item.tags {
                uniqueTags.insert(tag)
            }
        }
        tags = Array(uniqueTags).sorted()
    }
    
    func getTag(by name: String) -> String? {
        tags.first { $0 == name }
    }
}

// MARK: - History Manager

@Observable
class HistoryManager {
    static let shared = HistoryManager()
    
    var items: [HistoryItem] = []
    var isLoading = false
    
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm-ss"
        return formatter
    }()
    
    private init() {
        loadItems()
    }
    
    // MARK: - Storage Directory (iCloud 优先，本地回退)
    
    private var storageURL: URL {
        // 优先尝试 iCloud
        if let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = containerURL.appendingPathComponent("Documents")
            
            // 确保目录存在
            if !fileManager.fileExists(atPath: documentsURL.path) {
                try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            }
            
            print("Using iCloud storage: \(documentsURL.path)")
            return documentsURL
        }
        
        // 回退到本地存储
        let localURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Records")
        
        if !fileManager.fileExists(atPath: localURL.path) {
            try? fileManager.createDirectory(at: localURL, withIntermediateDirectories: true)
        }
        
        print("Using local storage: \(localURL.path)")
        return localURL
    }
    
    // MARK: - File Name Generation
    
    private func generateFileName(for date: Date) -> String {
        return dateFormatter.string(from: date) + ".md"
    }
    
    private func parseDate(from fileName: String) -> Date? {
        let name = fileName.replacingOccurrences(of: ".md", with: "")
        return dateFormatter.date(from: name)
    }
    
    // MARK: - Markdown Parsing & Generation
    
    private func parseMarkdownFile(content: String) -> (description: String, tags: [String], body: String)? {
        let lines = content.components(separatedBy: "\n")
        
        guard lines.first == "---" else {
            // 没有 front matter，整个内容就是 body
            return ("", [], content)
        }
        
        // 查找结束的 ---
        var endIndex = -1
        for i in 1..<lines.count {
            if lines[i] == "---" {
                endIndex = i
                break
            }
        }
        
        guard endIndex > 0 else {
            return ("", [], content)
        }
        
        // 解析 front matter
        let frontMatterLines = Array(lines[1..<endIndex])
        var description = ""
        var tags: [String] = []
        var inTags = false
        
        for line in frontMatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("description:") {
                let value = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
                description = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if trimmed.hasPrefix("tags:") {
                inTags = true
            } else if inTags && trimmed.hasPrefix("- ") {
                let tagValue = trimmed.replacingOccurrences(of: "- ", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !tagValue.isEmpty {
                    tags.append(tagValue)
                }
            } else if !trimmed.hasPrefix("-") && trimmed.contains(":") {
                inTags = false
            }
        }
        
        // 获取 body（跳过 front matter 后的空行）
        var bodyStartIndex = endIndex + 1
        while bodyStartIndex < lines.count && lines[bodyStartIndex].trimmingCharacters(in: .whitespaces).isEmpty {
            bodyStartIndex += 1
        }
        
        let body = lines[bodyStartIndex...].joined(separator: "\n")
        
        return (description, tags, body)
    }
    
    private func generateMarkdownContent(text: String, description: String, tags: [String], createdAt: Date) -> String {
        var content = "---\n"
        content += "created: \(dateFormatter.string(from: createdAt))\n"
        content += "description: \"\(description)\"\n"
        
        if !tags.isEmpty {
            content += "tags:\n"
            for tag in tags {
                content += "  - \"\(tag)\"\n"
            }
        }
        
        content += "---\n\n"
        content += text
        
        return content
    }
    
    // MARK: - Record Management
    
    func addRecord(_ text: String, tags: [String] = []) {
        guard !text.isEmpty else { return }
        let documentsURL = storageURL
        
        // 避免重复添加相同内容
        if let existingItem = items.first(where: { $0.text == text }) {
            deleteRecord(existingItem)
        }
        
        let now = Date()
        let fileName = generateFileName(for: now)
        let description = String(text.prefix(50))
        let content = generateMarkdownContent(text: text, description: description, tags: tags, createdAt: now)
        
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            let newItem = HistoryItem(
                fileName: fileName,
                text: text,
                createdAt: now,
                description: description,
                tags: tags
            )
            items.insert(newItem, at: 0)
            TagManager.shared.refreshTags(from: items)
            
        } catch {
            print("Failed to write record to iCloud: \(error)")
        }
    }
    
    func deleteRecord(_ item: HistoryItem) {
        let documentsURL = storageURL
        
        let fileURL = documentsURL.appendingPathComponent(item.fileName)
        
        do {
            try fileManager.removeItem(at: fileURL)
            items.removeAll { $0.id == item.id }
            TagManager.shared.refreshTags(from: items)
        } catch {
            print("Failed to delete record: \(error)")
            // 即使文件删除失败，也从内存中移除
            items.removeAll { $0.id == item.id }
        }
    }
    
    func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            let documentsURL = storageURL
            
            let fileURL = documentsURL.appendingPathComponent(item.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        items.remove(atOffsets: offsets)
        TagManager.shared.refreshTags(from: items)
    }
    
    func clearAll() {
        let documentsURL = storageURL
        
        for item in items {
            let fileURL = documentsURL.appendingPathComponent(item.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        items.removeAll()
        TagManager.shared.refreshTags(from: items)
    }
    
    // MARK: - Tag Management
    
    func addTag(to itemId: UUID, tagName: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        let trimmedTag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        
        if !items[index].tags.contains(trimmedTag) {
            items[index].tags.append(trimmedTag)
            saveItem(items[index])
            TagManager.shared.refreshTags(from: items)
        }
    }
    
    func removeTag(from itemId: UUID, tagName: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        items[index].tags.removeAll { $0 == tagName }
        saveItem(items[index])
        TagManager.shared.refreshTags(from: items)
    }
    
    func toggleTag(for itemId: UUID, tagName: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        if items[index].tags.contains(tagName) {
            items[index].tags.removeAll { $0 == tagName }
        } else {
            items[index].tags.append(tagName)
        }
        saveItem(items[index])
        TagManager.shared.refreshTags(from: items)
    }
    
    func getItems(filteredBy tagName: String?) -> [HistoryItem] {
        guard let tagName = tagName else { return items }
        return items.filter { $0.tags.contains(tagName) }
    }
    
    // MARK: - Save Item
    
    private func saveItem(_ item: HistoryItem) {
        let documentsURL = storageURL
        
        let content = generateMarkdownContent(
            text: item.text,
            description: item.description,
            tags: item.tags,
            createdAt: item.createdAt
        )
        
        let fileURL = documentsURL.appendingPathComponent(item.fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to update record: \(error)")
        }
    }
    
    // MARK: - Load Items
    
    func loadItems() {
        let documentsURL = storageURL
        
        isLoading = true
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            var loadedItems: [HistoryItem] = []
            
            for fileURL in fileURLs {
                guard fileURL.pathExtension == "md" else { continue }
                
                let fileName = fileURL.lastPathComponent
                guard let createdAt = parseDate(from: fileName) else { continue }
                
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    
                    if let parsed = parseMarkdownFile(content: content) {
                        let item = HistoryItem(
                            fileName: fileName,
                            text: parsed.body,
                            createdAt: createdAt,
                            description: parsed.description,
                            tags: parsed.tags
                        )
                        loadedItems.append(item)
                    }
                } catch {
                    print("Failed to read file \(fileName): \(error)")
                }
            }
            
            // 按创建时间降序排序
            items = loadedItems.sorted { $0.createdAt > $1.createdAt }
            TagManager.shared.refreshTags(from: items)
            
        } catch {
            print("Failed to list iCloud documents: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Refresh (for pull-to-refresh)
    
    func refresh() {
        loadItems()
    }
    
    // MARK: - Export All Notes
    
    func exportAllNotes() throws -> URL {
        let documentsURL = storageURL
        
        // 创建临时目录
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("NotesExport_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 复制所有 md 文件到临时目录
        let fileURLs = try fileManager.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        for fileURL in fileURLs {
            guard fileURL.pathExtension == "md" else { continue }
            let destURL = tempDir.appendingPathComponent(fileURL.lastPathComponent)
            try fileManager.copyItem(at: fileURL, to: destURL)
        }
        
        // 创建 zip 文件
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let zipName = "Notes_\(dateFormatter.string(from: Date())).zip"
        let zipURL = fileManager.temporaryDirectory.appendingPathComponent(zipName)
        
        // 删除可能存在的旧文件
        try? fileManager.removeItem(at: zipURL)
        
        // 使用 FileManager 的 zipItem 方法创建 zip
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &error) { zippedURL in
            try? fileManager.copyItem(at: zippedURL, to: zipURL)
        }
        
        // 清理临时目录
        try? fileManager.removeItem(at: tempDir)
        
        if let error = error {
            throw error
        }
        
        return zipURL
    }
}
