//
//  TrialChip.swift
//  ScreenTimeShield
//

import SwiftUI

/// Trial-countdown / purchase CTA shown unless the user has full access.
struct TrialChip: View {
  @ObservedObject var access: AccessController
  var onUnlock: () -> Void

  private var isExpired: Bool { access.accessState == .expired }

  var body: some View {
    Button(action: onUnlock) {
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
}

#Preview {
  TrialChip(access: AccessController.shared) {}
    .padding()
}
