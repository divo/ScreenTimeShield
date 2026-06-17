//
//  ContentView.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import SwiftUI
import FamilyControls
import Foundation
import AlertToast
import DeviceActivity
import UnplugCore

struct ContentView: View {
  @State private var isShowingRestrict = false

  @EnvironmentObject var model: Model
  @StateObject private var access = AccessController.shared
  @State var showToast: Bool = false
  @State var showInvalidatedWarning: Bool = false
  @State private var showPaywall = false
  @State private var showSettings = false
  @State private var armRequest: ArmRequest?

  private enum ArmRequest: Identifiable { case schedule, hour; var id: Int { hashValue } }

  private var isExpired: Bool { access.accessState == .expired }
  private var hasApps: Bool { !model.isEmpty() }

  private var isQuickRestrictDisabled: Bool {
    model.insideInterval || isExpired || model.selectionToRestrict.applicationTokens.isEmpty
  }

  // MARK: Primary button state (Start / Stop / Blocking)

  private var primaryTitle: String {
    if model.insideInterval { return "Blocking" }
    if model.isArmed { return "Stop blocking" }
    return "Start blocking"
  }

  private var primaryDisabled: Bool {
    if model.insideInterval { return true }          // active → locked
    if model.isArmed { return false }                // armed, inactive → can stop
    return !hasApps && !isExpired                    // not armed → need apps (or route expired to paywall)
  }

  private func onPrimary() {
    if model.insideInterval { return }
    if model.isArmed { stop() } else { start() }
  }

  // MARK: Arm / disarm

  /// Re-register the schedule from the current config — but only when already armed. Editing never
  /// arms; that's the explicit Start tap. Expired access silently skips (paywall only via the CTAs).
  private func applySchedule() {
    guard model.isArmed, !isExpired, !model.isEmpty() else { return }
    access.startTrialIfNeeded()
    let bi = model.blockedInterval
    Schedule.setSchedule(start: bi.start, end: bi.end, event: model.activityEvent(), repeats: true)
    if model.notificationsEnabled {
      Schedule.setNotificationSchedule(restrictionStart: bi.start, restrictionEnd: bi.end)
    }
  }

  private func start() {
    if isExpired { showPaywall = true; return }
    guard hasApps else { isShowingRestrict = true; return }
    if isRiskyToArm() { armRequest = .schedule } else { performArm() }
  }

  private func performArm() {
    access.startTrialIfNeeded()
    model.isArmed = true
    applySchedule()
  }

  private func stop() {
    model.isArmed = false
    DeviceActivityCenter().stopMonitoring([.daily, .notificationSchedule])
    model.clearRestrictions()
  }

  /// App-card tap: open the picker, never the paywall (expired users go through the CTAs).
  private func openPicker() {
    guard !isExpired else { return }
    isShowingRestrict = true
  }

  private func restrictForNextHour() {
    if isExpired { showPaywall = true; return }
    armRequest = .hour   // immediate lockout — always confirm
  }

  private func performRestrictHour() {
    access.startTrialIfNeeded()
    let now = Date()
    let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
    Schedule.setSchedule(start: now, end: oneHourLater, event: model.activityEvent(), repeats: false)
  }

  // MARK: Risk / confirmation

  private func minutesOfDay(_ date: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
  }

  private func timeString(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }

  /// Arming is risky (→ confirm) when it would lock you in immediately or leave almost no free time.
  private func isRiskyToArm() -> Bool {
    let bi = model.blockedInterval
    let activeNow = ScheduleMath.windowContains(now: minutesOfDay(Date()),
                                                start: minutesOfDay(bi.start),
                                                end: minutesOfDay(bi.end))
    let free = ScheduleMath.freeMinutes(windowStart: minutesOfDay(model.start),
                                        windowEnd: minutesOfDay(model.end),
                                        blockOutsideWindow: model.blockOutsideWindow)
    return activeNow || free <= 30
  }

  private func confirmMessage(_ req: ArmRequest) -> String {
    switch req {
    case .hour:
      return String(localized: "This blocks everything for the next hour and can't be stopped until then.")
    case .schedule:
      let bi = model.blockedInterval
      let activeNow = ScheduleMath.windowContains(now: minutesOfDay(Date()),
                                                  start: minutesOfDay(bi.start),
                                                  end: minutesOfDay(bi.end))
      return activeNow
        ? String(localized: "Blocking starts now and can't be stopped until \(timeString(bi.end)).")
        : String(localized: "This leaves almost no time unblocked, and can't be changed once active.")
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      Text("Unplug ∎")
        .font(.largeTitle.bold())
        .foregroundStyle(
          LinearGradient(colors: [Style.primaryColor, .purple],
                         startPoint: .leading, endPoint: .trailing)
        )
      Spacer()
      Button { showSettings = true } label: {
        Image(systemName: "gearshape")
          .font(.title3)
          .foregroundStyle(Style.primaryColor)
          .padding(8)
          .background(Style.primaryColor.opacity(0.12), in: Circle())
      }
    }
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(.systemBackground), Style.primaryColor.opacity(0.12)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
      )
      .ignoresSafeArea()

      // Fixed, non-scrolling layout — the restricted-apps view scrolls internally instead.
      // No NavigationStack large title: it would latch onto the inner ScrollView and drag
      // the whole screen around when that list scrolls.
      VStack(spacing: 16) {
        header

        StatusBanner()

        if access.accessState != .fullAccess {
          TrialChip(access: access) { showPaywall = true }
        }

        AppCard(pickerPresented: $isShowingRestrict, onTap: openPicker)

        ScheduleCard()

        Spacer(minLength: 16)

        PinnedActions(
          primaryTitle: primaryTitle,
          primaryLocked: model.insideInterval,
          primaryDisabled: primaryDisabled,
          quickRestrictDisabled: isQuickRestrictDisabled,
          onPrimary: onPrimary,
          onRestrictHour: restrictForNextHour
        )
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .toast(isPresenting: $showToast, alert: {
      AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "Cannot remove apps from block"))
    })
    .toast(isPresenting: $showInvalidatedWarning, duration: 0, tapToDismiss: true, alert: {
      AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "App selection was reset, please re-select apps"))
    })
    .onChange(of: model.selectionToRestrict) { _ in
      // While a block is active, apps may be added but not removed. A removal fails
      // validation: warn and revert to the saved (enforced) selection.
      if model.insideInterval && !model.validateRestriction() {
        showToast = true
        model.loadSelection()
        return
      }
      model.saveSelection()
      showInvalidatedWarning = false
      applySchedule()
    }
    .onChange(of: model.start) { _ in applySchedule() }
    .onChange(of: model.end) { _ in applySchedule() }
    .onChange(of: model.blockOutsideWindow) { _ in applySchedule() }
    .onChange(of: model.notificationsEnabled) { newValue in
      if newValue && !model.isEmpty() {
        let bi = model.blockedInterval
        Schedule.setNotificationSchedule(restrictionStart: bi.start, restrictionEnd: bi.end)
      } else {
        DeviceActivityCenter().stopMonitoring([.notificationSchedule])
      }
    }
    .onAppear {
      model.loadSelection()
      // Source-of-truth sync (also migrates pre-arm-flag users): armed iff a daily schedule exists.
      model.isArmed = DeviceActivityCenter().activities.contains(.daily)
      if model.selectionIsInvalidated() {
        showInvalidatedWarning = true
      }
    }
    .task {
      // Skip launch-time StoreKit work under the unit-test runner or QA mode — AppTransaction
      // can block / prompt for an Apple-ID sign-in on a simulator without one.
      guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
            ProcessInfo.processInfo.environment["UNPLUG_SKIP_FC"] == nil else { return }
      await access.refreshAccess()
    }
    .fullScreenCover(isPresented: $showPaywall) {
      PaywallView()
        .environmentObject(access)
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
        .environmentObject(model)
    }
    .alert("Start blocking?", isPresented: Binding(
      get: { armRequest != nil },
      set: { if !$0 { armRequest = nil } }
    ), presenting: armRequest) { req in
      Button(req == .hour ? "Block for an hour" : "Start blocking") {
        switch req {
        case .schedule: performArm()
        case .hour: performRestrictHour()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: { req in
      Text(confirmMessage(req))
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(Model())
  }
}
