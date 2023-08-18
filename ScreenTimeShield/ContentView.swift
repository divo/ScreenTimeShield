//
//  ContentView.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import SwiftUI
import FamilyControls
import Foundation

struct ContentView: View {
  @State private var isShowingRestrict = false
  
  @EnvironmentObject var model: Model
  @State var start: Date = Calendar.current.startOfDay(for: Date.now)
  @State var end: Date = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
  @State var activeRestriction = ContentView.restrictionSet()
  
  var body: some View {
    NavigationView {
      VStack {
        HStack {
          Text("Unskippable app limits").padding(.horizontal)
          Spacer()
        }
        
        if activeRestriction {
          Text("You have a restriction setup").padding(20)
        }
        
        VStack {
          DatePicker("Schedule start", selection: $start, displayedComponents: .hourAndMinute)
          DatePicker("Schedule End", selection: $end, displayedComponents: .hourAndMinute)
        }.padding(20)
        Button("Select apps to restrict") {
          isShowingRestrict = true
        }.familyActivityPicker(isPresented: $isShowingRestrict, selection: $model.selectionToRestrict)
          .padding(20)
          .foregroundColor(Style.primaryColor)
        Spacer()
        
      }.onChange(of: model.selectionToRestrict) { newValue in
        model.setRestrictions()
        Schedule.setSchedule(start: start, end: end)
        activeRestriction = ContentView.restrictionSet()
      }.navigationTitle("Unplug ∎")
        .navigationBarTitleDisplayMode(.large)
    }
  }
  
  static func restrictionSet() -> Bool {
    UserDefaults().object(forKey: "active-restriction") != nil
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(Model())
  }
}
