# PROTOTYPE: MVP screens (throwaway, never merge)

Answers the wayfinder ticket [What do the MVP screens look like?](https://github.com/LukGer/shift-calendar/issues/8)
on the map [Map: Shift-aware alarm app MVP](https://github.com/LukGer/shift-calendar/issues/1).

Three structurally different layouts of the same MVP, each covering first-run permissions, mapping Shortcuts to
Shift Types, editing an Alarm Set, the read-only list of upcoming armed alarms, and skipping one Shift.
All data is in-memory stubs: no EventKit, no AlarmKit, nothing persists.

| Variant | Home | Shift Types / Alarm Set | First run |
| --- | --- | --- | --- |
| A · One list | Agenda of all 7 days, swipe to skip | Behind a settings sheet, pushed Form editor | Paged walkthrough, names Shortcuts at the end |
| B · Tabs | Hero card for the next Shift, compact rest of week | Own tab of cards, sheet editor with time wheel | One checklist screen, Shortcuts mapped later |
| C · Week strip | 7-day strip plus the tapped day's detail | Inline, expandable on the same screen | No wall: in-context permission banners |
| **D · B home + A rest (chosen)** | B's next-Shift hero and compact week, gear in the toolbar, no tab bar | A's settings sheet and Form editor | A's paged walkthrough |

## Run

```sh
./run.sh                                   # build, install, launch in the first available iPhone simulator (override with DEVICE_NAME)
./run.sh -variant B -screen editor         # jump straight to a variant and screen
./screenshots.sh                           # capture every variant × screen into screenshots/
```

Switch variants with the floating black bar (or ← / → on a hardware keyboard).
Screens: `onboarding`, `home`, `types`, `editor`. `-page 0-4` picks the onboarding page in variant A.

D's screenshots were taken on the iPhone Duo (the only iPhone the iOS 27.1 simulator runtime supports), so their status bar renders sideways.
