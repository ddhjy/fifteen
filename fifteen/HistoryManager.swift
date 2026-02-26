import Foundation
import SwiftUI

struct HistoryItem: Identifiable, Equatable {
    let id: UUID
    var fileName: String
    var text: String
    let createdAt: Date
    var description: String
    var tags: [String]
    var isDraft: Bool
    
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
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    var formattedDate: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)
        
        if interval < 3600 {
            return "刚刚"
        }
        
        return Self.relativeDateFormatter.localizedString(for: createdAt, relativeTo: now)
    }
}

@Observable
class TagManager {
    static let shared = TagManager()
    
    var tags: [String] = []
    
    private(set) var tagCounts: [String: Int] = [:]
    
    private(set) var lastSelectedTags: [String] = []
    
    private let lastSelectedTagsKey = "lastSelectedTags"
    private let lastSelectedTagsTimeKey = "lastSelectedTagsTime"
    
    private let tagMemoryExpiration: TimeInterval = 30 * 60
    
    private init() {
        loadLastSelectedTags()
    }
    
    func refreshTags(from items: [HistoryItem]) {
        var uniqueTags = Set<String>()
        var counts: [String: Int] = [:]
        
        for item in items {
            for tag in item.tags {
                uniqueTags.insert(tag)
                counts[tag, default: 0] += 1
            }
        }
        
        tags = Array(uniqueTags)
        tagCounts = counts
    }
    
    func count(for tag: String) -> Int {
        return tagCounts[tag, default: 0]
    }
    
    func getTag(by name: String) -> String? {
        tags.first { $0 == name }
    }
    
    private func loadLastSelectedTags() {
        let savedTime = UserDefaults.standard.double(forKey: lastSelectedTagsTimeKey)
        if savedTime > 0 {
            let elapsed = Date().timeIntervalSince1970 - savedTime
            if elapsed > tagMemoryExpiration {
                lastSelectedTags = []
                return
            }
        }
        
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
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSelectedTagsTimeKey)
        }
    }
}

@Observable
class HistoryManager {
    static let shared = HistoryManager()
    
    var items: [HistoryItem] = []
    var isLoading = false
    
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
    
    private let draftFileName = "_draft.md"
    
    var currentDraft: HistoryItem {
        if let draft = items.first(where: { $0.isDraft }) {
            return draft
        }
        let newDraft = createNewDraft()
        items.insert(newDraft, at: 0)
        return newDraft
    }
    
    private func ensureDraftExists() {
        if !items.contains(where: { $0.isDraft }) {
            let newDraft = createNewDraft()
            items.insert(newDraft, at: 0)
        }
    }
    
    private func createNewDraft() -> HistoryItem {
        return HistoryItem(tags: TagManager.shared.lastSelectedTags, isDraft: true)
    }
    
    func updateDraftText(_ text: String) {
        guard let index = items.firstIndex(where: { $0.isDraft }) else { return }
        items[index].text = text
        saveDraft()
    }
    
    func finalizeDraft() {
        guard let draftIndex = items.firstIndex(where: { $0.isDraft }),
              !items[draftIndex].text.isEmpty else { return }
        
        let draft = items[draftIndex]
        
        TagManager.shared.saveLastSelectedTags(draft.tags)
        
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
        
        items[draftIndex] = finalItem
        saveItem(finalItem)
        
        deleteDraftFile()
        
        let newDraft = createNewDraft()
        items.insert(newDraft, at: 0)
        
        TagManager.shared.refreshTags(from: savedItems)
    }
    
    var savedItems: [HistoryItem] {
        items.filter { !$0.isDraft }
    }
    
    func getSavedItems(filteredBy tagName: String?) -> [HistoryItem] {
        var result = savedItems
        if let tagName = tagName {
            result = result.filter { $0.tags.contains(tagName) }
        }
        return result
    }
    
    func getSavedItems(filteredBy tags: [String]) -> [HistoryItem] {
        guard !tags.isEmpty else { return savedItems }
        return savedItems.filter { item in
            tags.allSatisfy { item.tags.contains($0) }
        }
    }
    
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
    
    private func deleteDraftFile() {
        let fileURL = storageURL.appendingPathComponent(draftFileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    private var storageURL: URL {
        if let cached = _cachedStorageURL {
            return cached
        }
        
        let url = resolveStorageURL()
        _cachedStorageURL = url
        return url
    }
    
    private func resolveStorageURL() -> URL {
        if let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = containerURL.appendingPathComponent("Documents")
            
            if !fileManager.fileExists(atPath: documentsURL.path) {
                try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            }
            
            print("Using iCloud storage: \(documentsURL.path)")
            return documentsURL
        }
        
        let localURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Records")
        
        if !fileManager.fileExists(atPath: localURL.path) {
            try? fileManager.createDirectory(at: localURL, withIntermediateDirectories: true)
        }
        
        print("Using local storage: \(localURL.path)")
        return localURL
    }
    
    private func generateFileName(for date: Date) -> String {
        return dateFormatter.string(from: date) + ".md"
    }
    
    private func parseDate(from fileName: String) -> Date? {
        let name = fileName.replacingOccurrences(of: ".md", with: "")
        return dateFormatter.date(from: name)
    }
    
    private func parseMarkdownFile(content: String) -> (description: String, tags: [String], body: String)? {
        let lines = content.components(separatedBy: "\n")
        
        guard lines.first == "---" else {
            return ("", [], content)
        }
        
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
    
    func addRecord(_ text: String, tags: [String] = []) {
        guard !text.isEmpty else { return }
        let documentsURL = storageURL
        
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
            items.removeAll { $0.id == item.id }
        }
    }
    
    func deleteRecords(at offsets: IndexSet) {
        let documentsURL = storageURL
        for index in offsets {
            let item = items[index]
            let fileURL = documentsURL.appendingPathComponent(item.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        items.remove(atOffsets: offsets)
        TagManager.shared.refreshTags(from: items)
    }
    
    func deleteRecords(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        
        let documentsURL = storageURL
        
        for item in items where ids.contains(item.id) {
            let fileURL = documentsURL.appendingPathComponent(item.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        
        items.removeAll { ids.contains($0.id) }
        
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
        
        for index in items.indices {
            if let tagIndex = items[index].tags.firstIndex(of: oldName) {
                items[index].tags[tagIndex] = trimmedNewName
                saveItem(items[index])
            }
        }
        
        TagManager.shared.refreshTags(from: items)
    }
    
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
            
            items = loadedItems.sorted { $0.createdAt > $1.createdAt }
            
            if let draft = loadDraft() {
                items.insert(draft, at: 0)
            }
            
            TagManager.shared.refreshTags(from: savedItems)
            
        } catch {
            print("Failed to list iCloud documents: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() {
        loadItems()
    }
    
    func exportAllNotes() throws -> URL {
        let documentsURL = storageURL
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("NotesExport_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let zipName = "Notes_\(dateFormatter.string(from: Date())).zip"
        let zipURL = fileManager.temporaryDirectory.appendingPathComponent(zipName)
        
        try? fileManager.removeItem(at: zipURL)
        
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &error) { zippedURL in
            try? fileManager.copyItem(at: zippedURL, to: zipURL)
        }
        
        try? fileManager.removeItem(at: tempDir)
        
        if let error = error {
            throw error
        }
        
        return zipURL
    }
}
