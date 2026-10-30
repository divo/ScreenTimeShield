//
//  QAChecklistView.swift
//  ScreenTimeShield
//
//  The device half of qa/iap-test-checklist.md — the cases the simulator can't run. Steps use
//  verbatim text so this QA-only copy stays out of the string catalog. Ticks live in standard
//  UserDefaults, so deleting the app (the restore case) clears them.
//

import SwiftUI

struct QAChecklistView: View {
  private struct QACase: Identifiable {
    let id: String
    let title: String
    let steps: [String]
  }

  private static let cases: [QACase] = [
    QACase(id: "upgradeReminder", title: "Upgrade from build 18 clears the daily reminder (optional)", steps: [
      "Only if this build was installed as an update over build 18, without deleting the app first.",
      "Before updating: on build 18 you set a schedule, pinned Trial expired and opened the app once. That scheduled build 18's daily \"Your blocks are off\" reminder at the schedule's start time.",
      "Open this build once.",
      "Expect: at the next schedule start time, no \"Your blocks are off\" notification arrives.",
      "Do this before Setup, because Setup deletes the app.",
    ]),
    QACase(id: "setup", title: "Setup: fresh TestFlight install", steps: [
      "Delete Unplug, then install this build from TestFlight.",
      "Open QA / Debug and check Real StoreKit state → StoreKit grandfathered = no.",
      "If it reads yes, stop: the paywall is unreachable and the rest of this list is invalid.",
    ]),
    QACase(id: "trialStart", title: "A · Trial starts on arming (steps 2–5)", steps: [
      "The chip reads \"1 days left in trial · Unlock\". \"1 days\" is the known N5 bug.",
      "Tap Choose apps & websites and pick at least one app.",
      "Set a window that includes the current time, then tap Start blocking and confirm.",
      "Expect: it arms with no paywall.",
      "QA / Debug: Access state = trial, Trial days remaining = 1.",
      "On this 1-day build, the trial now ends at midnight at the end of tomorrow, whatever the time is now.",
    ]),
    QACase(id: "shield", title: "B · Shield during the trial (step 10)", steps: [
      "Open an app you blocked.",
      "Expect: the Unplug shield appears, and both of its buttons close it without unlocking.",
    ]),
    QACase(id: "counter", title: "H · Times-stopped counter (step 40)", steps: [
      "QA / Debug → Times stopped → 0.",
      "Open a blocked app 3 or 4 times, at least 1 minute apart (the counter ignores repeats within 60 s).",
      "Expect: QA / Debug → Times stopped has gone up.",
    ]),
    QACase(id: "v19", title: "C · Expired with a block armed (V19, step 15)", steps: [
      "Arm a block whose window starts in a few minutes.",
      "QA / Debug → pin Trial expired.",
      "Expect (known bug V19): the chip reads \"Trial ended\", but the screen still looks armed and offers Stop blocking.",
      "Wait until the window starts, then open a blocked app. Expect: no shield.",
      "Report anything worse than this, such as a crash or a shield that never clears.",
      "To return to a running trial: pin Trial started today, then pin Off.",
    ]),
    QACase(id: "trialEndedNotification", title: "C · Trial ends at midnight, notification at 09:00 (overnight)", steps: [
      "Do this before the purchase: buying cancels the notification.",
      "QA / Debug → pin Last day of trial. Expect: the chip reads \"1 days left\" (N5), and the trial ends at midnight tonight.",
      "Close Unplug and leave it closed overnight.",
      "Expect: no notification at midnight.",
      "Expect: one notification, \"Your Unplug trial has ended\", at 09:00 tomorrow.",
      "Open Unplug. Expect: \"Trial ended\".",
      "Expect: no repeat of the notification the day after. Earlier builds repeated a reminder daily.",
    ]),
    QACase(id: "v20", title: "C · Overnight expiry (V20, step 16, optional)", steps: [
      "Optional, and it takes a day. Do it before the purchase: a purchase makes it impossible.",
      "With pin Off and the real trial running, arm a block.",
      "Don't open Unplug until the day after tomorrow. A trial started today ends at midnight at the end of tomorrow.",
      "Expect (known bug V20): the block still enforces after the trial has ended.",
      "Open Unplug. Expect: \"Trial ended\", and the next block doesn't apply a shield.",
    ]),
    QACase(id: "buy", title: "D · Buy the unlock (steps 17–20, one-way)", steps: [
      "Finish every case above first. A sandbox purchase can't be undone.",
      "QA / Debug → pin Off, then pin Trial expired.",
      "Tap the chip. Expect: the button shows a price, \"Unlock forever ($4.99)\".",
      "Tap it and complete the purchase with your sandbox account.",
      "Expect: the paywall closes by itself, the chip disappears straight away, and QA / Debug shows Override = none. The purchase clears the pin.",
    ]),
    QACase(id: "verify", title: "D · Purchase grants access (steps 21–23)", steps: [
      "QA / Debug: expect StoreKit purchased = yes, StoreKit grandfathered = no, Access state = fullAccess.",
      "Back on the main screen, expect: no trial chip.",
      "The simulator can't do this check, because there grandfathered reads yes.",
    ]),
    QACase(id: "afterBuy", title: "D · Blocking and cold launch after buying (steps 24–25)", steps: [
      "Arm a block that includes now and open a blocked app. Expect: the shield.",
      "Force-quit Unplug and reopen it. Expect: still no chip, and still fullAccess in QA / Debug.",
    ]),
    QACase(id: "offline", title: "D · Offline launch and restore (steps 26–27)", steps: [
      "Turn on airplane mode, force-quit Unplug and reopen it.",
      "Expect: no \"Trial ended\". If it shows, that is known bug V18. Write down what you saw.",
      "Still offline: QA / Debug → Open paywall → Restore Purchase.",
      "Expect: \"No previous purchase found.\" (known V17), and no crash.",
      "Turn airplane mode off.",
    ]),
    QACase(id: "grandfathered", title: "F · Grandfathered pin (step 32)", steps: [
      "QA / Debug → pin Full access — grandfathered.",
      "Expect: no chip, and Start blocking arms a block with no paywall.",
      "QA / Debug → pin Off.",
    ]),
    QACase(id: "restore", title: "E · Restore after reinstall (steps 28–31, do last)", steps: [
      "Do this last: deleting the app also clears the ticks on this screen.",
      "Delete Unplug and reinstall it from TestFlight, signed in to the same sandbox account.",
      "Note how it opens. A trial chip is expected. If it already has full access, StoreKit synced the purchase by itself. That's fine, but note it.",
      "Tap the chip (or QA / Debug → Open paywall) → Restore Purchase.",
      "Expect: the paywall closes, the chip goes, and QA / Debug shows StoreKit purchased = yes.",
    ]),
  ]

  @AppStorage("qa_checklist_done") private var doneRaw = ""

  private var done: Set<String> { Set(doneRaw.split(separator: ",").map(String.init)) }

  private func toggle(_ id: String) {
    var ids = done
    if ids.remove(id) == nil { ids.insert(id) }
    doneRaw = ids.sorted().joined(separator: ",")
  }

  var body: some View {
    List {
      Section {
        Text(verbatim: "\(done.count) of \(Self.cases.count) done. Tap a case to tick it off.")
          .foregroundStyle(.secondary)
      }

      ForEach(Self.cases) { qaCase in
        let isDone = done.contains(qaCase.id)
        Section {
          Button { toggle(qaCase.id) } label: {
            Label {
              Text(verbatim: qaCase.title).fontWeight(.semibold)
            } icon: {
              Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
            }
          }
          if !isDone {
            ForEach(Array(qaCase.steps.enumerated()), id: \.offset) { index, step in
              Text(verbatim: "\(index + 1). \(step)").font(.subheadline)
            }
          }
        }
      }
    }
    .navigationTitle(Text(verbatim: "QA checklist"))
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationView { QAChecklistView() }
}
