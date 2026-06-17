//
//  RestrictedAppList.swift
//  ScreenTimeShield
//
//  Vertical icon+name list of restricted tokens. Flexes to fill the space the fixed-height
//  elements leave (frame(maxHeight: .infinity)) and scrolls internally when content overflows,
//  so the whole screen always fits without scrolling.
//

import SwiftUI
import FamilyControls

struct RestrictedAppList: View {
  @EnvironmentObject var model: Model

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
    .frame(maxHeight: .infinity)
  }

  @ViewBuilder
  private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        content()
          .labelStyle(.titleAndIcon)
          .lineLimit(1)
        Spacer(minLength: 0)
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
