//
//  AppGrid.swift
//  ScreenTimeShield
//

import SwiftUI
import FamilyControls

/// Grid of the restricted apps / categories / websites, rendered from their
/// FamilyControls tokens. Adds a lock badge to each while a block is active.
struct AppGrid: View {
  @EnvironmentObject var model: Model

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

  var body: some View {
    LazyVGrid(columns: columns, spacing: 14) {
      ForEach(Array(model.selectionToRestrict.applicationTokens), id: \.self) { token in
        icon { Label(token).labelStyle(.iconOnly) }
      }
      ForEach(Array(model.selectionToRestrict.categoryTokens), id: \.self) { token in
        icon { Label(token).labelStyle(.iconOnly) }
      }
      ForEach(Array(model.selectionToRestrict.webDomainTokens), id: \.self) { token in
        icon { Label(token).labelStyle(.iconOnly) }
      }
    }
  }

  private func icon<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    // FamilyControls token icons are system-drawn at ~25pt and ignore `.font`; `.scaleEffect`
    // is the only way to enlarge them (with some blur). scaleEffect keeps the layout size, so
    // the frame reserves the grid cell while the scaled icon sits centered in it.
    content()
      .scaleEffect(2.0)
      .frame(width: 56, height: 56)
      .overlay(alignment: .bottomTrailing) {
        if model.insideInterval {
          Image(systemName: "lock.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(Style.primaryColor, in: Circle())
            .overlay(Circle().stroke(.background, lineWidth: 1.5))
        }
      }
  }
}

#Preview {
  // Empty in previews — FamilyControls tokens can't be synthesized outside a real selection.
  AppGrid()
    .environmentObject(Model())
    .padding()
}
