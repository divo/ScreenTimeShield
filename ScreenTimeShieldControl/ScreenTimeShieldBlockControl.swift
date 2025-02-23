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
                isOn: value.isRunning,
                action: StartTimerIntent()
            ) { isRunning in
              Label(isRunning ? "On" : "Off", systemImage: isRunning ? "powerplug.fill" : "powerplug")
            }
        }
        .displayName("Focus")
        .description("Block restricted apps for 1 hour")
    }
}

extension ScreenTimeShieldBlockControl {
    struct Value {
      var isRunning: Bool {
        Model.shared.insideInterval
      }
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            ScreenTimeShieldBlockControl.Value(name: configuration.controlName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            return ScreenTimeShieldBlockControl.Value(name: configuration.controlName)
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
