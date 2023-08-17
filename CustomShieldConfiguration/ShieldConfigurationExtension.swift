//
//  ShieldConfigurationExtension.swift
//  CustomShieldConfiguration
//
//  Created by Steven Diviney on 17/08/2023.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield as needed for applications.
      customShieldConfiguration()
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
      customShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        ShieldConfiguration()
    }
  
  func customShieldConfiguration() -> ShieldConfiguration {
    let primaryLabel = ShieldConfiguration.Label(text: "Restricted", color: UIColor.red)
    let subtitleLabel = ShieldConfiguration.Label(text: "Get up and move", color: UIColor.red)
    
    let primaryButton = ShieldConfiguration.Label(text: "Unlock", color: UIColor.darkGray)
    let secondaryButton = ShieldConfiguration.Label(text: "Close", color: UIColor.red)
    
    return ShieldConfiguration(backgroundBlurStyle: UIBlurEffect.Style.dark,
                               backgroundColor: UIColor.lightGray,
                               icon: UIImage(systemName: "time"),
                               title: primaryLabel,
                               subtitle: subtitleLabel,
                               primaryButtonLabel: primaryButton,
                               primaryButtonBackgroundColor: UIColor.red,
                               secondaryButtonLabel: secondaryButton)
  }
}