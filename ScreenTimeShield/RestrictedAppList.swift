//
//  RestrictedAppList.swift
//  ScreenTimeShield
//
//  EXPERIMENT (uncommitted): vertical icon+name list of restricted tokens with a
//  fixed height, so it scrolls internally while the rest of the screen stays put.
//

import SwiftUI
import FamilyControls

struct RestrictedAppList: View {
  @EnvironmentObject var model: Model
  var height: CGFloat = 200

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(Array(model.selectionToRestrict.applicationTokens), id: \.self) { token in
          row { Label(token) }
        }
        ForEach(Array(model.selectionToRestrict.categoryTokens), id: \.self) { token in
          row { Label(token) }
        }
        ForEach(Array(model.selectionToRestrict.webDomainTokens), id: \.self) { token in
          row { Label(token) }
        }
      }
    }
    .frame(height: height)
  }

  @ViewBuilder
  private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        content()
          .labelStyle(.titleAndIcon)
          .lineLimit(1)
        Spacer(minLength: 0)
        if model.insideInterval {
          Image(systemName: "lock.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 10)
      Divider()
    }
  }
}

#Preview {
  RestrictedAppList()
    .environmentObject(Model())
    .padding()
}
