# Testing Plan

## Unit tests
- Attendance state transitions (present/absent/late/excused).
- Assessment validation (ayah range vs surah, criteria scores).
- Surah/ayah range validation (1-114, ayah bounds).
- Learning task state machine transitions.
- Role resolution (director/teacher/student; suspended/incomplete).
- Account-linking rules (no duplicate links, no cross-student takeover).
- Enrollment transitions (active/completed/transferred/withdrawn/archived).
- Date and timezone handling (center IANA timezone, not device-local).
- Report calculations (attendance rate denominator, excused treatment).
- Idempotency (outbox operation keys).
- Offline queue behavior (retry, ordering, persistence after restart).

## Widget tests
- Login validation (email trim/format, Arabic messages).
- Role-specific navigation (director/teacher/student shells).
- Teacher dashboard (cards, schedule, follow-ups).
- Student roster (search, filters, open profile).
- Attendance selection (status picker, bulk operations).
- Memorization assessment form (7 steps, save/cancel, unsaved confirmation).
- Learning plan (task list, statuses, actions).
- Director student management (list, filters, add student).
- Account-mode selection (no login / create login).
- Empty and error states.
- Confirmation dialogs (destructive ops).
- Arabic RTL rendering where practical.

## Security tests
Firestore Security Rules unit tests via Firebase Emulator (see security.md, 12 cases).

## Integration tests
End-to-end acceptance scenarios A–F (accountless student, student login, account activation, teaching session, offline operation, authorization switching).

## Model serialization tests
All models: fromJson/toJson round-trip, enum handling, nullable fields.

## Repository tests
Repository implementations against Firestore emulator (queries, pagination, transactions).

## Navigation & role-authorization tests
Route guards prevent unauthorized routes; role shells load correct destinations.

## Rule
Run tests matching each change; report actual pass/fail; never claim unexecuted tests passed.