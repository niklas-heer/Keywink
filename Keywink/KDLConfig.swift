import Foundation

/// Maps the configuration onto KDL nodes. Every node is one item: the node name is the action
/// type, the first argument the key, the second the target, and `label` and `icon` are
/// properties. Groups nest their items as children:
///
///     group "o" label="Open" {
///         application "s" "/Applications/Safari.app"
///         url "g" "https://google.com" label="Google"
///     }
enum KDLConfig {
  enum DecodeError: LocalizedError, Equatable {
    case unknownType(String)
    case missingValue(type: String, key: String?)

    var errorDescription: String? {
      switch self {
      case .unknownType(let name):
        let known = Type.allCases.map(\.rawValue).joined(separator: ", ")
        return "Unknown node '\(name)'. Nodes must be one of: \(known)."
      case .missingValue(let type, let key):
        return "The \(type) action '\(key ?? "")' needs a second value with its target."
      }
    }
  }

  static let header = """
    // Keywink configuration in KDL. One node per item: the node name is the action type,
    // the first value the key, the second the target. label= and icon= are optional.

    """

  static func encode(_ root: Group) -> String {
    header + KDL.serialize(root.actions.map(node))
  }

  static func decode(_ text: String) throws -> Group {
    Group(key: nil, actions: try KDL.parse(text).map(item))
  }

  private static func node(for item: ActionOrGroup) -> KDL.Node {
    var node: KDL.Node
    switch item {
    case .group(let group):
      node = KDL.Node(name: Type.group.rawValue, arguments: [keyValue(group.key)])
      node.children = group.actions.map(self.node)
      appendProperties(label: group.label, icon: group.iconPath, to: &node)
    case .action(let action):
      node = KDL.Node(
        name: action.type.rawValue, arguments: [keyValue(action.key), .string(action.value)])
      appendProperties(label: action.label, icon: action.iconPath, to: &node)
    }
    return node
  }

  private static func keyValue(_ key: String?) -> KDL.Value {
    guard let key, !key.isEmpty else { return .null }
    return .string(KeyMaps.text(for: key) ?? key)
  }

  private static func appendProperties(label: String?, icon: String?, to node: inout KDL.Node) {
    if let label, !label.isEmpty {
      node.properties.append(KDL.Property(key: "label", value: .string(label)))
    }
    if let icon, !icon.isEmpty {
      node.properties.append(KDL.Property(key: "icon", value: .string(icon)))
    }
  }

  private static func item(from node: KDL.Node) throws -> ActionOrGroup {
    guard let type = Type(rawValue: node.name) else {
      throw DecodeError.unknownType(node.name)
    }
    let key = node.arguments.first?.stringValue
    let label = node.property("label")?.stringValue
    let icon = node.property("icon")?.stringValue

    if type == .group {
      return .group(
        Group(key: key, label: label, iconPath: icon, actions: try node.children.map(item)))
    }
    guard node.arguments.count >= 2, let value = node.arguments[1].stringValue else {
      throw DecodeError.missingValue(type: node.name, key: key)
    }
    return .action(Action(key: key, type: type, label: label, value: value, iconPath: icon))
  }
}
