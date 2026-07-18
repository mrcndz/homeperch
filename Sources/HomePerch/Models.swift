import Foundation

struct Entity: Identifiable, Decodable {
    let entityId: String
    var state: String
    let attributes: Attributes

    // Local overrides, not decoded (absent from CodingKeys)
    var customName: String?
    var customIcon: String?

    struct Attributes: Decodable {
        let friendlyName: String?
        let unitOfMeasurement: String?

        enum CodingKeys: String, CodingKey {
            case friendlyName = "friendly_name"
            case unitOfMeasurement = "unit_of_measurement"
        }
    }

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    var id: String { entityId }
    var name: String { customName ?? originalName }
    var originalName: String { attributes.friendlyName ?? entityId }
    var domain: String { String(entityId.split(separator: ".").first ?? "") }
    var isOn: Bool { state == "on" }

    /// Domains controllable with homeassistant.toggle
    var isToggleable: Bool {
        ["switch", "light", "input_boolean", "fan", "automation"].contains(domain)
    }

    var displayState: String {
        if let unit = attributes.unitOfMeasurement {
            return "\(state) \(unit)"
        }
        return state.capitalized
    }

    var icon: String {
        if let customIcon { return customIcon }
        return switch domain {
        case "light": "lightbulb.fill"
        case "switch": "power"
        case "sensor": "thermometer.medium"
        case "fan": "fan.fill"
        case "climate": "snowflake"
        case "input_boolean": "house.fill"
        default: "circle.fill"
        }
    }
}
