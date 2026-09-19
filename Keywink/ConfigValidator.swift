import Foundation

struct ValidationError: Identifiable, Equatable {
  let id = UUID()
  let path: [Int]  // Path to the item with the error (indices in the actions array)
  let message: String
  let type: ValidationErrorType

  static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
    lhs.id == rhs.id
  }
}

enum ValidationErrorType {
  case emptyKey
  case nonSingleCharacterKey
  case duplicateKey
}

class ConfigValidator {
  static func validate(group: Group) -> [ValidationError] {
    var errors = [ValidationError]()

    // Validate the root group
    validateGroup(group, path: [], errors: &errors)

    return errors
  }

  private static func validateGroup(_ group: Group, path: [Int], errors: inout [ValidationError]) {
    // Check if the group key is valid (if not root level)
    if !path.isEmpty {
      validateKey(group.key, at: path, errors: &errors)
    }

    // Check for duplicate keys within this group
    var keysInGroup = [String: Int]()  // key: index

    for (index, item) in group.actions.enumerated() {
      let currentPath = path + [index]

      // Get the key from the item
      let key: String?
      switch item {
      case .action(let action):
        key = action.key
        // Validate the key for actions
        validateKey(key, at: currentPath, errors: &errors)
      case .group(let subgroup):
        key = subgroup.key
        // Recursively validate subgroups
        validateGroup(subgroup, path: currentPath, errors: &errors)
      // Note: We don't validate the key here because it will be validated in the recursive call
      }

      // Check for duplicates
      if let key = key, !key.isEmpty {
        // Normalize key to glyph representation for consistent comparison
        let normalizedKey = KeyMaps.glyph(for: key) ?? key

        if let existingIndex = keysInGroup[normalizedKey] {
          // Found a duplicate key
          let duplicatePath = path + [existingIndex]
          errors.append(
            ValidationError(
              path: duplicatePath,
              message: "Multiple actions for the same key '\(normalizedKey)'",
              type: .duplicateKey
            ))
          errors.append(
            ValidationError(
              path: currentPath,
              message: "Multiple actions for the same key '\(normalizedKey)'",
              type: .duplicateKey
            ))
        } else {
          keysInGroup[normalizedKey] = index
        }
      }
    }
  }

  private static func validateKey(_ key: String?, at path: [Int], errors: inout [ValidationError]) {
    guard let key = key else {
      errors.append(
        ValidationError(
          path: path,
          message: "Key is missing",
          type: .emptyKey
        ))
      return
    }

    if key.isEmpty {
      errors.append(
        ValidationError(
          path: path,
          message: "Key is empty",
          type: .emptyKey
        ))
      return
    }

    // Check if key is valid in our key mapping system
    let entry = KeyMaps.entry(for: key) ?? KeyMaps.entry(forText: key)

    if entry == nil && key.count != 1 {
      errors.append(
        ValidationError(
          path: path,
          message: "Key must be a single character or a valid key name",
          type: .nonSingleCharacterKey
        ))
      return
    }

    // Check if key is reserved (only for non-root level)
    if !path.isEmpty, let entry = entry, entry.isReserved {
      errors.append(
        ValidationError(
          path: path,
          message: "Key '\(key)' is reserved and cannot be bound",
          type: .duplicateKey  // Reusing existing error type
        ))
    }
  }

  // Helper function to find an item at a specific path
  static func findItem(in group: Group, at path: [Int]) -> ActionOrGroup? {
    guard !path.isEmpty else { return .group(group) }

    var currentGroup = group
    var remainingPath = path

    while !remainingPath.isEmpty {
      let index = remainingPath.removeFirst()

      guard index < currentGroup.actions.count else { return nil }

      if remainingPath.isEmpty {
        // We've reached the target item
        return currentGroup.actions[index]
      } else {
        // We need to go deeper
        guard case .group(let subgroup) = currentGroup.actions[index] else {
          // Path points through an action, which can't contain other items
          return nil
        }
        currentGroup = subgroup
      }
    }

    return nil
  }
}
