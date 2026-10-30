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
real Firestore emulator (`firebase/rules-tests`, 61 tests) and cover:
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

1. **Private teacher notes.** `memorization_records` stores `privateTeacherNote`
   next to `studentVisibleFeedback` in one document. Firestore rules cannot hide
   individual fields, so a student allowed to read the document would see the
   private note. The collection is therefore fully denied for now. **Before
   Phase 5/6, move the private note to a separate document/subcollection** (and
   expose student-visible feedback separately).
2. **Audit atomicity is by convention.** The attendance correction writes the
   update and its audit entry in one atomic batch, but rules cannot force the
   audit write. A modified client could skip it. Moving corrections into a
   Cloud Function would close this.
3. **Cloud Functions are type-checked and their rule logic is unit-tested, but
   they have not been run against the Auth/Firestore emulators or deployed.**
4. **Director provisioning** (setting the `role`/`centerId` custom claims and the
   `users/{uid}` profile for the first director) is not implemented.
5. **App Check, rate limiting, Storage rules** are not configured.
6. `assertFails` in rules tests also passes when a rule *errors*. The emulator
   evaluates both `create` and `update` for a `set()` on a new document, and the
   `update` branch errors (null `resource`) and fails closed. Each rule's allow
   path has a positive test, so no legitimate access is being masked.
7. **Query scoping.** Firestore rejects a list query unless the query itself
   proves the rule (`resource.data.centerId == ...`). Every director query on
   enrollments, attendance and audit_logs therefore carries a `centerId` filter
   (rules tests demonstrate that an unscoped query is refused). Teacher-side
   queries (`recordedBy`, `teacherId`) will need the same treatment in Phase 5.
8. **Atomic batch size.** Changing a circle's teacher updates the circle, its
   enrolments, students and upcoming sessions in one batch (Firestore limit 500
   writes). Circles too large for that are refused, not split.
9. **Enrollment capacity** is checked by reading, not in a transaction; two
   directors taking the last seat simultaneously could both succeed.
10. **Student creation** is not written to the audit log (archive, reinstate,
   edit, assign/transfer and access changes are).
11. Teachers/students cannot yet read what they need for several planned
   screens (e.g. a student reading their circle/schedule). Add rules together
   with those features, each with tests.
