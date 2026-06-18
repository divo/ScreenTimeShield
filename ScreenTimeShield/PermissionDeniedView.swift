//
//  PermissionDeniedView.swift
//  ScreenTimeShield
//
//  Shown in place of the app card when Family Controls (Screen Time) authorization
//  isn't granted. Without it the app can't enforce any blocks. There's no per-app
//  Screen Time toggle in Settings, but re-calling requestAuthorization re-shows the
//  system prompt — so "Allow access" re-requests directly.
//

import SwiftUI

struct PermissionDeniedView: View {
  var onAllow: () -> Void

  private let cardCorner = Style.Radius.card

  var body: some View {
    VStack(spacing: Style.Spacing.md) {
      Spacer(minLength: 0)

      Image(systemName: "lock.shield")
        .font(.system(size: 44, weight: .regular))
        .foregroundStyle(Style.primaryColor)

      VStack(spacing: Style.Spacing.xs) {
        Text("Screen Time access is off")
          .font(.headline)
          .multilineTextAlignment(.center)
        Text("Allow access so Unplug can block your apps.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Spacer(minLength: 0)

      Button(action: onAllow) {
        Text("Allow access")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Style.primaryGradient)
          .clipShape(RoundedRectangle(cornerRadius: Style.Radius.button))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(Style.Spacing.md)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
  }
}

#Preview {
  PermissionDeniedView(onAllow: {})
    .padding()
}
