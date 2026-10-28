# What can AlarmKit do for a third-party shift alarm app?

Research for [issue #2](https://github.com/LukGer/shift-calendar/issues/2). Gathered 2026-10-28. Terms (Shift, Shift Type, Alarm Set, Arming) are from `GLOSSARY.md`.

## Answer in one line

AlarmKit (iOS 26+) lets a third-party app schedule one-shot alarms at fixed future dates that ring through silent mode and every Focus, that persist across reboot, force quit and crash, and that need only an `Info.plist` string and a one-time user permission. No entitlement and no paid account is required to use the API. Apple publishes no fixed count limit. An app can only list and cancel the alarms it scheduled, and it has to keep its own record of which alarm belongs to which Shift.

## Sources

Primary, in order of trust:

- **[DOC]** Apple Developer Documentation, AlarmKit: <https://developer.apple.com/documentation/alarmkit>, plus the symbol pages cited inline. Read through the DocC JSON at `developer.apple.com/tutorials/data/documentation/alarmkit/...`.
- **[SAMPLE]** Apple sample code article "Scheduling an alarm with AlarmKit": <https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit>
- **[WWDC]** WWDC25 session 230 "Wake up to the AlarmKit API" (transcript): <https://developer.apple.com/videos/play/wwdc2025/230/>
- **[FAQ]** "AlarmKit FAQ", Apple Developer Forums thread 797158, posted by an Apple engineer (DTS, Core Technologies), Aug 2025: <https://developer.apple.com/forums/thread/797158>
- **[ENT]** Forum thread 797950 with an Apple engineer's reply about a made-up AlarmKit entitlement: <https://developer.apple.com/forums/thread/797950>
- **[MEMB]** Apple "Developer account overview / compare memberships": <https://developer.apple.com/support/compare-memberships/>
- **[BG]** Apple BackgroundTasks docs: <https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate>, <https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app>

Lower trust, used only as signals and labelled where cited: Apple forum threads with no Apple reply.

## Findings by sub-question

### 1. Scheduling alarms at fixed future clock times

Yes. `Alarm.Schedule` has two cases [DOC `Alarm.Schedule`]:

- `.fixed(Date)`: "A one-shot alarm that fires at a specific time, not a time relative to the current time zone." [DOC `Alarm.Schedule.fixed(_:)`] The WWDC session adds that it "specifies a single future date … This schedule is absolute and does not change when device timezone changes." [WWDC]
- `.relative(Relative)`: an hour and minute (`Relative.Time(hour:minute:)`) plus a `Recurrence` of `.never` or `.weekly([Locale.Weekday])`. It "accounts for timezone changes." [DOC `Alarm.Schedule.Relative`, `Recurrence`; WWDC]

A relative schedule carries no date, only a time of day and an optional weekly pattern. Shifts fall on irregular dates, so Arming has to use `.fixed(Date)`, with one alarm per alarm in the Alarm Set per Shift. Weekly recurrence does not fit a rota.

You schedule with `AlarmManager.shared.schedule(id: Alarm.ID, configuration:)`. The app picks the ID, a UUID [DOC `schedule(id:configuration:)`; SAMPLE]. Use `AlarmConfiguration.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)` for a classic alarm with no countdown UI [DOC].

### 2. How many alarms can be scheduled at once

There is no documented number. The Apple engineer in [FAQ] says: "There is no set number as a limit, but this does not mean you can schedule a limitless number of alarms. Depending on device state, available resources, etc., the device may impose a limit… When you hit a limit … you will receive the `maximumLimitReached` error." The docs describe that error only as "A maximum number of alarms is already scheduled." [DOC `AlarmManager.AlarmError.maximumLimitReached`]

**Not verified:** the actual ceiling. A rolling 7-day window holds about 7 Shifts × the alarms in each Alarm Set, so roughly 15–30 alarms. Apple neither guarantees nor rules out that number. The app should handle `maximumLimitReached` by arming the nearest Shifts first and telling the user.

### 3. Ringing through silent mode and Focus

Yes. "It overrides both a device's focus and silent mode, if necessary." [SAMPLE] "When it fires, the alert breaks through the silent mode and the current focus." [WWDC] On Focus specifically, the Apple engineer in [FAQ] was asked "Is there a focus mode that AlarmKit cannot break through?" and answered: "No. AlarmKit alarms can break through all focus modes."

The person grants this per app ("People opt in to enable alarm functionality for each app") and can turn it off in Settings [WWDC]. Apple also says alarms "are not a replacement for … critical alerts or time-sensitive notifications" [WWDC]. That is guidance on fit, not a limit, and wake-up-for-a-shift is the use case Apple names ("recurring alerts with a schedule, like a wake-up alarm").

The system forwards the alert to a paired Apple Watch [SAMPLE; WWDC].

### 4. Surviving app kill, reboot and app updates

- **Force quit, crash, reboot:** Yes. [FAQ]: "all alarms are expected to persist regardless of app or device state changes, once they are successfully scheduled." Alarms live in a system daemon, not the app process. The docs describe `alarms` as fetching "from the daemon" [DOC `AlarmManager.alarms`].
- **App updates:** **Not verified.** No primary source names app updates. The FAQ's "regardless of app … state changes" implies they survive, and one unanswered forum post reports alarms ringing even after the app is *deleted* (thread 812273, no Apple reply). This needs a test on device: schedule, update the build, check `alarms`.
- **Hidden or locked apps:** Alarms scheduled by an app the user has hidden, or locked behind Face ID/passcode (the iOS 18 app-lock feature), "will silently fail" [FAQ]. Tell her not to lock or hide the app.
- **Known OS-update bug (low trust):** A forum report says alarm UI strings showed as localization keys after an OS update or restart, fixed by re-scheduling (thread 802740). Re-arming on every app launch covers this.

### 5. Listing, updating and cancelling the app's own alarms

- **List:** `AlarmManager.shared.alarms` (throws) returns all alarms "that belong to the current client" [DOC]. It is scoped to the app, so the app cannot see the built-in Clock alarms or other apps' alarms.
- **Observe:** `alarmUpdates` is an async sequence that emits the full array "when the set of alarms changes", including when an alarm alerts, snoozes or is dismissed [DOC]. An alarm missing from it "is no longer scheduled" [SAMPLE].
- **Cancel:** `cancel(id:)` "Deletes the alarm from the system even if the alarm has a repeating schedule." [DOC]
- **Stop:** `stop(id:)` deletes a one-shot alarm, or moves a repeating one to its next occurrence [DOC]. Also `pause`, `resume`, `countdown(id:)`.
- **Update:** There is no update API. Change an alarm by `cancel(id:)` and then `schedule(...)`. **Not verified:** what `schedule` does when given an ID that already exists. Cancel first.
- **Fired alarms disappear:** "As soon as an alarm fires and stops it's deleted from the daemon's store. If you want to determine if a one-shot alarm has fired, persist your alarms in your own store." [DOC `alarms`] (A forum report, thread 796901 with no Apple reply, says one-shot *relative* alarms sometimes stay listed. Another reason to keep our own store.)
- **Our own mapping:** `Alarm` exposes only `id`, `schedule`, `countdownDuration` and `state` [DOC `Alarm`]. Custom `AlarmMetadata` travels in `AlarmAttributes` for the UI and is not read back from `alarms`. So the app needs its own persisted record of Shift → Alarm Set → alarm IDs to diff against when the calendar changes.

### 6. Authorization flow

- Add `NSAlarmKitUsageDescription` to `Info.plist`. "If the key is missing or its value is an empty string, your app can't schedule alarms with AlarmKit." [DOC `NSAlarmKitUsageDescription`]
- Call `AlarmManager.shared.requestAuthorization()`. It prompts once if no choice has been made yet and returns `.authorized`, `.denied` or `.notDetermined` [DOC `requestAuthorization()`, `AuthorizationState`]. If it is never called, the prompt appears automatically on the first `schedule` [SAMPLE; WWDC].
- Check `authorizationState` or observe `authorizationUpdates` [DOC]. "If a person … denies authorization, all attempts to schedule alarms fail." [DOC] The user can change it in Settings at any time [WWDC].
- Design implication: prompt during first-run setup, while the app is in the foreground, so that background Arming never runs into `.notDetermined`.

### 7. The system UI when an alarm fires

- Full-screen system alert (and Lock Screen, Dynamic Island, StandBy, Apple Watch) showing the **custom title** and **the app's name** [WWDC; SAMPLE]. The title is `AlarmPresentation.Alert(title: LocalizedStringResource, …)` [DOC]. The Shift Type and alarm label can go here, for example "Night shift – leave now".
- **Stop:** provided by the system. Since iOS 26.1 the initializer is `Alert(title:secondaryButton:secondaryButtonBehavior:)` with "a system-provided stop control". The 26.0 `stopButton:` variant is deprecated [DOC `AlarmPresentation.Alert`].
- **One optional secondary button** (`AlarmButton(text:textColor:systemImageName:)`), with a behavior of either:
  - `.countdown`: snooze or repeat. The alarm goes back to a countdown for `CountdownDuration.postAlert` seconds, "the snooze duration for an alarm", and then alerts again [DOC `postAlert`; SAMPLE]. An alarm with a countdown or snooze needs a widget extension with a Live Activity: "AlarmKit expects a widget extension if an app supports a countdown presentation. Otherwise, the system may unexpectedly dismiss alarms and fail to alert." [SAMPLE; WWDC]
  - `.custom`: runs an App Intent, for example "Open" to launch the app [SAMPLE; WWDC]. Secondary intents are "only available after first unlock" [DOC `AlarmConfiguration`].
- **Stop runs app code:** the `stopIntent` set in the configuration is called when the alarm is dismissed, and its `perform` code executes [FAQ Q4]. This is the one documented hook where the app gets to run code because of an alarm, without the user opening it.
- **Hardware buttons:** "Any physical button that causes a reaction from AlarmKit will stop the currently alerting alarm", and pressing one "will dismiss all currently alerting alarms" [FAQ]. Snooze cannot be forced. A volume press counts as stop.
- **Sound:** system default, or a custom sound via ActivityKit's `AlertConfiguration.AlertSound` naming a file "in your app's main bundle or Library/Sounds folder of your app's data container" [WWDC; DOC `alarm(schedule:…sound:)`].
- `tintColor` in `AlarmAttributes` brands the alert and secondary button [DOC; WWDC].
- Two alarms (ours or another app's) at the same minute: which one alerts is "non-deterministic" [FAQ]. Stagger an Alarm Set's alarms by at least a minute.

### 8. Entitlements and the paid Apple Developer Program

- **No entitlement exists for AlarmKit.** Requirements are only the `Info.plist` key and runtime authorization [DOC; SAMPLE; WWDC]. In [ENT] someone added a `com.apple.developer.alarmkit` entitlement, which an LLM had invented, and device builds failed until they removed it. An Apple engineer replied about LLMs "making up non-existent entitlements". Apple's entitlements index lists nothing AlarmKit-related (checked 2026-10-28).
- **Free personal team:** Because no capability is involved, AlarmKit should work on a free "Personal Team" build. **Not verified on a device by a primary source.** The real constraint is the free team itself: "Provisioning profiles that enable apps to be installed on a device will expire 7 days from issuance. You'll need to rebuild and reinstall your app," with at most 3 apps per device and 10 App IDs that expire after 7 days [MEMB].
- **Not verified:** whether alarms already scheduled still ring after the app's free provisioning profile has expired and the app no longer launches. The daemon holds the alarms, so they plausibly do. But a `stopIntent` and any re-Arming could not run, and the 7-day window would drain within a week.
- A countdown or snooze UI needs a widget extension (a second target). **Not verified:** whether a Personal Team can sign that extension. Apple's supported-capabilities matrix (<https://developer.apple.com/help/account/reference/supported-capabilities-ios>) did not render its per-membership columns when fetched.

## Implications for our design

1. **A ~7-day rolling window of fixed-time alarms is supported.** Use `.fixed(Date)` one-shot alarms, one per alarm in the Alarm Set per Shift, and diff them against our own persisted Shift → alarm-ID map. Handle `maximumLimitReached` (no published cap) by arming nearest-first.
2. **They ring through silent mode and every Focus**, after a one-time per-app permission. Ask for it during onboarding.
3. **A paid account is not needed for the API**, but a free Personal Team build expires every 7 days and must be reinstalled from a Mac. For one nurse relying on it, that is the deciding factor for issue #7, not AlarmKit.
4. **Re-Arming without opening the app is outside AlarmKit.** Scheduled alarms persist on their own, but nothing in AlarmKit wakes the app when the calendar changes. `BGAppRefreshTask` timing is not guaranteed ("the system doesn't guarantee launching the task at the specified date") [BG]. The one documented AlarmKit hook is the `stopIntent` running app code each time she dismisses an alarm. That is an opportunistic chance to re-Arm, worth testing in issue #3. **Not verified:** whether EventKit reads and new `schedule` calls succeed from inside that intent while the device is locked.
5. **Keep alarms simple to avoid a widget extension:** with no snooze (`postAlert`) and no countdown, a Stop-only alert, or Stop plus an "Open" custom button, needs no Live Activity. Adding snooze brings in the widget extension.

## Implications for other open tickets

- **#6 Native vs cross-platform:** AlarmKit is a Swift-only framework, and its UI is driven by `LiveActivityIntent` App Intents and, for countdowns, a WidgetKit/ActivityKit extension. Expo has no first-party AlarmKit module (searched docs.expo.dev, none found). Community packages exist but were not evaluated. A React Native or Expo app would need a custom Swift native module plus Swift intents and extensions, so most of the platform-specific code is Swift either way.
- **#7 Distribution:** see implication 3.
- **#3 Background re-arming:** see implication 4.

## Open questions / not verified

- The real alarm-count ceiling on a device.
- Survival of alarms across an app update (implied, not stated).
- Whether alarms keep ringing once a free-team provisioning profile expires.
- Behaviour of `schedule(id:)` with an existing ID.
- Whether `stopIntent` can do EventKit reads and new AlarmKit scheduling before first unlock or while locked.
