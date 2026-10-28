# Can an iOS app re-arm alarms in the background when calendar events change?

Research for [#3](https://github.com/LukGer/shift-calendar/issues/3). Researched 2026-10-28 against iOS 26 docs.

Terms (**Shift**, **Shift Type**, **Alarm Set**, **Arming**) are as defined in `GLOSSARY.md`.

Each claim is tagged:

- **[Documented]**: stated by Apple documentation, a WWDC transcript, or an Apple DTS engineer.
- **[Observed]**: third-party reports, App Store listings, or community forum posts. Not a guarantee.
- **[Unverified]**: a plausible inference that no primary source confirms. Prototype before relying on it.

## Short answer

No. iOS has no way to wake an app *because the calendar changed*. EventKit change notifications only reach a process that is already running. Every way of re-Arming without opening the app is opportunistic: the system decides when, or whether, it happens. Robust Arming therefore comes from stacking several triggers that each run an idempotent "re-Arm the next N days" routine:

1. a `BGAppRefreshTask`,
2. an App Intent attached to each alarm's stop button, which runs every time she dismisses an alarm,
3. optionally, a Shortcuts "Time of Day" personal automation.

Alarms that are already scheduled keep firing whether or not the app runs. The risk is **stale** alarms (a moved or deleted Shift still rings), not missing alarms. Alarms run out only if no trigger fires for the whole Arming window.

## 1. EventKit change notifications

- **[Documented]** `EKEventStoreChanged` is "posted whenever changes are made to the Calendar database". Individual changes are not described; you must refetch everything. It is posted on the main actor. ([EKEventStoreChanged](https://developer.apple.com/documentation/eventkit/ekeventstorechangednotification))
- **[Documented]** The docs say nothing about delivery to a suspended or terminated app. EventKit has no counterpart to HealthKit's `enableBackgroundDelivery`, and no API that relaunches an app on a calendar change.
- **[Documented, analogous]** For Darwin notifications, Quinn (Apple DTS) says iOS will not resume an app to deliver one: a suspended app may get it on resume, and a terminated app never does. ([forum 769398](https://developer.apple.com/forums/thread/769398)) No Apple source says the same about `EKEventStoreChanged`, but it is an ordinary in-process `NotificationCenter` notification.
- **[Observed]** A developer forum post: "There's no way to know whether the calendar was updated while your app was closed or backgrounded." The only DTS reply did not dispute or address this. ([forum 817054](https://developer.apple.com/forums/thread/817054))

**Conclusion:** use `EKEventStoreChanged` only to re-Arm while the app happens to be running. Every other trigger must refetch the whole Arming window and diff it against what is armed.

## 2. BGAppRefreshTask / BGProcessingTask

- **[Documented]** The system decides when to launch the task and gives the app "up to 30 seconds of background runtime". ([Choosing background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app))
- **[Documented]** `earliestBeginDate`: "the system doesn't guarantee launching the task at the specified date, but only that it won't begin sooner." ([earliestBeginDate](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate)) This needs the `fetch` background mode. ([BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask))
- **[Documented]** Quinn's "iOS Background Execution Limits" post (last updated 2026-01-09) says:
  - the system "applies a range of heuristics to decide which apps get app refresh time and when";
  - if you expect it "say, every 15 minutes, you'll be disappointed";
  - "there are common scenarios where it won't grant you *any* background execution time at all!"
  - `BGProcessingTask` time is "typically delivered overnight when the user is asleep".

  ([forum 685525](https://developer.apple.com/forums/thread/685525))
- **[Documented]** Force quit: when the user swipes the app away in the app switcher, iOS sets a flag that blocks background launches until she next opens the app manually. Quinn calls this "a clear statement of user intent" with "no documented way for your app to override the user's choice". He also notes that iOS does not always honour the flag, and that the exceptions are undocumented. (same post)
- **[Documented]** `BGContinuedProcessingTask` (new in iOS 26) "starts in the foreground". It shows its progress in a Live Activity, so it cannot wake the app. ([BGContinuedProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask))
- **[Unverified]** How often refresh actually runs. Apple publishes no number. The WWDC20 session "Background execution demystified" (10063), which listed the factors (app usage, Low Power Mode, the Background App Refresh switch, force quit, budgets), is no longer available from Apple, according to Quinn's post. The usual heuristic is that an app the user rarely opens gets little or no refresh time. That works directly against an app she is supposed to never open.

**Conclusion:** schedule a `BGAppRefreshTask` as the baseline trigger, but treat it as unreliable. It could run several times a day or never.

## 3. AlarmKit and App Intents hooks

- **[Documented]** The schedules:
  - **fixed**: a single absolute date, "does not change when device timezone changes";
  - **relative**: a time of day with an optional weekly recurrence.

  ([WWDC25 230 "Wake up to the AlarmKit API"](https://developer.apple.com/videos/play/wwdc2025/230/))

  Shifts are irregular, so Arming means one fixed alarm per alarm in each Shift's Alarm Set. A relative weekly recurrence does not fit a rota.
- **[Documented]** Each alarm can carry a `stopIntent` and a `secondaryIntent`, both `LiveActivityIntent`. "AlarmKit gives you the ability to run your own code when someone taps an alarm button." ([AlarmConfiguration](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration), WWDC25 230)
- **[Documented]** For a `LiveActivityIntent`, "the system launches your app process without opening the app, performs the intent". ([LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent))
- **[Documented]** The secondary intent "is only available after first unlock" (AlarmConfiguration overview; the docs are unclear whether this also covers `stopIntent`).
- **[Documented]** `AlarmManager.alarms` "fetches all alarms from the daemon that belong to the current client". `alarmUpdates` lets the app reconcile with what is actually armed. ([AlarmManager](https://developer.apple.com/documentation/alarmkit/alarmmanager))
- **[Documented]** `AlarmError.maximumLimitReached`: "A maximum number of alarms is already scheduled." **[Unverified]** Apple does not publish the limit. A 7-day window with a 3-alarm Alarm Set is about 21 alarms. Measure the real cap before widening the window.
- **[Documented]** `NSAlarmKitUsageDescription` must be present, or "apps can't schedule alarms with AlarmKit". The user grants authorization once. ([Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit))
- **[Documented]** Quinn's post now lists AlarmKit as the supported route for timer and alarm apps. AlarmKit is a scheduling API, though, not a background-execution API.
- **[Unverified]** That the stop intent's `perform()` gets enough time, and has EventKit access while the device is locked, to fetch the calendar and re-schedule a 7-day window. This is the most valuable trigger, because she stops an alarm before nearly every Shift. **Prototype it first.**

## 4. Other wake-up hooks

| Hook | What is documented | Fit for us |
|---|---|---|
| Shortcuts personal automation, "Time of Day", run without asking | **[Documented]** Automations can be set to "run without asking" ([Shortcuts guide](https://support.apple.com/guide/shortcuts/create-a-new-personal-automation-apd690170742/ios)). Time of Day supports daily repeats ([Event triggers](https://support.apple.com/guide/shortcuts/apd932ff833f/ios)). | A daily "Arm my shifts" App Intent run by the system without opening the app. She does a one-time setup in Shortcuts. **[Observed]** Unreliable when the phone is idle or locked ([forum 665845](https://developer.apple.com/forums/thread/665845); no Apple reply). |
| Shortcuts "Alarm" trigger ("Is Stopped" / "Is Snoozed") | **[Documented]** It applies to Clock app alarms (Any, Existing, Wake-up) ([Event triggers](https://support.apple.com/guide/shortcuts/apd932ff833f/ios)). | **[Unverified]** whether AlarmKit alarms count. The stop intent in section 3 does this job directly. |
| Focus filter (`SetFocusFilterIntent`) | **[Documented]** On a Focus change, `perform()` runs in the app if it is running, otherwise in an extension that gets "spun up" ([WWDC22 10121](https://developer.apple.com/videos/play/wwdc2022/10121/)). | Would ride on a nightly Sleep Focus. **[Unverified]** whether an extension may call AlarmKit or EventKit. Low priority. |
| Widget timeline reloads | **[Documented]** A frequently viewed widget typically gets "40 to 70 refreshes" a day ([Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)). | Only if she keeps the widget visible. **[Unverified]** whether a widget extension can schedule AlarmKit alarms. Useful at least as a "next Shift / armed?" glance. |
| Region monitoring (`CLMonitor`) | **[Documented]** "If an iOS app isn't running when a condition is satisfied, the system tries to launch it", and only after first unlock ([Monitoring proximity to regions](https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions)). | Re-Arm on arriving at or leaving the hospital. Reliable wake, but needs Always location permission (**[Unverified]** on that page) and is a privacy and battery ask. Fallback only. |
| Silent (background) push | **[Documented]** "The system decides when to launch the app". It is rate-limited above 3 per hour and gives 30 s ([Choosing background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)). It is blocked after a force quit (Quinn). | Needs a server that sees calendar changes (only possible if the rota calendar is a remote CalDAV or ICS feed) and the push capability. Overkill for one user. |

## 5. Comparable shipping apps

**[Observed]** only. No app documents its mechanism.

- Supershift: "reads your calendar and sets your alarms automatically every day" (requires iOS 26.2+). ([App Store](https://apps.apple.com/us/app/-/id1104165041))
- KeyAlarm turns calendar events with a keyword into AlarmKit alarms. ([9to5Mac](https://9to5mac.com/2026/09/05/indie-app-spotlight-keyalarm-calendar-events-into-alarms/))
- "Shift Calendar Alarm" syncs alarms for the next 60 days after you save changes in the app, and offers a manual "rebuild". ([App Store](https://apps.apple.com/app/id6760447926))

The 60-day window plus a manual rebuild suggests that at least one competitor arms far ahead and relies on the app being opened, rather than trusting background refresh. Supershift's "every day" wording fits a daily `BGAppRefreshTask`, but that is **[Unverified]**.

## 6. What this means for Arming

**How stale can it get?** Suppose she edits a Shift and never opens the app:

- **Best case:** some trigger runs within hours: a refresh task, the stop intent on her next alarm, or a daily Shortcut.
- **Typical case:** the stop intent fires at her next alarm. The staleness window is "until the next alarm she dismisses", usually under 24 to 48 hours during a working week. **[Unverified]** until prototyped.
- **Worst case:** she force-quits the app, Background App Refresh is off or starved, and she has no alarms for a while (holiday). Nothing runs. Old alarms keep firing on their original times, so a moved or deleted Shift still rings. When the window passes its end, no new alarms exist for Shifts beyond it.

**Danger asymmetry:** a stale alarm that fires on a day off is annoying. A *moved-earlier* Shift with no alarm means she oversleeps. The design should make the second case visible.

**Mitigations:**

1. Make Arming idempotent and full-window. Each run refetches the window, diffs it against `AlarmManager.alarms`, and cancels or schedules to match. Any trigger can then call it.
2. Stack the triggers:
   - `EKEventStoreChanged` while the app is running;
   - a `BGAppRefreshTask`, rescheduled every run;
   - a stop/secondary `LiveActivityIntent` on every alarm;
   - an optional, documented one-time Shortcuts "Time of Day" automation that calls an "Arm Shifts" App Intent.
3. Trade off the window length. A longer window (14 to 30 days) lowers the risk of running out of alarms but leaves more alarms stale. Bound it by the unpublished `maximumLimitReached` cap.
4. Show freshness. The app and any widget show "last Armed at …". A local notification when Arming has not run for more than N days asks her to open the app. Tell her not to force-quit the app.
5. Hold back silent push and region monitoring unless the prototype shows the cheaper triggers are not enough.

## Implications for other decisions

- **Native vs Expo/React Native:** the critical paths are Swift-only system extension points:
  - App Intents (`LiveActivityIntent` stop intent, Shortcuts intent);
  - AlarmKit `AlarmConfiguration`;
  - a widget extension;
  - `BGTaskScheduler` handlers that must finish within 30 s.

  Expo has no official AlarmKit module. Community bindings exist ([react-native-nitro-ios-alarm-kit](https://github.com/Gautham495/react-native-nitro-ios-alarm-kit)) **[Observed]**. `expo-background-task` wraps `BGTaskScheduler` and warns that "short intervals are often ignored" ([Expo docs](https://docs.expo.dev/versions/latest/sdk/background-task/)). Booting a JS runtime inside a 30 s budget, or inside an intent's `perform()`, is extra risk. All of this favours native Swift.
- **Paid developer account:** with free provisioning (Personal Team), "provisioning profiles ... will expire 7 days from issuance. You'll need to rebuild and reinstall your app" ([Compare memberships](https://developer.apple.com/support/compare-memberships/)). An app she never opens has to keep running for months, so a free account is effectively ruled out. TestFlight or ad hoc distribution needs the Apple Developer Program. Silent push would also need it.
- **Arming design:** model Arming as a stateless reconcile (calendar window → desired alarms → diff with `AlarmManager.alarms`). Store Shift-to-alarm mapping in alarm metadata or the alarm ID, so any trigger can reconcile without app state.

## Open questions for a prototype

1. Does a `stopIntent` `perform()` on a locked phone get EventKit read access and enough time to reconcile 7 days?
2. What is the actual `maximumLimitReached` cap?
3. How often does `BGAppRefreshTask` actually run for an app that is rarely opened? Log it on her phone for two weeks.
4. Can a widget or Focus filter extension call AlarmKit?
5. Does a Shortcuts Time of Day automation run an App Intent reliably while the phone is locked?
