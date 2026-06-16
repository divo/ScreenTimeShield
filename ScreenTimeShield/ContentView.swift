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
  @State private var isPulsing = false

  private let cardCorner: CGFloat = 16
  private let appGridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

  private var isExpired: Bool { access.accessState == .expired }

  private var isQuickRestrictDisabled: Bool {
    model.insideInterval || model.selectionToRestrict.applicationTokens.isEmpty
  }

  private var appCount: Int {
    model.selectionToRestrict.applicationTokens.count + model.selectionToRestrict.categoryTokens.count
  }
  private var siteCount: Int { model.selectionToRestrict.webDomainTokens.count }

  private func timeString(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
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
              statusBanner

              if access.accessState != .fullAccess {
                trialChip
              }

              appCard

              scheduleCard

              Spacer(minLength: 16)

              pinnedActions
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

  // MARK: - Sections

  private var statusBanner: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(model.insideInterval ? Style.primaryColor : Color.secondary)
        .frame(width: 9, height: 9)
        .opacity(model.insideInterval ? (isPulsing ? 0.3 : 1.0) : 1.0)
        .animation(model.insideInterval ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isPulsing)
        .onChange(of: model.insideInterval) { isPulsing = $0 }
        .onAppear { isPulsing = model.insideInterval }

      if model.insideInterval {
        Text("Block active").fontWeight(.semibold)
          + Text("  ends \(timeString(model.end))").foregroundColor(.secondary)
      } else {
        Text("Block inactive").fontWeight(.semibold)
          + Text("  locks at \(timeString(model.start))").foregroundColor(.secondary)
      }
      Spacer(minLength: 0)
    }
    .font(.subheadline)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(model.insideInterval ? Style.primaryColor.opacity(0.12) : Color.secondary.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private var trialChip: some View {
    Button { showPaywall = true } label: {
      HStack(spacing: 6) {
        Image(systemName: isExpired ? "lock" : "clock.badge")
        (isExpired
         ? Text("Trial ended · Unlock Unplug")
         : Text("\(access.trialDaysRemaining) days left in trial · Unlock"))
          .fontWeight(.medium)
      }
      .font(.footnote)
      .foregroundStyle(Style.primaryColor)
      .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  private var appCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(model.insideInterval ? "Restricted" : "Will be restricted")
          .font(.headline)
        Spacer()
        Text("\(appCount) apps · \(siteCount) websites")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if model.isEmpty() {
        VStack(spacing: 8) {
          Image(systemName: "apps.iphone")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text("No apps or websites selected yet")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
      } else {
        // Natural-height grid — the outer ScrollView handles overflow for large
        // selections (avoids janky same-axis nested scrolling).
        appGrid.padding(.vertical, 2)
      }
    }
    .padding(16)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
    .contentShape(RoundedRectangle(cornerRadius: cardCorner))
    .onTapGesture { openPickerOrPaywall() }
    .familyActivityPicker(isPresented: $isShowingRestrict, selection: $model.selectionToRestrict)
  }

  private var appGrid: some View {
    LazyVGrid(columns: appGridColumns, spacing: 14) {
      ForEach(Array(model.selectionToRestrict.applicationTokens), id: \.self) { token in
        appIcon { Label(token).labelStyle(.iconOnly) }
      }
      ForEach(Array(model.selectionToRestrict.categoryTokens), id: \.self) { token in
        appIcon { Label(token).labelStyle(.iconOnly) }
      }
      ForEach(Array(model.selectionToRestrict.webDomainTokens), id: \.self) { token in
        appIcon { Label(token).labelStyle(.iconOnly) }
      }
    }
  }

  private func appIcon<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
      .font(.system(size: 64))
      .frame(width: 64, height: 64)
      .overlay(alignment: .bottomTrailing) {
        if model.insideInterval {
          Image(systemName: "lock.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(Style.primaryColor, in: Circle())
            .overlay(Circle().stroke(.background, lineWidth: 1.5))
        }
      }
  }

  private var scheduleCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      ScheduleRangeSlider(
        start: $model.start,
        end: $model.end,
        locked: model.insideInterval,
        now: model.insideInterval ? Date() : nil
      )
      if model.insideInterval {
        Label("Schedule locked while a block is active", systemImage: "lock")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Daily schedule")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .padding(16)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
  }

  private var pinnedActions: some View {
    VStack(spacing: 8) {
      Button {
        openPickerOrPaywall()
      } label: {
        Text(model.insideInterval ? "Add apps to restriction" : "Select apps to restrict")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(
            LinearGradient(colors: [Style.primaryColor, .purple],
                           startPoint: .leading, endPoint: .trailing)
          )
          .clipShape(RoundedRectangle(cornerRadius: 14))
      }

      Button {
        if isExpired { showPaywall = true; return }
        access.startTrialIfNeeded()
        let now = Date()
        let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        Schedule.setSchedule(start: now, end: oneHourLater, event: model.activityEvent(), repeats: false)
      } label: {
        Text("Restrict for next hour")
          .font(.headline)
          .foregroundStyle(isQuickRestrictDisabled ? Color.secondary : Style.primaryColor)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(
            (isQuickRestrictDisabled ? Color.secondary : Style.primaryColor).opacity(0.12)
          )
          .clipShape(RoundedRectangle(cornerRadius: 14))
      }
      .disabled(isQuickRestrictDisabled)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(Model())
  }
}
