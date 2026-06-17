//
//  PinnedActions.swift
//  ScreenTimeShield
//

import SwiftUI

/// The two bottom-pinned CTAs: primary select/add, and "Restrict for next hour".
/// Purely presentational — the screen owns the actions.
struct PinnedActions: View {
  var isActive: Bool
  var quickRestrictDisabled: Bool
  var onPrimary: () -> Void
  var onRestrictHour: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Button(action: onPrimary) {
        Text(isActive ? "Add apps to restriction" : "Select apps to restrict")
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

      Button(action: onRestrictHour) {
        Text("Restrict for next hour")
          .font(.headline)
          .foregroundStyle(quickRestrictDisabled ? Color.secondary : Style.primaryColor)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(
            (quickRestrictDisabled ? Color.secondary : Style.primaryColor).opacity(0.12)
          )
          .clipShape(RoundedRectangle(cornerRadius: 14))
      }
      .disabled(quickRestrictDisabled)
    }
  }
}

#Preview {
  PinnedActions(isActive: false, quickRestrictDisabled: false, onPrimary: {}, onRestrictHour: {})
    .padding()
}
