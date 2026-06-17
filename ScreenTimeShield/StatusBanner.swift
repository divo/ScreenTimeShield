//
//  StatusBanner.swift
//  ScreenTimeShield
//

import SwiftUI

/// Slim banner leading the main screen: block active/inactive + the relevant time.
struct StatusBanner: View {
  @EnvironmentObject var model: Model
  @State private var isPulsing = false

  private func timeString(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }

  private func setPulsing(_ active: Bool) {
    if active {
      withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { isPulsing = true }
    } else {
      withAnimation(.easeInOut(duration: 0.2)) { isPulsing = false }
    }
  }

  var body: some View {
    HStack(spacing: 10) {
      // Soft, position-stable strobe — only the opacity animates (explicit, scoped), so the
      // dot never changes size or position.
      Circle()
        .fill(model.insideInterval ? Style.primaryColor : Color.secondary)
        .frame(width: 9, height: 9)
        .opacity(isPulsing ? 0.4 : 1.0)
        .onAppear { setPulsing(model.insideInterval) }
        .onChange(of: model.insideInterval) { setPulsing($0) }

      if model.insideInterval {
        Text("Block active").fontWeight(.semibold)
          + Text("  ends \(timeString(model.end))").foregroundColor(.secondary)
      } else {
        Text("Block inactive").fontWeight(.semibold)
          + Text("  locks at \(timeString(model.start))").foregroundColor(.secondary)
      }
      Spacer(minLength: 0)
    }
    .font(.subheadline)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(model.insideInterval ? Style.primaryColor.opacity(0.12) : Color.secondary.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

#Preview {
  StatusBanner()
    .environmentObject(Model())
    .padding()
}
