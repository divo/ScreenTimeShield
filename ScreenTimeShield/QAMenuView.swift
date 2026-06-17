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
        Section("Current state") {
          row("Access state", stateLabel)
          row("Trial days remaining", "\(access.trialDaysRemaining)")
          row("Times stopped", "\(access.timesStopped)")
          row("Full access", access.hasFullAccess ? "yes" : "no")
        }

        Section("Trial") {
          Button("Start trial now") { access.qaStartTrial() }
          Button("Expire trial") { access.qaExpireTrial() }
          Button("Reset trial (fresh install)") { access.qaResetTrial() }
        }

        Section("Entitlement") {
          Toggle("Force full access", isOn: Binding(
            get: { access.qaForceFullAccess },
            set: { access.qaSetFullAccess($0) }
          ))
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
