# Architecture and scheduling design

## Product scope

A standalone, responsive school timetable web app for a single school with up to 20 class groups. It manages teachers, teacher-subject capabilities, class groups, subjects, rooms, weekly lesson requirements, generated schedules and exam events.

## Current runnable prototype

- `index.html`: complete browser UI and application logic.
- `README.md`: run instructions, workbook columns and known limitations.
- `schema.sql`: proposed PostgreSQL schema for a production/server-backed version.
- `ARCHITECTURE.md`: system design and solver approach.

The prototype stores its data in browser `localStorage`. It is useful for evaluating workflow and basic scheduling but is not a shared, hosted multi-user system.

## Production architecture

1. **Responsive client:** React or a similar component framework; accessible forms and timetable grid; role-aware pages.
2. **API service:** Node.js/Express with schema validation, authentication, authorization and versioned endpoints.
3. **PostgreSQL:** normalized school, teacher, class, subject, room, requirement, timetable-version, entry, exam and audit tables. Use transactions when publishing a schedule.
4. **Constraint solver:** OR-Tools CP-SAT service or library. Keep the solver deterministic when a seed is provided and save its parameters and validation report.
5. **Document service:** workbook import with row-level error reporting, XLSX exports and server-generated PDF for stable print layouts.
6. **Security/operations:** salted password hashing, secure sessions, per-school authorization, HTTPS, backups, audit trail, monitoring and restore tests.

## Scheduling model

### Decision variable

For each required lesson instance `i`, choose exactly one feasible `(day, period, room)` placement. In a CP-SAT model, this can be represented by Boolean variables `x[i,d,p,r]` or by a slot variable with equivalent constraints.

### Hard constraints

- Every required lesson instance is placed exactly once for a complete timetable.
- A class has at most one lesson in any `(day, period)` slot.
- A teacher has at most one lesson in any `(day, period)` slot.
- A room has at most one lesson in any `(day, period)` slot.
- Teacher is qualified for the assigned subject.
- Teacher unavailability and blocked periods are respected.
- Teacher daily and weekly teaching limits are respected.
- Room capacity and specialist-room requirements are respected.
- Locked lessons remain in their assigned slots during repair/re-optimization.
- Consecutive-period requirements are represented as paired blocks rather than independent periods.

### Soft objectives

Minimize a weighted objective, for example:

`score = w1 * subject_repetition + w2 * teacher_gaps + w3 * class_gaps + w4 * uneven_daily_load + w5 * undesirable_periods + w6 * preference_violations`

Weights must be configurable and visible in the validation report. A lower score is better; hard constraints are never traded off against soft preferences.

### Solver flow

1. Validate imported data and report missing references, teacher-subject mismatches, impossible weekly loads and insufficient room capacity.
2. Expand each requirement into lesson instances; create double-period blocks when required.
3. Generate feasible placements and apply hard constraints.
4. Optimize soft preferences within a time limit.
5. Independently validate the returned schedule in the API layer.
6. Save as a draft timetable version with solver metadata and a structured validation report.
7. Allow a scheduler to inspect/edit; revalidate every edit.
8. Publish only when all hard checks pass; preserve prior published versions.

## Important design note

The current browser prototype uses a constraint-aware greedy heuristic with randomized attempts, not CP-SAT. It is intentionally transparent and does not claim globally optimal scheduling. It reports unplaced periods. The `prefer double periods` flag is stored in this prototype but is not yet enforced as a paired block; production solver implementation must enforce it. Exam planning currently checks class and room slot conflicts but does not automatically optimize exams.


## Default school calendar (Somalia)
- Teaching days: Saturday, Sunday, Monday, Tuesday, Wednesday, Thursday.
- Periods per day: 7.
- Default blocked periods: none, so all 42 weekly slots are available per class. Breaks should be configured as non-teaching time only if they are not counted among the seven lessons.

## Weekly subject pairing constraints

These are HARD constraints, not preferences: 3 periods = one consecutive double plus one single fixed to period 7; 4 periods = two consecutive doubles; 5 periods = two consecutive doubles plus one single fixed to period 7. Period 7 must exist and must not be marked as a blocked/break period whenever any 3- or 5-period assignment exists. Fixed period-7 blocks are scheduled before flexible blocks. If a legal period-7 slot cannot be found, the generator leaves the lesson unplaced and reports the constraint failure; it never moves the leftover single to another period. Validation checks the required 2+1, 2+2, and 2+2+1 grouping patterns and flags non-consecutive doubles.
