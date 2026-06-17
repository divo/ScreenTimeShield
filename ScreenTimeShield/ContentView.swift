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

  private var isExpired: Bool { access.accessState == .expired }

  private var isQuickRestrictDisabled: Bool {
    model.insideInterval || isExpired || model.selectionToRestrict.applicationTokens.isEmpty
  }

  /// Register the daily restriction (+ notification) schedule, unless access has lapsed.
  /// When expired we silently skip scheduling — the paywall is only surfaced by the trial
  /// chip and the primary CTA, not as a side effect of editing.
  private func applyScheduleIfPermitted() {
    guard !isExpired else { return }
    guard !model.isEmpty() else { return }
    access.startTrialIfNeeded()
    Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
    if model.notificationsEnabled {
      Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
    }
  }

  /// App-card tap: open the picker, never the paywall (expired users go through the CTAs).
  private func openPicker() {
    guard !isExpired else { return }
    isShowingRestrict = true
  }

  /// Primary CTA — one of the only two places (with the trial chip) that surfaces the paywall.
  private func primaryAction() {
    if isExpired { showPaywall = true } else { isShowingRestrict = true }
  }

  private func restrictForNextHour() {
    access.startTrialIfNeeded()
    let now = Date()
    let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
    Schedule.setSchedule(start: now, end: oneHourLater, event: model.activityEvent(), repeats: false)
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
          isActive: model.insideInterval,
          quickRestrictDisabled: isQuickRestrictDisabled,
          onPrimary: primaryAction,
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
      applyScheduleIfPermitted()
    }
    .onChange(of: model.start) { _ in applyScheduleIfPermitted() }
    .onChange(of: model.end) { _ in applyScheduleIfPermitted() }
    .onChange(of: model.notificationsEnabled) { newValue in
      if newValue && !model.isEmpty() {
        Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
      } else {
        DeviceActivityCenter().stopMonitoring([.notificationSchedule])
      }
    }
    .onAppear {
      model.loadSelection()
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
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(Model())
  }
}
