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

struct ContentView: View {
  @State private var isShowingRestrict = false
  
  @EnvironmentObject var model: Model
  @State var showToast: Bool = false
  
  static let screenWidth = UIScreen.main.bounds.size.width
  
  private var isQuickRestrictDisabled: Bool {
    model.insideInterval || model.selectionToRestrict.applicationTokens.isEmpty
  }
 
  var body: some View {
    NavigationView {
      ZStack {
        VStack() {
          HStack {
            Text("Unskippable app limits").padding(.horizontal).foregroundStyle(.secondary)
            Spacer()
          }
          
          // Block Status Pill
          HStack(alignment: .center, spacing: 8) {
            Circle()
              .fill(model.insideInterval ? .red : .gray)
              .frame(width: 8, height: 8)
            Text(model.insideInterval ? "Block active" : "Block inactive")
              .font(.subheadline)
              .foregroundStyle(model.insideInterval ? .primary : .secondary)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(.secondary.opacity(0.1))
          .clipShape(Capsule())
          .padding(.horizontal)
          .padding(.vertical, 10)
          
         
          if model.selectionToRestrict.applicationTokens.count != 0 {
            Text("You have restricted \(model.selectionToRestrict.applicationTokens.count) apps and \(model.selectionToRestrict.webDomainTokens.count) websites").padding(0)
          }
          
          VStack {
            DatePicker("Schedule start", selection: $model.start, displayedComponents: .hourAndMinute)
              .disabled(model.insideInterval)
              .foregroundColor(model.insideInterval ? Color(uiColor: .systemGray) : .primary)
            DatePicker("Schedule End", selection: $model.end, displayedComponents: .hourAndMinute)
              .disabled(model.insideInterval)
              .foregroundColor(model.insideInterval ? Color(uiColor: .systemGray) : .primary)
          }.padding(20)
          
          // Notification Toggle
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Toggle("Send refocus notifications", isOn: $model.notificationsEnabled)
                .tint(Style.primaryColor)
              Spacer()
            }
            if model.notificationsEnabled {
              HStack {
                Image(systemName: "bell.badge")
                  .foregroundColor(Style.primaryColor)
                  .font(.system(size: 14))
                Text("Get notified when using restricted apps outside scheduled restriction")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            } else {
              HStack {
                Image(systemName: "bell.slash")
                  .foregroundColor(Color.gray)
                  .font(.system(size: 14))
                Text("Get notified when using restricted apps outside scheduled restriction")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
          }
          .padding(.horizontal, 30)
          .padding(.bottom, 15)
          
          Button(model.insideInterval ? "Add apps to restriction" : "Select apps to restrict") {
            isShowingRestrict = true
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

          // New Quick Restrict Button
          Button("Restrict for next hour") {
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
          .disabled(isQuickRestrictDisabled)

          if model.insideInterval {
            HStack {
              Image(systemName: "exclamationmark.lock").foregroundColor(Color(uiColor: .systemPink))
                .font(.system(size: 14))
              Text("Limits are locked when active. Apps can still be added to restriction")
                .font(.footnote)
            }.padding(.top, 26)
             .padding(.horizontal, 26)
          } else {
            HStack {
              Image(systemName: "lock.open.trianglebadge.exclamationmark").foregroundColor(Color(uiColor: .systemPink))
                .font(.system(size: 14))
              Text("Limits will be locked when active")
                .font(.footnote)
            }.padding(.top, 26)
             .padding(.horizontal, 26)
          }
          Spacer()
          
        }
      }.toast(isPresenting: $showToast, alert: {
        AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: String(localized: "Cannot remove apps from block"))
      })
      .onChange(of: model.selectionToRestrict) { newValue in
        // Not allowing the user to remove any apps from a block is a bit over the top 
        // if model.validateRestriction() {
           model.saveSelection()
           Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
           if model.notificationsEnabled {
             Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
           }
        // } else {
        //   // TODO: Show warning
        //   print("Cannot remove apps from restrictions")
        //   showToast = true
        //   model.loadSelection()
        // }
      }.onChange(of: model.start) { newValue in
        if !model.isEmpty() {
          Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
          if model.notificationsEnabled {
            Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
          }
        }
      }.onChange(of: model.end) { newValue in
        if !model.isEmpty() {
          Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
          if model.notificationsEnabled {
            Schedule.setNotificationSchedule(restrictionStart: model.start, restrictionEnd: model.end)
          }
        }
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
    }.navigationViewStyle(StackNavigationViewStyle())
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(Model())
  }
}
