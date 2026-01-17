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
    var fileName: String      // var: 草稿保存时需要更新文件名
    var text: String          // var: 编辑时需要更新
    let createdAt: Date
    var description: String
    var tags: [String]
    var isDraft: Bool         // 标记是否为草稿
    
    init(id: UUID = UUID(), fileName: String = "", text: String = "", createdAt: Date = Date(), description: String = "", tags: [String] = [], isDraft: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.text = text
        self.createdAt = createdAt
        self.description = description.isEmpty && !text.isEmpty ? String(text.prefix(50)) : description
        self.tags = tags
        self.isDraft = isDraft
    }
    
    var preview: String {
        if text.count <= 200 {
            return text
        }
        return String(text.prefix(200)) + "..."
    }
    
    // 静态 DateFormatter 缓存，避免重复创建
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    var formattedDate: String {
        Self.relativeDateFormatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Tag Manager (从记录中动态聚合标签)

@Observable
class TagManager {
    static let shared = TagManager()
    
    var tags: [String] = []
    
    /// 上次选择的标签（用于新草稿默认标签）
    private(set) var lastSelectedTags: [String] = []
    
    private let tagOrderKey = "tagOrderData"
    private let lastSelectedTagsKey = "lastSelectedTags"
    
    private init() {
        loadTagOrder()
        loadLastSelectedTags()
    }
    
    func refreshTags(from items: [HistoryItem]) {
        var uniqueTags = Set<String>()
        for item in items {
            for tag in item.tags {
                uniqueTags.insert(tag)
            }
        }
        
        // 读取保存的顺序
        let savedOrder = loadTagOrder()
        
        // 按保存的顺序排列，新标签追加到末尾
        var orderedTags: [String] = []
        for tagName in savedOrder {
            if uniqueTags.contains(tagName) {
                orderedTags.append(tagName)
                uniqueTags.remove(tagName)
            }
        }
        // 追加新标签（按字母排序）
        orderedTags.append(contentsOf: uniqueTags.sorted())
        
        tags = orderedTags
    }
    
    func getTag(by name: String) -> String? {
        tags.first { $0 == name }
    }
    
    // MARK: - Tag Order Persistence
    
    @discardableResult
    private func loadTagOrder() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: tagOrderKey),
              let order = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return order
    }
    
    private func saveTagOrder() {
        if let data = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(data, forKey: tagOrderKey)
        }
    }
    
    // MARK: - Last Selected Tags
    
    private func loadLastSelectedTags() {
        guard let data = UserDefaults.standard.data(forKey: lastSelectedTagsKey),
              let savedTags = try? JSONDecoder().decode([String].self, from: data) else {
            lastSelectedTags = []
            return
        }
        lastSelectedTags = savedTags
    }
    
    func saveLastSelectedTags(_ tags: [String]) {
        lastSelectedTags = tags
        if let data = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(data, forKey: lastSelectedTagsKey)
        }
    }
    
    // MARK: - Reorder Tags
    
    func moveTag(from source: IndexSet, to destination: Int) {
        tags.move(fromOffsets: source, toOffset: destination)
        saveTagOrder()
    }
}

// MARK: - History Manager

@Observable
class HistoryManager {
    static let shared = HistoryManager()
    
    var items: [HistoryItem] = []
    var isLoading = false
    
    // 缓存存储目录，避免重复检查 iCloud 和目录存在性
    private var _cachedStorageURL: URL?
    
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm-ss"
        return formatter
    }()
    
    private init() {
        loadItems()
        ensureDraftExists()
    }
    
    // MARK: - Draft Management
    
    private let draftFileName = "_draft.md"
    
    /// 当前草稿（始终存在唯一一个）
    var currentDraft: HistoryItem {
        if let draft = items.first(where: { $0.isDraft }) {
            return draft
        }
        // 理论上不应该到这里，因为 ensureDraftExists 会确保存在
        let newDraft = createNewDraft()
        items.insert(newDraft, at: 0)
        return newDraft
    }
    
    /// 确保草稿存在
    private func ensureDraftExists() {
        if !items.contains(where: { $0.isDraft }) {
            let newDraft = createNewDraft()
            items.insert(newDraft, at: 0)
        }
    }
    
    /// 创建新的空草稿（使用上次选择的标签作为默认值）
    private func createNewDraft() -> HistoryItem {
        return HistoryItem(tags: TagManager.shared.lastSelectedTags, isDraft: true)
    }
    
    /// 更新草稿文本内容
    func updateDraftText(_ text: String) {
        guard let index = items.firstIndex(where: { $0.isDraft }) else { return }
        items[index].text = text
        saveDraft()
    }
    
    /// 完成草稿（发送按钮行为）
    func finalizeDraft() {
        guard let draftIndex = items.firstIndex(where: { $0.isDraft }),
              !items[draftIndex].text.isEmpty else { return }
        
        let draft = items[draftIndex]
        
        // 保存当前选择的标签，用于下次创建草稿时作为默认值
        TagManager.shared.saveLastSelectedTags(draft.tags)
        
        // 生成正式文件名并保存
        let now = Date()
        let fileName = generateFileName(for: now)
        let finalItem = HistoryItem(
            id: draft.id,
            fileName: fileName,
            text: draft.text,
            createdAt: now,
            description: String(draft.text.prefix(50)),
            tags: draft.tags,
            isDraft: false
        )
        
        // 替换草稿为正式记录
        items[draftIndex] = finalItem
        saveItem(finalItem)
        
        // 删除草稿文件
        deleteDraftFile()
        
        // 创建新草稿并插入到最前面（会自动使用上次选择的标签）
        let newDraft = createNewDraft()
        items.insert(newDraft, at: 0)
        
        TagManager.shared.refreshTags(from: savedItems)
    }
    
    /// 获取已保存的记录（排除草稿）
    var savedItems: [HistoryItem] {
        items.filter { !$0.isDraft }
    }
    
    /// 获取已保存的记录（带标签筛选）
    func getSavedItems(filteredBy tagName: String?) -> [HistoryItem] {
        var result = savedItems
        if let tagName = tagName {
            result = result.filter { $0.tags.contains(tagName) }
        }
        return result
    }
    
    /// 获取已保存的记录（带多标签交集筛选）
    func getSavedItems(filteredBy tags: [String]) -> [HistoryItem] {
        guard !tags.isEmpty else { return savedItems }
        return savedItems.filter { item in
            // 记录必须包含所有选中的标签
            tags.allSatisfy { item.tags.contains($0) }
        }
    }
    
    /// 保存草稿到磁盘
    private func saveDraft() {
        guard let draft = items.first(where: { $0.isDraft }) else { return }
        
        let content = generateMarkdownContent(
            text: draft.text,
            description: String(draft.text.prefix(50)),
            tags: draft.tags,
            createdAt: draft.createdAt
        )
        
        let fileURL = storageURL.appendingPathComponent(draftFileName)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    /// 加载草稿
    private func loadDraft() -> HistoryItem? {
        let fileURL = storageURL.appendingPathComponent(draftFileName)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8),
              let parsed = parseMarkdownFile(content: content) else {
            return nil
        }
        
        return HistoryItem(
            text: parsed.body,
            tags: parsed.tags,
            isDraft: true
        )
    }
    
    /// 删除草稿文件
    private func deleteDraftFile() {
        let fileURL = storageURL.appendingPathComponent(draftFileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Storage Directory (iCloud 优先，本地回退)
    
    private var storageURL: URL {
        // 使用缓存的存储路径，避免重复检查
        if let cached = _cachedStorageURL {
            return cached
        }
        
        let url = resolveStorageURL()
        _cachedStorageURL = url
        return url
    }
    
    /// 解析存储目录（仅在首次调用时执行）
    private func resolveStorageURL() -> URL {
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
        let documentsURL = storageURL  // 仅获取一次
        for index in offsets {
            let item = items[index]
            let fileURL = documentsURL.appendingPathComponent(item.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        items.remove(atOffsets: offsets)
        TagManager.shared.refreshTags(from: items)
    }
    
    /// 批量删除记录（优化版本：一次性删除多条记录）
    func deleteRecords(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        
        let documentsURL = storageURL
        
        // 删除文件
        for item in items where ids.contains(item.id) {
            let fileURL = documentsURL.appendingPathComponent(item.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        
        // 批量从内存移除
        items.removeAll { ids.contains($0.id) }
        
        // 只刷新一次标签
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
            if items[index].isDraft {
                saveDraft()
            } else {
                saveItem(items[index])
            }
            TagManager.shared.refreshTags(from: savedItems)
        }
    }
    
    func removeTag(from itemId: UUID, tagName: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        items[index].tags.removeAll { $0 == tagName }
        if items[index].isDraft {
            saveDraft()
        } else {
            saveItem(items[index])
        }
        TagManager.shared.refreshTags(from: savedItems)
    }
    
    func toggleTag(for itemId: UUID, tagName: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        
        if items[index].tags.contains(tagName) {
            items[index].tags.removeAll { $0 == tagName }
        } else {
            items[index].tags.append(tagName)
        }
        if items[index].isDraft {
            saveDraft()
        } else {
            saveItem(items[index])
        }
        TagManager.shared.refreshTags(from: savedItems)
    }
    
    func getItems(filteredBy tagName: String?) -> [HistoryItem] {
        guard let tagName = tagName else { return items }
        return items.filter { $0.tags.contains(tagName) }
    }
    
    func renameTag(from oldName: String, to newName: String) {
        let trimmedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewName.isEmpty, oldName != trimmedNewName else { return }
        
        // 更新所有包含该标签的 items
        for index in items.indices {
            if let tagIndex = items[index].tags.firstIndex(of: oldName) {
                items[index].tags[tagIndex] = trimmedNewName
                saveItem(items[index])
            }
        }
        
        TagManager.shared.refreshTags(from: items)
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
                
                // 跳过草稿文件，草稿会单独加载
                if fileName == draftFileName { continue }
                
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
            
            // 加载草稿并插入到最前面
            if let draft = loadDraft() {
                items.insert(draft, at: 0)
            }
            
            TagManager.shared.refreshTags(from: savedItems)
            
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
