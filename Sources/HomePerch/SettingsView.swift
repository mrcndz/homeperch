import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var ha: HAClient

    @State private var search = ""

    // Buffer connection edits; persisting per keystroke writes the file and goes live mid-typing
    @State private var url = ""
    @State private var tokenText = ""
    @FocusState private var focusedField: ConnectionField?

    private enum ConnectionField {
        case url, token
    }

    private var filteredEntities: [Entity] {
        guard !search.isEmpty else { return ha.entities }
        return ha.entities.filter {
            $0.originalName.localizedCaseInsensitiveContains(search)
                || $0.entityId.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        Form {
            connectionSection
            favoritesSection
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
    }

    private var connectionSection: some View {
        Section("Connection") {
            TextField("Home Assistant URL", text: $url, prompt: Text("http://homeassistant.local:8123"))
                .focused($focusedField, equals: .url)
            SecureField("Long-Lived Access Token", text: $tokenText)
                .focused($focusedField, equals: .token)
            Text("Create a token in Home Assistant: Profile → Security → Long-lived access tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Test Connection") {
                commitConnection()
                Task { await ha.refresh() }
            }
            if ha.isConnected {
                Label("Connected, \(ha.entities.count) entities", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if let error = ha.lastError {
                Label(error, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            url = ha.baseURL
            tokenText = ha.token
        }
        .onSubmit(commitConnection)
        .onChange(of: focusedField) { _, focused in
            if focused == nil { commitConnection() }
        }
    }

    private func commitConnection() {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if ha.baseURL != trimmedURL { ha.baseURL = trimmedURL }
        if ha.token != tokenText { ha.token = tokenText }
    }

    private var favoritesSection: some View {
        Section("Fixed entities") {
            TextField("Search", text: $search, prompt: Text("Filter entities"))
            ForEach(filteredEntities) { entity in
                EntitySettingsRow(entity: entity)
            }
        }
    }
}

struct EntitySettingsRow: View {
    @EnvironmentObject private var ha: HAClient
    let entity: Entity

    // Buffer edits locally; writing to customNames per keystroke rebuilds the list and drops focus
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private static let icons = [
        "lightbulb.fill", "lamp.table.fill", "lamp.floor.fill", "lamp.ceiling.fill",
        "power", "poweroutlet.type.b.fill", "fan.fill", "tv.fill",
        "thermometer.medium", "snowflake", "house.fill", "bolt.fill",
        "washer.fill", "microwave.fill", "speaker.wave.2.fill", "curtains.closed",
    ]

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { ha.favorites.contains(entity.entityId) },
                set: { pinned in
                    if pinned { ha.favorites.insert(entity.entityId) }
                    else { ha.favorites.remove(entity.entityId) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                TextField("", text: $name, prompt: Text(entity.originalName))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .focused($nameFocused)
                    .onAppear { name = ha.customNames[entity.entityId] ?? "" }
                    .onSubmit(commitName)
                    .onChange(of: nameFocused) { _, focused in
                        if !focused { commitName() }
                    }
                Text(entity.entityId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("Default") { ha.customIcons.removeValue(forKey: entity.entityId) }
                ForEach(Self.icons, id: \.self) { icon in
                    Button { ha.customIcons[entity.entityId] = icon } label: {
                        Label(icon, systemImage: icon)
                    }
                }
            } label: {
                Image(systemName: entity.icon)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let desired: String? = trimmed.isEmpty ? nil : trimmed
        // Skip no-op writes: Return triggers both onSubmit and the focus-loss commit
        guard ha.customNames[entity.entityId] != desired else { return }
        if let desired { ha.customNames[entity.entityId] = desired }
        else { ha.customNames.removeValue(forKey: entity.entityId) }
    }
}
