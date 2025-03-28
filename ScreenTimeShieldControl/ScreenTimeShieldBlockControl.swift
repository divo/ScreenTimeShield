//
//  ScreenTimeShieldControlControl.swift
//  ScreenTimeShieldControl
//
//  Created by Steven Diviney on 22/02/2025.
//

import AppIntents
import SwiftUI
import WidgetKit

struct ScreenTimeShieldBlockControl: ControlWidget {
    static let kind: String = "com.halfspud.ScreenTimeShield.ScreenTimeShieldControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Focus for 1 hour",
                isOn: value,
                action: StartTimerIntent()
            ) { isOn in
              Label(isOn ? "On" : "Off", systemImage: isOn ? "powerplug.fill" : "powerplug")
            }
        }
        .displayName("Focus")
        .description("Block restricted apps for 1 hour")
    }
}

extension ScreenTimeShieldBlockControl {
    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Bool {
          print("Control center state preview \(Model.shared.insideInterval)")
          return Model.shared.insideInterval
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Bool {
          print("Control center state \(Model.shared.insideInterval)")
          return Model.shared.insideInterval
        }
    }
}


struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Focus Name Configuration"

    @Parameter(title: "Control Name", default: "Focus")
    var controlName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"
  
    @Parameter(title: "Focus")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
      // Start the timer…
      let model = Model.shared
      
      if model.insideInterval { return .result() }
      print("Press focus control")
                            
      let now = Date()
      let oneHour = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
      Schedule.setSchedule(start: now, end: oneHour, event: model.activityEvent(), repeats: false)
        return .result()
    }
}
