//
//  ScheduleCard.swift
//  ScreenTimeShield
//

import SwiftUI

/// Card wrapping the 24h schedule range slider, with a locked caption while active.
struct ScheduleCard: View {
  @EnvironmentObject var model: Model

  private let cardCorner: CGFloat = 16

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ScheduleRangeSlider(
        start: $model.start,
        end: $model.end,
        locked: model.insideInterval,
        now: model.insideInterval ? Date() : nil
      )
      if model.insideInterval {
        Label("Schedule locked while a block is active", systemImage: "lock")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Daily schedule")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .padding(16)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
  }
}

#Preview {
  ScheduleCard()
    .environmentObject(Model())
    .padding()
}
