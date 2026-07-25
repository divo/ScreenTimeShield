//
//  StoreKitEdgeTests.swift
//  ScreenTimeShieldTests
//
//  Regression tests for the StoreKit edges found by the QA pass: transactions that land
//  outside the foreground buy flow (V15) and pending / Ask-to-Buy purchases (V16).
//  These assert the corrected behaviour, so they fail against today's Store.swift.
//

import XCTest
import StoreKit
import StoreKitTest
@testable import Unplug

@MainActor
final class StoreKitEdgeTests: XCTestCase {

  private var session: SKTestSession!

  override func setUp() async throws {
    // The bundled config lives in the read-only test bundle; SKTestSession needs to
    // write a working copy, so load it from a writable temp copy instead.
    let bundled = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "StoreKit", withExtension: "storekit"))
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("StoreKit-\(UUID().uuidString).storekit")
    try FileManager.default.copyItem(at: bundled, to: tmp)

    session = try SKTestSession(contentsOf: tmp)
    session.disableDialogs = true
    session.clearTransactions()
  }

  override func tearDown() async throws {
    session?.clearTransactions()
    session = nil
  }

  /// The simulator's StoreKit test daemon fails to persist its configuration in some
  /// headless `xcodebuild` environments ("Error saving configuration file"), serving zero
  /// products. Detect that and skip, so these run for real under Xcode/device but never
  /// report a false failure in a broken sim. Verified manually in Pass 4 via the simulator.
  private func requireStoreKitTestEnvironment() async throws {
    let products = (try? await Product.products(for: [Store.lifetimeProductID])) ?? []
    try XCTSkipIf(products.isEmpty,
                  "StoreKit test environment unavailable — SKTestSession served no products.")
  }

  private func pollUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    return condition()
  }

  private func unfinishedLifetimeTransactionIDs() async -> [UInt64] {
    var ids: [UInt64] = []
    for await result in Transaction.unfinished {
      guard case .verified(let transaction) = result else { continue }
      if transaction.productID == Store.lifetimeProductID { ids.append(transaction.id) }
    }
    return ids
  }

  /// V15: a transaction that lands outside the foreground buy flow must be observed live
  /// (a `Transaction.updates` listener), not only on the next explicit refresh.
  func testV15OutOfBandTransactionIsObservedWithoutManualRefresh() async throws {
    try await requireStoreKitTestEnvironment()

    let store = Store()
    await store.refreshPurchasedState()
    XCTAssertFalse(store.isPurchased, "precondition: no entitlement before the out-of-band buy")

    try await session.buyProduct(productIdentifier: Store.lifetimeProductID)

    let observed = await pollUntil { store.isPurchased }
    XCTAssertTrue(observed,
                  "V15: entitlement granted while the app is running was never observed — Store has no Transaction.updates listener, so isPurchased only changes when someone calls refreshPurchasedState().")
  }

  /// V15: an observed transaction must be finished, otherwise StoreKit re-delivers it for
  /// the life of the install.
  func testV15OutOfBandTransactionIsFinished() async throws {
    try await requireStoreKitTestEnvironment()

    let store = Store()
    try await session.buyProduct(productIdentifier: Store.lifetimeProductID)
    await store.refreshPurchasedState()
    XCTAssertTrue(store.isPurchased, "precondition: the out-of-band transaction is entitling")

    var unfinished = await unfinishedLifetimeTransactionIDs()
    let deadline = Date().addingTimeInterval(5)
    while !unfinished.isEmpty, Date() < deadline {
      try? await Task.sleep(nanoseconds: 200_000_000)
      unfinished = await unfinishedLifetimeTransactionIDs()
    }

    XCTAssertEqual(unfinished, [],
                   "V15: the lifetime transaction is still unfinished — Store.finish() only runs on the .success(.verified) arm of the foreground buy, so nothing ever acknowledges a transaction that arrives any other way.")
  }

  /// V16: a purchase that comes back `.pending` (Ask to Buy) must be picked up when it is
  /// approved, without the user backgrounding the app to force a refresh.
  func testV16ApprovedPendingPurchaseIsObservedWithoutManualRefresh() async throws {
    try await requireStoreKitTestEnvironment()
    session.askToBuyEnabled = true

    let store = Store()
    await store.loadProduct()
    _ = try? await store.purchase()

    try XCTSkipIf(store.isPurchased,
                  "SKTestSession did not defer the purchase — Ask to Buy was not honoured, so there is no pending transaction to approve.")

    let pending = session.allTransactions()
      .first { $0.productIdentifier == Store.lifetimeProductID && $0.pendingAskToBuyConfirmation }
    try XCTSkipIf(pending == nil,
                  "SKTestSession recorded no pending Ask to Buy transaction for the lifetime product.")
    let target = try XCTUnwrap(pending)

    try session.approveAskToBuyTransaction(identifier: target.identifier)

    let observed = await pollUntil { store.isPurchased }
    XCTAssertTrue(observed,
                  "V16: the approved Ask-to-Buy purchase was never observed — purchase() collapsed .pending into false and nothing listens for the approval, so the paid user stays on the paywall until an unrelated foreground transition.")
  }

  /// V18 (StoreKit half): once a user is known to predate the IAP, a later AppTransaction
  /// failure must not take that verdict away — including across the relaunch that clears
  /// in-memory state.
  func testV18GrandfatheredVerdictSurvivesLaterAppTransactionFailure() async throws {
    try await requireStoreKitTestEnvironment()
    guard #available(iOS 17.0, *) else {
      throw XCTSkip("Simulating an AppTransaction failure needs SKTestSession.setSimulatedError (iOS 17+).")
    }

    let cutover = Date.distantFuture
    let store = Store()
    await store.refreshGrandfatheredState(cutoverDate: cutover)
    try XCTSkipUnless(store.isGrandfathered,
                      "SKTestSession served no verified AppTransaction, so there is no grandfathered verdict to lose.")

    try await session.setSimulatedError(.generic(.unknown), forAPI: .appTransaction)

    let relaunched = Store()
    await relaunched.refreshGrandfatheredState(cutoverDate: cutover)
    XCTAssertTrue(relaunched.isGrandfathered,
                  "V18: the grandfathered verdict is process-local derived state — a fresh Store starts at false and one failed AppTransaction fetch leaves it there, demoting a legacy user to expired.")
  }
}
