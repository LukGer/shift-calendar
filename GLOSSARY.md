# Shift Calendar

An alarm app for shift workers: it reads upcoming shifts from the calendar and sets the right alarms for them, so nobody has to re-set alarms by hand before each shift.

## Language

**Shift**:
A work shift on one date, recognised from an all-day event in one of her chosen calendars whose title is a Shortcut.
_Avoid_: Dienst, appointment, event (when meaning a recognised shift)

**Shift Type**:
A category of Shift (e.g. day shift, night shift), recognised by its Shortcut.
_Avoid_: Shift kind, shortcut (the Shortcut is how a Shift Type is recognised, not the type itself)

**Shortcut**:
The event title that identifies a Shift Type, such as "td" or "nd"; each Shift Type has exactly one.
_Avoid_: Code, abbreviation, tag

**Alarm Set**:
The ordered group of alarms that belongs to one Shift Type.
_Avoid_: Alarm group, alarm profile

**Arming**:
The app scheduling the Alarm Set for an upcoming Shift, replacing the manual re-setting of alarms.
_Avoid_: Syncing, activating

**Arming Window**:
The period ahead, starting now, for which every Shift's Alarm Set is armed; about 7 days.
_Avoid_: Look-ahead, horizon

**Skip**:
Her choice that one Shift rings nothing, tied to that Shift's date and Shift Type.
_Avoid_: Cancel, mute, day off
