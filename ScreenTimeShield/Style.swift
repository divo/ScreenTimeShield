//
//  Style.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 18/08/2023.
//

import SwiftUI

struct Style {
  static let primaryColor = Color(red: 105 / 255, green: 87 / 255, blue: 232 / 255)
  static let primaryUIColor = UIColor(red: 105 / 255, green: 87 / 255, blue: 232 / 255, alpha: 1.0)
  static let backgroundColor = Color(red: 94 / 255, green: 208 / 255, blue: 250 / 255)
  static let errorColor = Color(red: 248 / 255, green: 106 / 255, blue: 106 / 255)
  static let fontColor = Color(red: 240 / 255, green: 244 / 255, blue: 248 / 255)
  static let fontUIColor = UIColor(red: 240 / 255, green: 244 / 255, blue: 248 / 255, alpha: 1.0)

  /// The brand gradient used on primary buttons, the wordmark, and the schedule fill.
  static let primaryGradient = LinearGradient(colors: [primaryColor, .purple],
                                              startPoint: .leading, endPoint: .trailing)

  /// App wordmark / large title.
  static let titleFont = Font.system(size: 34, weight: .heavy, design: .rounded)

  /// Corner radii (design-system.md: 12 buttons / cards a touch larger).
  enum Radius {
    static let button: CGFloat = 12
    static let card: CGFloat = 16
  }

  /// Spacing scale from design-system.md — use these, not arbitrary values.
  enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
  }
}
