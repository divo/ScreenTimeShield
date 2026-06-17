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
    model.insideInterval || model.selectionToRestrict.applicationTokens.isEmpty
  }

  /// Register the daily restriction (+ notification) schedule, unless access has lapsed.
  private func applyScheduleIfPermitted() {
    guard !isExpired else { showPaywall = true; return }
    guard !model.isEmpty() else { return }
    access.startTrialIfNeeded()
    Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
    if model.notificationsEnabled {
      Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
    }
  }

  private func openPickerOrPaywall() {
    if isExpired { showPaywall = true } else { isShowingRestrict = true }
  }

  private func restrictForNextHour() {
    if isExpired { showPaywall = true; return }
    access.startTrialIfNeeded()
    let now = Date()
    let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
    Schedule.setSchedule(start: now, end: oneHourLater, event: model.activityEvent(), repeats: false)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [Color(.systemBackground), Style.primaryColor.opacity(0.12)],
          startPoint: .topTrailing,
          endPoint: .bottomLeading
        )
        .ignoresSafeArea()

        GeometryReader { geo in
          ScrollView {
            VStack(spacing: 16) {
              StatusBanner()

              if access.accessState != .fullAccess {
                TrialChip(access: access) { showPaywall = true }
              }

              AppCard(pickerPresented: $isShowingRestrict, onTap: openPickerOrPaywall)

              ScheduleCard()

              Spacer(minLength: 16)

              PinnedActions(
                isActive: model.insideInterval,
                quickRestrictDisabled: isQuickRestrictDisabled,
                onPrimary: openPickerOrPaywall,
                onRestrictHour: restrictForNextHour
              )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(minHeight: geo.size.height, alignment: .top)
          }
        }
      }
      .navigationTitle("Unplug ∎")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button { showSettings = true } label: {
            Image(systemName: "gearshape")
          }
          .tint(Style.primaryColor)
        }
      }
      .toast(isPresenting: $showToast, alert: {
        AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "Cannot remove apps from block"))
      })
      .toast(isPresenting: $showInvalidatedWarning, duration: 0, tapToDismiss: true, alert: {
        AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "App selection was reset, please re-select apps"))
      })
      .onChange(of: model.selectionToRestrict) { _ in
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
      if access.accessState == .expired { showPaywall = true }
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
