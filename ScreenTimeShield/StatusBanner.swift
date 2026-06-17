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

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(model.insideInterval ? Style.primaryColor : Color.secondary)
        .frame(width: 9, height: 9)
        .opacity(model.insideInterval ? (isPulsing ? 0.3 : 1.0) : 1.0)
        .animation(model.insideInterval ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isPulsing)
        .onChange(of: model.insideInterval) { isPulsing = $0 }
        .onAppear { isPulsing = model.insideInterval }

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
