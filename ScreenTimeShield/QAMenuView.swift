//
//  QAMenuView.swift
//  ScreenTimeShield
//
//  In-app QA/debug controls for the trial + paywall flow. Drives AccessController state
//  in-process — no StoreKit, no FamilyControls. Present in release builds on purpose
//  (TestFlight has no DEBUG); the entry point is exposed in a separate, revertable commit.
//

import SwiftUI
import UnplugCore

struct QAMenuView: View {
  @EnvironmentObject var access: AccessController
  @Environment(\.dismiss) private var dismiss
  @State private var showPaywall = false

  private var stateLabel: String {
    switch access.accessState {
    case .trial: return "trial"
    case .expired: return "expired"
    case .fullAccess: return "fullAccess"
    }
  }

  var body: some View {
    NavigationView {
      Form {
        Section {
          NavigationLink { QAChecklistView() } label: { Text(verbatim: "QA checklist (device)") }
        }

        Section {
          ForEach(QATrialPreset.allCases) { preset in
            Button { access.qaSetTrial(preset) } label: { Text(verbatim: preset.label) }
          }
        } header: {
          Text(verbatim: "Set trial state")
        } footer: {
          Text(verbatim: "Rewrites the trial clock once, then the app runs normally. A real purchase "
               + "still wins: turn on the switch below to see these states after buying.")
        }

        Section {
          Toggle(isOn: Binding(
            get: { access.qaIgnoresEntitlement },
            set: { access.qaIgnoresEntitlement = $0 }
          )) {
            Text(verbatim: "Ignore purchase & grandfathering")
          }
        } footer: {
          Text(verbatim: "Treats this device as unpaid, so the trial and paywall screens are reachable "
               + "after a sandbox purchase. A banner shows on the main screen while it is on. Buying "
               + "or restoring turns it off.")
        }

        Section("Resulting state") {
          row("Access state", stateLabel)
          row("Trial days remaining", "\(access.trialDaysRemaining)")
          row("Full access", access.hasFullAccess ? "yes" : "no")
          row("Times stopped", "\(access.timesStopped)")
        }

        Section {
          row("StoreKit purchased", access.storeKit.isPurchased ? "yes" : "no")
          row("StoreKit grandfathered", access.storeKit.isGrandfathered ? "yes" : "no")
        } header: {
          Text("Real StoreKit state")
        } footer: {
          Text(verbatim: "What StoreKit actually reports, before the ignore switch. If \"grandfathered\" is yes on "
               + "a fresh install, the test environment's synthesized original-purchase date predates "
               + "PricingConfig.cutoverDate — the paywall would be unreachable without the ignore switch.")
        }

        Section("Times stopped (stat gate ≥ \(PricingConfig.statThreshold))") {
          HStack {
            ForEach([0, 4, 5, 23], id: \.self) { n in
              Button("\(n)") { access.qaSetTimesStopped(n) }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
          }
        }

        Section {
          Button("Open paywall") { showPaywall = true }
        }

        Section {
          Button("Reset to fresh install", role: .destructive) {
            access.qaResetToFreshInstall()
            dismiss()
          }
        } footer: {
          Text("Wipes selection, schedule, trial, and all local state.")
        }
      }
      .navigationTitle("QA / Debug")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .fullScreenCover(isPresented: $showPaywall) {
        PaywallView().environmentObject(access)
      }
    }
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label)
      Spacer()
      Text(value).foregroundStyle(.secondary)
    }
  }
}
