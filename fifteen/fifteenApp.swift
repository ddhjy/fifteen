import Foundation
import Network
import SwiftUI

@main
struct fifteenApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await MainActor.run {
                        AutoPasteSyncManager.shared.handleScenePhaseChange(scenePhase)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    Task { @MainActor in
                        AutoPasteSyncManager.shared.handleScenePhaseChange(newPhase)
                    }
                }
        }
    }
}

@MainActor
final class AutoPasteSyncManager {
    static let shared = AutoPasteSyncManager()

    private let callbackPort: UInt16 = 7789
    private let debounceInterval: TimeInterval = 0.3
    private let controlServer = FifteenControlServer()

    private var pendingSyncTask: Task<Void, Never>?
    private var isSceneActive = false

    private init() {
        controlServer.onClearDraft = { [weak self] in
            Task { @MainActor in
                self?.handleRemoteDraftClear()
            }
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        let isActive = phase == .active
        if isSceneActive == isActive {
            if isActive && isSyncEnabled {
                startControlServerIfNeeded()
                scheduleCurrentDraftSync(immediate: true)
            }
            return
        }

        isSceneActive = isActive
        pendingSyncTask?.cancel()
        pendingSyncTask = nil

        guard isActive else {
            controlServer.stop()
            return
        }

        guard isSyncEnabled else { return }
        startControlServerIfNeeded()
        scheduleCurrentDraftSync(immediate: true)
    }

    func settingsDidChange() {
        pendingSyncTask?.cancel()
        pendingSyncTask = nil

        guard isSceneActive else { return }

        if isSyncEnabled {
            startControlServerIfNeeded()
            scheduleCurrentDraftSync(immediate: true)
            return
        }

        controlServer.stop()
        if hasSyncTarget {
            sendDraft(text: "")
        }
    }

    func scheduleDraftSync(text: String, immediate: Bool = false) {
        pendingSyncTask?.cancel()
        pendingSyncTask = nil

        guard isSceneActive, isSyncEnabled else { return }

        if immediate {
            sendDraft(text: text)
            return
        }

        pendingSyncTask = Task {
            try? await Task.sleep(for: .seconds(debounceInterval))
            guard !Task.isCancelled else { return }
            sendDraft(text: text)
        }
    }

    private var hasSyncTarget: Bool {
        !syncHost.isEmpty
    }

    private var isSyncEnabled: Bool {
        (autoPasteSyncWorkflow?.isActive ?? false) && hasSyncTarget
    }

    private func scheduleCurrentDraftSync(immediate: Bool) {
        scheduleDraftSync(text: HistoryManager.shared.currentDraft.text, immediate: immediate)
    }

    private func startControlServerIfNeeded() {
        controlServer.start(port: callbackPort)
    }

    private func handleRemoteDraftClear() {
        HistoryManager.shared.clearDraft()
    }

    private func sendDraft(text: String) {
        guard let url = targetURL(path: "/draft") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(DraftPayload(text: text, callbackPort: callbackPort))

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    print("AutoPaste sync failed with status: \(httpResponse.statusCode)")
                }
            } catch {
                print("AutoPaste sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func targetURL(path: String) -> URL? {
        guard let workflow = autoPasteSyncWorkflow else { return nil }

        let host = workflow.syncConfig.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = workflow.syncConfig.port
        components.path = path
        return components.url
    }

    private var autoPasteSyncWorkflow: Workflow? {
        WorkflowManager.shared.autoPasteSyncWorkflow
    }

    private var syncHost: String {
        autoPasteSyncWorkflow?.syncConfig.host.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private struct DraftPayload: Encodable {
    let text: String
    let callbackPort: UInt16
}

private final class FifteenControlServer {
    var onClearDraft: (() -> Void)?

    private let queue = DispatchQueue(label: "cn.onepointech.fifteen.controlserver")
    private var listener: NWListener?

    func start(port: UInt16) {
        guard listener == nil, let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            let listener = try NWListener(using: .tcp, on: nwPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("Fifteen control server failed: \(error.localizedDescription)")
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            print("Failed to start Fifteen control server: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            let response = self?.response(for: data, error: error) ?? Self.httpResponse(status: 500, body: "{\"error\":\"internal error\"}")
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for data: Data?, error: NWError?) -> String {
        if let error {
            return Self.httpResponse(status: 500, body: "{\"error\":\"\(error)\"}")
        }

        guard let data, let rawRequest = String(data: data, encoding: .utf8) else {
            return Self.httpResponse(status: 400, body: "{\"error\":\"invalid request\"}")
        }

        let lines = rawRequest.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return Self.httpResponse(status: 400, body: "{\"error\":\"malformed request\"}")
        }

        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            return Self.httpResponse(status: 400, body: "{\"error\":\"malformed request\"}")
        }

        let method = components[0].uppercased()
        let path = components[1]

        guard method == "POST" else {
            return Self.httpResponse(status: 405, body: "{\"error\":\"method not allowed\"}")
        }

        guard path == "/draft/clear" else {
            return Self.httpResponse(status: 404, body: "{\"error\":\"not found\"}")
        }

        Task { @MainActor [weak self] in
            self?.onClearDraft?()
        }
        return Self.httpResponse(status: 200, body: "{\"ok\":true}")
    }

    private static func httpResponse(status: Int, body: String) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Error"
        }

        return "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    }
}
