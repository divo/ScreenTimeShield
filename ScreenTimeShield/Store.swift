//
//  Store.swift
//  ScreenTimeShield
//
//  StoreKit 2 wrapper for the one-time "lifetime unlock" purchase + grandfathering.
//

import Foundation
import StoreKit
import UnplugCore

@MainActor
final class Store: ObservableObject {
  static let lifetimeProductID = "com.halfspud.ScreenTimeShield.lifetime"

  @Published private(set) var isPurchased = false
  @Published private(set) var isGrandfathered = false
  @Published private(set) var product: Product?

  var hasFullAccess: Bool { isPurchased || isGrandfathered }

  /// Load the lifetime product from the App Store / StoreKit config.
  func loadProduct() async {
    do {
      product = try await Product.products(for: [Self.lifetimeProductID]).first
    } catch {
      print("Store: failed to load product: \(error)")
    }
  }

  /// Purchase the lifetime unlock. Returns true on a verified success.
  @discardableResult
  func purchase() async throws -> Bool {
    if product == nil { await loadProduct() }
    guard let product else { return false }

    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      guard case .verified(let transaction) = verification else { return false }
      await transaction.finish()
      await refreshPurchasedState()
      return true
    case .userCancelled, .pending:
      return false
    @unknown default:
      return false
    }
  }

  /// Restore prior purchases (Apple-mandated entry point).
  func restore() async {
    try? await AppStore.sync()
    await refreshPurchasedState()
  }

  /// Recompute `isPurchased` from the user's current entitlements.
  func refreshPurchasedState() async {
    var purchased = false
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      if transaction.productID == Self.lifetimeProductID, transaction.revocationDate == nil {
        purchased = true
      }
    }
    isPurchased = purchased
  }

  /// Recompute `isGrandfathered` from the original-download version vs the cutover build.
  func refreshGrandfatheredState(cutoverBuild: Int) async {
    do {
      let result = try await AppTransaction.shared
      guard case .verified(let appTransaction) = result else { return }
      isGrandfathered = Grandfather.isGrandfathered(
        originalVersion: appTransaction.originalAppVersion,
        cutoverBuild: cutoverBuild)
    } catch {
      // AppTransaction unavailable (e.g. offline first-run) — leave prior value untouched.
      print("Store: AppTransaction unavailable: \(error)")
    }
  }
}
