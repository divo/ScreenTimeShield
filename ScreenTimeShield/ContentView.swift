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

struct ContentView: View {
  @State private var isShowingRestrict = false
  
  @EnvironmentObject var model: Model
  @State var showToast: Bool = false
 
  var body: some View {
    NavigationView {
      ZStack {
        VStack {
          HStack {
            Text("Unskippable app limits").padding(.horizontal)
            Spacer()
          }
          
          if model.selectionToRestrict.applicationTokens.count != 0 {
            Text("You have restricted \(model.selectionToRestrict.applicationTokens.count) apps and \(model.selectionToRestrict.webDomainTokens.count) websites").padding(20)
          }
          
          VStack {
            DatePicker("Schedule start", selection: $model.start, displayedComponents: .hourAndMinute)
              .disabled(model.insideInterval)
              .foregroundColor(model.insideInterval ? Color(uiColor: .systemGray) : .primary)
            DatePicker("Schedule End", selection: $model.end, displayedComponents: .hourAndMinute)
              .disabled(model.insideInterval)
              .foregroundColor(model.insideInterval ? Color(uiColor: .systemGray) : .primary)
          }.padding(20)
          Button(model.insideInterval ? "Add apps to restriction" : "Select apps to restrict") {
            isShowingRestrict = true
          }
          .familyActivityPicker(isPresented: $isShowingRestrict, selection: $model.selectionToRestrict)
          .padding(0)
          .controlSize(.large)
          .foregroundColor(.white)
          .buttonStyle(.borderedProminent)
          .tint(Style.primaryColor)
          
          // New Quick Restrict Button
          Button("Restrict for next hour") {
            let now = Date()
            let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
            Schedule.setSchedule(start: now, end: oneHourLater, event: model.activityEvent(), repeats: false)
          }
          .disabled(model.selectionToRestrict.applicationTokens.isEmpty)
          .padding(10)
          .controlSize(.large)
          .foregroundColor(.white)
          .buttonStyle(.borderedProminent)
          .tint(Style.primaryColor)

          if model.insideInterval {
            HStack {
              Image(systemName: "exclamationmark.lock").foregroundColor(Color(uiColor: .systemPink))
              Text("Limits are locked when active. Apps can still be added to restriction")
           }
          } else {
            HStack {
              Image(systemName: "lock.open.trianglebadge.exclamationmark").foregroundColor(Color(uiColor: .systemPink))
              Text("Limits will be locked when active")
            }
          }
          Spacer()
          
        }
      }.toast(isPresenting: $showToast, alert: {
        AlertToast(displayMode: .alert, type: .error(Style.errorColor), title: "Cannot remove apps from block")
      })
      .onChange(of: model.selectionToRestrict) { newValue in
        // Not allowing the user to remove any apps from a block is a bit over the top 
        // if model.validateRestriction() {
           model.saveSelection()
           Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
        // } else {
        //   // TODO: Show warning
        //   print("Cannot remove apps from restrictions")
        //   showToast = true
        //   model.loadSelection()
        // }
      }.onChange(of: model.start) { newValue in
        if !model.isEmpty() {
          Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
        }
      }.onChange(of: model.end) { newValue in
        if !model.isEmpty() {
          Schedule.setSchedule(start: model.start, end: model.end, event: model.activityEvent(), repeats: true)
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
