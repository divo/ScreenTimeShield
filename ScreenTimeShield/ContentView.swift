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
  private let appGridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

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
      .frame(maxWidth: .infinity, alignment: .leading)
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
      .font(.system(size: 34))
      .frame(width: 52, height: 52)
      .overlay(alignment: .bottomTrailing) {
        if model.insideInterval {
          Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .bold))
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

// MARK: - SettingsView

/// Settings sheet reached from the main-screen toolbar gear. Houses the refocus
/// notifications toggle (moved off the main screen) and the QA/Debug entry.
struct SettingsView: View {
  @EnvironmentObject var model: Model
  @Environment(\.dismiss) private var dismiss
  @State private var showQAMenu = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Send refocus notifications", isOn: $model.notificationsEnabled)
            .tint(Style.primaryColor)
        } footer: {
          Text("Get notified when using restricted apps outside of blocked hours")
        }

        // QA / Debug entry point — remove (revert this commit) before production.
        Section {
          Button("QA / Debug") { showQAMenu = true }
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(isPresented: $showQAMenu) {
        QAMenuView()
          .environmentObject(AccessController.shared)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(Model())
  }
}

// MARK: - ScheduleRangeSlider

/// A horizontal 24-hour dual-handle range selector bound to two `Date` values
/// (hour/minute only). Same-day window for now — overnight (end < start) is a
/// known follow-up.
struct ScheduleRangeSlider: View {
  @Binding var start: Date
  @Binding var end: Date
  var locked: Bool = false
  /// When non-nil, draws a "now" marker on the track (used while a block is active).
  var now: Date? = nil

  private static let trackSpace = "ScheduleRangeSliderTrack"
  private let snapMinutes = 5
  private let minGap = 15            // minimum window length, in minutes
  private let totalMinutes = 24 * 60
  private let trackHeight: CGFloat = 8
  private let thumbSize: CGFloat = 28

  private func minutes(of date: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
  }

  private func dateAtMinute(_ minute: Int) -> Date {
    let m = max(0, min(totalMinutes, minute))
    return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
  }

  private func x(for minute: Int, width: CGFloat) -> CGFloat {
    width * CGFloat(minute) / CGFloat(totalMinutes)
  }

  private func minute(forX px: CGFloat, width: CGFloat) -> Int {
    let raw = Int((px / max(width, 1)) * CGFloat(totalMinutes))
    let snapped = Int((Double(raw) / Double(snapMinutes)).rounded()) * snapMinutes
    return max(0, min(totalMinutes, snapped))
  }

  private func label(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { geo in
        let w = geo.size.width
        let startX = x(for: minutes(of: start), width: w)
        let endX = x(for: minutes(of: end), width: w)

        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: trackHeight)

          Capsule()
            .fill(LinearGradient(colors: [Style.primaryColor, .purple],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: max(0, endX - startX), height: trackHeight)
            .offset(x: startX)
            .opacity(locked ? 0.45 : 1)

          if let now {
            nowMarker(at: x(for: minutes(of: now), width: w), date: now)
          }

          handle(at: startX, date: start, edge: .start, width: w)
          handle(at: endX, date: end, edge: .end, width: w)
        }
        .frame(height: thumbSize + 28, alignment: .center)
        .coordinateSpace(name: Self.trackSpace)
      }
      .frame(height: thumbSize + 28)

      hourAxis
    }
  }

  // MARK: Pieces

  private enum Edge { case start, end }

  private func handle(at cx: CGFloat, date: Date, edge: Edge, width: CGFloat) -> some View {
    VStack(spacing: 6) {
      Text(label(date))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Style.primaryColor.opacity(locked ? 0.4 : 1), in: Capsule())

      Circle()
        .fill(.white)
        .frame(width: thumbSize, height: thumbSize)
        .overlay(Circle().stroke(Style.primaryColor.opacity(locked ? 0.4 : 1), lineWidth: 3))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }
    .opacity(locked ? 0.6 : 1)
    .offset(x: cx - thumbSize / 2)
    .gesture(locked ? nil : DragGesture(coordinateSpace: .named(Self.trackSpace))
      .onChanged { value in
        let m = minute(forX: value.location.x, width: width)
        switch edge {
        case .start:
          start = dateAtMinute(min(m, minutes(of: end) - minGap))
        case .end:
          end = dateAtMinute(max(m, minutes(of: start) + minGap))
        }
      })
  }

  private func nowMarker(at cx: CGFloat, date: Date) -> some View {
    VStack(spacing: 2) {
      Text("now \(label(date))")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Style.primaryColor)
        .fixedSize()
      Rectangle()
        .fill(Style.primaryColor)
        .frame(width: 2, height: thumbSize + 6)
    }
    .offset(x: cx - 1, y: -2)
  }

  private var hourAxis: some View {
    GeometryReader { geo in
      let w = geo.size.width
      ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
        let cx = w * CGFloat(hour) / 24
        Text(hour == 24 ? "24:00" : String(format: "%02d:00", hour))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize()
          .frame(width: 44)
          .offset(x: min(max(cx - 22, 0), w - 44))
      }
    }
    .frame(height: 14)
  }
}

struct ScheduleRangeSlider_Previews: PreviewProvider {
  struct Harness: View {
    @State var start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    @State var end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
    var locked: Bool
    var now: Date?
    var body: some View {
      ScheduleRangeSlider(start: $start, end: $end, locked: locked, now: now)
        .padding(24)
    }
  }
  static var previews: some View {
    Group {
      Harness(locked: false, now: nil)
        .previewDisplayName("Editable")
      Harness(locked: true, now: Calendar.current.date(bySettingHour: 13, minute: 36, second: 0, of: Date()))
        .previewDisplayName("Locked + now")
    }
    .previewLayout(.sizeThatFits)
  }
}
