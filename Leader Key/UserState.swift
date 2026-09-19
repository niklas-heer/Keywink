import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!
  private var configObservation: AnyCancellable?

  @Published var display: String?
  @Published var isShowingRefreshState: Bool
  @Published var navigationPath: [Group] = []

  var currentGroup: Group? {
    return navigationPath.last
  }

  init(
    userConfig: UserConfig!,
    lastChar: String? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.isShowingRefreshState = isShowingRefreshState
    self.navigationPath = []
    configObservation = userConfig.$root.dropFirst().sink { [weak self] _ in
      // Navigation contains value copies; a replaced config must never execute stale actions.
      self?.clear()
    }
  }

  func clear() {
    display = nil
    navigationPath = []
    isShowingRefreshState = false
  }

  func navigateToGroup(_ group: Group) {
    navigationPath.append(group)
  }

  /// Global group shortcuts always resolve from the root, even inside another group.
  @discardableResult
  func openRootGroup(for key: String) -> Bool {
    guard
      let group = userConfig.root.actions.compactMap({ item -> Group? in
        guard case .group(let group) = item,
          KeyMaps.glyph(for: group.key ?? "") == KeyMaps.glyph(for: key)
        else { return nil }
        return group
      }).first
    else { return false }

    isShowingRefreshState = false
    display = group.key
    navigationPath = [group]
    return true
  }
}
