//
//  StoreTests.swift
//  ScreenTimeShieldTests
//
//  Integration tests for the StoreKit 2 purchase wrapper, driven by SKTestSession
//  against the bundled StoreKit.storekit configuration.
//

import XCTest
import StoreKitTest
@testable import Unplug

@MainActor
final class StoreTests: XCTestCase {

  private var session: SKTestSession!

  override func setUp() async throws {
    session = try SKTestSession(configurationFileNamed: "StoreKit")
    session.disableDialogs = true
    session.clearTransactions()
  }

  override func tearDown() async throws {
    session.clearTransactions()
    session = nil
  }

  func testNotPurchasedInitially() async {
    let store = Store()
    await store.refreshPurchasedState()
    XCTAssertFalse(store.isPurchased)
  }

  func testProductLoads() async {
    let store = Store()
    await store.loadProduct()
    XCTAssertEqual(store.product?.id, Store.lifetimeProductID)
  }

  func testPurchaseMakesIsPurchasedTrue() async throws {
    let store = Store()
    await store.loadProduct()
    _ = try await store.purchase()
    await store.refreshPurchasedState()
    XCTAssertTrue(store.isPurchased)
  }

  func testRestoreReflectsPriorPurchase() async throws {
    try await session.buyProduct(productIdentifier: Store.lifetimeProductID)
    let store = Store()
    await store.refreshPurchasedState()
    XCTAssertTrue(store.isPurchased)
  }
}
