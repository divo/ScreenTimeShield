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
  @State private var showQAMenu = false
  @State private var isPulsing = false

  static let screenWidth = UIScreen.main.bounds.size.width

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
 
  var body: some View {
    NavigationView {
      ZStack {
        LinearGradient(
          colors: [Color(.systemBackground), Style.primaryColor.opacity(0.12)],
          startPoint: .topTrailing,
          endPoint: .bottomLeading
        )
        .ignoresSafeArea()

        GeometryReader { geo in
        ScrollView {
        VStack() {
          HStack {
            Text("Unskippable app limits").padding(.horizontal).foregroundStyle(.secondary)
            Spacer()
          }

          // Trial / access banner — always a visible purchase CTA unless the user has full access.
          if access.accessState != .fullAccess {
            Button {
              showPaywall = true
            } label: {
              HStack(spacing: 6) {
                Image(systemName: access.accessState == .expired ? "lock" : "clock.badge")
                (access.accessState == .expired
                 ? Text("Trial ended · Unlock Unplug")
                 : Text("\(access.trialDaysRemaining) days left in trial · Unlock"))
                  .font(.footnote.weight(.medium))
              }
              .foregroundStyle(Style.primaryColor)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          // Block Status Pill
          HStack(alignment: .center, spacing: 8) {
            Circle()
              .fill(model.insideInterval ? .red : .gray)
              .frame(width: 8, height: 8)
              .opacity(model.insideInterval ? (isPulsing ? 0.3 : 1.0) : 1.0)
              .animation(model.insideInterval ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isPulsing)
              .onChange(of: model.insideInterval) { newValue in
                isPulsing = newValue
              }
              .onAppear { isPulsing = model.insideInterval }
            Text(model.insideInterval ? "Block active" : "Block inactive")
              .font(.subheadline)
              .foregroundStyle(model.insideInterval ? .primary : .secondary)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 8)
          .background(.secondary.opacity(0.1))
          .clipShape(Capsule())
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          
         
          Text("You have restricted \(model.selectionToRestrict.applicationTokens.count) apps and \(model.selectionToRestrict.webDomainTokens.count) websites")
            .padding(.vertical, 8)
          
          VStack {
            DatePicker("Schedule Start", selection: $model.start, displayedComponents: .hourAndMinute)
              .disabled(model.insideInterval)
              .foregroundColor(model.insideInterval ? Color(uiColor: .systemGray) : .primary)
            DatePicker("Schedule End", selection: $model.end, displayedComponents: .hourAndMinute)
              .disabled(model.insideInterval)
              .foregroundColor(model.insideInterval ? Color(uiColor: .systemGray) : .primary)
          }
          .padding(16)
          .background(Style.primaryColor.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          
          // Notification Toggle
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Toggle("Send refocus notifications", isOn: $model.notificationsEnabled)
                .tint(Style.primaryColor)
              Spacer()
            }
            HStack(alignment: .top) {
              Image(systemName: model.notificationsEnabled ? "bell.badge" : "bell.slash")
                .foregroundColor(model.notificationsEnabled ? Style.primaryColor : .gray)
                .font(.system(size: 14))
              Text("Get notified when using restricted apps outside of blocked hours")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(16)
          .background(Style.primaryColor.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .padding(.horizontal, 16)
          .padding(.bottom, 16)

          Spacer()

          if model.insideInterval {
            HStack(alignment: .top) {
              Image(systemName: "exclamationmark.lock").foregroundColor(Color(uiColor: .systemPink))
                .font(.system(size: 14))
              Text("Limits are locked when active. Apps can still be added to restriction")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 24)
             .padding(.bottom, 16)
          } else {
            HStack(alignment: .top) {
              Image(systemName: "lock.open.trianglebadge.exclamationmark").foregroundColor(Color(uiColor: .systemPink))
                .font(.system(size: 14))
              Text("Limits will be locked when active")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 24)
             .padding(.bottom, 16)
          }

          Button(model.insideInterval ? "Add apps to restriction" : "Select apps to restrict") {
            if isExpired { showPaywall = true } else { isShowingRestrict = true }
          }
          .foregroundColor(.white)
          .buttonStyle(.borderedProminent)
          .tint(.clear)
          .padding(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
          .frame(maxWidth: ContentView.screenWidth - 100)
          .background(
            LinearGradient(
              colors: [Style.primaryColor, .purple],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .circular))
          .familyActivityPicker(isPresented: $isShowingRestrict, selection: $model.selectionToRestrict)
          .tint(Style.primaryColor)

          Button("Restrict for next hour") {
            if isExpired { showPaywall = true; return }
            access.startTrialIfNeeded()
            let now = Date()
            let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
            Schedule.setSchedule(start: now, end: oneHourLater, event: model.activityEvent(), repeats: false)
          }
          .foregroundColor(.white)
          .buttonStyle(.borderedProminent)
          .tint(.clear)
          .padding(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
          .frame(maxWidth: ContentView.screenWidth - 100)
          .background(isQuickRestrictDisabled ? .secondary : Style.primaryColor)
          .clipShape(RoundedRectangle(cornerRadius: 12.0, style: .circular))
          .padding(.top, 8)
          .padding(.bottom, 16)
          .disabled(isQuickRestrictDisabled)

          // QA / Debug entry point — remove (revert this commit) before production.
          Button("QA / Debug") { showQAMenu = true }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)

        }
        .frame(minHeight: geo.size.height, alignment: .top)
        }
        }
      }.toast(isPresenting: $showToast, alert: {
        AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "Cannot remove apps from block"))
      })
      .toast(isPresenting: $showInvalidatedWarning, duration: 0, tapToDismiss: true, alert: {
        AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "App selection was reset, please re-select apps"))
      })
      .onChange(of: model.selectionToRestrict) { newValue in
           model.saveSelection()
           showInvalidatedWarning = false
           applyScheduleIfPermitted()
      }.onChange(of: model.start) { newValue in
        applyScheduleIfPermitted()
      }.onChange(of: model.end) { newValue in
        applyScheduleIfPermitted()
      }.onChange(of: model.notificationsEnabled) { newValue in
        if newValue && !model.isEmpty() {
          Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
        } else {
          DeviceActivityCenter().stopMonitoring([.notificationSchedule])
        }
      }.navigationTitle("Unplug ∎")
        .navigationBarTitleDisplayMode(.large)
    }.onAppear {
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
    .sheet(isPresented: $showQAMenu) {
      QAMenuView()
        .environmentObject(access)
    }
    .navigationViewStyle(StackNavigationViewStyle())
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
