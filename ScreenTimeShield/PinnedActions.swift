//
//  PinnedActions.swift
//  ScreenTimeShield
//

import SwiftUI

/// The two bottom-pinned CTAs: the primary block control (Start / Stop / Blocking) and
/// "Restrict for next hour". Purely presentational — the screen owns the state and actions.
struct PinnedActions: View {
  var primaryTitle: String
  var primaryLocked: Bool       // active block — shows a lock and is non-interactive
  var primaryDisabled: Bool
  var quickRestrictDisabled: Bool
  var onPrimary: () -> Void
  var onRestrictHour: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Button(action: onPrimary) {
        HStack(spacing: 6) {
          if primaryLocked {
            Image(systemName: "lock.fill")
          }
          Text(primaryTitle)
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
          LinearGradient(colors: [Style.primaryColor, .purple],
                         startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(primaryDisabled ? 0.5 : 1)
      }
      .disabled(primaryDisabled)

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
  VStack(spacing: 24) {
    PinnedActions(primaryTitle: "Start blocking", primaryLocked: false, primaryDisabled: false,
                  quickRestrictDisabled: false, onPrimary: {}, onRestrictHour: {})
    PinnedActions(primaryTitle: "Stop blocking", primaryLocked: false, primaryDisabled: false,
                  quickRestrictDisabled: true, onPrimary: {}, onRestrictHour: {})
    PinnedActions(primaryTitle: "Blocking", primaryLocked: true, primaryDisabled: true,
                  quickRestrictDisabled: true, onPrimary: {}, onRestrictHour: {})
  }
  .padding()
}
