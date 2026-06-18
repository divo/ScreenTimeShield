//
//  AccessController.swift
//  ScreenTimeShield
//
//  App-only owner of trial + entitlement state. Kept out of the shared Model so the
//  DeviceActivity/Shield extensions (which compile Model) don't pull in StoreKit.
//  Extensions read the cached `enforcementAllowed` gate from the app group instead.
//

import Foundation
import SwiftUI
import UserNotifications
import UnplugCore
import DeviceActivity
import FamilyControls
import Combine

@MainActor
final class AccessController: ObservableObject {
  static let shared = AccessController()

  private let kv = AppGroupStore()
  let storeKit = Store()
  private var cancellables = Set<AnyCancellable>()

  /// QA hook: skip the Family Controls gate so the trial/paywall UI is testable on a
  /// simulator without Screen Time auth. (Reverted with the rest of the hook before production.)
  private let skipFC = ProcessInfo.processInfo.environment["UNPLUG_SKIP_FC"] != nil

  @Published private(set) var accessState: AccessState = .trial
  /// Whether Family Controls (Screen Time) authorization is granted. When false the app
  /// can't enforce blocks, so the UI shows the permission-denied state instead of the app list.
  @Published private(set) var fcAuthorized: Bool = false

  init() {
    fcAuthorized = skipFC || AuthorizationCenter.shared.authorizationStatus == .approved

    // `storeKit` is a nested ObservableObject: its @Published changes (e.g. `product`
    // finishing loading, `isPurchased`) fire Store's objectWillChange, which does NOT
    // bubble up to views observing AccessController. Forward it so the UI reacts —
    // otherwise the buy button stays disabled until some other @Published here changes.
    storeKit.objectWillChange
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &cancellables)

    // Live-track Screen Time authorization so granting/revoking it updates the UI.
    if !skipFC {
      AuthorizationCenter.shared.$authorizationStatus
        .receive(on: RunLoop.main)
        .sink { [weak self] status in self?.fcAuthorized = (status == .approved) }
        .store(in: &cancellables)
    }
  }

  var trialStartDate: Date? {
    get { kv.date(forKey: AppGroupKeys.trialStart) }
    set { kv.setDate(newValue, forKey: AppGroupKeys.trialStart) }
  }

  /// Our own value stat: times a restricted app/site hit the shield (written by the shield extension).
  var timesStopped: Int { kv.integer(forKey: AppGroupKeys.timesStopped) }

  var trialDaysRemaining: Int {
    AccessEvaluator.trialDaysRemaining(now: Date(),
                                       trialStart: trialStartDate,
                                       trialLength: PricingConfig.trialLength)
  }

  var hasFullAccess: Bool { storeKit.hasFullAccess || qaForceFullAccess }

  /// Re-present the Family Controls system prompt. There's no per-app Screen Time toggle in
  /// Settings, but re-calling `requestAuthorization` re-shows the dialog (even after a prior
  /// "Don't Allow"), so this is how the denied state recovers.
  func requestAuthorization() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    } catch {
      print("Family Controls authorization request failed: \(error)")
    }
    fcAuthorized = skipFC || AuthorizationCenter.shared.authorizationStatus == .approved
  }

  /// Begin the trial the first time the user sets up a block. No-op afterwards.
  func startTrialIfNeeded() {
    if trialStartDate == nil {
      trialStartDate = Date()
      // Recompute synchronously off the new start date so gating reflects it immediately.
      recomputeAccessState()
    }
  }

  /// Recompute entitlement + access state, caching the enforcement gate the extensions read.
  func refreshAccess() async {
    // Re-read Screen Time auth on foreground (scenePhase) so granting it in Settings reflects on return.
    if !skipFC { fcAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved }
    await storeKit.refreshPurchasedState()
    await storeKit.refreshGrandfatheredState(cutoverDate: PricingConfig.cutoverDate)
    recomputeAccessState()
  }

  func purchase() async throws -> Bool {
    let ok = try await storeKit.purchase()
    recomputeAccessState()
    return ok
  }

  func restore() async {
    await storeKit.restore()
    recomputeAccessState()
  }

  private func recomputeAccessState() {
    accessState = AccessEvaluator.accessState(now: Date(),
                                              trialStart: trialStartDate,
                                              hasFullAccess: hasFullAccess,
                                              trialLength: PricingConfig.trialLength)
    // Extensions can't query StoreKit — cache whether enforcement is currently permitted.
    kv.setBool(accessState != .expired, forKey: AppGroupKeys.enforcementAllowed)
    updateTrialEndedNotification()
  }

  private static let trialEndedNotificationID = "unplug.trial.ended"

  /// After expiry, fire a daily reminder at the user's habitual block-start time — the moment
  /// they'd normally be protected. Removed once access is restored.
  private func updateTrialEndedNotification() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [Self.trialEndedNotificationID])

    guard accessState == .expired else { return }
    // "start" is the schedule start time the Model persists into the app group.
    guard let start = kv.date(forKey: "start") else { return }

    let content = UNMutableNotificationContent()
    content.title = String(localized: "Your blocks are off")
    content.body = String(localized: "Nothing's stopping the scroll right now. Unlock Unplug to bring your block back.")
    content.sound = .default

    let comps = Calendar.current.dateComponents([.hour, .minute], from: start)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    let request = UNNotificationRequest(identifier: Self.trialEndedNotificationID, content: content, trigger: trigger)
    center.add(request)
  }

  // MARK: - QA
  // In-app QA controls. Present in release builds (TestFlight has no DEBUG); the menu
  // that drives these is exposed in a separate, easily-reverted commit. These simulate
  // entitlement *results* (not real StoreKit transactions) and persist via the app group.

  /// QA-only override that forces full access without a StoreKit purchase.
  var qaForceFullAccess: Bool {
    get { kv.bool(forKey: AppGroupKeys.qaForceFullAccess) }
    set { kv.setBool(newValue, forKey: AppGroupKeys.qaForceFullAccess) }
  }

  func qaStartTrial() {
    trialStartDate = Date()
    recomputeAccessState()
    objectWillChange.send()
  }

  func qaExpireTrial() {
    trialStartDate = Date(timeIntervalSinceNow: -(PricingConfig.trialLength + PricingConfig.secondsPerDay))
    recomputeAccessState()
    objectWillChange.send()
  }

  func qaResetTrial() {
    trialStartDate = nil
    recomputeAccessState()
    objectWillChange.send()
  }

  func qaSetFullAccess(_ on: Bool) {
    qaForceFullAccess = on
    recomputeAccessState()
    objectWillChange.send()
  }

  func qaSetTimesStopped(_ count: Int) {
    kv.setInteger(count, forKey: AppGroupKeys.timesStopped)
    objectWillChange.send()
  }

  /// QA-only: wipe all shared storage and active schedules back to a fresh-install state.
  func qaResetToFreshInstall() {
    let model = Model.shared
    DeviceActivityCenter().stopMonitoring()      // all activities
    model.clearRestrictions()

    UserDefaults.standard.removePersistentDomain(forName: "group.screentimeshield")

    // Reset the in-memory @Published model values (not auto-cleared by removing the domain).
    model.selectionToRestrict = FamilyActivitySelection()
    model.start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    model.end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    model.notificationsEnabled = true
    model.hasSelection = false
    model.insideInterval = false
    model.blockOutsideWindow = false
    model.isArmed = false

    recomputeAccessState()
    objectWillChange.send()
  }
}
