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

@MainActor
final class AccessController: ObservableObject {
  static let shared = AccessController()

  private let kv = AppGroupStore()
  let storeKit = Store()

  @Published private(set) var accessState: AccessState = .trial

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

  var hasFullAccess: Bool { storeKit.hasFullAccess }

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
    await storeKit.refreshPurchasedState()
    await storeKit.refreshGrandfatheredState(cutoverBuild: PricingConfig.cutoverBuild)
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
                                              hasFullAccess: storeKit.hasFullAccess,
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
}
