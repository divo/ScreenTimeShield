//
//  SettingsView.swift
//  ScreenTimeShield
//

import SwiftUI

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

        // ⚠️ DEV BUILD — QA / Debug entry point is ENABLED. Comment this Section out again before
        // submitting to the App Store. See the revert checklist in status.md.
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
