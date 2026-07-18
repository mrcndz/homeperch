import Foundation

/// Persisted at ~/.homeperch as key=value lines
struct Config {
    var baseURL = ""
    var token = ""
    var favorites: Set<String> = []
    var customNames: [String: String] = [:]
    var customIcons: [String: String] = [:]

    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".homeperch")

    static func load() -> Config {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return Config() }
        var config = Config()
        for line in text.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "ha_base_url": config.baseURL = value
            case "ha_api_key": config.token = value
            case "favorites": config.favorites = Set(value.split(separator: ",").map(String.init))
            case "custom_names": config.customNames = Self.decodeMap(value)
            case "custom_icons": config.customIcons = Self.decodeMap(value)
            default: break
            }
        }
        return config
    }

    func save() {
        let lines = [
            "ha_base_url=\(baseURL)",
            "ha_api_key=\(token)",
            "favorites=\(favorites.sorted().joined(separator: ","))",
            "custom_names=\(Self.encodeMap(customNames))",
            "custom_icons=\(Self.encodeMap(customIcons))",
        ]
        try? (lines.joined(separator: "\n") + "\n")
            .write(to: Self.fileURL, atomically: true, encoding: .utf8)
    }

    private static func decodeMap(_ value: String) -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(value.utf8))) ?? [:]
    }

    private static func encodeMap(_ map: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(map) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
