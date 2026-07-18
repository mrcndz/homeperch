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
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func refresh() async {
        guard isConfigured, let url = apiURL("states") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(for: request(url))
            let all = try JSONDecoder().decode([Entity].self, from: data)
            entities = all
                .filter { $0.isToggleable || $0.domain == "sensor" }
                .map { entity in
                    var e = applyPending(entity)
                    e.customName = customNames[e.entityId]
                    e.customIcon = customIcons[e.entityId]
                    return e
                }
                .sorted { $0.name < $1.name }
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = error.localizedDescription
        }
    }

    func setState(_ entity: Entity, on: Bool) async {
        let service = on ? "turn_on" : "turn_off"
        guard let url = apiURL("services/homeassistant/\(service)") else { return }

        // Optimistic update so the switch reflects the target state immediately
        let target = on ? "on" : "off"
        pending[entity.entityId] = (target, Date().addingTimeInterval(5))
        if let index = entities.firstIndex(where: { $0.entityId == entity.entityId }) {
            entities[index].state = target
        }

        var req = request(url)
        req.httpMethod = "POST"
        req.httpBody = try? JSONEncoder().encode(["entity_id": entity.entityId])
        _ = try? await URLSession.shared.data(for: req)
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
