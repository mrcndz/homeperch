import Foundation

@MainActor
final class HAClient: ObservableObject {
    @Published var entities: [Entity] = []
    @Published var isConnected = false
    @Published var lastError: String?

    @Published var baseURL: String {
        didSet { persist() }
    }
    @Published var token: String {
        didSet { persist() }
    }
    @Published var favorites: Set<String> {
        didSet { persist() }
    }
    @Published var customNames: [String: String] {
        didSet {
            persist()
            applyOverrides()
        }
    }
    @Published var customIcons: [String: String] {
        didSet {
            persist()
            applyOverrides()
        }
    }

    private var refreshTask: Task<Void, Never>?
    // Bumped on every refresh; stale responses (older generation) are discarded
    private var refreshGeneration = 0
    // Optimistic states by entity id; refresh keeps them until HA confirms or they expire
    private var pending: [String: (state: String, until: Date)] = [:]

    init() {
        let config = Config.load()
        baseURL = config.baseURL
        favorites = config.favorites
        customNames = config.customNames
        customIcons = config.customIcons
        token = config.token
        startPolling()
    }

    private func persist() {
        Config(
            baseURL: baseURL,
            token: token,
            favorites: favorites,
            customNames: customNames,
            customIcons: customIcons
        ).save()
    }

    var isConfigured: Bool { !baseURL.isEmpty && !token.isEmpty }

    func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    func refresh() async {
        guard isConfigured, let url = apiURL("states") else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        do {
            let all = try await Self.fetchEntities(request(url))
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            entities = all
                .map { entity in
                    var e = applyPending(entity)
                    e.customName = customNames[e.entityId]
                    e.customIcon = customIcons[e.entityId]
                    return e
                }
                .sorted { $0.name < $1.name }
            isConnected = true
            lastError = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            if (error as? URLError)?.code == .cancelled { return }
            isConnected = false
            lastError = error.localizedDescription
        }
    }

    // Off the main actor: /api/states returns every entity, decode can be heavy
    private nonisolated static func fetchEntities(_ request: URLRequest) async throws -> [Entity] {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode([Entity].self, from: data)
            .filter { $0.isToggleable || $0.domain == "sensor" }
    }

    private nonisolated static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        throw http.statusCode == 401
            ? URLError(.userAuthenticationRequired)
            : URLError(.badServerResponse)
    }

    func setState(_ entity: Entity, on: Bool) async {
        let service = on ? "turn_on" : "turn_off"
        guard let url = apiURL("services/homeassistant/\(service)") else { return }

        // Optimistic update so the switch reflects the target state immediately
        let target = on ? "on" : "off"
        let previous = entity.state
        pending[entity.entityId] = (target, Date().addingTimeInterval(5))
        if let index = entities.firstIndex(where: { $0.entityId == entity.entityId }) {
            entities[index].state = target
        }

        var req = request(url)
        req.httpMethod = "POST"
        req.httpBody = try? JSONEncoder().encode(["entity_id": entity.entityId])
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            try Self.validate(response)
        } catch {
            // Roll back the optimistic state; the call didn't take
            pending.removeValue(forKey: entity.entityId)
            if let index = entities.firstIndex(where: { $0.entityId == entity.entityId }) {
                entities[index].state = previous
            }
            lastError = error.localizedDescription
            return
        }
        try? await Task.sleep(for: .seconds(1))
        await refresh()
    }

    // Re-apply name/icon overrides to already-loaded entities (e.g. edited in Settings)
    private func applyOverrides() {
        entities = entities.map { entity in
            var e = entity
            e.customName = customNames[e.entityId]
            e.customIcon = customIcons[e.entityId]
            return e
        }
        .sorted { $0.name < $1.name }
    }

    // Keep an optimistic state until HA reports it back or it expires
    private func applyPending(_ entity: Entity) -> Entity {
        guard let p = pending[entity.entityId] else { return entity }
        if entity.state == p.state || Date() >= p.until {
            pending.removeValue(forKey: entity.entityId)
            return entity
        }
        var kept = entity
        kept.state = p.state
        return kept
    }

    private func apiURL(_ path: String) -> URL? {
        URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))?
            .appending(path: "api/\(path)")
    }

    private func request(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }
}
