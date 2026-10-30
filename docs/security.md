# Security Model

## Principle
Authorization enforced by the backend (Firestore Security Rules + Cloud Functions). Frontend role checks are UI convenience only and never sufficient.

## Roles
- `director`: manages authorized center data and admin functions.
- `teacher`: assigned circles + authorized student records only.
- `student`: own permitted data only.
- `guardian`: reserved for future (narrowly scoped, verified relationship).
- Accountless students: no auth identity; records protected by center/role boundaries.

## Rules (enforced)
1. Never trust a client-supplied `centerId`, role, teacher assignment, or permission claim.
2. Never treat possession of a document ID as authorization.
3. Never expose private teacher notes to students.
4. Never allow a user to grant themselves a role (role written only by trusted provisioning functions/custom claims).
5. Admin SDK bypasses Security Rules — every privileged Cloud Function performs its own authorization.
6. No service account credentials or secrets in client; nothing committed.
7. Cross-center access denied; accountless student records protected; account linking cannot take over another student's identity.

## Security tests to verify
1. Student cannot read another student's private records.
2. Teacher cannot access an unauthorized circle.
3. Teacher cannot grant self director permissions.
4. Student cannot modify official assessment scores.
5. Student cannot modify official attendance.
6. Suspended user cannot access protected data.
7. Cross-center access denied.
8. Accountless student records protected.
9. Account linking cannot take over another student identity.
10. Unauthorized users cannot read by guessing document IDs.
11. Private teacher notes remain private.
12. Financial records inaccessible (module out of scope; reserved).

## Additional controls
- Firebase App Check enabled.
- Rate limiting on auth and callable functions.
- Audit log collection for sensitive operations.
- Secure account provisioning via callable functions (not client-side create).
- Firestore + Storage rules; Emulator Suite for local testing.
- Security Rules tested with firebase emulator unit tests.
---

# Implementation status (updated during Phase 4)

## Enforced and tested

Firestore Security Rules (`firebase/firestore.rules`) are tested against the
real Firestore emulator (`firebase/rules-tests`, 110 tests) and cover:
users, centers, students, teachers, circles, enrollments, schedules,
attendance and audit_logs, including the enrollment-assignment batch and the
rule that director list queries must filter by `centerId`. Everything else is **default deny**.

| Spec case | Where verified |
|---|---|
| Student cannot read another student's records | students / attendance tests |
| Teacher cannot access an unassigned student or circle | students / circles tests |
| Teacher cannot grant themselves director | users tests (`users/*` is client read-only) |
| Student cannot modify attendance | attendance tests |
| Suspended user is locked out | students / attendance tests |
| Cross-center access denied | students / attendance / users tests |
| Accountless student records stay protected | students tests |
| Account linking cannot be forged from a client | students tests (`authUserId`, `accountMode` immutable to clients) |
| Guessing a document id grants nothing | students tests |

Teaching sessions (Phase 5):
* The session's own teacher may move it `scheduled -> inProgress` (not before
  its date) and `inProgress -> completed`, changing nothing else.
* Attendance can be created only for the teacher's own session that is in
  progress; the teacher may fix their own entry (status/note only) until the
  session completes. After that only a director's audited correction works.

Assessments: the session's teacher may record one for their own student while
the session is in progress, with a valid surah (1-114) and ayah range, and may
amend it until the session completes; afterwards it is frozen. Nothing is
deleted.

Learning tasks: a teacher assigns a task to their own student (always created
as `upcoming`, with no practice claim or verification). Only a teacher
verification can complete a task, and it must carry `verifiedBy == auth.uid`
and a truthful result; `completed` and `cancelled` are final; cancelling needs
a reason. `overdue` is derived from the due date and never stored. The
student's own transitions (report practice) are added with the student app.

Student-facing data (Phase 6 groundwork):
* A student may read their own `students/{id}` document, so it holds nothing
  staff-only. The director's note about a student lives in
  `student_admin_notes/{studentId}` (director only); circles no longer carry
  admin notes.
* A student reads the circle and sessions of the circle named in their own
  profile (`currentCircleId`, maintained by enrolment changes) and nothing else.
* A student may start a task and report practice (stored as a *claim*), never
  complete, cancel or return it.

Capacity: each circle carries `activeCount`; assigning, transferring and
archiving update it inside a transaction that re-checks the capacity, and the
rules refuse any write that would push it past `maxCapacity` (proved with two
concurrent real SDK transactions: exactly one commits). An in-progress session
keeps its teacher when a circle's teacher changes, so no hand-over race exists.

Notifications: addressed to one user and readable only by them (not even the
director). A director may notify any active member of the center (announcements,
alerts); a teacher may notify only the login of one of their own students, and
only about tasks. The recipient can only mark a notification read. Messages are
generic: no student detail is placed in a notification. Delivery is in-app;
push (FCM) is not wired.

Key design points:
* `users/{uid}` is written only by the Admin SDK. Role and status are read from
  it (not from client data or stale tokens), so suspension is immediate.
* **Teacher document id == teacher's auth uid** (set at provisioning). Rules
  rely on this to match `assignedTeacherIds` / `recordedBy` without extra reads.
* Attendance document id is `<sessionId>_<studentId>`; rules enforce it, so
  duplicates are impossible and retries are idempotent.
* Only a director can change a recorded attendance value, and the write must
  carry `correctionMetadata.correctedBy == auth.uid`.
* Student `authUserId` / `accountMode` / `centerId` are immutable to clients.
  Logins are created/changed only by the `enableStudentAccess` and
  `setStudentAccessSuspended` Cloud Functions, which authorize from verified
  token claims, refuse to link an already-registered email (no account
  takeover), re-check state inside a transaction, roll back on failure, and
  write an audit entry.

## Known gaps — do not treat as production-ready

1. **Audit atomicity is by convention.** Client-side batches (attendance
   correction, archive, edit, assign) write the change and its audit entry
   together, but rules cannot force the audit write; a modified client could
   skip it. Moving these into Cloud Functions would close this.
2. **Nothing is deployed.** The Cloud Functions are tested end to end on the
   emulators, the rules on the Firestore emulator, but there is no Firebase
   project configured (`firebase_options.dart` is a placeholder).
3. **Director provisioning** is an operator CLI (`docs/operations.md`); there is
   no in-app way to create a director, by design.
4. **App Check, rate limiting and Storage rules** are not configured.
5. **Atomic batch size.** Changing a circle's teacher is one atomic batch for a
   normal circle. A circle needing more than ~450 writes is applied in several
   batches with the circle itself last, so a failure part-way leaves the circle
   on its old teacher and the same save can be repeated safely; it is not
   atomic in that rare case.
6. **Session start date** is checked by the rules (`date <= request.time`); the
   "same day only" restriction is enforced by the app, not the rules.
7. `assertFails` in rules tests also passes when a rule *errors* (the emulator
   evaluates both `create` and `update` for a `set()` on a new document, and
   the `update` branch fails closed). Every allow path has a positive test, so
   no legitimate access is being masked.
8. **Query scoping.** Firestore rejects a list query unless the query itself
   proves the rule, so every director, teacher and student query carries the
   center and the owning id (rules tests show unscoped queries are refused).
   New queries must follow the same pattern.
