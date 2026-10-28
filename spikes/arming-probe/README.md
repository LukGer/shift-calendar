# Arming Probe (throwaway spike)

For [Does Arming run when she stops an alarm on a locked phone?](https://github.com/LukGer/shift-calendar/issues/9). Never merged. It only exists to put facts on that ticket.

Every alarm the probe rings carries a `stopIntent` and an "Arm" `secondaryIntent`. Each one runs what an Arming reconcile would do, with instrumentation:

1. It logs `protectedData`, the app state, the Background App Refresh setting and Low Power Mode.
2. It reads the next 7 days of events through EventKit and logs the calendar count, event count and all-day titles.
3. It cancels the previous batch of 20 alarms and schedules 20 new ones about 30 days out. These stand in for the reconcile and are not meant to ring during the test.
4. If **Each run schedules another** is on (the default), it schedules the next test alarm. You can hear a locked-phone schedule work without opening the app.
5. It logs `alive` every 5 s for 60 s. The last `alive` line shows how long iOS let it run.

Log lines go to `Documents/probe.log`, which the app shows newest first. They also go to the unified log (Console.app, subsystem `ArmingProbe`) in case the file can't be written while the phone is locked.

## Run it

Needs Xcode 26.1+, an iPhone on iOS 26.1+, and any Apple ID (a free Personal Team is enough for a spike).

1. Open `ArmingProbe.xcodeproj`. Under Signing & Capabilities, pick your team. If Xcode rejects the bundle ID, change it to something unique.
2. Plug in the iPhone and press Run. The first time, trust the developer under Settings › General › VPN & Device Management.
3. In the app, tap **Request access** and allow both. Make sure there are a few all-day events in the next week (for example "td", "nd").

### Primary: stop on a locked phone

4. Tap **Schedule test alarm** (1 min), lock the phone, and leave it locked.
5. When it rings, press **Stop** on the Lock Screen. Don't unlock.
6. Wait for the chained alarm (2 min). When it rings, tap **Arm** this time. Don't unlock.
7. Let a third alarm ring, then stop it with a **volume button**.
8. Turn off **Each run schedules another** (or **Cancel all probe alarms**), then **Copy log**.
9. Repeat 4–8 once after force-quitting the app (swipe it away) and once after a **reboot, before the first unlock**. Unlock only after the alarm has rung and been stopped.

### Secondary

10. **Find alarm limit**: logs where `maximumLimitReached` hits, then cancels what it added.
11. **Schedule an existing ID twice**: logs whether the second `schedule` throws or replaces the first.
12. **Schedule update sentinels**, then raise `CURRENT_PROJECT_VERSION` in the target's build settings and press Run again (an in-place update). Reopen the app: the sentinel line should say `3/3 present … running build 2`.
13. **Cancel all probe alarms**, then **Copy log**.

Paste both logs into the ticket.

## Reading the log

- No `[stopIntent …] start` line after a stop: the intent never ran.
- `protectedData=false` with `calendars=0`: the calendar is unreadable while locked.
- `alarmkit error`: scheduling failed from the intent.
- The last `alive` line: the time budget. A run that ends without an `end` line was suspended or killed.
