# Shift Calendar

An alarm app for shift workers: it reads upcoming shifts from the calendar and sets the right alarms for them, so nobody has to re-set alarms by hand before each shift.

## Language

**Shift**:
A calendar event the app recognises as a work shift.
_Avoid_: Dienst, appointment, event (when meaning a recognised shift)

**Shift Type**:
A category of Shift (e.g. day shift, night shift), recognised from the event's title shortcut such as "td" or "nd".
_Avoid_: Shift kind, shortcut (the shortcut is how a Shift Type is recognised, not the type itself)

**Alarm Set**:
The ordered group of alarms that belongs to one Shift Type.
_Avoid_: Alarm group, alarm profile

**Arming**:
The app scheduling the Alarm Set for an upcoming Shift, replacing the manual re-setting of alarms.
_Avoid_: Syncing, activating
