//
//  AppCard.swift
//  ScreenTimeShield
//

import SwiftUI
import FamilyControls

/// Card showing what's restricted: a header with an explicit Add/Edit action, and the
/// app list (or a tappable empty state). `onTap` / presenting `pickerPresented` opens the picker.
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
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(model.insideInterval ? "Restricted" : "Will be restricted")
            .font(.headline)
          if !model.isEmpty() {
            Text("\(appCount) apps · \(siteCount) websites")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        if !model.isEmpty() {
          Button(action: onTap) {
            Label("Add", systemImage: "plus")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Style.primaryColor)
          }
        }
      }

      if model.isEmpty() {
        Button(action: onTap) {
          VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
              .font(.largeTitle)
              .foregroundStyle(Style.primaryColor)
            Text("Choose apps & websites")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Style.primaryColor)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      } else {
        RestrictedAppList()
      }
    }
    .padding(16)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
    .familyActivityPicker(isPresented: $pickerPresented, selection: $model.selectionToRestrict)
  }
}

#Preview {
  AppCard(pickerPresented: .constant(false), onTap: {})
    .environmentObject(Model())
    .padding()
}
