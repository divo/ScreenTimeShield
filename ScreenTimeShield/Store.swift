//
//  Store.swift
//  ScreenTimeShield
//
//  StoreKit 2 wrapper for the one-time "lifetime unlock" purchase + grandfathering.
//

import Foundation
import StoreKit

@MainActor
final class Store: ObservableObject {
  static let lifetimeProductID = "com.halfspud.ScreenTimeShield.lifetime"

  @Published private(set) var isPurchased = false
  @Published private(set) var isGrandfathered = false
  @Published private(set) var product: Product?

  var hasFullAccess: Bool { isPurchased || isGrandfathered }

  /// Load the lifetime product from the App Store / StoreKit config.
  func loadProduct() async {
    // stub — Pass 3
  }

  /// Purchase the lifetime unlock. Returns true on a verified success.
  @discardableResult
  func purchase() async throws -> Bool {
    false // stub — Pass 3
  }

  /// Restore prior purchases (Apple-mandated entry point).
  func restore() async {
    // stub — Pass 3
  }

  /// Recompute `isPurchased` from the user's current entitlements.
  func refreshPurchasedState() async {
    // stub — Pass 3
  }

  /// Recompute `isGrandfathered` from the original-download version vs the cutover build.
  func refreshGrandfatheredState(cutoverBuild: Int) async {
    // stub — Pass 3
  }
}
