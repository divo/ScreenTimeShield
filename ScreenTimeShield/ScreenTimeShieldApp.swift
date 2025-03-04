//
//  ScreenTimeShieldApp.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import SwiftUI
import FamilyControls
import UserNotifications

@main
struct ScreenTimeShieldApp: App {
  
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  
  @StateObject var model = Model.shared
  
  init() {
    configureNavigationBarAppearance()
    requestNotificationPermission()
  }
  
  private func requestNotificationPermission() {
    // Configure notification categories and actions
    configureNotificationCategories()
    
    // Request authorization for notifications
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
      if granted {
        print("Notification permission granted")
      } else if let error = error {
        print("Error requesting notification permission: \(error.localizedDescription)")
      } else {
        print("Notification permission denied")
      }
    }
  }
  
  private func configureNotificationCategories() {
    // Define a category for app usage alerts
    let openAppAction = UNNotificationAction(
      identifier: "OPEN_APP_ACTION",
      title: "Open App",
      options: .foreground
    )
    
    let appUsageCategory = UNNotificationCategory(
      identifier: "APP_USAGE_ALERT",
      actions: [openAppAction],
      intentIdentifiers: [],
      options: []
    )
    
    // Register the category with the notification center
    UNUserNotificationCenter.current().setNotificationCategories([appUsageCategory])
  }
  
  private func configureNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = .systemBackground
    
    // Remove bottom border
    appearance.shadowColor = .clear
    
    // Create gradient for the title
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = CGRect(x: 0, y: 0, width: 300, height: 60) // Large enough for the title
    gradientLayer.colors = [Style.primaryUIColor.cgColor, UIColor.purple.cgColor]
    gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
    gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    
    let renderer = UIGraphicsImageRenderer(bounds: gradientLayer.bounds)
    let gradientImage = renderer.image { ctx in
      gradientLayer.render(in: ctx.cgContext)
    }
    
    let attrs: [NSAttributedString.Key: Any] = [
      .foregroundColor: UIColor(patternImage: gradientImage),
      .font: UIFont.systemFont(ofSize: 34, weight: .bold)
    ]
    
    appearance.largeTitleTextAttributes = attrs
    
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().standardAppearance = appearance
  }
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(model)
    }
  }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    Task {
      await requestFamilyControls()
    }
    
    return true
  }
  
  func requestFamilyControls() async {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    } catch {
      print("Error requesting Family Controls: \(error)")
    }
  }
}
