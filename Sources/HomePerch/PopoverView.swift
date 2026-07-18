import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var ha: HAClient
    @Environment(\.openSettings) private var openSettings
    private enum Filter: Equatable {
        case all, favorites, domain(String)

        init(raw: String) {
            self = switch raw {
            case "favorites": .favorites
            case let r where r.hasPrefix("domain:"): .domain(String(r.dropFirst(7)))
            default: .all
            }
        }

        var raw: String {
            switch self {
            case .all: "all"
            case .favorites: "favorites"
            case .domain(let d): "domain:\(d)"
            }
        }
    }

    // Persisted so the selection survives popover close/reopen
    @AppStorage("lastFilter") private var filterRaw = ""

    private var filter: Filter {
        let f = Filter(raw: filterRaw)
        // Fall back when the selected domain no longer exists
        if case .domain(let d) = f, !ha.entities.isEmpty, !domains.contains(d) { return .all }
        if f == .favorites, ha.favorites.isEmpty { return .all }
        return f
    }

    private var domains: [String] {
        Array(Set(ha.entities.map(\.domain))).sorted()
    }

    private var filtered: [Entity] {
        switch filter {
        case .all: ha.entities
        case .favorites: ha.entities.filter { ha.favorites.contains($0.entityId) }
        case .domain(let domain): ha.entities.filter { $0.domain == domain }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ha.isConnected {
                if !domains.isEmpty { chips }
                content
            } else {
                Text(ha.isConfigured ? "Disconnected" : "Configure your Home Assistant URL and token in ~/.homeperch or Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .task {
            if filterRaw.isEmpty {
                filterRaw = ha.favorites.isEmpty ? Filter.all.raw : Filter.favorites.raw
            }
            await ha.refresh()
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !ha.favorites.isEmpty {
                    chip("Favorites", isSelected: filter == .favorites) { filterRaw = Filter.favorites.raw }
                }
                chip("All", isSelected: filter == .all) { filterRaw = Filter.all.raw }
                ForEach(domains, id: \.self) { domain in
                    chip(domain.capitalized, isSelected: filter == .domain(domain)) {
                        filterRaw = Filter.domain(domain).raw
                    }
                }
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(.quaternarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            Text("No entities")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 38)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { entity in
                        EntityRow(entity: entity)
                    }
                }
            }
            // Hug the content height, scroll only past the cap
            .frame(height: min(CGFloat(filtered.count) * 42 - 4, 560))
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings") {
                // Accessory apps open Settings behind other windows; activate first
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open in HA") {
                if let url = URL(string: ha.baseURL) { NSWorkspace.shared.open(url) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

struct EntityRow: View {
    @EnvironmentObject private var ha: HAClient
    let entity: Entity

    var body: some View {
        if entity.isToggleable {
            Button {
                Task { await ha.setState(entity, on: !entity.isOn) }
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 10) {
            Image(systemName: entity.icon)
                .font(.system(size: 13))
                .foregroundStyle(entity.isToggleable && entity.isOn ? Color.white : .primary)
                .frame(width: 26, height: 26)
                .background(
                    entity.isToggleable && entity.isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(entity.name).font(.body)
                // Sensors already show their value in the trailing badge
                if entity.isToggleable {
                    Text(entity.displayState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !entity.isToggleable {
                Text(entity.displayState)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
