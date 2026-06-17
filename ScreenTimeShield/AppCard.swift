//
//  AppCard.swift
//  ScreenTimeShield
//

import SwiftUI
import FamilyControls

/// Card showing what's restricted: a count header and the app grid (or an empty
/// state). Tapping it, or presenting `pickerPresented`, opens the system picker.
struct AppCard: View {
  @EnvironmentObject var model: Model
  @Binding var pickerPresented: Bool
  var onTap: () -> Void

  private let cardCorner: CGFloat = 16

  private var appCount: Int {
    model.selectionToRestrict.applicationTokens.count + model.selectionToRestrict.categoryTokens.count
  }
  private var siteCount: Int { model.selectionToRestrict.webDomainTokens.count }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(model.insideInterval ? "Restricted" : "Will be restricted")
          .font(.headline)
        Spacer()
        Text("\(appCount) apps · \(siteCount) websites")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if model.isEmpty() {
        VStack(spacing: 8) {
          Image(systemName: "apps.iphone")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text("No apps or websites selected yet")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
      } else {
        // Natural-height grid — the outer ScrollView handles overflow for large
        // selections (avoids janky same-axis nested scrolling).
        AppGrid().padding(.vertical, 2)
      }
    }
    .padding(16)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
    .contentShape(RoundedRectangle(cornerRadius: cardCorner))
    .onTapGesture { onTap() }
    .familyActivityPicker(isPresented: $pickerPresented, selection: $model.selectionToRestrict)
  }
}
