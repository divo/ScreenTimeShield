//
//  PaywallView.swift
//  ScreenTimeShield
//
//  Lifetime-unlock paywall. Leads with loss framing and our own "times stopped" stat
//  (shown only when it clears the threshold), not a feature list.
//

import SwiftUI
import StoreKit
import UnplugCore

struct PaywallView: View {
  @EnvironmentObject var access: AccessController
  @Environment(\.dismiss) private var dismiss

  @State private var purchasing = false
  @State private var restoring = false
  @State private var errorMessage: String?

  private var product: Product? { access.storeKit.product }

  private var showStat: Bool {
    StatGate.shouldShowStat(timesStopped: access.timesStopped, threshold: PricingConfig.statThreshold)
  }

  var body: some View {
    ZStack {
      LinearGradient(colors: [.black, Style.primaryColor.opacity(0.35)],
                     startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        HStack {
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white.opacity(0.6))
              .padding(8)
          }
        }
        .padding(.horizontal, 12)

        Spacer()

        Image("unplug")
          .resizable().scaledToFit().frame(width: 64, height: 64)
          .foregroundStyle(.white)

        VStack(spacing: 12) {
          Text("Don't go back.")
            .font(.largeTitle.bold())
            .foregroundStyle(.white)

          if showStat {
            Text("Unplug stopped you \(access.timesStopped) times during your trial.")
              .font(.title3.weight(.medium))
              .foregroundStyle(.white)
              .multilineTextAlignment(.center)
          } else {
            Text("Your blocks are unbypassable — keep them that way.")
              .font(.title3.weight(.medium))
              .foregroundStyle(.white.opacity(0.9))
              .multilineTextAlignment(.center)
          }

          Text("Unlock unbypassable app blocking forever. One-time purchase, no subscription.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)

        Spacer()

        if let message = errorMessage {
          Text(message)
            .font(.footnote)
            .foregroundStyle(Style.errorColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }

        VStack(spacing: 12) {
          Button {
            Task { await buy() }
          } label: {
            HStack {
              if purchasing { ProgressView().tint(.white) }
              Text(buyButtonTitle)
                .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Style.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: Style.Radius.button))
          }
          .disabled(purchasing || product == nil)

          Button {
            Task { await restore() }
          } label: {
            Text(restoring ? "Restoring…" : "Restore Purchase")
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.8))
          }
          .disabled(restoring)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
      }
    }
    .task {
      await access.storeKit.loadProduct()
    }
    .onChange(of: access.accessState) { newValue in
      if newValue == .fullAccess { dismiss() }
    }
  }

  private var buyButtonTitle: String {
    if let price = product?.displayPrice {
      return String(localized: "Unlock forever — \(price)")
    }
    return String(localized: "Unlock forever")
  }

  private func buy() async {
    errorMessage = nil
    purchasing = true
    defer { purchasing = false }
    do {
      let ok = try await access.purchase()
      if ok { dismiss() }
    } catch {
      errorMessage = String(localized: "Purchase failed. Please try again.")
    }
  }

  private func restore() async {
    restoring = true
    defer { restoring = false }
    await access.restore()
    if access.hasFullAccess {
      dismiss()
    } else {
      errorMessage = String(localized: "No previous purchase found.")
    }
  }
}
