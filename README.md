# AI School Timetable Generator — Prototype v1.0

A responsive, standalone browser-based school timetable scheduling prototype for a single school with up to 20 class groups.

## Run it

1. Extract the ZIP file.
2. Open `index.html` in a modern browser (Chrome or Edge recommended).
3. Demo data is included so you can explore the interface immediately.
4. Edit teachers, classes, subjects, rooms and lesson assignments, then open **AI Generator** and generate a timetable.

No server installation is required for this prototype. Data is stored in the browser's `localStorage` on that device. Do not clear browser data without downloading a JSON backup.

## Features in this prototype

- Responsive dashboard and school data management.
- Teacher-subject capability mapping and workload limits.
- Class, subject, weekly lesson assignment and room management.
- Constraint-aware timetable generation with multiple randomized attempts and soft scoring.
- Hard conflict validation for class, teacher and room double-booking.
- Class, teacher and room timetable views.
- Print / Save as PDF through the browser print dialog.
- CSV export of generated schedules and exam events.
- Excel workbook import for sheets named `Teachers`, `Classes`, `Subjects`, `Rooms`, and `Assignments`.
- Excel template download (requires internet access for the SheetJS CDN).
- JSON backup and restore.
- Basic exam event planning and duplicate class/room slot checking.

## Workbook columns

- **Teachers:** `name`, `subjects` (comma-separated), `maxDay`, `maxWeek`
- **Classes:** `name`, `grade`, `students`, `room`
- **Subjects:** `name`, `code`
- **Rooms:** `name`, `type`, `capacity`
- **Assignments:** `className`, `subjectName`, `teacherName`, `periods`, `double`

Sheet names are case-insensitive. Column names should match these names.

## Important limitations

This is a functional prototype, not yet a production-grade hosted application. The scheduling engine is a constraint-aware heuristic (greedy candidate placement, randomized attempts, and soft scoring), not a mathematical proof of global optimality. It can report unplaced periods when requirements exceed available capacity or the constraints cannot be satisfied by the heuristic. The `double` assignment preference is stored but not yet enforced as a paired consecutive-period constraint. Exam events are checked for conflicts but are not automatically optimized. Data is local to one browser/device; cloud database, authentication/roles, shared access, audit log, automated server backups, and robust multi-user concurrency are not implemented yet.

For production use, the recommended next phase is a server-backed architecture with PostgreSQL, authentication and role permissions, a proper constraint solver (e.g. OR-Tools CP-SAT), audited manual edits, transactional validation, and hosted backup/restore.


### Default timetable settings
The app is configured for Saturday–Thursday (six days) and seven teaching periods per day. This provides 42 weekly lesson slots per class before any blocked periods are configured. Leave the blocked-period field blank if all seven periods are teaching periods.

## Xeerka isku xigsiinta xiisadaha

- Maaddo leh 3 xiiso toddobaadkii: hal lammaane (2 xiiso oo isku xiga) iyo hal xiiso oo lagu beegayo xiisadda 7aad.
- Maaddo leh 4 xiiso toddobaadkii: laba lammaane oo min 2 xiiso ah.
- Maaddo leh 5 xiiso toddobaadkii: laba lammaane oo min 2 xiiso ah iyo hal xiiso oo lagu beegayo xiisadda 7aad.
- Haddii xeerarkan adag la waafajin kari waayo sababo la xiriira isku-dhac ama waqti aan bannaanayn, generator-ku wuxuu ku soo bandhigayaa warbixinta in qaybtaas aan la meelayn; si aamusan uguma beddelayo hal-hal xiiso.

## Hard lesson-pairing rule

- 3 weekly lessons: one consecutive double + one single lesson in period 7.
- 4 weekly lessons: two consecutive double lessons.
- 5 weekly lessons: two consecutive double lessons + one single lesson in period 7.
- Period 7 must be enabled and cannot be marked as a break when a 3- or 5-period assignment exists.
- If the rule cannot be satisfied, the generator reports an unplaced lesson instead of silently breaking the rule.
